# Performance

High throughput is a primary goal (s5cmd / Skyplane class).

## Defaults

| knob | default | role |
| --- | --- | --- |
| `numworkers` | `max(32, schedulers×8)` | parallel objects |
| `concurrency` | 16 | parallel parts of one object |
| `part_size` | 16 MiB | multipart PUT / range GET |
| HTTP | keep-alive pool 512 sessions | `:httpc` profile `:orian` |

Hash NIFs run as **dirty CPU** jobs so they do not stall BEAM schedulers. `Orian.blake3/1` uses the **Rust** `blake3` crate when that NIF is loaded.

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
