defmodule Orian.S3.XML do
  @moduledoc false

  def list_objects(xml) when is_binary(xml) do
    keys =
      Regex.scan(~r/<Contents>[\s\S]*?<\/Contents>/, xml)
      |> Enum.map(fn [block] ->
        %{
          key: tag(block, "Key"),
          size: tag(block, "Size") |> to_int(),
          etag: tag(block, "ETag") |> strip_quotes(),
          last_modified: tag(block, "LastModified")
        }
      end)

    truncated? = String.contains?(xml, "<IsTruncated>true</IsTruncated>")
    token = tag(xml, "NextContinuationToken")
    token = if token == "", do: nil, else: token
    {keys, truncated?, token}
  end

  def upload_id(xml), do: tag(xml, "UploadId")

  def etag_from_headers(headers) do
    headers
    |> Enum.find_value(fn
      {k, v} ->
        if String.downcase(to_string(k)) == "etag", do: to_string(v)

      _ ->
        nil
    end)
  end

  defp tag(xml, name) do
    case Regex.run(~r/<#{name}>([\s\S]*?)<\/#{name}>/, xml, capture: :all_but_first) do
      [v] -> unescape(v)
      _ -> ""
    end
  end

  defp unescape(s) do
    s
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  defp strip_quotes(s), do: s |> String.trim() |> String.trim("\"")
  defp to_int(""), do: 0
  defp to_int(s), do: String.to_integer(s)
end
