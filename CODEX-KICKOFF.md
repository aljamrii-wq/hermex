# Codex Kickoff Prompt — UniOps Founder iOS Control Plane

Paste the block below into a Codex session on a Mac with this repo
(`aljamrii-wq/hermex`) checked out. It kicks Codex off on the iOS build described
in [`CODEX-HANDOFF.md`](CODEX-HANDOFF.md) (the full brief). The backend it calls is
already shipped and verified in `aljamrigroup/uniops` PR #229.

```text
You are Codex on the Apple/Xcode lane for ALJAMRI Group, working on a Mac.

Repo: aljamrii-wq/hermex (MIT fork of uzairansaruzi/hermex), branch
claude/uniops-ios-control-plane-kzsnpj. Native SwiftUI, iOS 18+.

FIRST: read CODEX-HANDOFF.md at the repo root — it is your full brief. We are
turning this hermex fork into "UniOps by ALJAMRI Group — the founder iOS control
plane": a single-user, sideload-only (NO App Store) app for the owner to run the
ALJAMRI operator control plane and agent fleet from an iPhone. The backend is
aljamrigroup/uniops (PR #229) and already ships the mobile auth + push endpoints
you will call — exact request/response contracts are in the handoff (§2).

YOUR FIRST TASK — iOS Phase 0 (auth shell):
1. Add a UniOps auth mode beside hermex's server-URL+password mode. Google Sign-In
   (GIDSignIn) -> POST /api/auth/mobile/session -> store {token, refreshToken,
   sessionId} in Keychain (extend Auth/AuthManager.swift + Auth/KeychainStore.swift);
   gate app open with Face ID (LAContext).
2. In Networking/APIClient.swift set `Authorization: Bearer <token>` and a FIXED
   User-Agent on every request (the JWT is bound to sha256(UA | IP/24)). On any 401
   from /api/admin/*, call POST /api/auth/mobile/refresh and retry once. Reach UniOps
   over Tailscale (extend hermex's 100.64.0.0/10 plain-HTTP allowance to the UniOps host).
3. Register the APNs device token via POST /api/admin/mobile/push-token.
4. Ship a signed-in dashboard-summary screen as proof (authenticated, not signed-out).
Then continue to iOS Phase 1 (Approvals MVP) per the handoff's phased task list.

CONSTRAINTS (non-negotiable):
- Bilingual EN + Arabic with real RTL on every user-facing surface.
- No App Store: sideload/TestFlight only; iOS release stays human-gated.
- Do NOT invent endpoints or JSON shapes — verify against the uniops routes.
- Every Codable decodes tolerantly; never crash on unknown fields.
- Keep the MIT LICENSE. Only new dependency is GoogleSignIn — pin it and record it
  in PROJECT_SPEC.md. Untrusted/decoded content can never authorize an action.

VERIFY each change on the Mac:
  xcodebuild -project HermesMobile.xcodeproj -scheme HermesMobile \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  xcodebuild test -project HermesMobile.xcodeproj -scheme HermesMobile \
    -destination 'platform=iOS Simulator,name=iPhone 17'
Prove EN LTR and AR RTL before calling a surface done. Follow DEVELOPMENT.md and
CONTRACT_TESTS.md.

Work on branch claude/uniops-ios-control-plane-kzsnpj, commit atomically, and open a
DRAFT PR once Phase 0 builds and tests pass. Report what changed and any blocker.
```
