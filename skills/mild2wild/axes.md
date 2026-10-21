# mild2wild Axis Library

Reference pairs for variant generation. Adapted from design-shotfun/axes.md. Use these as the treatment axes that mild and medium cards move along, and as vocabulary for naming what a bold card pushes. Not a mandatory trio; pick the axes that fit the subject.

Each pair is one axis. The two poles are the extremes — variants can sit anywhere between them, but they should land clearly on one side to create contrast across the batch.

Contents:
- Density
- Restraint
- Editorial vs utilitarian
- Warmth
- Type character
- Depth
- Grid character
- Ornament level
- Motion implication
- Color volume
- Scale contrast
- Surface character

---

## Density

**Dense** — information-forward, tight spacing, high data-to-chrome ratio. Rows, tables, compact lists. Feels productive, tool-like. The screen respects your time by showing you more.

**Airy** — generous whitespace, few elements per viewport, breathing room around everything. Feels calm, editorial, unhurried. The screen respects your attention by asking less of it.

---

## Restraint

**Restrained** — nothing decorative. Type and space do all the work. Color appears once, if at all. The design looks like it could not be simpler. Confidence through subtraction.

**Expressive** — ornament earns its keep but is present. Layering, texture, color volume, illustration, motion implications. The design has a visual personality that announces itself.

---

## Editorial vs utilitarian

**Editorial** — the screen reads like a publication. Hierarchy is typographic. Headings carry weight. White space is intentional. Copy is part of the design, not labeled data fields.

**Utilitarian** — the screen reads like a tool. Labels, fields, controls. Density of function over visual statement. The interface gets out of the way of the task.

---

## Warmth

**Warm** — tinted surfaces, rounded shapes, softer shadows, colors biased toward amber/terracotta/cream. Feels approachable, human, analog.

**Cool / neutral** — clean whites or mid-grays, sharp edges, no color bleed into neutrals. Feels precise, clinical, digital. The warmth is in the product, not the chrome.

---

## Type character

**Serif-led** — display type is serif or transitional. Carries authority and editorial gravity. Pairs with fine details and tighter leading.

**Sans-led** — display type is sans or grotesque. Carries clarity and directness. Works at any scale without fussiness.

---

## Depth

**Flat** — surfaces live on one plane. No shadows, no elevation. Borders or color contrast establish hierarchy. Feels modern, graphic, poster-like.

**Layered** — explicit elevation model: cards lift, modals float, active states cast shadows. Depth communicates hierarchy spatially rather than typographically.

---

## Grid character

**Strict grid** — columns, gutters, baseline alignment. Everything sits on the grid. Feels structured, trustworthy, designed-by-a-system. Predictability is the feature.

**Asymmetric** — intentional grid breaks. Pull-quotes bleeding past the column, images crossing gutters, deliberate misalignment for emphasis. Feels designed-by-a-human.

---

## Ornament level

**Minimal ornament** — no decorative elements. Dividers only where necessary. No icons decorating headings. The structure is the decoration.

**Considered ornament** — icons, rule lines, spot illustrations, or texture used deliberately to reinforce meaning or brand voice. Each decorative element has a job.

---

## Motion implication

**Static** — the design reads as still. No transition hints in the layout. State changes imply snap cuts or simple fades. Prioritizes clarity over dynamism.

**Motion-implied** — the layout implies choreography. Staggered lists, entrance paths baked into the hierarchy. The design hints at how it would animate even in a static frame.

---

## Color volume

**Monochromatic** — one hue (or near-one-hue) for the whole surface. Accent used sparingly or not at all. Relationships created through lightness and weight, not color.

**Accent-forward** — the accent color does real work. Applied to CTAs, active states, key data points. The accent is part of the experience, not just a brand tag.

---

## Scale contrast

**Uniform scale** — type sizes stay within a narrow band. The hierarchy is created through weight and position, not dramatic size jumps. Feels measured, composed.

**High contrast scale** — large display text against small body text. Dramatic size jumps. The page has a focal point that anchors everything else. Feels bold, editorial.

---

## Surface character

**Bare** — content sits directly on the background. No cards, no panels, no borders. The page is the container. Forces typographic hierarchy to carry more weight.

**Contained** — content lives in cards, panels, or bordered sections. Explicit containers communicate grouping and create scannability. Risks feeling overdesigned if overdone.

---

## Pencil style archetypes

Optional. `mcp__pencil__get_style` returns 26 style archetypes. When a variant's axis position matches one, attach the nearest archetype name to its brief. Examples (not exhaustive; call `get_style` for the live list):

| Axis position              | Candidate archetype    |
| -------------------------- | ---------------------- |
| Editorial, serif-led       | Editorial Scientific   |
| Contained, warm, airy      | Soft Bento             |
| Utilitarian, dense, strict | Blueprint Technical    |

The archetype guides composition and mood only. Colors, fonts, and spacing still come from the project's design variables, never from the archetype.
