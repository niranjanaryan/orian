defmodule Orian.S3.HTTP do
  @moduledoc false

  def request(method, url, path, body, headers0, opts) do
    host = Keyword.fetch!(opts, :host)
    region = Keyword.get(opts, :region, "us-east-1")
    query = Keyword.get(opts, :query, "")
    timeout = Keyword.get(opts, :timeout, 120_000)
    body = body || ""

    headers =
      [{"host", host} | headers0]
      |> maybe_sign(opts, method, path, query, body, region)

    url = if query == "", do: url, else: url <> "?" <> query
    http_opts = [timeout: timeout] ++ ssl_opts(opts)

    case do_req(method, url, headers, body, http_opts) do
      {:ok, {{_, code, _}, resp_headers, resp_body}} ->
        {:ok, code, stringify_headers(resp_headers), IO.iodata_to_binary(resp_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_req(:get, url, headers, _body, http_opts) do
    :httpc.request(:get, {String.to_charlist(url), encode_headers(headers)}, http_opts, [])
  end

  defp do_req(:head, url, headers, _body, http_opts) do
    :httpc.request(:head, {String.to_charlist(url), encode_headers(headers)}, http_opts, [])
  end

  defp do_req(:delete, url, headers, _body, http_opts) do
    :httpc.request(:delete, {String.to_charlist(url), encode_headers(headers)}, http_opts, [])
  end

  defp do_req(method, url, headers, body, http_opts) when method in [:put, :post] do
    ctype =
      Enum.find_value(headers, ~c"application/octet-stream", fn {k, v} ->
        if String.downcase(k) == "content-type", do: String.to_charlist(v)
      end)

    :httpc.request(
      method,
      {String.to_charlist(url), encode_headers(headers), ctype, body},
      http_opts,
      []
    )
  end

  defp maybe_sign(headers, opts, method, path, query, body, region) do
    if Keyword.get(opts, :unsigned, false) do
      headers
    else
      case {Keyword.get(opts, :access_key_id), Keyword.get(opts, :secret_access_key)} do
        {ak, sk} when is_binary(ak) and is_binary(sk) ->
          sign(
            method,
            path,
            query,
            headers,
            body,
            region,
            ak,
            sk,
            Keyword.get(opts, :session_token)
          )

        _ ->
          headers
      end
    end
  end

  defp sign(method, path, query, headers, payload, region, ak, sk, token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    datestamp = Calendar.strftime(now, "%Y%m%d")
    payload_hash = sha256_hex(payload)

    headers =
      headers
      |> put_hdr("x-amz-date", amz_date)
      |> put_hdr("x-amz-content-sha256", payload_hash)
      |> then(fn h -> if token, do: put_hdr(h, "x-amz-security-token", token), else: h end)

    signed_names =
      headers
      |> Enum.map(fn {k, _} -> String.downcase(k) end)
      |> Enum.sort()
      |> Enum.uniq()

    canonical_headers =
      signed_names
      |> Enum.map(fn n -> n <> ":" <> hdr_value(headers, n) <> "\n" end)
      |> IO.iodata_to_binary()

    signed_headers = Enum.join(signed_names, ";")
    method_s = method |> Atom.to_string() |> String.upcase()
    canon_q = canonicalize_query(query)

    canonical =
      method_s <>
        "\n" <>
        path <>
        "\n" <>
        canon_q <>
        "\n" <>
        canonical_headers <>
        "\n" <>
        signed_headers <>
        "\n" <> payload_hash

    scope = datestamp <> "/" <> region <> "/s3/aws4_request"

    string_to_sign =
      "AWS4-HMAC-SHA256\n" <> amz_date <> "\n" <> scope <> "\n" <> sha256_hex(canonical)

    sig = hmac_hex(aws_signing_key(sk, datestamp, region, "s3"), string_to_sign)

    auth =
      "AWS4-HMAC-SHA256 Credential=#{ak}/#{scope}, SignedHeaders=#{signed_headers}, Signature=#{sig}"

    put_hdr(headers, "authorization", auth)
  end

  defp canonicalize_query(""), do: ""

  defp canonicalize_query(q) do
    q
    |> URI.decode_query()
    |> Enum.sort_by(fn {k, _} -> k end)
    |> URI.encode_query()
  end

  defp aws_signing_key(secret, date, region, service) do
    ("AWS4" <> secret)
    |> hmac(date)
    |> hmac(region)
    |> hmac(service)
    |> hmac("aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp hmac_hex(key, data), do: Base.encode16(hmac(key, data), case: :lower)
  defp sha256_hex(data), do: Base.encode16(:crypto.hash(:sha256, data), case: :lower)

  defp put_hdr(headers, k, v),
    do: [
      {k, v} | Enum.reject(headers, fn {hk, _} -> String.downcase(hk) == String.downcase(k) end)
    ]

  defp hdr_value(headers, name) do
    {_, v} = Enum.find(headers, fn {k, _} -> String.downcase(k) == name end)
    v
  end

  defp encode_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(to_string(v))} end)
  end

  defp stringify_headers(headers) do
    Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp ssl_opts(opts) do
    if Keyword.get(opts, :insecure, false) do
      [ssl: [verify: :verify_none]]
    else
      []
    end
  end
end
