# Contributing · Codexveil

Codex Desktop skin product line (DreamSkin). Public contributions welcome via **Issues** and **Pull requests**.

## Rules of the road

1. Read [`docs/PROJECT.md`](docs/PROJECT.md) and [`docs/PRODUCT-LAYERS.md`](docs/PRODUCT-LAYERS.md).
2. **Hard no:** second injector/daemon, editing Codex **asar** install trees, adding a second theme catalog without ADR (product is **arina-only** unless maintainer reopens).
3. Prefer small, testable diffs. Run `npm test` (and doctor/smoke when touching inject/CDP).

## PR checklist

- [ ] Scope matches PRODUCT-LAYERS L0 (what we are / are not)
- [ ] Tests green for touched packages
- [ ] No secrets; no install-state paths committed

## License

**MIT** — see `LICENSE`.

## Security

[`SECURITY.md`](SECURITY.md) · threat notes in `docs/`.
