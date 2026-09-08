defmodule Mix.Tasks.Orian.Install do
  @moduledoc "Install orian: Burrito single binary if possible, else escript."
  use Mix.Task
  @shortdoc "Install the orian CLI (single binary or escript)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    case maybe_burrito() do
      {:ok, src} ->
        dest = Orian.CLI.Paths.install_bin(src, "orian")
        Mix.shell().info("installed single binary #{dest}")

      :error ->
        Mix.Task.run("orian.build")
        Mix.Task.run("escript.build")
        dest = Orian.CLI.Paths.install_escript("orian")
        priv = Orian.CLI.Paths.copy_priv(:orian)
        Mix.shell().info("installed escript #{dest} (needs escript on PATH)")
        Mix.shell().info("NIFs in #{priv}")
        Mix.shell().info("for a single binary: zig 0.15 + xz, then mix orian.binary")
    end

    Mix.shell().info("bin dir #{Orian.CLI.Paths.bin_dir()}")
  end

  defp maybe_burrito do
    Mix.Task.run("orian.binary")

    case Path.wildcard("burrito_out/orian_*") do
      [f | _] -> {:ok, f}
      _ -> :error
    end
  rescue
    e ->
      Mix.shell().error("burrito: #{Exception.message(e)}")
      :error
  end
end
