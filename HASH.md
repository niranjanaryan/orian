# BLAKE3 vs XXH3

Orian is the hash + blob package for Gale / Ingot / Dusk.

| Hash | Crypto | Use |
| --- | --- | --- |
| **BLAKE3** | Yes | Content id, S5 CID, S3 metadata |
| **XXH3-64** | No | Checksums, cache keys |
| SHA-256 | Yes | AWS SigV4 only (S3 protocol) |

**Production hasher is the Zig NIF** (best measured 1 MiB BLAKE3 / 8 MiB XXH3). Rust `blake3` crate is kept for the transfer engine and `mix bench` agreement checks. Digests must match.

Do not use XXH3 as a blob id.
