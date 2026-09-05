defmodule Stow.Native do
  @moduledoc "Zig NIF: BLAKE3, XXH3, FNV-1a hash64."
  @on_load :load_nif

  def load_nif do
    path =
      case :code.priv_dir(:stow) do
        {:error, _} -> Path.expand("../../priv/stow_nif", __DIR__)
        dir -> Path.join(dir, "stow_nif")
      end

    :erlang.load_nif(String.to_charlist(path), 0)
  rescue
    _ -> :ok
  end

  def blake3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def xxh3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def hash64(_bin), do: :erlang.nif_error(:nif_not_loaded)
end
