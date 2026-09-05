defmodule Stow.Rs do
  @moduledoc """
  Rust NIF: official `blake3` crate + `xxhash-rust` XXH3.

  Built by rustler. Use for benches and as a second implementation;
  `Stow.blake3/1` stays on the Zig NIF.
  """
  use Rustler, otp_app: :stow, crate: :stow_nif, path: "native/rust"

  def blake3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def xxh3(_bin), do: :erlang.nif_error(:nif_not_loaded)
end
