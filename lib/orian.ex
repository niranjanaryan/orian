defmodule Orian do
  @moduledoc """
  Fast object transfer and content-addressed storage — **s5cmd** / **Skyplane** class.

      mix orian cp data/* s3://bucket/prefix/
      mix orian sync s3://src/ s3://dst/
      Orian.Transfer.cp("data/*", "s3://bucket/", numworkers: 64, concurrency: 8)

  Workers for many objects (`numworkers`), multipart parts per object
  (`concurrency`). BLAKE3 is the content id; XXH3 is checksum-only.

      {:ok, cid} = Orian.put(body)

  Clustering stays [Ingot](https://github.com/niranjanaryan/ingot) /
  [Dusk](https://github.com/niranjanaryan/dusk). HTTP/3 is
  [Gale](https://github.com/niranjanaryan/gale).
  """

  defdelegate put(data, opts \\ []), to: Orian.Store
  defdelegate get(cid, opts \\ []), to: Orian.Store
  defdelegate verify(data, cid), to: Orian.Store
  defdelegate cp(src, dst, opts \\ []), to: Orian.Transfer
  defdelegate sync(src, dst, opts \\ []), to: Orian.Transfer

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
