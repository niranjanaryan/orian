# Changelog

## Unreleased

- s5cmd/Skyplane-class `Orian.Transfer` + `mix orian` (`cp`, `sync`, `ls`, `rm`, `cat`, `run`)
- Parallel workers, multipart PUT, S3 CopyObject / streamed S3↔S3
- Renamed package **stow → orian**
- `mix bench` writes `benchmark/RESULTS.md` (Zig vs Rust vs OTP)

## 0.1.0

BLAKE3 / XXH3 Zig + Rust NIFs. Memory, S3 (SigV4), and S5 blob backends.
