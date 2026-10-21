# Banner and menu templates

Plain monospace in a fenced block. No emoji. Header fields: `mild2wild · <count> · <preset> · <subject> · <medium>`. Card numbers sit under their tier, filled by the split rule in SKILL.md. If shape was inferred instead of asked, add a line: `count <n> chosen: <flow|static>`.

## Banner: full

```
 mild2wild · 10 · full · onboarding flow · pencil
 ░░ mild     ▒▒ medium   ▓▓ bold     ██ wild     ██▶ wilder
 01 02       03 04       05 06       07 08       09 10
 ──── DESIGN.md holds ────────────┤├──── allowed to break ────
```

## Banner: clean (first three tiers only)

```
 mild2wild · 9 · clean · settings page · html
 ░░ mild     ▒▒ medium   ▓▓ bold
 01 02 03    04 05 06    07 08 09
 ──── DESIGN.md holds · nothing breaks ────
```

## Banner: extreme (bold to wilder)

```
 mild2wild · 6 · extreme · settings page · html
 ▓▓ bold     ██ wild     ██▶ wilder
 01 02       03 04       05 06
 ──── bold holds DESIGN.md ──┤├── wild + wilder break it ────
```

## Recap (end of round)

Same strip, then ideas under each tier, `★` on the pick:

```
 ░░ mild     ▒▒ medium   ▓▓ bold     ██ wild     ██▶ wilder
 01 02       03 04       05 06 ★     07 08       09 10
 ░░ 01 one-line idea
 ...
 ██ 07 one-line idea · breaks: <rule>
```

## Menu card (no args or `help`)

```
 mild2wild · design ladder, mild to wilder
 usage: /mild2wild [count] [clean|full|extreme] <what to design>

 full     ░░ mild  ▒▒ medium  ▓▓ bold  ██ wild  ██▶ wilder   (default)
 clean    ░░ mild  ▒▒ medium  ▓▓ bold                         nothing breaks DESIGN.md
 extreme                      ▓▓ bold  ██ wild  ██▶ wilder

 count    default 10. flows and multi-screen: fewer (6). single static things: more (20).

 /mild2wild 20 hero section
 /mild2wild clean settings page
 /mild2wild extreme 6 onboarding flow
```
