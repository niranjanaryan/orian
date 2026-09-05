# Changelog

## Unreleased

- Production hash path is Zig NIF (won 1–8 MiB benches); Tokio engine stays for transfer
- Standalone `orian` CLI (`mix orian.install` → `~/.local/bin/orian`)
- Rust/Tokio streaming engine (`bulk`/`put_file`/`get_file`/`pipe`) — bytes skip the BEAM
- Throughput defaults: dirty-CPU NIFs, httpc keep-alive pool, parallel range GET, 16 MiB parts
- s5cmd/Skyplane-class `Orian.Transfer` + `mix orian` (`cp`, `sync`, `ls`, `rm`, `cat`, `run`)
- Parallel workers, multipart PUT, S3 CopyObject / streamed S3↔S3
- Renamed package **stow → orian**
- `mix bench` writes `benchmark/RESULTS.md` (Zig vs Rust vs OTP)

## 0.1.0

BLAKE3 / XXH3 Zig + Rust NIFs. Memory, S3 (SigV4), and S5 blob backends.
