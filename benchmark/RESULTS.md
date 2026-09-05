# Orian / Stow hash + store bench

Machine: unix darwin OTP 29 aarch64-apple-darwin
Date: 2026-09-06
Zig NIF: yes. Rust NIF (official blake3 crate): true

## Hash throughput

| size | zig blake3 | rust blake3 | zig xxh3 | rust xxh3 | otp sha256 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 64 B | 213.2 | 529.0 | 2642.2 | 1665.8 | 300.8 |
| 1 KiB | 668.4 | 795.4 | 15700.4 | 13970.9 | 1542.1 |
| 64 KiB | 1313.3 | 1513.2 | 25604.3 | 28682.9 | 1907.1 |
| 1 MiB | 1318.8 | 1515.2 | 26069.2 | 29506.7 | 1933.9 |
| 8 MiB | 1319.6 | 1512.9 | 25931.9 | 29452.4 | 1945.6 |

## Memory store (ETS, BLAKE3 CID)

| op | size | throughput |
| --- | ---: | ---: |
| put | 1 MiB | 1242.0 MiB/s |
| get + verify | 1 MiB | 1319.6 MiB/s |

## Digest agreement

Zig BLAKE3 == Rust BLAKE3 (and XXH3): **true**.

BLAKE3 is the content id. XXH3 is checksum-only. OTP SHA-256 is the S3 SigV4 floor, not a CID.
