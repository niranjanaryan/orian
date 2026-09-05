defmodule Orian.CLI do
  @moduledoc """
  Standalone CLI (`orian`) and Mix task (`mix orian`).
  """

  @version Mix.Project.config()[:version]

  @help """
  orian #{@version} — fast object transfer (s5cmd / Skyplane class)

    orian cp   SRC DST
    orian sync SRC DST
    orian ls   LOC
    orian rm   LOC
    orian cat  LOC
    orian run  FILE
    orian version

  SRC/DST: path, glob, s3://bucket/key, gs://bucket/key

  Flags:
    --numworkers N      parallel objects
    --concurrency N     parts per object
    --part-size MiB     multipart / range size
    --endpoint-url URL  S3-compatible endpoint
    --region R
    --unsigned
    --dry-run
    --blake3            write x-amz-meta-blake3
    -h, --help

  Env: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_ENDPOINT_URL

  Install: mix orian.install   (escript → ~/.local/bin/orian)
  """

  def main(args), do: main(args, halt: !mix?())

  def main(args, opts) do
    _ = Application.ensure_all_started(:orian)

    {parsed, rest, _} =
      OptionParser.parse(args,
        strict: [
          numworkers: :integer,
          concurrency: :integer,
          part_size: :integer,
          endpoint_url: :string,
          region: :string,
          unsigned: :boolean,
          dry_run: :boolean,
          blake3: :boolean,
          help: :boolean,
          version: :boolean
        ],
        aliases: [h: :help, n: :numworkers, c: :concurrency, v: :version]
      )

    result =
      cond do
        parsed[:help] == true ->
          info(@help)
          :ok

        parsed[:version] == true or rest == ["version"] ->
          info("orian #{@version}")
          :ok

        rest == [] ->
          info(@help)
          :ok

        true ->
          dispatch(rest, to_kw(parsed))
      end

    finish(result, Keyword.get(opts, :halt, false))
  end

  defp dispatch(["cp", src, dst | _], kw), do: print_stats(Orian.Transfer.cp(src, dst, kw))
  defp dispatch(["sync", src, dst | _], kw), do: print_stats(Orian.Transfer.sync(src, dst, kw))

  defp dispatch(["ls", loc | _], kw) do
    case Orian.Transfer.ls(loc, kw) do
      {:ok, items} ->
        Enum.each(items, fn %{key: k, size: s} -> info("#{s}\t#{k}") end)
        :ok

      {:error, e} ->
        err(inspect(e))
        {:error, e}
    end
  end

  defp dispatch(["rm", loc | _], kw) do
    case Orian.Transfer.rm(loc, kw) do
      :ok -> :ok
      other -> err(inspect(other))
    end
  end

  defp dispatch(["cat", loc | _], kw) do
    u = Orian.URI.parse(loc)

    cond do
      Orian.URI.local?(u) ->
        IO.binwrite(:stdio, File.read!(u.path))
        :ok

      Orian.URI.objectstore?(u) ->
        case Orian.S3.Object.get_object(u.bucket, u.key, kw) do
          {:ok, body} ->
            IO.binwrite(:stdio, body)
            :ok

          {:error, e} ->
            err(inspect(e))
            {:error, e}
        end
    end
  end

  defp dispatch(["run", file | _], kw) do
    lines =
      file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.reject(&(String.starts_with?(&1, "#") or String.trim(&1) == ""))

    workers = Keyword.get(kw, :numworkers, Orian.Perf.numworkers())

    results =
      lines
      |> Task.async_stream(
        fn line ->
          argv = OptionParser.split(line)
          main(argv, halt: false)
        end,
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.to_list()

    info("run #{length(results)} commands")
    :ok
  end

  defp dispatch(_, _) do
    info(@help)
    :ok
  end

  defp print_stats({:ok, %{dry_run: true, jobs: jobs}}) do
    Enum.each(jobs, fn j -> info("dry #{j.src.raw} -> #{j.dst.raw}") end)
    :ok
  end

  defp print_stats({:ok, %{ok: ok, error: err}}) do
    info("ok=#{ok} error=#{err}")
    if err > 0, do: {:error, err}, else: :ok
  end

  defp to_kw(opts) do
    endpoint = opts[:endpoint_url]
    host = if endpoint, do: host_of(endpoint)

    [
      numworkers: opts[:numworkers],
      concurrency: opts[:concurrency],
      part_size: if(opts[:part_size], do: opts[:part_size] * 1_048_576),
      host: host,
      region: opts[:region],
      unsigned: opts[:unsigned] || false,
      dry_run: opts[:dry_run] || false,
      blake3: opts[:blake3] || false
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp host_of(url) do
    uri = Elixir.URI.parse(url)
    h = uri.host || url
    if uri.port, do: "#{h}:#{uri.port}", else: h
  end

  defp info(msg), do: IO.puts(msg)
  defp err(msg), do: IO.puts(:stderr, msg)

  defp mix? do
    Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :get, 0)
  rescue
    _ -> false
  end

  defp finish(:ok, false), do: :ok
  defp finish({:error, _} = e, false), do: e
  defp finish(:ok, true), do: System.halt(0)
  defp finish(_, true), do: System.halt(1)
end
