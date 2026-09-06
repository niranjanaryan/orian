defmodule Orian.Native do
  @moduledoc "Zig NIF: BLAKE3, XXH3, FNV-1a hash64."
  @on_load :load_nif

  def load_nif do
    Enum.find_value(nif_candidates(), fn path ->
      case :erlang.load_nif(String.to_charlist(path), 0) do
        :ok -> true
        {:error, _} -> false
      end
    end)

    :ok
  rescue
    _ -> :ok
  end

  defp nif_candidates do
    _ = Code.ensure_loaded(Orian.CLI.Paths)

    app =
      case :code.priv_dir(:orian) do
        {:error, _} -> []
        dir -> [Path.join(dir, "orian_nif")]
      end

    env = System.get_env("ORIAN_PRIV")
    env = if env, do: [Path.join(env, "orian_nif")], else: []
    script = escript_priv()

    app ++
      env ++
      Orian.CLI.Paths.nif_dirs(:orian, "orian_nif") ++
      script ++
      [Path.expand("../../priv/orian_nif", __DIR__)]
  end

  defp escript_priv do
    case :escript.script_name() do
      :undefined ->
        []

      name ->
        dir = name |> to_string() |> Path.dirname()
        [Path.join(dir, "priv/orian_nif"), Path.join([dir, "..", ".orian", "priv", "orian_nif"])]
    end
  rescue
    _ -> []
  end

  def blake3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def xxh3(_bin), do: :erlang.nif_error(:nif_not_loaded)
  def hash64(_bin), do: :erlang.nif_error(:nif_not_loaded)
end
