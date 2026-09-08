# Orian Consumer Awareness

## Target Audience

| Segment | Who they are | Why they care |
|---------|-------------|---------------|
| Stacks node operators | Node snapshot backups | 50–100× faster than whole-file BEAM path |
| sBTC relay operators | State sync to object storage | Parallel cp/sync with BLAKE3 content IDs |
| DevOps teams | Chain data exports | Cron-like batch jobs via `orian run` |

## Awareness Channels

### Stacks Ecosystem
- **Stacks Forum:** Fast backup/restore tutorials
- **Stacks Discord:** Q&A, demos, office hours
- **Stacks GitHub:** Issues, discussions, PRs

### Elixir Ecosystem
- **Elixir Forum:** "Fast object transfer in Elixir"
- **Hex.pm:** Package description, docs, changelogs
- **GitHub:** Issues, discussions, stars, forks

### Social Media
- **Twitter/X:** Benchmark screenshots, backup demos
- **Reddit r/elixir:** Cross-post tutorials
- **YouTube:** Full backup/restore screencast

## Content Strategy

### Blog Posts / Tutorials
1. **"Fast Stacks Node Snapshots with Orian"**
   - `orian stacks snapshot` preset
   - S3/S5 backup workflow
   - BLAKE3 content IDs for deduplication
   - Target: Stacks node operators

2. **"sBTC Relay State Sync with Orian"**
   - `orian stacks relay-state` preset
   - Relay DB snapshots to object storage
   - Parallel transfer for large state files
   - Target: sBTC relay operators

3. **"Batch Chain Data Exports with Orian"**
   - `orian run` job-file support
   - Cron-like scheduled exports
   - Multi-cloud transfer patterns
   - Target: DevOps teams

### Demo Videos
- **3 min:** Node snapshot backup/restore
- **5 min:** Batch chain data export

### Benchmark Publications
- `benchmark/TRANSFER_THROUGHPUT.md` — S3/S5 transfer rates
- `benchmark/BACKUP_TIME.md` — Time to backup/restore node DB

## Adoption Metrics

| Metric | Baseline | 30-day target | 90-day target |
|--------|----------|---------------|---------------|
| Hex downloads | 0 | 100+ | 500+ |
| GitHub stars | 0 | 20+ | 100+ |
| Stacks Forum replies | 0 | 3+ | 15+ |
| Blog post views | 0 | 300+ | 1,200+ |
| Demo video views | 0 | 100+ | 600+ |

## Timeline

### Week 1-2
- [ ] Publish snapshot backup tutorial
- [ ] Post Stacks Forum thread
- [ ] Record backup demo

### Week 3-4
- [ ] Publish relay state sync tutorial
- [ ] Post Elixir Forum thread
- [ ] Submit Reddit r/elixir cross-post

### Week 5-8
- [ ] Publish batch export tutorial
- [ ] Monitor and respond to feedback
- [ ] Update benchmarks

## Key Messages

**For Stacks operators:**
> "Back up Stacks node snapshots 50–100× faster with Orian. Parallel S3/S5 transfer with BLAKE3 content IDs."

**For Elixir developers:**
> "s5cmd/Skyplane-class object transfer in Elixir. Rust/Tokio engine with dirty-IO NIF for maximum throughput."

## Competitive Positioning

| Competitor | Gap we fill |
|------------|-------------|
| s5cmd | Elixir-native, BLAKE3 content IDs, FLAME integration |
| Skyplane | Multi-cloud path planning, Elixir runtime |
| AWS CLI | Parallel transfer, content-addressable storage |
| Custom scripts | Standardized CLI, production-ready error handling |

**Our advantage:** Only high-performance, Elixir-native object transfer tool with BLAKE3 content IDs and Stacks-specific presets.

---

*This document is part of the Elixir Distributed Stack consumer awareness strategy.*
