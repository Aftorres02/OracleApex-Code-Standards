# Documentation Formatting (Markdown)

**Single responsibility:** Formatting conventions for standalone markdown
documentation (READMEs, `docs/*.md`, architecture/flow references) —
independent of in-code comment conventions (see `plsql-standards.md` §9-11
for JavaDoc-style unit docs).

> New file — authored directly (not consolidated from a prior source).

## 1. Headings Are Plain Text, Never Code

Never put inline code/backticks inside a heading — code font at heading
size/weight renders inconsistently across viewers and reads as broken.
State the concept in plain words in the heading, then name the exact
identifier in the body text immediately below it.

**BAD**:
```md
### `master_login` sets `FSP_AFTER_LOGIN_URL`
```

**GOOD**:
```md
### Set the post-login redirect

`master_login` sets `FSP_AFTER_LOGIN_URL`:
```

## 2. One Heading Per Logical Step, Not a Nested List

When documenting a sequential process, give each step its own heading
(one level below the section — e.g. `###` under `##`) instead of collapsing
the whole sequence into a single numbered list with nested sub-bullets.
Each step gets room to breathe and the doc stays scannable.

## 3. Loose Lists for Multi-Line Items

When a bullet needs more than a short phrase (a condition plus its
consequence, a description plus a follow-up clause), put a blank line
between bullets to force a "loose list" render — each item gets its own
paragraph spacing instead of being crammed tight against its neighbors.

## 4. Section Dividers

Use `---` horizontal rules between major sections once a doc has more than
2-3 top-level sections — otherwise they visually run together.

## 5. Callouts

Use a blockquote (`>`) for asides, caveats, or notes that are related to
but not part of the main flow, with a bold label prefix:

```md
> **Note:** which function the scheme is wired to call isn't confirmed
> from the package code alone — check the app's Authentication Scheme.
```
