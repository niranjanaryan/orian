defmodule Mix.Tasks.Orian do
  @moduledoc "Orian CLI. Same as the `orian` escript."
  use Mix.Task
  @shortdoc "orian cp|sync|ls|rm|cat|run"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    Orian.CLI.main(args, halt: false)
  end
end
