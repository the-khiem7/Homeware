---
baseline_schema: "2.0"
pack: "frontdoor"
document: "roadmap"
status: "active"
updated: "2026-10-14"
code_ref: "uncommitted"
---

# frontdoor roadmap

| Phase | Depends on | Status | Acceptance |
|---|---|---|---|
| Phase 1 | - | complete | Facts collected from the repo |
| Phase 2 | Phase 1 | complete | Hero direction and title font chosen by the user |
| Phase 3 | Phase 2 | complete | All images render without WARN and were looked at |
| Phase 4 | Phase 3 | complete | `README.md` written, local checks pass |
| Phase 5 | Phase 4 | complete | Four more figures built, placed and checked |
| Phase 6 | Phase 5 | pending | Observed on github.com, committed on the user's request |

## Phase 1: Audit and fact collection

Status: complete. Repo read in full: `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, template, head of each of the five guides. Classified brownfield with no brand evidence. No tests read the README. Questions A to D answered by the user.

## Phase 2: Signature and hero

Status: complete. Seven rounds on a local board. The user chose direction 8 (the assembly room), then DM Serif Display for the title. Reasoning and alternatives: FD-D1 (visual identity) and FD-D2 (typefaces).

## Phase 3: Image build

Status: complete. Evidence: `render.py` on all four pages ends without WARN; every image was opened in light and dark; the smallest text pairs were computed with `contrast.py`. Largest file `rules.webp` at 104 KB.

## Phase 4: README rewrite and local verification

Status: complete. Evidence, run from the repo root on the working tree:

- Secret scan with trivy: clean, with `.frontdoor/` skipped.
- Non-ASCII scan: no hits anywhere, `.frontdoor/` included.
- Identifier scan (twelve-digit numbers, email shapes, user paths): no hits outside `.frontdoor/`.
- The one helper script parses.
- Five guide links, the other four links, 14 image paths and 4 navigation anchors all resolve.

## Phase 5: Additional figures

Status: complete. Evidence: `figures.html` renders `problem`, `guide`, `integrate` and `contribute` without WARN; all eight files opened in light and dark; smallest text pairs measured earlier hold for the same tokens. README now has 22 image paths (11 images, each a light and dark pair), all present, none unused; largest file `rules.webp` at 102 KB. Re-run after the README edit: trivy clean with `.frontdoor/` skipped, no non-ASCII, no identifier hits outside `.frontdoor/`, script parses, all anchors resolve. The hero was then re-rendered without its eyebrow caption (FD-D16); both themes viewed, no WARN. Reasoning: FD-D14, FD-D15 and FD-D16.

## Phase 6: Observe and publish

Status: pending. State: every change is staged as one set, none committed; the hero files carry later unstaged edits. Steps in order:

- Commit on the user's explicit request only. Splitting into the commits below needs the index reset first; ask before doing it. Proposed split: `README.md`, `assets/`, `.gitignore` as `docs(readme)`; `AGENTS.md` as `docs(agents)`; the pack under `docs/baseline/frontdoor/` as its own commit (FD-D12). No attribution trailer.
- After a push, open the README on github.com in light, dark and at phone width. Check the `<picture>` inside `<h1>` (FD-D3), the `<picture>` inside `<a>` for the buttons, that the button labels read at height 40, and that the seven figures stay legible at the column width.
- Record what was observed here, including a failure.

## Risks

| Risk | Handling |
|---|---|
| github.com renders `<picture>` inside `<h1>` differently | Fallback and cost are in FD-D3 |
| The pack is public text once committed | FD-D12 |
| The flow figure states an edge the README only implies | FD-Q1 |

## Next action

Phase 6, first step: ask the user whether to commit, then follow the steps above in order. Settle FD-Q5 (more figures) first if the user wants more images, because each file enters git history.
