---
baseline_schema: "2.0"
pack: "frontdoor"
document: "hallucination"
status: "active"
updated: "2026-10-14"
code_ref: "uncommitted"
---

# frontdoor hallucination journal

## Entry index

| ID | About | Status | Related |
|---|---|---|---|
| FD-Q1 | Flow figure draws a "no, try the next one" edge the README only implies | open | FD-D5 |
| FD-Q5 | More figures beyond the seven | open | FD-D14 |
| FD-D1 | Visual identity: assembly-sheet room | closed | FD-D2 |
| FD-D2 | Typefaces | closed | FD-D1, FD-D4 |
| FD-D3 | Hero markup in an `<h1>` | closed, unverified on github.com | FD-D4 |
| FD-D4 | Navigation as numbered image buttons | closed | FD-D2, FD-D3 |
| FD-D5 | First figure set and kept text forms | closed, extended by FD-D14 | FD-Q1, FD-D14 |
| FD-D6 | Section order | closed | - |
| FD-D7 | Wording of the replaced intro sentence | closed | FD-Q4 |
| FD-D8 | Light-theme accent color | closed | - |
| FD-D9 | Asset folders and the `AGENTS.md` non-ASCII check | closed | - |
| FD-D10 | Lesson: font WARN on a one-weight page | closed | - |
| FD-D11 | Lesson: box WARN on a clipped group | closed | - |
| FD-D12 | The pack is committed with the repository | closed | FD-Q2 |
| FD-D13 | `.frontdoor/` is kept | closed | FD-Q3 |
| FD-D14 | Four more figures | closed | FD-D5, FD-D1 |
| FD-D15 | Lesson: a count in a figure caption | closed | FD-D14 |
| FD-D16 | Hero carries no eyebrow caption | closed | FD-D1 |

## Open questions

### FD-Q1: Does "Try these in order" license a "no, try the next one" edge in the flow figure?

The README says "Try these in order" and gives a "When it works" column. It does not say that a failed condition moves to the next row. The figure `techniques` draws exactly that edge, plus an "Ask IT" exit after row 5 taken from the Ground rules. Options: keep (reads as intended, one inference), or drop the edges and draw a plain numbered list. Recommended: keep.

### FD-Q5: Add more figures beyond the seven?

The README carries seven figures: hero, problem, guide, rules, techniques, integrate, contribute. Candidates that name no guide: a three-outcomes figure (installs per technique; needs admin, so stop and ask IT; installable but not allowed by organization policy, all from Ground rules) and a closing strip for License. Every file added or re-rendered stays in git history, so the image set is best settled before the commit. Recommended: none.

## Closed decisions

### FD-D1: Visual identity is a flat-pack assembly sheet for a furnished room

- Decision: the hero, scenes and diagrams use isometric single-weight line art with numbered steps and one green accent; the metaphor is furnishing your own room while the rest of the building stays IT's.
- Why: it mirrors the repo's idea (install per user, leave machine scope alone) and the fixed section skeleton of every guide - a closed room with a locked door says it without a sentence.
- Breaks if ignored: a later image in another look makes the page read as two projects.
- Rejected: the user picked direction 8 on the board and gave no per-option reasons; the risk listed on the board at the time is shown.

| Direction (board id) | Risk recorded |
|---|---|
| Pegboard (c) | Says little about no admin |
| Blueprint plan (6) | Common look; rooms imply folders |
| Welcome mat (7) | Says little about how guides work |
| Moving boxes (9) | Playful for a security audience |
| Windowsill pots (10) | Names tools, goes stale |
| Hermit crab (11) | Mascot undersells the rule |
| Catalogue (12) | Lists guides, re-render per guide |
| Transit map (13) | Diagram, not warm |
| Cross-stitch (14) | Says home, not locked-down |
| Passport (15) | Resembles a real document |
| Tent in lobby (16) | Link to portable zip needs text |
| Tarot cards (17) | Mystic tone |
| Motel sign (18) | Americana, repeats README |
| Constructivist poster (19) | Slogan tone |
| House in a bottle (20) | Idea needs a sentence beside it |

### FD-D2: Titles in DM Serif Display, everything else in IBM Plex Mono

- Decision: titles, section labels in figures and button labels use DM Serif Display; body, captions and labels use IBM Plex Mono.
- Why: the user was satisfied with the mono body and asked for a different title face; DM Serif Display was their choice from four candidates.
- Breaks if ignored: a third face or a different title face splits the identity.
- Rejected: the user gave no per-face reasons; risks recorded on the board were Fredoka (rounded faces can read as a children's brand), Unbounded (wide, so the title shrinks), Syne ExtraBold (so wide it overlapped the scene until cut to 58 px). Archivo Narrow and Bricolage Grotesque were tried in the early rounds only.

### FD-D3: Hero sits in `<h1 align="center"><picture>`

- Decision: the hero is a `<picture>` inside the `<h1>`, with alt text that starts with the name and the promise, then describes the drawing.
- Why: the page keeps its title with images off; the user approved it knowing it was not yet checked on github.com.
- Breaks if ignored: with the image alone and no heading, the page has no title for screen readers or search.
- Rejected: a `<p align="center">` image followed by `# Homeware` as text - the name would show twice.
- Unverified: a `<picture>` inside an `<h1>` and inside an `<a>` was not seen on github.com.

### FD-D4: Navigation is four numbered image buttons shown at height 40

- Decision: Guides, Ground rules, Techniques, Contributing, numbered 1 to 4 in section order, labels in DM Serif Display, each wrapped in an anchor, `height="40"`.
- Why: the user asked for graphic buttons; at height 40 the 28 px label reads at about 20 px on screen, above the 17 px readable floor.
- Breaks if ignored: the numbers claim an order, so they must keep matching the page.
- Rejected: height 34 (the reference default - label about 17 px, no margin above the floor), plain text anchors (the user declined).

### FD-D5: Three figures, text forms kept

- Decision: hero, a rules scene and a techniques flow; the Ground rules bullets stay as text and the techniques table moves into `<details>` under the flow; the PowerShell block stays visible.
- Why: the user took the largest option offered and asked that each text form be kept; alt text narrates every node of the flow.
- Breaks if ignored: dropping the table leaves alt text as the only text form of the flow.
- Rejected: hero only; hero plus rules scene.

### FD-D6: Guides table sits above Ground rules

- Decision: order is hero, buttons, intro, Guides, Ground rules, General techniques, Contributing, License.
- Why: a visitor first asks whether their tool is listed.
- Breaks if ignored: the numbered buttons stop matching the section order.
- Rejected: the original order with Ground rules first.

### FD-D7: Intro says guides include only steps run as a standard user

- Decision: the line reads "Guides include only steps that were run as a standard user. A step taken from vendor docs and not tested says so in the guide." The old sentence about a real locked-down workstation is gone.
- Why: this restates the rule in `CONTRIBUTING.md`; the approved wording (each guide records its tested version) is false for the GitLab MCP guide, which lists "-".
- Breaks if ignored: the README claims something one of its five guides contradicts.
- Rejected: the old sentence (cannot be traced to the guides), the approved wording as given (the "-" row), deleting the line (loses the label policy).
- Departs from the wording the user approved; the user then accepted this wording. Closes FD-Q4.

### FD-D8: Light accent is `#2a715f`

- Decision: the light-theme accent is `#2a715f`, 5.05 on the paper `#f3efe6`; the dark accent `#6cc7ad` stays, 8.55 on `#191b1f`.
- Why: the first value `#2f7d6b` measured 4.29, large-text only, and the accent carries 17 px labels.
- Breaks if ignored: small green labels fall below the contrast floor in light theme.
- Rejected: keeping `#2f7d6b`.

### FD-D9: Images in `assets/readme/`, sources in `assets/source/`, check 2 excludes `*.webp`

- Decision: rendered images and HTML sources live in the two folders; check 2 of `AGENTS.md` (non-ASCII scan) excludes `*.webp`; the Layout table lists both folders.
- Why: a WebP is binary and always produces non-ASCII hits; the user approved the folders and the check change.
- Breaks if ignored: the check fails on every image and agents learn to ignore it.
- Rejected: leaving check 2 unchanged.

### FD-D12: The pack is committed with the repository

- Closes FD-Q2.
- Decision: `docs/baseline/frontdoor/` is committed together with the repository content.
- Why: the user chose it from four options after being told that `AGENTS.md` calls the repository public and that their global rule keeps packs out of published repositories.
- Breaks if ignored: if this is the published repository, the pack ships; every edit to the pack stays free of identifiers (`AGENTS.md` hard rule 1) because it is now public text.
- Rejected: local only via `.git/info/exclude`, `docs/baseline/` in `.gitignore`, a private working repository - the user declined all three and gave no reasons.
- The commit itself still needs the user's explicit request.

### FD-D13: `.frontdoor/` is kept

- Closes FD-Q3.
- Decision: do not delete `.frontdoor/`; leave the seven rounds of sketches and the board in place.
- Why: the user answered no to deleting it after the README is seen on github.com and gave no reason; it is gitignored, so nothing ships.
- Breaks if ignored: deleting it loses the images of every direction listed in FD-D1 and the board that compares them.
- Rejected: delete now, delete after the github.com check.
- The `AGENTS.md` scans reach this folder; the last runs found nothing in it.

### FD-D14: Four more figures beside the first three

- Decision: add `problem` (default installer against a Homeware guide, after the intro), `guide` (the template sections in order, above the Guides table), `integrate` (the integration steps, above the code block) and `contribute` (the path to add a guide, in Contributing). Source: `assets/source/figures.html`. Extends FD-D5.
- Why: the user said three visual elements were too few; each new figure carries a relation the text gives slowly (before and after, an order, a mapping), and every label comes from `README.md`, `CONTRIBUTING.md` or the guide template.
- Breaks if ignored: a figure that names a guide or states a count goes stale or contradicts its source.
- Not drawn: figures for the Guides table rows (they would name guides; FD-D1 records the same risk for the catalogue direction) and for the sentence on organization policy (it would only restate the sentence).

### FD-D16: The hero carries no eyebrow caption

- Decision: the line "ASSEMBLY SHEET / STANDARD USER" above the title is removed from the hero, together with its `.no` rule in `shared.css`.
- Why: the user asked for its removal; the title block stays vertically centered without it.
- Breaks if ignored: n/a.
- Rejected: keeping it - it had been carried over from direction 8 by default and was never confirmed by the user.

## Lessons

### FD-D10: A font WARN on a page with one weight is a false alarm

- Mistake: reading "IBM Plex Mono not loaded" on `nav.html` as a missing font. It looked real because `render.py` prints it as a fallback face in the images.
- Disproved by: the digits rendered in Plex Mono. The check probes the family at weight 400, and the page used only weight 600, so the 400 face was never fetched.
- Fix: weight 400 for the number circles; the WARN went away. A hidden element that forces the load would also silence it and would hide the cause.

### FD-D11: A box WARN on a clipped group is not overflow

- Mistake: treating "content leaves the item box" on `rules.html` as a real overflow. It looked real because a glow circle of radius 190 reaches past the item edge.
- Disproved by: the circle sits inside a clip path, so nothing drawn leaves the box; the check measures the unclipped group.
- Fix: `data-bleed` on the clipped group, then look at the image.

### FD-D15: A count in a figure caption must match its source

- Mistake: the first `contribute` caption said "four steps, in this order". It looked right because the figure draws four numbered rows.
- Disproved by: `CONTRIBUTING.md` lists five steps under "Adding a guide"; the scan comes from its sanitization checklist, not from that list.
- Fix: the caption now says "the short path; CONTRIBUTING.md has the full checklist". A figure that says a number states a count the source has to back.
