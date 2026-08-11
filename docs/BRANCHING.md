# Branching and repository rules

PrivateMic uses a lightweight, release-ready `main` model.

- `main` contains reviewed, releasable code.
- `feature/*`, `fix/*`, `docs/*`, and `chore/*` are short-lived pull-request branches.
- `vMAJOR.MINOR.PATCH` tags identify immutable releases.
- Experimental or local-only work stays off release tags until it is intentionally approved for public distribution.

## Recommended GitHub ruleset for `main`

In **Settings → Rules → Rulesets**, create an active branch ruleset targeting `main` with:

- require a pull request before merging;
- require one approval and dismiss stale approvals;
- require the `Build and test` status check;
- require branches to be up to date before merging;
- require conversation resolution;
- block force pushes and branch deletion; and
- allow repository administrators to bypass only for emergencies.

Squash merge is the recommended default because it keeps one focused commit per pull request. Delete merged branches automatically.

Create a tag ruleset targeting `v*` that restricts tag creation and deletion to the repository owner. This prevents accidental or replaced releases.
