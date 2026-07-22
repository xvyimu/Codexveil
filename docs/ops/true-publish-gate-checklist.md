# Codexveil · true publish gate checklist (wave7)

> **Do not run this as automation.** Operator-only after Dual-B tip is green.

## Preconditions (automated — already on main)

| Check | Command | Expected |
| --- | --- | --- |
| Tip publish whitelist | `pwsh -NoProfile -File scripts/windows/verify-publish-runtime-payload.ps1` | `VERIFY OK` · exit **0** |
| Unit / contracts | `npm test` | exit **0** |
| Theme-load present in repo | `Test-Path packages/runtime/scripts/theme-load.mjs` | true |

## Human-only steps (when you choose to publish)

1. Confirm version string (e.g. continues `1.3.25` line or next stamp) — matches product policy.
2. Close running Codex DreamSkin / injector watch if install dir is locked.
3. From repo root (`D:\orca\Codexveil`):

```powershell
pwsh -NoProfile -File scripts/windows/publish-runtime.ps1 -Version <VERSION>
```

4. Post-publish proofs:

```powershell
# replace <id> with versions folder name printed by publish
$ver = "$env:LOCALAPPDATA\Programs\CodexDreamSkin\versions\<id>"
Test-Path "$ver\scripts\theme-load.mjs"   # must be True
Test-Path "$ver\scripts\injector.mjs"
pwsh -NoProfile -File scripts/windows/verify-install-matches-repo.ps1  # if available for this layout
npm run doctor   # optional live
```

5. Smoke: start DreamSkin, switch a theme, confirm no `ERR_MODULE_NOT_FOUND` for `theme-load`.

## Explicit non-actions for agents

- Do **not** run `publish-runtime.ps1` without user “publish now”.
- Do **not** force-push, delete install backups, or touch unrelated Programs paths.
- Dry-run / `verify-publish-runtime-payload.ps1` is enough for CI/agent evidence.

## Related

- Dual-B report: `docs/ops/wave6-dual-b-codexveil-claude.md`
- ADR 0003 version stamp discipline
