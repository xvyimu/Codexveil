# Security policy (Codexveil / codex-skin)

Unofficial **Windows CDP Skin** for OpenAI Codex Desktop.  
GitHub: [xvyimu/Codexveil](https://github.com/xvyimu/Codexveil) (formerly `Codex-Dream-Skin`, left fork network).  
Not affiliated with OpenAI. Does **not** modify `app.asar`, WindowsApps packages, or code signatures.

## Supported versions

Only the current `main` branch and the latest published product line (see `package.json` / `docs/BASELINE.generated.md`) receive security-relevant fixes.

## Threat model (honest)

| Attacker | In scope? | Controls |
|----------|-----------|----------|
| LAN / remote host | **Yes** | CDP and control-plane bind **127.0.0.1 only**; WebSocket URL shape guard (`cdp-url-guard.mjs`) |
| Same-user mistaken script | **Yes** | `control.token` + header `x-codex-skin-token` on mutating POSTs (query token **rejected**) |
| Same-user malware | **No** | Already has full user privileges; token file is readable under `%LOCALAPPDATA%` by design |
| Malicious theme package | **Yes** | Schema **data-only** (rejects `scripts` / `hooks` / …); path escape checks; image size caps |
| npm supply chain | **Low** | **Zero** production npm dependencies |

We do **not** claim multi-user OS isolation or that Codex itself is a hardened security boundary.

## Report a vulnerability

Prefer **private** disclosure (GitHub Security Advisories on `xvyimu/Codexveil` when enabled, or private contact to the repo owner).

Please include:

- Affected revision (`git rev-parse HEAD`) and install `runtimeId` if relevant  
- OS / architecture  
- Minimal reproduction  
- Impact and preconditions  

**Do not** open a public issue with exploit payloads, full `control.token` values, or private chat content.

In-scope examples:

- Theme package path traversal or executable field smuggling past schema  
- Control-plane reachable off-loopback  
- CDP attach to non-loopback / unexpected debugger URL accepted by our guard  
- Token or secrets written to logs in plaintext (see SEC-02 audit note in `docs/PAIN-POINTS.md`)  
- Install-tree / publish path that drops security-critical scripts without detection  

Out-of-scope examples:

- SmartScreen prompts on unsigned binaries (documented #24; see `docs/plans/codesign-decision-2026-07-21.md`)  
- Store tile bare launch without skin (OS AUMID limit #21)  
- Issues only in upstream `Fei-Away/Codex-Dream-Skin` without a path in this repo  

## Operational controls (maintainers)

| Control | Where |
|---------|--------|
| Loopback CDP URL validation | `packages/runtime/scripts/cdp-url-guard.mjs` + unit tests |
| Control-plane auth | `control-plane.mjs` · `docs/dual-open-policy.md` |
| Theme data-only | `packages/themes/theme-schema.mjs` |
| Install vs repo drift | `scripts/windows/verify-install-matches-repo.ps1` |
| Post-update failure observability | `docs/contracts/post-update-report.md` |
| Release evidence (DOM) | `docs/evidence/` · `Run-ReleaseProbes.ps1` (real dumps gitignored) |

## Vendor / upstream

`vendor/dreamskin/` is a **read-only mirror**. It is not re-licensed by this document; see root `NOTICE`. Production paths must not import `vendor/`.

## Related

- [`docs/dual-open-policy.md`](./dual-open-policy.md) — entry + token contract  
- [`docs/PAIN-POINTS.md`](./PAIN-POINTS.md) — #21 / #24 / SEC-02  
- [`docs/plans/codesign-decision-2026-07-21.md`](./plans/codesign-decision-2026-07-21.md) — signing Go/No-Go  
- Root [`LICENSE`](../LICENSE) (MIT) · [`NOTICE`](../NOTICE)  
