# Stow

Fast **content-addressed storage** for Elixir. Zig NIF + Rust NIF.

```
gale  — Phoenix HTTP/3
ingot — Iroh + Zenoh cluster
dusk  — Zenoh + Iroh cluster
stow  — BLAKE3 / S3 / S5 blobs
```

```elixir
{:stow, "~> 0.1"}

{:ok, cid} = Stow.put(body)
{:ok, ^body} = Stow.get(cid)

Stow.put(body,
  backend: :s3,
  bucket: "blobs",
  unsigned: true,
  host: "127.0.0.1:9000",
  scheme: "http"
)

Stow.put(body, backend: :s5, endpoint: "http://127.0.0.1:5050")
```

- **BLAKE3** — object identity (S5 CID, `x-amz-meta-blake3`)
- **XXH3** — routing / checksum only
- **S3** — SigV4 or unsigned MinIO; key defaults to hex(BLAKE3)
- **S5** — `0x5b 0x82 0x1e` + BLAKE3 + size; HTTP `/s5/upload` and `/s5/blob/{hex}`

`Stow.blake3/1` is the Zig NIF. `Stow.Rs.blake3/1` is the official Rust `blake3` crate (same digest). See [HASH.md](HASH.md).

`mix bench` — [benchmark/RESULTS.md](benchmark/RESULTS.md). On Apple silicon / OTP 29, 1 MiB: Zig BLAKE3 **1.3 GiB/s**, Rust BLAKE3 **1.5 GiB/s**, XXH3 **~26–30 GiB/s**. Digests match.

MIT. https://github.com/niranjanaryan/stow
