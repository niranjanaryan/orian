# Performance

High throughput is a **primary goal**. Target: **50–100×** versus copying whole objects through the BEAM (`:httpc` + Elixir binaries).

## How

The hot path is a **Rust/Tokio engine** (`Orian.Engine`): streaming file→socket and socket→file, HTTP/1.1 keep-alive pool (256 idle/host), `UNSIGNED-PAYLOAD` SigV4 so Elixir never hashes or buffers the body. One dirty-IO NIF runs a whole batch (`bulk/2`).

BEAM `:httpc` remains a fallback if the NIF is missing.

50–100× is vs the old whole-file-through-the-VM path on many objects / large objects. It will not beat physics on a 1 Gbps NIC (max ~125 MiB/s). On 10–100 Gbps or localhost S3 (MinIO), native streaming is the difference between tens of MiB/s and multi-GiB/s.

## Defaults

| knob | default | role |
| --- | --- | --- |
| `numworkers` | `max(32, schedulers×8)` | parallel objects |
| `concurrency` | 16 | parallel parts of one object |
| `part_size` | 16 MiB | multipart PUT / range GET |
| HTTP | keep-alive pool 512 sessions | `:httpc` profile `:orian` |

Hash NIFs are **dirty CPU**. Production `blake3`/`xxh3` is **Zig** (won the 1–8 MiB benches). The **Rust/Tokio engine** is the transfer path.

Transfer does **not** hash every byte by default (`blake3: false`). Pass `--blake3` / `blake3: true` when you want `x-amz-meta-blake3`.

## Tune

```elixir
# many small objects
Orian.cp("*.json", "s3://b/", numworkers: 256)

# few huge objects
Orian.cp("dump.bin", "s3://b/", numworkers: 4, concurrency: 32, part_size: 64 * 1024 * 1024)
```

```bash
mix orian cp --numworkers 256 --concurrency 16 data/ s3://bucket/
```

## Not yet (Skyplane overlay)

Gateway VMs, compression overlays, and multi-cloud path planning are out of this cut. Client-side parallelism + multipart + keep-alive is the current hot path.

`mix bench` writes [benchmark/RESULTS.md](benchmark/RESULTS.md).
