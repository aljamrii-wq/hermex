# Codex Handoff — UniOps Founder iOS Control Plane (hermex base)

**From:** Claude (UniOps backend + fork setup)
**To:** Codex (Apple/Xcode lane, builds on a Mac)
**Date:** 2026-07-07
**This repo:** `aljamrii-wq/hermex` (MIT fork of `uzairansaruzi/hermex`) — the base app.
**Companion repo:** `aljamrigroup/uniops` — the control-plane backend (all the server work below is there).

## 1. Mission

Turn this hermex fork into **UniOps by ALJAMRI Group — the founder iOS control plane**: a single-user, sideload-only (no App Store) native app for the owner (aljamri@skyhubtravel.ae) to run the ALJAMRI operator control plane and agent fleet from an iPhone.

Full plan (read it first): in the uniops repo,
`docs/superpowers/plans/2026-07-07-uniops-ios-founder-control-plane.md` (branch
`claude/uniops-ios-control-plane-kzsnpj`, PR #229).

**Why hermex is the base:** it already ships exactly the control-plane breadth the plan wanted — streaming chat with steer/stop mid-run, sessions (browse/search/resume + offline cache), scheduled **Tasks** (cron), **Skills** browser, **Workspace** file browser, **Memory/Insights**, a **Live Activity** widget, a **Share Extension**, and App Intents. It's native SwiftUI, iOS 18+, MIT, zero-to-few third-party deps. The main work is **swapping its connection/auth layer from `hermes-webui` (URL+password) to UniOps**, then adding UniOps-specific surfaces (approvals first).

> **Correction (2026-07-07, post your Phase-1 push `49df36d`):** `uniops#226` merged into `dev`
> while Phase 1 was in flight and shipped a **unified `GET /api/admin/approvals`** endpoint
> (Approvals Command Center) that supersedes the five separate approval endpoints §4 originally
> listed. Re-point the approvals inbox at the unified endpoint — see the updated §2/§4 below. Two
> corrections to what you built: **GitHub escrow is not a separate source** (escrow items are
> `OpenClawPendingAction` rows the OpenClaw decision routes already branch on — approving via
> OpenClaw covers escrow, don't call the escrow routes directly), and **NightShift is not an
> approvals source** in the canonical design (drop the NightShift improvement/skill-card decision
> screens from the approvals inbox — NightShift stays its own standalone feature, not wired here).
> Everything else you built (auth shell, Keychain, Face ID, bearer+refresh, APNs, dashboard proof,
> owner-confirmation gate, EN/AR/RTL) is unaffected and correct.

## 2. What is already DONE (server-side, by Claude) — uniops PR #229

The backend unblocker is merged-ready on branch `claude/uniops-ios-control-plane-kzsnpj`. All of it is verified: `tsc --noEmit` clean, migrations applied to a real Postgres, contract tests green. You do **not** need to build any of this — just call it.

### Auth (owner-only, over Tailscale)
- `POST /api/auth/mobile/session` — **owner sign-in**. Unauthenticated.
  - Body: `{ "credential": "<Google ID token>", "deviceId"?: string, "deviceName"?: string }`
  - 200: `{ success, token: "<UniOps JWT>", refreshToken: "<sessionId>.<secret>", sessionId, expiresIn: "4h", refreshExpiresAt: "<ISO>" }`
  - Errors: 400 `VALIDATION_ERROR`, 429 `RATE_LIMITED`, 401 `GOOGLE_TOKEN_INVALID`, 403 `GOOGLE_EMAIL_NOT_VERIFIED` / `FORBIDDEN` / `ACCOUNT_NOT_FOUND` / `ACCOUNT_DISABLED`, 500 `GOOGLE_CONFIG_MISSING` / `GOOGLE_ALLOWLIST_MISSING`.
- `POST /api/auth/mobile/refresh` — re-mint the 4h JWT. Unauthenticated (uses the refresh token).
  - Body: `{ "refreshToken": "<sessionId>.<secret>" }`  →  200: `{ success, token, sessionId, expiresIn }`; 401 `MOBILE_REFRESH_INVALID` if revoked/expired.
- `GET /api/auth/mobile/session` — list the owner's active sessions (security screen). **Bearer.**
  - 200: `{ success, sessions: [{ id, channel, tokenClass, deviceName, deviceId, createdAt, lastSeenAt, expiresAt }] }`
- `DELETE /api/auth/mobile/session/{id}` — **lost-phone kill switch.** Bearer. → `{ success, revoked }`.

### Approvals (unified — `uniops#226`, merged to `dev`)
- `GET /api/admin/approvals` — **Bearer**, requires `settings:view` OR `system:view` (owner has `*:*`
  via `requireAnyPermission`). Query: `?source=openclaw|agent_runtime|autopilot|supplier_ops`
  (optional filter), `?countOnly=1` (badge-poll mode → `{ success, counts, generatedAt }` only),
  `?limit=` (default via `resolveListLimit`, cap 200; `countOnly` uses 500).
  - 200 body: `{ success, items: PendingApprovalItem[], counts: { total, bySource: {openclaw,
    agent_runtime, autopilot, supplier_ops} }, generatedAt }`.
  - `PendingApprovalItem`: `{ id: "<source>:<recordId>", source, title, description, riskTier,
    requestedBy, requestedAt, stepUp: boolean, href, decide: { approve: {url, body}, deny: {url,
    body} | null, headers?: {"x-tenant-id"?: string}, reasonField: "reason"|"decisionNote"|null } }`.
  - **The client does not need per-source endpoint knowledge.** Each item's `decide.approve`/`.deny`
    already carries the exact URL + JSON body to POST (merge in the owner's note under
    `reasonField` if present, and send `decide.headers` if present, e.g. `x-tenant-id` for
    `agent_runtime`). `stepUp: true` means that item's decision route needs a recent step-up — a
    freshly minted/refreshed mobile token satisfies it.
  - **GitHub escrow is not a separate source.** Escrow items surface as `source: "openclaw"` (title
    prefixed `GitHub · ...`); their `decide` URLs are the OpenClaw approve/deny routes, which branch
    internally. Do not call the escrow routes directly.
  - **NightShift is not an approvals source.** It is intentionally absent — leave it out of the
    approvals inbox entirely; it remains a standalone feature outside this MVP.
- Real-time updates: no bearer-accepting SSE yet (see §4) — poll `GET /api/admin/approvals?countOnly=1`
  for the badge and re-fetch the full list on pull-to-refresh / APNs wake.

### Push
- `POST /api/admin/mobile/push-token` — register the APNs device token. **Bearer**, requires `dashboard:view` (owner has `*:*`).
  - Body: `{ "token": "<APNs device token>", "deviceId"?: string, "platform"?: "apns" }` → `{ success, id }`
- Server sender `lib/mobile-push/apns.ts` (`sendPushToAdminUser`) sends alert / **liveactivity** push; wiring it to fire on new approvals is a follow-up.

### Auth mechanics you MUST honor in the app
- Send the JWT as `Authorization: Bearer <jwt>` (a non-`sk_` bearer is treated as a session JWT).
- **Session fingerprint:** the JWT is bound to `sha256(ip/24-bucket | user-agent)` and the guards enforce it. So:
  1. Reach UniOps over **Tailscale** (stable tailnet IP across wifi/cellular). The app's admin calls (`/api/admin/*`) are **IP-boundary-gated** — off-tailnet they 403.
  2. Use a **fixed, stable `User-Agent`** for every request (set it once in the APIClient).
  3. On any `401` from an admin call, call `/api/auth/mobile/refresh` (re-binds the fingerprint to the current request), then retry. Face ID gates local use / re-mint.
- `/api/auth/mobile/*` sign-in/refresh are exempt from the IP boundary (like web Google login); the `/api/admin/*` calls are not.

### Owner-policy (already wired server-side, mirror it client-side)
`lib/mobile-operator-console/authorize.ts` maps approve/reject/steer/stop to an owner-policy decision with **hard blocks** (untrusted-derived content can never authorize an action), **trusted-channel** requirement (`chowder_ios_tailscale`), and **owner-confirmation triggers** (delete / deploy-prod / payment / secret / export-PII / spend / DNS-IAM-firewall). The app should show a confirm step for any action whose effect matches those triggers, and must never let decoded/transcribed content trigger an action on its own.

## 3. hermex → UniOps adaptation map (concrete)

Work in `HermesMobile/`. The layers to change:

| Concern | hermex today | Change for UniOps |
|---|---|---|
| Auth | `Auth/AuthManager.swift`, `Auth/KeychainStore.swift` — server URL + password | Add a UniOps auth mode: **Google Sign-In** (`GIDSignIn`) → `POST /api/auth/mobile/session` → store `{ token, refreshToken, sessionId }` in Keychain; **Face ID** gate (LAContext); refresh on 401. Keep the existing server-URL/password path if you still want direct hermes-webui/agent chat. |
| API base + headers | `Networking/APIClient.swift`, `Networking/CustomHeader.swift` | Point base URL at the UniOps host over Tailscale; set `Authorization: Bearer` + a fixed `User-Agent`. |
| Endpoints | `Networking/Endpoints.swift` | Add UniOps endpoints (auth/mobile/*, admin/mobile/push-token, and the approval endpoints in §4). Keep hermex's endpoints for the agent-chat surface. |
| Account model | `Models/ServerAccount.swift`, `ServerCatalog.swift` | Extend to hold a UniOps session (bearer + refresh + sessionId + owner email). |
| Push | `LiveActivities/AgentLiveActivityManager.swift`, notification scheduler in `Config/AppTheme.swift` | Register for APNs, `POST /api/admin/mobile/push-token`; drive Live Activity from remote push (hermex's are local today — add push-to-start). |
| New surfaces | `Features/*` | Add **Approvals** (the MVP), then Fleet Ops, product consoles, device control — per the plan's modules. |

**Agent-chat reconciliation (later, not the MVP):** hermex talks to `hermes-webui`. UniOps mediates OpenClaw/Hermes. For now, the agent-chat/sessions/tasks/skills/files screens can keep pointing at a Hermes/hermes-webui server (the owner runs one); the UniOps-specific value in Phase 1 is **auth + approvals + push**. Reconcile the two agent protocols later (see the plan §8, decision 2).

## 4. Phased task list for Codex

Build in this order; each phase is a sideload build for the owner.

- **iOS Phase 0 — Auth + shell.** Google Sign-In → `/api/auth/mobile/session` bearer; Keychain + Face ID; refresh-on-401; fixed User-Agent; Tailscale reachability (hermex already allows plain HTTP on `100.64.0.0/10` — extend to the UniOps host); register APNs token. Ship a signed-in dashboard-summary screen (authenticated proof — not signed-out).
- **iOS Phase 1 — Approvals MVP ("approve UniOps from your phone").** One inbox over the unified
  `GET /api/admin/approvals` (see §2) — **not** the individual per-source routes. Render `items`
  grouped/badged by `source` (openclaw — incl. escrow — / agent_runtime / autopilot / supplier_ops;
  **no NightShift**); tapping approve/deny POSTs exactly the item's `decide.approve`/`.deny` `{url,
  body}` (+ `headers` if present, + the owner's note under `reasonField` if the UI collects one).
  Mirror the owner-confirmation triggers from §2 before sending any decision. `stepUp: true` items
  are covered by a fresh/refreshed mobile token. Badge count: poll `?countOnly=1`.
  Action Center + live feed: `GET /api/stream`, `GET /api/admin/realtime/stream` (SSE; **cookie-auth
  only today — add a bearer variant server-side or poll + APNs wake**).
  Live Activity for a running agent task; APNs push wakes it.
- **iOS Phase 2 — Agent console.** Reuse hermex's chat/steer-stop/sessions/tasks/skills/files against the Hermes agent gateway.
- **iOS Phase 3+ — Fleet Ops (ops repo surfaces, monitoring-first), product consoles (Finance/Travel/Inbox/Compliance), device control (glasses/Flipper/camera). See the plan.**

## 5. Constraints (non-negotiable)

- **No App Store.** Sideload / TestFlight-internal only. iOS release stays human-gated (ops canon).
- **Bilingual EN + Arabic with real RTL** on every user-facing surface — ALJAMRI launch gate (AGENTS.md). Build the localization layer from day one.
- **Tailscale** for admin reachability; owner phone on the tailnet.
- **Don't invent endpoints or JSON shapes** — verify against uniops routes (this repo's existing convention too). Every `Codable` decodes tolerantly; never crash on unknown fields.
- **MIT base** — keep `LICENSE` and attribution. Do not add third-party deps beyond `PROJECT_SPEC.md`'s locked list without approval (GoogleSignIn is the one likely addition — get it approved and pin it).
- Untrusted content can never authorize an action (hard block).

## 6. Build & verify (you have a Mac; Claude did not)

```zsh
xcodebuild -project HermesMobile.xcodeproj -scheme HermesMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project HermesMobile.xcodeproj -scheme HermesMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Follow `DEVELOPMENT.md` (post-change flow) and `CONTRACT_TESTS.md` (tolerant decoding + endpoint verification). Prove EN LTR and AR RTL before calling a surface done. The UniOps backend it calls is already verified in PR #229.

## 7. References
- Plan: `uniops` → `docs/superpowers/plans/2026-07-07-uniops-ios-founder-control-plane.md`
- Backend endpoints: `uniops` → `app/api/auth/mobile/*`, `app/api/admin/mobile/push-token/route.ts`, `app/api/admin/approvals/route.ts` (unified approvals, from `uniops#226`)
- Approvals aggregator (source of the item/decide contract): `uniops` → `lib/approvals/{service,types}.ts`
- Session store / policy: `uniops` → `lib/mobile-operator-console/{session,authorize,google-owner}.ts`; APNs `lib/mobile-push/apns.ts`
- This app's source of truth: `PROJECT_SPEC.md`, `DEVELOPMENT.md`, `AGENTS.md`
- Branch convention: develop on `claude/uniops-ios-control-plane-kzsnpj`; open draft PRs.
