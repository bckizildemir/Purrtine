# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Exists? | Meaning                                  |
| -------------------------- | -------------------- | ------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | yes     | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | yes     | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | yes     | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | yes     | Requires human implementation            |
| `wontfix`                  | `wontfix`            | yes     | Will not be actioned                     |

All five roles have a label, checked against the live tracker on 2026-09-09 with `gh label list`. `needs-triage` and `needs-info` were created that day, closing the gap this repo's 2026-09-08 documentation audit found.

Creating a label changes the shared tracker, so ask the owner before you add a role to this table, then run `gh label create <name> --description "<meaning>"`.

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.
