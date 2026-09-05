defmodule Orian.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    start_httpc()

    Supervisor.start_link([], strategy: :one_for_one, name: Orian.Supervisor)
  end

  defp start_httpc do
    case :inets.start(:httpc, profile: Orian.Perf.http_profile()) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, :already_started} -> :ok
      other -> other
    end

    :httpc.set_options(Orian.Perf.httpc_options(), Orian.Perf.http_profile())
  rescue
    _ -> :ok
  end
end
