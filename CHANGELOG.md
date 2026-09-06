# Changelog

## 0.1.0 — 2026-09-06

First public Hex release.

* s5cmd/Skyplane-class `orian` CLI (`cp`, `sync`, `ls`, `rm`, `cat`, `run`)
* Rust/Tokio streaming engine — object bytes skip the BEAM
* Zig NIF BLAKE3 (CID) and XXH3 (checksum)
* S3 SigV4 + S5 blob CID; multipart and parallel range GET
* `mix orian.install` → `~/.local/bin/orian`
