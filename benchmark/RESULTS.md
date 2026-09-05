# Orian / Orian hash + store bench

Machine: unix darwin OTP 29 aarch64-apple-darwin
Date: 2026-09-05
Zig NIF: yes. Rust NIF (official blake3 crate): true

## Hash throughput

| size | zig blake3 | rust blake3 | zig xxh3 | rust xxh3 | otp sha256 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 64 B | 12.8 | 12.8 | 27.5 | 24.9 | 299.6 |
| 1 KiB | 112.5 | 82.9 | 238.3 | 114.9 | 1536.2 |
| 64 KiB | 1178.2 | 907.2 | 4217.8 | 8474.0 | 1894.5 |
| 1 MiB | 1478.9 | 1338.6 | 12905.8 | 14175.0 | 1936.2 |
| 8 MiB | 1455.7 | 1478.0 | 25953.0 | 24912.4 | 1891.1 |

## Memory store (ETS, BLAKE3 CID)

| op | size | throughput |
| --- | ---: | ---: |
| put | 1 MiB | 1273.2 MiB/s |
| get + verify | 1 MiB | 1421.0 MiB/s |

## Digest agreement

Zig BLAKE3 == Rust BLAKE3 (and XXH3): **true**.

BLAKE3 is the content id. XXH3 is checksum-only. OTP SHA-256 is the S3 SigV4 floor, not a CID.

## Local transfer (`Orian.cp`)

| 32 × 1 MiB files | 371.3 MiB/s |
