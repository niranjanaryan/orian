defmodule Orian do
  @moduledoc """
  Fast blob storage for Elixir.

  **BLAKE3** is the content id (S5 CID, S3 metadata). **XXH3** is the
  non-crypto checksum. Zig NIF is the default; Rust NIF (`Orian.Rs`) is
  the reference implementation (official `blake3` crate).

      {:ok, cid} = Orian.put(body)
      {:ok, ^body} = Orian.get(cid)

      Orian.put(body, backend: :s3, bucket: "b", unsigned: true, host: "127.0.0.1:9000", scheme: "http")
      Orian.put(body, backend: :s5, endpoint: "http://127.0.0.1:5050")

  Clustering stays [Ingot](https://github.com/niranjanaryan/ingot) /
  [Dusk](https://github.com/niranjanaryan/dusk). HTTP/3 is
  [Gale](https://github.com/niranjanaryan/gale).
  """

  defdelegate put(data, opts \\ []), to: Orian.Store
  defdelegate get(cid, opts \\ []), to: Orian.Store
  defdelegate verify(data, cid), to: Orian.Store

  def blake3(bin) when is_binary(bin), do: Orian.Native.blake3(bin)
  def xxh3(bin) when is_binary(bin), do: Orian.Native.xxh3(bin)
  def hash64(bin) when is_binary(bin), do: Orian.Native.hash64(bin)

  def nif_loaded? do
    byte_size(blake3("a")) == 32
  rescue
    _ -> false
  end

  def backends do
    %{
      zig_nif: nif_loaded?(),
      rust_nif: rust_loaded?()
    }
  end

  def rust_loaded? do
    match?(<<_::binary-size(32)>>, Orian.Rs.blake3("a"))
  rescue
    _ -> false
  end
end
