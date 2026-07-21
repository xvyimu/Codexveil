# @codex-skin/contracts

Shared **Zod** schemas for cross-layer fields (ADR 0004).

- Dev-plane only — **not** copied into `versions/<id>/`
- Keep CSS color regex aligned with `packages/runtime/scripts/injector.mjs`

```bash
pnpm --filter @codex-skin/contracts test
# = tsc + node --test dist/index.test.js
pnpm --filter @codex-skin/contracts build
```
