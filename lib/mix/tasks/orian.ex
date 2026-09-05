defmodule Mix.Tasks.Orian do
  @moduledoc "s5cmd-style object transfer. See `Orian.CLI`."
  use Mix.Task
  @shortdoc "cp / sync / ls / rm / cat / run (s5cmd-class)"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    Orian.CLI.main(args)
  end
end
