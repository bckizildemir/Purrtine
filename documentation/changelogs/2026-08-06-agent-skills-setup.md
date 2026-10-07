# Agent Skills Setup — 2026-08-06

## Overview
Configured the mattpocock engineering skills for this repo via `/setup-matt-pocock-skills`.

## Changes Made
- Added `docs/agents/issue-tracker.md` — declares GitHub Issues, via the `gh` CLI, as this repo's issue tracker.
- Added `docs/agents/domain.md` — declares the single-context domain-doc layout (`CONTEXT.md` + `docs/adr/`, created lazily).
- Added an `## Agent skills` section to `CLAUDE.md` pointing at both docs.

## Why
The engineering skills (`triage`, `wayfinder`, `to-tickets`, `domain-modeling`, etc.) need a per-repo answer for where issues live and how domain docs are laid out before their first use.

## Verification
- Docs-only change; no Swift code touched. No build or test run needed.
- Both new files reviewed against the `setup-matt-pocock-skills` template so their content matches what the skill's other consumers (`code-review`, `wayfinder`) expect at these exact paths.
