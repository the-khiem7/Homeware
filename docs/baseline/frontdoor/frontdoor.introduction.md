---
baseline_schema: "2.0"
pack: "frontdoor"
document: "introduction"
status: "active"
updated: "2026-10-14"
code_ref: "uncommitted"
---

# frontdoor - Homeware README redesign

## Scope

Redesign the front page of the Homeware repository: a complete `README.md` built around a hero banner, numbered navigation buttons and six more figures, every image a light and dark pair. In scope: `README.md`, `assets/readme/`, `assets/source/`, the Layout table and check 2 of `AGENTS.md`. Out of scope: the five guides, `CONTRIBUTING.md`, the guide template, a landing page.

## Current truth

Inspected state: working tree on top of HEAD `809cd70`. Every change is staged in the index, nothing is committed; the hero images, `hero.html` and `shared.css` were edited after staging and also carry unstaged changes.

| Item | State |
|---|---|
| `README.md` | Rewritten, staged. Hero in `<h1>`, four image buttons, a before-and-after figure after the intro, the template figure and then the Guides table, the rules scene, the techniques flow with the old table inside `<details>`, the integration figure above its code block, the add-a-guide figure in Contributing. The code block and the License are unchanged |
| `assets/readme/` | 22 WebP, 11 images each with a `-dark` twin: hero, four buttons and six figures (problem, guide, rules, techniques, integrate, contribute). 3 KB to 102 KB each |
| `assets/source/` | `shared.css`, `shared.js`, `hero.html`, `nav.html`, `rules.html`, `techniques.html`, `figures.html`. The render command is in each page's header comment |
| `AGENTS.md` | Layout table lists `assets/`; check 2 excludes `*.webp` |
| `.frontdoor/` | Seven rounds of sketches and a local board. Gitignored, never committed, kept (FD-D13) |
| github.com rendering | Not observed |

No image names a guide or states a count of guides, so adding a guide to the registry never forces a re-render.

## Signature

| Line | Value |
|---|---|
| Concept | Flat-pack assembly sheet for a room you furnish inside a building you do not own |
| Shape language | Isometric single-weight outlines, numbered step circles, dashed insertion paths, no characters |
| Typeface | DM Serif Display for titles and button labels, IBM Plex Mono for all other text |
| Palette logic | Warm paper or charcoal ground, one ink line, one green accent reserved for what is allowed |
| Presentation | One assembly-sheet scene per picture, short mono captions |
| Not | Stock icons, blue-purple gradient, mascot, furniture-brand look |

## Constraints

| Constraint | Source |
|---|---|
| Public repository: no usernames, hostnames, account ids, company names or screenshots in images, alt text or sources | `AGENTS.md` hard rules 1 and 2 |
| ASCII only, no en or em dash, no hard-wrapped paragraph in `README.md` and in the sources | `AGENTS.md` |
| Copyable commands stay text, never inside `<details>` | skill rule for READMEs |
| Smallest image text 17 CSS px; small text at contrast 4.5 or better | image quality floor |
| One image at most 300 KB | `render.py` default |
| An image states nothing the README does not | figure rule: a figure is where an invented claim hides |
| Fonts load from a font host; render online or the fallback face lands in the images | `render.py` WARN |

## Open items

Open questions and every closed decision with its reasoning: `frontdoor.hallucination.md`. Phase status and next action: `frontdoor.roadmap.md`.
