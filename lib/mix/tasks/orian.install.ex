defmodule Mix.Tasks.Orian.Install do
  @moduledoc "Build escript + NIFs and install `orian` for Linux, macOS, and Windows."
  use Mix.Task
  @shortdoc "Install the orian CLI (all OS)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("orian.build")
    Mix.Task.run("compile")
    Mix.Task.run("escript.build")

    dest = Orian.CLI.Paths.install_escript("orian")
    priv = Orian.CLI.Paths.copy_priv(:orian)
    Mix.shell().info("installed #{dest}")
    Mix.shell().info("NIFs in #{priv}")
    Mix.shell().info(path_hint())
  end

  defp path_hint do
    dir = Orian.CLI.Paths.bin_dir()

    if Orian.CLI.Paths.windows?() do
      "add #{dir} to PATH (Windows: System Properties → Environment Variables)"
    else
      "ensure #{dir} is on PATH"
    end
  end
end
