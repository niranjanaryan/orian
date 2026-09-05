# BLAKE3 vs XXH3

Stow is the hash + blob package for Gale / Ingot / Dusk.

| Hash | Crypto | Use |
| --- | --- | --- |
| **BLAKE3** | Yes | Content id, S5 CID, S3 metadata |
| **XXH3-64** | No | Checksums, cache keys |
| SHA-256 | Yes | AWS SigV4 only (S3 protocol) |

Zig `std.crypto.hash.Blake3` is the default NIF. The Rust NIF uses the official `blake3` crate (C+asm, usually faster). Digests must match. `mix bench` prints MiB/s for both.

Do not use XXH3 as a blob id.
