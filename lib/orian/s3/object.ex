defmodule Orian.S3.Object do
  @moduledoc """
  Key-addressed S3 (path-style or virtual-host). Used by `Orian.Transfer`.
  """

  alias Orian.S3.HTTP
  alias Orian.S3.XML

  def put_object(bucket, key, body, opts) when is_binary(body) do
    {url, path} = target(opts, bucket, key)
    host = Keyword.fetch!(opts, :host)
    headers = [{"content-type", Keyword.get(opts, :content_type, "application/octet-stream")}]
    headers = maybe_meta(headers, body, opts)

    case HTTP.request(:put, url, path, body, headers, Keyword.put(opts, :host, host)) do
      {:ok, code, _, _} when code in 200..299 -> :ok
      {:ok, code, _, body} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_object(bucket, key, opts) do
    {url, path} = target(opts, bucket, key)
    headers = range_hdr(opts)

    case HTTP.request(:get, url, path, "", headers, opts) do
      {:ok, 200, _, body} -> {:ok, body}
      {:ok, 206, _, body} -> {:ok, body}
      {:ok, code, _, body} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_object(bucket, key, opts) do
    {url, path} = target(opts, bucket, key)

    case HTTP.request(:delete, url, path, "", [], opts) do
      {:ok, code, _, _} when code in 200..299 -> :ok
      {:ok, 204, _, _} -> :ok
      {:ok, code, _, body} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def copy_object(src_bucket, src_key, dst_bucket, dst_key, opts) do
    {url, path} = target(opts, dst_bucket, dst_key)
    src = "/" <> src_bucket <> "/" <> src_key
    headers = [{"x-amz-copy-source", URI.encode(src)}]

    case HTTP.request(:put, url, path, "", headers, opts) do
      {:ok, code, _, _} when code in 200..299 -> :ok
      {:ok, code, _, body} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_objects(bucket, prefix, opts) do
    do_list(bucket, prefix, opts, nil, [])
  end

  def put_file(bucket, key, path, opts) do
    if Orian.Engine.loaded?() do
      Orian.Engine.put_file(bucket, key, path, opts)
    else
      part_size = Keyword.get(opts, :part_size, Orian.Perf.part_size())
      conc = Keyword.get(opts, :concurrency, Orian.Perf.concurrency())
      {:ok, %{size: size}} = File.stat(path)

      if size <= part_size do
        put_object(bucket, key, File.read!(path), opts)
      else
        multipart_file(bucket, key, path, size, part_size, conc, opts)
      end
    end
  end

  def get_file(bucket, key, dest, opts) do
    if Orian.Engine.loaded?() do
      Orian.Engine.get_file(bucket, key, dest, opts)
    else
      part_size = Keyword.get(opts, :part_size, Orian.Perf.part_size())
      conc = Keyword.get(opts, :concurrency, Orian.Perf.concurrency())
      File.mkdir_p!(Path.dirname(dest))

      case head_object(bucket, key, opts) do
        {:ok, %{size: size}} when size > part_size ->
          range_get_file(bucket, key, dest, size, part_size, conc, opts)

        _ ->
          case get_object(bucket, key, opts) do
            {:ok, body} -> File.write(dest, body)
            other -> other
          end
      end
    end
  end

  def head_object(bucket, key, opts) do
    {url, path} = target(opts, bucket, key)

    case HTTP.request(:head, url, path, "", [], opts) do
      {:ok, code, headers, _} when code in 200..299 ->
        {:ok, %{size: content_length(headers)}}

      {:ok, code, _, body} ->
        {:error, {code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_list(bucket, prefix, opts, token, acc) do
    query =
      [{"list-type", "2"}, {"prefix", prefix || ""}]
      |> then(fn q -> if token, do: [{"continuation-token", token} | q], else: q end)
      |> URI.encode_query()

    {url, _path} = target(opts, bucket, "")
    url = String.trim_trailing(url, "/")

    case HTTP.request(
           :get,
           url,
           path_root(opts, bucket),
           "",
           [],
           Keyword.put(opts, :query, query)
         ) do
      {:ok, 200, _, xml} ->
        {items, trunc?, next} = XML.list_objects(xml)
        acc = acc ++ items
        if trunc? and next, do: do_list(bucket, prefix, opts, next, acc), else: {:ok, acc}

      {:ok, code, _, body} ->
        {:error, {code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp range_get_file(bucket, key, dest, size, part_size, conc, opts) do
    {:ok, seed} = File.open(dest, [:write, :raw, :binary])
    if size > 0, do: :file.pwrite(seed, size - 1, <<0>>)
    File.close(seed)
    dest_c = String.to_charlist(dest)
    parts = chunk_offsets(size, part_size)

    results =
      parts
      |> Task.async_stream(
        fn {n, off, len} ->
          to = off + len - 1

          case get_object(bucket, key, Keyword.put(opts, :range, {off, to})) do
            {:ok, data} ->
              {:ok, fd} = :file.open(dest_c, [:read, :write, :raw, :binary])
              :ok = :file.pwrite(fd, off, data)
              :file.close(fd)
              {n, :ok}

            {:error, e} ->
              {n, {:error, e}}
          end
        end,
        max_concurrency: conc,
        timeout: Keyword.get(opts, :timeout, 300_000)
      )
      |> Enum.to_list()

    if Enum.any?(results, fn
         {:ok, {_, {:error, _}}} -> true
         {:exit, _} -> true
         _ -> false
       end) do
      {:error, :range_get}
    else
      :ok
    end
  end

  defp multipart_file(bucket, key, path, size, part_size, conc, opts) do
    with {:ok, upload_id} <- initiate_multipart(bucket, key, opts) do
      parts = chunk_offsets(size, part_size)

      results =
        parts
        |> Task.async_stream(
          fn {n, off, len} ->
            {:ok, fd} = :file.open(String.to_charlist(path), [:read, :raw, :binary])
            {:ok, data} = :file.pread(fd, off, len)
            :file.close(fd)
            {n, upload_part(bucket, key, upload_id, n, data, opts)}
          end,
          max_concurrency: conc,
          timeout: Keyword.get(opts, :timeout, 120_000)
        )
        |> Enum.map(fn
          {:ok, {n, {:ok, etag}}} -> {n, etag}
          {:ok, {n, {:error, e}}} -> {n, {:error, e}}
          {:exit, reason} -> {:error, reason}
        end)

      if Enum.any?(results, fn
           {_, {:error, _}} -> true
           {:error, _} -> true
           _ -> false
         end) do
        {:error, {:multipart, results}}
      else
        complete_multipart(bucket, key, upload_id, results, opts)
      end
    end
  end

  defp initiate_multipart(bucket, key, opts) do
    {url, path} = target(opts, bucket, key)

    case HTTP.request(:post, url, path, "", [], Keyword.put(opts, :query, "uploads=")) do
      {:ok, code, _, xml} when code in 200..299 ->
        id = XML.upload_id(xml)
        if id == "", do: {:error, {:no_upload_id, xml}}, else: {:ok, id}

      {:ok, code, _, body} ->
        {:error, {code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upload_part(bucket, key, upload_id, n, data, opts) do
    {url, path} = target(opts, bucket, key)
    query = "partNumber=#{n}&uploadId=#{URI.encode(upload_id)}"

    case HTTP.request(:put, url, path, data, [], Keyword.put(opts, :query, query)) do
      {:ok, code, headers, _} when code in 200..299 ->
        {:ok, XML.etag_from_headers(headers) || Integer.to_string(n)}

      {:ok, code, _, body} ->
        {:error, {code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp complete_multipart(bucket, key, upload_id, parts, opts) do
    xml =
      parts
      |> Enum.sort_by(fn {n, _} -> n end)
      |> Enum.map(fn {n, etag} ->
        "<Part><PartNumber>#{n}</PartNumber><ETag>#{etag}</ETag></Part>"
      end)
      |> then(fn ps ->
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><CompleteMultipartUpload>" <>
          IO.iodata_to_binary(ps) <> "</CompleteMultipartUpload>"
      end)

    {url, path} = target(opts, bucket, key)
    query = "uploadId=" <> URI.encode(upload_id)
    headers = [{"content-type", "application/xml"}]

    case HTTP.request(:post, url, path, xml, headers, Keyword.put(opts, :query, query)) do
      {:ok, code, _, _} when code in 200..299 -> :ok
      {:ok, code, _, body} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp chunk_offsets(size, part_size) do
    n = max(1, div(size + part_size - 1, part_size))

    for i <- 0..(n - 1) do
      off = i * part_size
      len = min(part_size, size - off)
      {i + 1, off, len}
    end
  end

  defp content_length(headers) do
    Enum.find_value(headers, 0, fn {k, v} ->
      if String.downcase(k) == "content-length" do
        String.to_integer(String.trim(v))
      end
    end)
  end

  defp maybe_meta(headers, body, opts) do
    if Keyword.get(opts, :blake3, true) do
      cid = Orian.CID.of(body)

      [
        {"x-amz-meta-blake3", Orian.CID.hex(cid)},
        {"x-amz-meta-xxh3", Integer.to_string(Orian.xxh3(body))}
        | headers
      ]
    else
      headers
    end
  rescue
    _ -> headers
  end

  defp range_hdr(opts) do
    case Keyword.get(opts, :range) do
      {from, to} -> [{"range", "bytes=#{from}-#{to}"}]
      _ -> []
    end
  end

  def target(opts, bucket, key) do
    scheme = Keyword.get(opts, :scheme, "https")
    host = Keyword.fetch!(opts, :host)
    path_style? = Keyword.get(opts, :path_style, true)
    key = key || ""

    if path_style? do
      path = "/" <> bucket <> if(key == "", do: "", else: "/" <> key)
      url = "#{scheme}://#{host}#{path_url(bucket, key)}"
      {url, path_encode(path)}
    else
      path = if key == "", do: "/", else: "/" <> key
      url = "#{scheme}://#{bucket}.#{host}#{path_url("", key)}"
      {url, path_encode(path)}
    end
  end

  defp path_root(opts, bucket) do
    if Keyword.get(opts, :path_style, true), do: "/" <> bucket, else: "/"
  end

  defp path_url(bucket, key) do
    segs =
      [bucket, key]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.flat_map(&String.split(&1, "/", trim: true))
      |> Enum.map(&URI.encode_www_form/1)

    "/" <> Enum.join(segs, "/")
  end

  defp path_encode(path) do
    path
    |> String.split("/")
    |> Enum.map(fn
      "" -> ""
      s -> URI.encode_www_form(s)
    end)
    |> Enum.join("/")
  end
end
