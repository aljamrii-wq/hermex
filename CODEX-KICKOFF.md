# Codex Kickoff Prompt — UniOps Founder iOS Control Plane

Paste the block below into a Codex session on a Mac with this repo
(`aljamrii-wq/hermex`, branch `claude/uniops-ios-control-plane-kzsnpj`) checked out.
It picks up the iOS build described in [`CODEX-HANDOFF.md`](CODEX-HANDOFF.md) (the full
brief, now updated with a Phase 1 correction — read the callout at the top).

**Status:** iOS Phase 0 (auth shell) is done — Google Sign-In, Keychain, Face ID,
bearer+refresh, APNs registration, authenticated dashboard proof, all verified via
`xcodebuild` build+test+RTL. Phase 1 (Approvals MVP) was built against five separate
per-source endpoints, but `uniops#226` merged a **unified `GET /api/admin/approvals`**
endpoint after that work started — this kickoff is the re-point task.

```text
You are Codex on the Apple/Xcode lane for ALJAMRI Group, working on a Mac.

Repo: aljamrii-wq/hermex (MIT fork of uzairansaruzi/hermex), branch
claude/uniops-ios-control-plane-kzsnpj. Native SwiftUI, iOS 18+.

FIRST: re-read CODEX-HANDOFF.md at the repo root, especially the correction callout
at the top and the updated §2 "Approvals (unified)" + §4 Phase 1 sections — the
backend contract changed under you mid-build.

YOUR TASK — re-point the Phase 1 approvals inbox at the unified endpoint:
1. Replace the five separate approval-source integrations (OpenClaw pending-actions,
   agent-runtime decision, autopilot action approve, GitHub escrow approve/deny,
   NightShift improvements/skills decision) with ONE call to
   GET /api/admin/approvals (Bearer; requires settings:view OR system:view, which the
   owner has via *:*). Response: { items: PendingApprovalItem[], counts, generatedAt }.
2. Each PendingApprovalItem already carries decide.approve / decide.deny as {url, body}
   (+ optional headers, e.g. x-tenant-id, + reasonField for an owner note) — POST
   EXACTLY that url/body/headers on approve/deny. Do not hand-construct per-source
   request shapes anymore; the server tells you what to call.
3. DROP GitHub escrow as a separate source/screen — escrow items already arrive with
   source: "openclaw" (title prefixed "GitHub · ..."); their decide URLs are the
   OpenClaw routes, which branch internally. Approving via OpenClaw covers escrow.
4. DROP NightShift entirely from the approvals inbox — it is not a source in the
   unified endpoint and is not part of this MVP. Remove the NightShift
   improvement-proposal and skill-card decision screens/models you added for it.
5. For the badge/poll, use GET /api/admin/approvals?countOnly=1 -> { counts,
   generatedAt } instead of any per-source count call.
6. Keep everything else from your Phase 1 work: owner-confirmation gate before any
   decision, EN/AR/RTL approval strings, stepUp handling (a fresh/refreshed mobile
   token satisfies items with stepUp: true).

CONSTRAINTS (non-negotiable, unchanged):
- Bilingual EN + Arabic with real RTL on every user-facing surface.
- No App Store: sideload/TestFlight only; iOS release stays human-gated.
- Do NOT invent endpoints or JSON shapes — verify against the uniops routes
  (lib/approvals/types.ts is the source of truth for the item shape).
- Every Codable decodes tolerantly; never crash on unknown fields.

VERIFY on the Mac:
  xcodebuild -project HermesMobile.xcodeproj -scheme HermesMobile \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  xcodebuild test -project HermesMobile.xcodeproj -scheme HermesMobile \
    -destination 'platform=iOS Simulator,name=iPhone 17'
Re-prove EN LTR and AR RTL for the approvals screen after the re-point.

Work on branch claude/uniops-ios-control-plane-kzsnpj, commit atomically, push, and
update the existing draft PR (#1). Report what changed and any blocker. Once this
lands, continue to iOS Phase 2 (Agent Console) per the handoff's phased task list.
```
