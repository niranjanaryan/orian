defmodule Orian.Engine do
  @moduledoc """
  Rust/Tokio transfer engine. Bytes never enter the BEAM.

  Streaming PUT/GET with a process-wide connection pool. This is the
  50–100× path versus copying whole objects through `:httpc`.
  """

  alias Orian.S3.HTTP
  alias Orian.S3.Object

  def loaded? do
    match?({:ok, 0, 0}, Orian.Rs.bulk([], 1))
  rescue
    _ -> false
  end

  def put_file(bucket, key, path, opts) do
    {url, canon} = Object.target(opts, bucket, key)

    {url, headers} =
      HTTP.prepare(
        :put,
        url,
        canon,
        content_type(opts),
        Keyword.put(opts, :payload_hash, :unsigned)
      )

    Orian.Rs.put_file(url, Path.expand(path), headers)
  end

  def get_file(bucket, key, dest, opts) do
    {url, canon} = Object.target(opts, bucket, key)
    {url, headers} = HTTP.prepare(:get, url, canon, [], opts)
    File.mkdir_p!(Path.dirname(dest))
    Orian.Rs.get_file(url, Path.expand(dest), headers)
  end

  def pipe(src_bucket, src_key, dst_bucket, dst_key, src_opts, dst_opts) do
    {surl, spath} = Object.target(src_opts, src_bucket, src_key)
    {durl, dpath} = Object.target(dst_opts, dst_bucket, dst_key)
    {surl, sh} = HTTP.prepare(:get, surl, spath, [], src_opts)

    {durl, dh} =
      HTTP.prepare(
        :put,
        durl,
        dpath,
        content_type(dst_opts),
        Keyword.put(dst_opts, :payload_hash, :unsigned)
      )

    Orian.Rs.pipe(surl, sh, durl, dh)
  end

  def bulk(jobs, concurrency) when is_list(jobs) do
    encoded =
      Enum.map(jobs, fn {op, url, path, headers} ->
        {to_string(op), url, path, headers}
      end)

    case Orian.Rs.bulk(encoded, concurrency) do
      {:ok, ok, err} -> {:ok, %{ok: ok, error: err}}
      other -> other
    end
  end

  def encode_put(bucket, key, path, opts) do
    {url, canon} = Object.target(opts, bucket, key)

    {url, headers} =
      HTTP.prepare(
        :put,
        url,
        canon,
        content_type(opts),
        Keyword.put(opts, :payload_hash, :unsigned)
      )

    {"put", url, Path.expand(path), headers}
  end

  def encode_get(bucket, key, dest, opts) do
    {url, canon} = Object.target(opts, bucket, key)
    {url, headers} = HTTP.prepare(:get, url, canon, [], opts)
    {"get", url, Path.expand(dest), headers}
  end

  defp content_type(opts) do
    [{"content-type", Keyword.get(opts, :content_type, "application/octet-stream")}]
  end
end
