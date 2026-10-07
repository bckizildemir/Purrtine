# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**Layout: single-context.** One `CONTEXT.md` and one `docs/adr/` at the repo root.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the glossary / ubiquitous language.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved. `docs/adr/` is created lazily too, so an absent `docs/adr/` is expected rather than a fault — check the directory instead of trusting a statement here about whether it exists.

## File structure

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-....md
│   └── 0002-....md
├── CatCareCalendar/          ← app sources
├── CatCareCalendarTests/
└── CatCareCalendarUITests/
```

If this repo ever splits into multiple bounded contexts, switch to a root `CONTEXT-MAP.md` pointing at per-context `CONTEXT.md` files, with context-scoped `docs/adr/` alongside each — and update the layout line at the top of this file.

## Related repo docs

These are separate from the domain docs above, but worth knowing about:

- `documentation/PRD.md` — source of truth for product scope and success metrics.
- `documentation/features/` — per-flow specs.
- `documentation/changelogs/` — dated change notes.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
