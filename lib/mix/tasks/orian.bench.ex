defmodule Mix.Tasks.Orian.Bench do
  @moduledoc false
  use Mix.Task
  @shortdoc "BLAKE3 / XXH3 / store throughput (Zig vs Rust vs OTP)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    unless Orian.nif_loaded?() do
      Mix.raise("Zig NIF not loaded; mix orian.build first")
    end

    rust? = Orian.rust_loaded?()
    {os, otp} = :os.type()

    header = [
      "# Orian / Orian hash + store bench",
      "",
      "Machine: #{os} #{otp} OTP #{:erlang.system_info(:otp_release)} #{:erlang.system_info(:system_architecture)}",
      "Date: #{Date.utc_today()}",
      "Zig NIF: yes. Rust NIF (official blake3 crate): #{rust?}",
      "",
      "## Hash throughput",
      "",
      "| size | zig blake3 | rust blake3 | zig xxh3 | rust xxh3 | otp sha256 |",
      "| ---: | ---: | ---: | ---: | ---: | ---: |"
    ]

    sizes = [
      {64, 50_000},
      {1_024, 20_000},
      {65_536, 2_000},
      {1_048_576, 64},
      {8_388_608, 8}
    ]

    hash_rows =
      Enum.map(sizes, fn {size, n} ->
        payload = :crypto.strong_rand_bytes(size)
        zb = mibs(size, n, fn -> Orian.blake3(payload) end)
        rb = if rust?, do: mibs(size, n, fn -> Orian.Rs.blake3(payload) end), else: nil
        zx = mibs(size, n, fn -> Orian.xxh3(payload) end)
        rx = if rust?, do: mibs(size, n, fn -> Orian.Rs.xxh3(payload) end), else: nil
        sh = mibs(size, n, fn -> :crypto.hash(:sha256, payload) end)

        Mix.shell().info(
          "#{fmt_size(size)}  zig-b3 #{fmt(zb)}  rust-b3 #{fmt(rb)}  zig-x #{fmt(zx)}  rust-x #{fmt(rx)}  sha256 #{fmt(sh)} MiB/s"
        )

        "| #{fmt_size(size)} | #{fmt(zb)} | #{fmt(rb)} | #{fmt(zx)} | #{fmt(rx)} | #{fmt(sh)} |"
      end)

    blob = :crypto.strong_rand_bytes(1_048_576)
    n_store = 64
    put_us = time(n_store, fn -> {:ok, _} = Orian.put(blob) end)
    {:ok, cid} = Orian.put(blob)
    get_us = time(n_store, fn -> {:ok, _} = Orian.get(cid) end)
    put_m = mibs_from_us(1_048_576, n_store, put_us)
    get_m = mibs_from_us(1_048_576, n_store, get_us)

    Mix.shell().info(
      "store put #{fmt(put_m)} MiB/s  get #{fmt(get_m)} MiB/s (1 MiB × #{n_store}, memory)"
    )

    agree =
      if rust? do
        sample = "orian bench"

        Orian.blake3(sample) == Orian.Rs.blake3(sample) and
          Orian.xxh3(sample) == Orian.Rs.xxh3(sample)
      else
        false
      end

    rest = [
      "",
      "## Memory store (ETS, BLAKE3 CID)",
      "",
      "| op | size | throughput |",
      "| --- | ---: | ---: |",
      "| put | 1 MiB | #{fmt(put_m)} MiB/s |",
      "| get + verify | 1 MiB | #{fmt(get_m)} MiB/s |",
      "",
      "## Digest agreement",
      "",
      "Zig BLAKE3 == Rust BLAKE3 (and XXH3): **#{agree}**.",
      "",
      "BLAKE3 is the content id. XXH3 is checksum-only. OTP SHA-256 is the S3 SigV4 floor, not a CID.",
      "",
      "## Local transfer (`Orian.cp`)",
      "",
      transfer_section(),
      ""
    ]

    File.mkdir_p!("benchmark")
    body = Enum.join(header ++ hash_rows ++ rest, "\n")
    File.write!("benchmark/RESULTS.md", body)
    Mix.shell().info("wrote benchmark/RESULTS.md")
  end

  defp mibs(size, n, fun) do
    fun.()
    us = time(n, fun)
    mibs_from_us(size, n, us)
  end

  defp mibs_from_us(_size, _n, us) when us <= 0, do: 0.0

  defp mibs_from_us(size, n, us) do
    bytes = size * n
    bytes / 1_048_576 / (us / 1_000_000)
  end

  defp time(n, fun) do
    t0 = System.monotonic_time(:microsecond)
    for _ <- 1..n, do: fun.()
    System.monotonic_time(:microsecond) - t0
  end

  defp fmt(nil), do: "n/a"
  defp fmt(x) when is_float(x), do: :io_lib.format("~.1f", [x]) |> IO.iodata_to_binary()

  defp transfer_section do
    root = Path.join(System.tmp_dir!(), "orian-bench-#{System.unique_integer([:positive])}")
    src = Path.join(root, "src")
    dst = Path.join(root, "dst")
    File.mkdir_p!(src)
    payload = :crypto.strong_rand_bytes(1_048_576)

    for i <- 1..32 do
      File.write!(Path.join(src, "f#{i}.bin"), payload)
    end

    {us, {:ok, %{ok: 32}}} =
      :timer.tc(fn -> Orian.cp(Path.join(src, "*"), dst <> "/", numworkers: 32) end)

    mibs = 32 / (us / 1_000_000)
    Mix.shell().info("local cp 32×1 MiB  #{fmt(mibs)} MiB/s  workers=32")
    File.rm_rf(root)

    "| 32 × 1 MiB files | #{fmt(mibs)} MiB/s |"
  end

  defp fmt_size(n) when n < 1024, do: "#{n} B"
  defp fmt_size(n) when n < 1_048_576, do: "#{div(n, 1024)} KiB"
  defp fmt_size(n), do: "#{div(n, 1_048_576)} MiB"
end
