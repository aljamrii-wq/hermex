# Codex Kickoff Prompt — UniOps Founder iOS Control Plane

Paste the block below into a Codex session on a Mac with this repo
(`aljamrii-wq/hermex`, branch `claude/uniops-ios-control-plane-kzsnpj`) checked out.
It picks up the iOS build described in [`CODEX-HANDOFF.md`](CODEX-HANDOFF.md) (the full
brief — read the addendum callouts at the top, especially the 2026-07-08 one about this
kickoff).

**Status:** iOS Phase 0 (auth shell) is done and hardware-verified. Phase 1 (Approvals MVP)
has just been **re-pointed at the unified `GET /api/admin/approvals` endpoint by Claude**
(commit `8bcae6a`) — but Claude's sandbox has no Xcode/Swift toolchain, so that re-point is
code-traced and structurally reviewed only. **It has never been compiled or run.** This
kickoff is a build-and-verify pass, not a rewrite.

```text
You are Codex on the Apple/Xcode lane for ALJAMRI Group, working on a Mac.

Repo: aljamrii-wq/hermex (MIT fork of uzairansaruzi/hermex), branch
claude/uniops-ios-control-plane-kzsnpj. Native SwiftUI, iOS 18+.

FIRST: read CODEX-HANDOFF.md at the repo root in full, especially the 2026-07-08 addendum
about this re-point, and `git log -p 8bcae6a` (or just read the current state of the five
touched files) to understand exactly what Claude changed before you start fixing it.

YOUR TASK — build, fix, and hardware-verify the Approvals MVP re-point:
1. `xcodebuild -project HermesMobile.xcodeproj -scheme HermesMobile -destination
   'platform=iOS Simulator,name=iPhone 17' build`. If it fails, the error is almost
   certainly localized to one of these five files (Claude wrote all of them blind):
   HermesMobile/Networking/Endpoints.swift, HermesMobile/Models/ServerInfo.swift,
   HermesMobile/Networking/APIClient.swift, HermesMobile/Auth/AuthManager.swift,
   HermesMobile/ContentView.swift. Fix compile errors directly — you have full context
   from CODEX-HANDOFF.md §2 on what the actual server contract is
   (lib/approvals/types.ts in the uniops repo is the source of truth if you need to
   double check a field name).
2. `xcodebuild test -project HermesMobile.xcodeproj -scheme HermesMobile -destination
   'platform=iOS Simulator,name=iPhone 17'`. HermesMobileTests/APIEndpointContractTests.swift
   and HermesMobileTests/APIClientAuthAndErrorTests.swift were both updated for the new
   endpoint/decision shape — fix whichever assertions don't match reality once you can
   actually run them.
3. Hardware/simulator-verify the approvals screen specifically:
   - Sign in, confirm the Approvals section loads from the unified endpoint and groups
     items by source (OpenClaw / Agent Runtime / Autopilot / Supplier Ops badges).
   - Tap Approve on an item, confirm the confirmation dialog appears and the decision
     POSTs to the item's own decide.approve.url (not a hand-built path).
   - Confirm the Reject button is ABSENT for any item whose decide.deny is null (some
     sources may not support denial) and PRESENT otherwise.
   - Switch to Arabic and confirm the approvals screen (badges, confirmation dialog,
     RTL layout) is correct.
4. If you find a real bug beyond a compile error (wrong assumption about the server
   contract, a SwiftUI state bug, etc.), fix it and note it clearly in your commit/PR
   update — don't just patch around it silently.

CONSTRAINTS (non-negotiable, unchanged):
- Bilingual EN + Arabic with real RTL on every user-facing surface.
- No App Store: sideload/TestFlight only; iOS release stays human-gated.
- Do NOT invent endpoints or JSON shapes — verify against the uniops routes
  (lib/approvals/types.ts is the source of truth for the item shape).
- Every Codable decodes tolerantly; never crash on unknown fields.

Work on branch claude/uniops-ios-control-plane-kzsnpj, commit atomically, push, and
update the existing draft PR (#1). Update your row in CLAUDE-CODEX-SHARED-LEDGER.md
(aljamrigroup/ops) when done. Report what you fixed and any real blocker. Once this is
hardware-proven, continue to iOS Phase 2 (Agent Console) per the handoff's phased task
list.
```
