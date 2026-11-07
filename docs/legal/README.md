# Legal pages: a copy, not the source

The live privacy policy, terms, and support pages are served by GitHub Pages from the separate public
repository `bckizildemir/catcarecalendar-legal`
(<https://bckizildemir.github.io/catcarecalendar-legal/>). That repository is the source of truth.
App Store Connect and the in-app Settings links point there. Nothing syncs this folder to it.

- To change a legal page, change it in `catcarecalendar-legal` first (publishing it is an owner
  decision, because the page is public and App Review compares it with the app), then copy the result
  here.
- Never copy this folder over the live repository without a diff: on 2026-11-07 this copy was older
  than the live site, and a copy in that direction would have removed the "Service providers" list,
  the US processing note, and the deletion-request path.
- When app behaviour that a page describes changes (what the Task Assistant sends, when the
  anonymous Firebase session starts, retention at Groq), check the live page in the same PR.
