# Orian

[![Hex.pm](https://img.shields.io/hexpm/v/orian.svg)](https://hex.pm/packages/orian)
[![Hexdocs](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/orian)
[![CI](https://github.com/niranjanaryan/orian/actions/workflows/ci.yml/badge.svg)](https://github.com/niranjanaryan/orian/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub-ea4aaa.svg)](https://github.com/sponsors/niranjanaryan)

Fast object transfer for Elixir — **s5cmd** / **Skyplane** class, plus BLAKE3 content ids.

```
gale   — Phoenix HTTP/3
ingot  — Iroh + Zenoh cluster (Hex: `ingot_cluster`)
dusk   — Zenoh + Iroh cluster
orian  — parallel S3/S5 transfer
zeiroh — Phoenix FLAME overlay
```

```elixir
{:orian, "~> 0.1"}
```

```bash
# from this repo
mix orian.install          # ~/.local/bin/orian  +  ~/.orian/priv NIFs

orian cp   data/*       s3://bucket/prefix/
orian sync s3://src/p/  s3://dst/p/
orian ls   s3://bucket/
orian --dry-run cp data/ s3://bucket/
orian run  jobs.txt
orian version
```

Inside a Mix project that depends on Orian: `mix orian cp …` (same CLI).

```elixir
Orian.Transfer.cp("data/*", "s3://bucket/", numworkers: 64, concurrency: 8)
```

| | s5cmd | Skyplane | Orian |
| --- | --- | --- | --- |
| Parallel object workers | `--numworkers` | gateway VMs | `numworkers` |
| Multipart / parts per file | `--concurrency` | chunk + connections | `concurrency` + part size |
| `cp` `sync` `ls` `rm` `run` | yes | `cp` `sync` | yes |
| Cross-cloud overlay VMs | no | yes | not yet (streamed S3↔S3) |
| BLAKE3 / S5 CID | no | no | yes (Zig + Rust NIF) |
| S3-compatible / MinIO / `gs://` XML | yes | AWS/GCP/Azure | S3 XML + endpoint-url |

High throughput is a primary goal. Dirty-CPU NIFs, HTTP keep-alive (512 sessions), 16 MiB parts, parallel range GET, Rust BLAKE3 on the hash path. See [PERFORMANCE.md](PERFORMANCE.md).

Tune like s5cmd: many small files → high `numworkers`; few large files → high `concurrency`.

Env: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ENDPOINT_URL`.

`mix bench` hashes: [benchmark/RESULTS.md](benchmark/RESULTS.md). MIT. https://github.com/niranjanaryan/orian
