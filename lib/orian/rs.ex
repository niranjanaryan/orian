defmodule Orian.Rs do
  @moduledoc """
  Rust NIF: official `blake3` crate + `xxhash-rust` XXH3.

  Built by rustler. Use for benches and as a second implementation;
  `Orian.blake3/1` stays on the Zig NIF.
  """
  use Rustler, otp_app: :orian, crate: :orian_nif, path: "native/rust"

  def blake3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def xxh3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def bulk(_jobs, _conc), do: :erlang.nif_error(:nif_not_loaded)
  def put_file(_url, _path, _headers), do: :erlang.nif_error(:nif_not_loaded)
  def get_file(_url, _path, _headers), do: :erlang.nif_error(:nif_not_loaded)
  def pipe(_su, _sh, _du, _dh), do: :erlang.nif_error(:nif_not_loaded)
  def engine_loaded, do: false
end
