defmodule Mix.Tasks.Stow.Bench do
  @moduledoc false
  use Mix.Task
  @shortdoc "Compare Zig vs Rust BLAKE3/XXH3 throughput"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    payload = :crypto.strong_rand_bytes(1_048_576)
    n = 32

    zig_b3 = time(n, fn -> Stow.blake3(payload) end)
    rust_b3 = if Stow.rust_loaded?(), do: time(n, fn -> Stow.Rs.blake3(payload) end), else: nil
    zig_x = time(n, fn -> Stow.xxh3(payload) end)
    rust_x = if Stow.rust_loaded?(), do: time(n, fn -> Stow.Rs.xxh3(payload) end), else: nil
    sha = time(n, fn -> :crypto.hash(:sha256, payload) end)

    mb = n * 1.0
    Mix.shell().info("1 MiB × #{n}")
    Mix.shell().info("  zig  blake3  #{fmt(mb, zig_b3)} MiB/s")
    Mix.shell().info("  rust blake3  #{fmt(mb, rust_b3)} MiB/s")
    Mix.shell().info("  zig  xxh3    #{fmt(mb, zig_x)} MiB/s")
    Mix.shell().info("  rust xxh3    #{fmt(mb, rust_x)} MiB/s")
    Mix.shell().info("  otp  sha256  #{fmt(mb, sha)} MiB/s")
  end

  defp time(n, fun) do
    fun.()
    t0 = System.monotonic_time(:microsecond)
    for _ <- 1..n, do: fun.()
    System.monotonic_time(:microsecond) - t0
  end

  defp fmt(_mb, nil), do: "n/a"

  defp fmt(mb, us) when us > 0 do
    :io_lib.format("~.1f", [mb / (us / 1_000_000)]) |> IO.iodata_to_binary()
  end
end
