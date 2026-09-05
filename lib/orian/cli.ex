defmodule Orian.CLI do
  @moduledoc """
  s5cmd-style CLI. `mix orian cp|sync|ls|rm|run|cat`.
  """

  @help """
  orian — fast object transfer (s5cmd / Skyplane class)

    mix orian cp   SRC DST
    mix orian sync SRC DST
    mix orian ls   LOC
    mix orian rm   LOC
    mix orian cat  LOC
    mix orian run  FILE   # one command per line, parallel

  SRC/DST: local path, glob, s3://bucket/key, gs://bucket/key

  Flags:
    --numworkers N     parallel objects (default: max(32, schedulers*8))
    --concurrency N    parallel parts per object (default 16)
    --part-size MiB    multipart / range size (default 16)
    --endpoint-url URL S3-compatible endpoint
    --region R
    --unsigned
    --dry-run
    --no-blake3

  Env: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_ENDPOINT_URL
  """

  def main(args) do
    {opts, rest, _} =
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
          help: :boolean
        ],
        aliases: [h: :help, n: :numworkers, c: :concurrency]
      )

    if opts[:help] or rest == [] do
      Mix.shell().info(@help)
      :ok
    else
      kw = to_kw(opts)
      dispatch(rest, kw)
    end
  end

  defp dispatch(["cp", src, dst | _], kw), do: print_stats(Orian.Transfer.cp(src, dst, kw))
  defp dispatch(["sync", src, dst | _], kw), do: print_stats(Orian.Transfer.sync(src, dst, kw))

  defp dispatch(["ls", loc | _], kw) do
    case Orian.Transfer.ls(loc, kw) do
      {:ok, items} ->
        Enum.each(items, fn %{key: k, size: s} -> Mix.shell().info("#{s}\t#{k}") end)
        :ok

      {:error, e} ->
        Mix.shell().error(inspect(e))
        {:error, e}
    end
  end

  defp dispatch(["rm", loc | _], kw) do
    case Orian.Transfer.rm(loc, kw) do
      :ok -> :ok
      other -> Mix.shell().error(inspect(other))
    end
  end

  defp dispatch(["cat", loc | _], kw) do
    u = Orian.URI.parse(loc)

    cond do
      Orian.URI.local?(u) ->
        Mix.shell().info(File.read!(u.path))

      Orian.URI.objectstore?(u) ->
        case Orian.S3.Object.get_object(u.bucket, u.key, s3_from(kw, u)) do
          {:ok, body} -> IO.binwrite(:stdio, body)
          {:error, e} -> Mix.shell().error(inspect(e))
        end
    end
  end

  defp dispatch(["run", file | _], kw) do
    lines =
      file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    workers = Keyword.get(kw, :numworkers, 32)

    results =
      lines
      |> Task.async_stream(
        fn line ->
          argv = OptionParser.split(line)
          main(argv)
        end,
        max_concurrency: workers,
        timeout: :infinity
      )
      |> Enum.to_list()

    Mix.shell().info("run #{length(results)} commands")
    :ok
  end

  defp dispatch(_, _) do
    Mix.shell().info(@help)
    :ok
  end

  defp print_stats({:ok, %{dry_run: true, jobs: jobs}}) do
    Enum.each(jobs, fn j -> Mix.shell().info("dry #{j.src.raw} -> #{j.dst.raw}") end)
    :ok
  end

  defp print_stats({:ok, %{ok: ok, error: err}}) do
    Mix.shell().info("ok=#{ok} error=#{err}")
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
      blake3: Keyword.get(opts, :blake3, true)
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp host_of(url) do
    uri = Elixir.URI.parse(url)
    h = uri.host || url
    if uri.port, do: "#{h}:#{uri.port}", else: h
  end

  defp s3_from(kw, _u), do: kw
end
