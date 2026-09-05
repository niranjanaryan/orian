defmodule Orian.URI do
  @moduledoc """
  Object locations: local paths, `s3://`, `gs://` (S3-compat), `s5://`.
  """

  defstruct [:scheme, :bucket, :key, :path, :endpoint, :raw]

  def parse(str) when is_binary(str) do
    cond do
      String.starts_with?(str, "s3://") -> parse_s3(:s3, str)
      String.starts_with?(str, "gs://") -> parse_s3(:gs, str)
      String.starts_with?(str, "s5://") -> parse_s5(str)
      true -> %__MODULE__{scheme: :file, path: str, raw: str}
    end
  end

  def objectstore?(%__MODULE__{scheme: s}), do: s in [:s3, :gs]
  def local?(%__MODULE__{scheme: :file}), do: true
  def local?(_), do: false

  def join(%__MODULE__{scheme: :file, path: path}, rel) do
    %__MODULE__{scheme: :file, path: Path.join(path, rel), raw: Path.join(path, rel)}
  end

  def join(%__MODULE__{scheme: sch, bucket: b, key: key} = u, rel) when sch in [:s3, :gs] do
    k =
      [key || "", rel]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("/")
      |> String.trim("/")

    %{u | key: k, raw: "#{sch}://#{b}/#{k}"}
  end

  def dir?(%__MODULE__{scheme: :file, path: path}) do
    String.ends_with?(path, "/") or File.dir?(path)
  end

  def dir?(%__MODULE__{key: key}) do
    key in [nil, ""] or String.ends_with?(key || "", "/")
  end

  defp parse_s3(scheme, str) do
    rest = str |> String.split("://", parts: 2) |> List.last()
    {bucket, key} = split_bucket(rest)
    %__MODULE__{scheme: scheme, bucket: bucket, key: key, raw: str}
  end

  defp parse_s5("s5://" <> rest) do
    %__MODULE__{scheme: :s5, endpoint: "http://" <> rest, raw: "s5://" <> rest}
  end

  defp split_bucket(rest) do
    case String.split(rest, "/", parts: 2) do
      [bucket] -> {bucket, ""}
      [bucket, key] -> {bucket, key}
    end
  end
end
