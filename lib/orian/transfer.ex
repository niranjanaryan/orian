defmodule Orian.Transfer do
  @moduledoc """
  Parallel copy/sync like **s5cmd** (`--numworkers`, `--concurrency`) and
  Skyplane-style bulk object movement (client-side; no gateway VMs yet).

      Orian.Transfer.cp("data/*", "s3://bucket/prefix/", numworkers: 32)
      Orian.Transfer.sync("s3://src/p/", "s3://dst/p/")
  """

  alias Orian.URI, as: Loc
  alias Orian.S3.Object

  def cp(src, dst, opts \\ []) do
    jobs = plan_cp(src, dst, opts)
    run_jobs(jobs, opts)
  end

  def sync(src, dst, opts \\ []) do
    jobs = plan_sync(src, dst, opts)
    run_jobs(jobs, opts)
  end

  def ls(loc, opts \\ []) do
    u = Loc.parse(loc)

    cond do
      Loc.local?(u) ->
        paths = local_list(u.path)
        {:ok, Enum.map(paths, &%{key: &1, size: file_size(&1)})}

      Loc.objectstore?(u) ->
        Object.list_objects(u.bucket, u.key, s3_opts(u, opts))

      true ->
        {:error, :unsupported}
    end
  end

  def rm(loc, opts \\ []) do
    u = Loc.parse(loc)

    cond do
      Loc.local?(u) ->
        File.rm(u.path)

      Loc.objectstore?(u) ->
        Object.delete_object(u.bucket, u.key, s3_opts(u, opts))

      true ->
        {:error, :unsupported}
    end
  end

  def plan_cp(src, dst, opts \\ []) do
    src_u = Loc.parse(src)
    dst_u = Loc.parse(dst)
    sources = expand_src(src_u, opts)

    Enum.map(sources, fn {rel, su} ->
      du = dest_for(dst_u, rel, length(sources) > 1 or Loc.dir?(dst_u))
      %{op: :cp, src: su, dst: du, rel: rel}
    end)
  end

  def plan_sync(src, dst, opts \\ []) do
    src_u = Loc.parse(src)
    dst_u = Loc.parse(dst)
    sources = expand_src(src_u, opts)
    dest_keys = dest_index(dst_u, opts)

    sources
    |> Enum.reject(fn {rel, su} ->
      Map.get(dest_keys, rel) == size_of(su)
    end)
    |> Enum.map(fn {rel, su} ->
      du = dest_for(dst_u, rel, true)
      %{op: :cp, src: su, dst: du, rel: rel}
    end)
  end

  defp run_jobs(jobs, opts) do
    workers = Keyword.get(opts, :numworkers, Orian.Perf.numworkers())
    dry? = Keyword.get(opts, :dry_run, false)

    if dry? do
      {:ok, %{ok: 0, error: 0, jobs: jobs, dry_run: true}}
    else
      stats =
        if Orian.Engine.loaded?() do
          run_engine(jobs, workers, opts)
        else
          run_beam(jobs, workers, opts)
        end

      :telemetry.execute(
        [:orian, :transfer, :done],
        %{ok: stats.ok, error: stats.error},
        %{}
      )

      {:ok, stats}
    end
  end

  defp run_engine(jobs, workers, opts) do
    {native, rest} = Enum.split_with(jobs, &native_job?/1)

    native_jobs =
      Enum.map(native, fn job -> encode_native(job, opts) end)
      |> Enum.reject(&is_nil/1)

    beam =
      run_beam(
        rest ++ Enum.filter(native, fn j -> is_nil(encode_native(j, opts)) end),
        workers,
        opts
      )

    eng =
      if native_jobs == [] do
        %{ok: 0, error: 0, errors: []}
      else
        case Orian.Engine.bulk(native_jobs, workers) do
          {:ok, %{ok: ok, error: err}} -> %{ok: ok, error: err, errors: []}
          {:error, e} -> %{ok: 0, error: length(native_jobs), errors: [e]}
        end
      end

    %{
      ok: beam.ok + eng.ok,
      error: beam.error + eng.error,
      errors: (beam[:errors] || []) ++ eng.errors
    }
  end

  defp native_job?(%{src: src, dst: dst}) do
    (Loc.local?(src) and Loc.objectstore?(dst)) or (Loc.objectstore?(src) and Loc.local?(dst))
  end

  defp native_job?(_), do: false

  defp encode_native(%{src: src, dst: dst}, opts) do
    cond do
      Loc.local?(src) and Loc.objectstore?(dst) ->
        Orian.Engine.encode_put(dst.bucket, dst.key, src.path, s3_opts(dst, opts))

      Loc.objectstore?(src) and Loc.local?(dst) ->
        File.mkdir_p!(Path.dirname(dst.path))
        Orian.Engine.encode_get(src.bucket, src.key, dst.path, s3_opts(src, opts))

      true ->
        nil
    end
  rescue
    _ -> nil
  end

  defp run_beam(jobs, workers, opts) do
    jobs
    |> Task.async_stream(
      fn job -> exec(job, opts) end,
      max_concurrency: max(workers, 1),
      timeout: Keyword.get(opts, :timeout, 300_000),
      ordered: false
    )
    |> Enum.reduce(%{ok: 0, error: 0, errors: []}, fn
      {:ok, :ok}, acc -> %{acc | ok: acc.ok + 1}
      {:ok, {:error, e}}, acc -> %{acc | error: acc.error + 1, errors: [e | acc.errors]}
      {:exit, e}, acc -> %{acc | error: acc.error + 1, errors: [e | acc.errors]}
    end)
  end

  defp exec(%{src: src, dst: dst}, opts) do
    cond do
      Loc.local?(src) and Loc.local?(dst) ->
        File.mkdir_p!(Path.dirname(dst.path))

        :file.copy(String.to_charlist(src.path), String.to_charlist(dst.path))
        |> case do
          {:ok, _} -> :ok
          {:error, e} -> {:error, e}
        end

      Loc.local?(src) and Loc.objectstore?(dst) ->
        Object.put_file(dst.bucket, dst.key, src.path, s3_opts(dst, opts))

      Loc.objectstore?(src) and Loc.local?(dst) ->
        Object.get_file(src.bucket, src.key, dst.path, s3_opts(src, opts))

      Loc.objectstore?(src) and Loc.objectstore?(dst) ->
        same_host? = s3_host(src, opts) == s3_host(dst, opts)

        if same_host? do
          Object.copy_object(src.bucket, src.key, dst.bucket, dst.key, s3_opts(dst, opts))
        else
          if Orian.Engine.loaded?() do
            Orian.Engine.pipe(
              src.bucket,
              src.key,
              dst.bucket,
              dst.key,
              s3_opts(src, opts),
              s3_opts(dst, opts)
            )
          else
            with {:ok, body} <- Object.get_object(src.bucket, src.key, s3_opts(src, opts)) do
              Object.put_object(dst.bucket, dst.key, body, s3_opts(dst, opts))
            end
          end
        end

      true ->
        {:error, {:unsupported_pair, src.scheme, dst.scheme}}
    end
  end

  defp expand_src(%Loc{scheme: :file, path: path}, _opts) do
    paths =
      if String.contains?(path, ["*", "?"]) do
        Path.wildcard(path)
      else
        if File.dir?(path), do: wildcard_dir(path), else: [path]
      end

    base = common_prefix(paths)

    Enum.map(paths, fn p ->
      rel = relative(base, p)
      {rel, %Loc{scheme: :file, path: p, raw: p}}
    end)
  end

  defp expand_src(%Loc{scheme: sch, bucket: b, key: key} = u, opts) when sch in [:s3, :gs] do
    prefix = key |> String.replace("*", "") |> String.replace("?", "")

    case Object.list_objects(b, prefix, s3_opts(u, opts)) do
      {:ok, items} ->
        Enum.map(items, fn %{key: k} ->
          rel = relative(prefix, k)
          {rel, %Loc{scheme: sch, bucket: b, key: k, raw: "#{sch}://#{b}/#{k}"}}
        end)

      {:error, _} ->
        [{key, u}]
    end
  end

  defp dest_for(dst, rel, as_dir?) do
    if as_dir? or Loc.dir?(dst), do: Loc.join(dst, rel), else: dst
  end

  defp dest_index(%Loc{scheme: :file, path: path}, _opts) do
    if File.dir?(path) do
      path
      |> wildcard_dir()
      |> Map.new(fn p -> {relative(path, p), file_size(p)} end)
    else
      %{}
    end
  end

  defp dest_index(%Loc{scheme: sch, bucket: b, key: key} = u, opts) when sch in [:s3, :gs] do
    case Object.list_objects(b, key, s3_opts(u, opts)) do
      {:ok, items} -> Map.new(items, fn %{key: k, size: s} -> {relative(key, k), s} end)
      _ -> %{}
    end
  end

  defp dest_index(_, _), do: %{}

  defp size_of(%Loc{scheme: :file, path: p}), do: file_size(p)
  defp size_of(_), do: nil

  defp wildcard_dir(path) do
    Path.wildcard(Path.join(path, "**/*")) |> Enum.filter(&File.regular?/1)
  end

  defp local_list(path) do
    if File.dir?(path), do: wildcard_dir(path), else: Path.wildcard(path)
  end

  defp file_size(p) do
    case File.stat(p) do
      {:ok, %{size: s}} -> s
      _ -> 0
    end
  end

  defp common_prefix([]), do: ""

  defp common_prefix([p | _] = paths) do
    if Enum.all?(paths, &String.contains?(&1, "/")) do
      Path.dirname(p)
    else
      "."
    end
  end

  defp relative(base, path) do
    base = String.trim_trailing(base || "", "/")
    path = String.trim_leading(path, "/")

    cond do
      base in ["", ".", nil] -> path
      String.starts_with?(path, base <> "/") -> String.replace_prefix(path, base <> "/", "")
      true -> Path.basename(path)
    end
  end

  defp s3_opts(u, opts) do
    host = s3_host(u, opts)

    [
      host: host,
      region: Keyword.get(opts, :region, System.get_env("AWS_REGION") || "us-east-1"),
      scheme: Keyword.get(opts, :scheme, default_scheme(host)),
      path_style: Keyword.get(opts, :path_style, true),
      unsigned: Keyword.get(opts, :unsigned, false),
      access_key_id: Keyword.get(opts, :access_key_id, System.get_env("AWS_ACCESS_KEY_ID")),
      secret_access_key:
        Keyword.get(opts, :secret_access_key, System.get_env("AWS_SECRET_ACCESS_KEY")),
      session_token: Keyword.get(opts, :session_token, System.get_env("AWS_SESSION_TOKEN")),
      concurrency: Keyword.get(opts, :concurrency, Orian.Perf.concurrency()),
      part_size: Keyword.get(opts, :part_size, Orian.Perf.part_size()),
      timeout: Keyword.get(opts, :timeout, 300_000),
      insecure: Keyword.get(opts, :insecure, false),
      blake3: Keyword.get(opts, :blake3, false)
    ]
  end

  defp s3_host(%Loc{scheme: :gs}, opts),
    do: Keyword.get(opts, :host, System.get_env("AWS_ENDPOINT_URL") || "storage.googleapis.com")

  defp s3_host(_, opts) do
    Keyword.get(opts, :host) ||
      endpoint_host(System.get_env("AWS_ENDPOINT_URL")) ||
      "s3.amazonaws.com"
  end

  defp endpoint_host(nil), do: nil

  defp endpoint_host(url) do
    uri = Elixir.URI.parse(url)
    host = uri.host || url
    if uri.port, do: "#{host}:#{uri.port}", else: host
  end

  defp default_scheme(host) do
    if String.contains?(host, "localhost") or String.starts_with?(host, "127."),
      do: "http",
      else: "https"
  end
end
