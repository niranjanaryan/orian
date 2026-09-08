defmodule Orian.Presets.Stacks do
  @moduledoc """
  Stacks-specific transfer presets for Orian.

  Provides optimized transfer configurations for:
  - Stacks node snapshot backups/restores
  - sBTC relay state sync
  """

  @doc """
  Preset for Stacks node snapshot backups.

  Optimized for large chain-data directories with BLAKE3 content IDs.
  """
  def node_snapshot do
    %{
      numworkers: 16,
      concurrency: 8,
      part_size: 64 * 1_048_576,
      blake3: true,
      filter: ~r(/stacks/node/db/.*)
    }
  end

  @doc """
  Preset for sBTC relay state sync.

  Optimized for small, frequent relay DB snapshots.
  """
  def relay_state do
    %{
      numworkers: 4,
      concurrency: 4,
      part_size: 16 * 1_048_576,
      blake3: true,
      filter: ~r(/sbtc/relay/.*)
    }
  end

  @doc """
  Apply a preset to transfer options.

  Merges preset defaults with user-provided options.
  """
  def apply(preset, user_opts) when is_map(preset) and is_list(user_opts) do
    preset
    |> Map.to_list()
    |> Keyword.merge(user_opts)
  end
end
