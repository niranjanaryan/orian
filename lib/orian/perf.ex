defmodule Orian.Perf do
  @moduledoc """
  Throughput knobs. High performance is the default.

  * `numworkers` — parallel objects (s5cmd `--numworkers`)
  * `concurrency` — parallel parts of one object (s5cmd `--concurrency`)
  * `part_size` — multipart / range chunk size
  """

  def numworkers do
    Application.get_env(:orian, :numworkers, max(32, System.schedulers_online() * 8))
  end

  def concurrency do
    Application.get_env(:orian, :concurrency, 16)
  end

  def part_size do
    Application.get_env(:orian, :part_size, 16 * 1024 * 1024)
  end

  def http_profile, do: :orian

  def httpc_options do
    [
      max_sessions: 512,
      max_keep_alive_length: 4096,
      keep_alive_timeout: 120_000,
      pipeline_timeout: 0,
      socket_opts: [nodelay: true, sndbuf: 2_097_152, recbuf: 2_097_152]
    ]
  end
end
