---
name: apexlang-lessons
description: Lessons learned for hand-authoring Oracle APEXlang (.apx) apps — grammar gotchas, when to skip the orchestrated generation loop, known packaged-tooling bugs/false positives, and runtime-only gotchas like Template Directive syntax that no compiler/linter catches. Load before writing or reviewing .apx files, and before writing any htmlExpression/htmlCode/Template Directive content.
---

# APEXlang Lessons

Fast-start notes for building an APEXlang app. This is **not** a
replacement for the packaged Oracle skill (`apex:apex` → `apexlang`) —
that skill's `references/policies/apexlang-dsl-reference.md`, its
`assets/grammar/apexlang.ebnf`, and its `templates/**` tree remain the
authoritative source for syntax. This skill only captures what took real
digging to find, what's actually required versus optional, and known
tooling bugs — so the next build doesn't have to re-scan everything from
zero.

> Project-specific details (SQLcl connection alias, target workspace,
> worked example apps already in a given repo) belong in that consumer
> project's own docs, not here — this skill only covers what holds true
> regardless of which project or workspace is being built against.

**Two different authorities, don't conflate them.** The packaged
`apexlang` skill's grammar/templates are authoritative for the DSL's
*compile-time shape* — what `apex validate` will accept. They say
nothing about how APEX actually *renders* a feature at runtime (Template
Directives, JavaScript/Dynamic Action behavior, a component's real
declarative attribute set). For that, the official Oracle APEX 26.1
documentation is authoritative — index at
`https://docs.oracle.com/en/database/oracle/apex/26.1/index.html`.
Whenever a feature's real runtime behavior matters and isn't already
nailed down by a working precedent in the target app's own `.apx` tree,
fetch the relevant page from there before relying on memory, a packaged
template's superficial resemblance, or a planning doc's own snippet —
see "Runtime-evaluated content the compiler never checks" below for the
concrete incident that made this necessary.

---

## Two speeds of generation

The packaged skill supports two very different workflows, and picking the
wrong one wastes time:

**The orchestrated loop** (`references/workflows/apex-generation.md`) —
generate → review → fix, with a live SQLcl compiler-truth audit via
`node tools/apexctl.mjs runtime validate ...`, and a 0.95 confidence
threshold before it calls anything done. This is thorough but slow — it
insists on live database evidence at every step. Use it for a large or
production-bound app where that audit trail matters.

**Direct hand-authoring** — read the relevant `templates/page-examples/**`
and `templates/items/**` files plus the grammar, write the `.apx` files by
hand, and only run `apex validate` once the draft is ready to check. This
is much faster for a first draft or a proof-of-concept; still needs a real
`apex validate` pass before `apex import` — hand-authoring doesn't skip
that gate, it just skips the generate/review/fix loop around it.

> **Note:** if the user says an agent "is taking too long," it's usually
> running the orchestrated loop when direct hand-authoring would have been
> enough for the ask.

---

## Minimum viable scaffold

Based on `templates/base-app-structure/scaffold-example/`, a runnable app
needs:

- `application.apx` — app-level config (auth scheme, theme, nav references)
- `.apex/apexlang.json` — just an `mmdVersion` stamp, copy as-is
- `deployments/default.json` — must name the target APEX workspace
- `pages/p00000-global-page.apx` — can be a bare `page 0 (name: Global Page)`
- `pages/p09999-login.apx` — required when using the default Oracle APEX
  Accounts authentication scheme; copy the scaffold version unmodified
- `shared-components/authentications.apx` — referenced by `application.apx`
- `shared-components/lists.apx` — the nav bar and nav menu lists, both
  referenced by `application.apx`
- `shared-components/themes/universal-theme/theme.apx` — referenced by
  `application.apx`
- `shared-components/static-files.apx` + `static-files/icons/*.png` — only
  needed if a page's hero/login region sets `image { fileUrl: #APP_FILES#... }`

Skip these unless the app actually uses them — they add no value empty and
just add surface area to review:

- `page-groups.apx` — only if pages are organized into named groups
- `shared-components/authorizations.apx` — only if a page/component
  references an authorization scheme
- `shared-components/breadcrumbs.apx` — only if a page has a breadcrumb
  region
- `shared-components/lovs.apx` — only if a shared (non-inline) LOV is used
- `shared-components/component-settings.apx` — global item/region defaults;
  omit unless a specific default needs overriding
- `supporting-objects/` — only when the app installs/deinstalls real DDL

---

## Grammar details not obvious from the example templates

The Markdown templates under `templates/items/**` illustrate common cases
but don't spell out every valid combination. These came from reading
`assets/grammar/apexlang.ebnf` directly:

A `displayOnly` item sourced from a PL/SQL expression (e.g. current
timestamp, a computed label) needs `language` **and** a fenced multiline
string, not just the expression as a bare string:

```apexlang
source {
    type: expression
    language: plsql
    plsqlExpression:
        ```plsql
        to_char(systimestamp, 'HH24:MI:SS')
        ```
}
```

A `displayOnly` item that mirrors another item's current value (including
built-ins like `APP_USER`) uses `source.type: item` with a plain string —
no `@` prefix, because `item` here is a session-state item name, not a
component reference:

```apexlang
source {
    type: item
    item: APP_USER
}
```

`source.type: substitutionString` is explicitly invalid on a `displayOnly`
item's `source` block. A raw substitution string like `&APP_USER.` is only
valid directly inside a static-content region's `source.htmlCode` — not as
an item source type.

The standard label/appearance template for an ordinary (non-required) item
is `@/optional-floating` — it comes from `theme.apx`'s
`componentDefaults.optionalLabel`, not a guessed alias like `@/text`.

Slot naming is inconsistent by design: items placed inside a host region
use `layout.slot: regionBody`, but a region placed directly on a standard
page body uses `layout.slot: BODY` (uppercase, page-level slot).

Every `.apx` file must use LF line endings. The orchestrated pipeline
enforces this and blocks with `APEXLANG_LF_LINE_ENDINGS_REQUIRED_001` if it
isn't; hand-authored files need the same check done manually before
`apex validate`.

A horizontal bar chart needs the orientation stated explicitly — it is not
inferred from `chart.type`:

```apexlang
chart {
    type: bar
}
chartAppearance {
    orientation: horizontal
}
```

A modal dialog page's form region goes in `contentBody`, not `BODY` — `BODY`
is the standard-page body slot, `contentBody` is the dialog-page equivalent:

```apexlang
region object-detail (
    type: form
    layout {
        sequence: 10
        slot: contentBody
    }
)
```

Every `displayOnly` page item bound to a form region needs an explicit
`settings` block (`sendOnPageSubmit: false`, `format: plainText`) even though
some canonical templates show it omitted. Without it, live `apex validate`
rejects the item on build 26.1.0+3102:

```apexlang
pageItem P110_STATUS (
    type: displayOnly
    settings {
        sendOnPageSubmit: false
        format: plainText
    }
    source {
        formRegion: @object-detail
        column: STATUS
        dataType: varchar2
    }
)
```

`execution.event` is not a valid property on a `dynamicAction`'s child
`action` block — only on the parent `dynamicAction`'s own `when`/`execution`.
Setting it on an `action` block is silently wrong; leave `execution` on an
action limited to `sequence` and `fireOnInit`.

> **Note:** `node tools/apexctl.mjs workspace probe` resolves its discovery
> root from the current working directory at invocation time, not from the
> app path you pass elsewhere. Running it from inside the skill package
> itself makes it scan the package's own `README.md`/`SKILL.md` as
> "discovered requirements sources" — not useful for an actual app build.
> For hand-authoring, skip `workspace probe` entirely; you already know the
> target app path and workspace name from the prompt.

---

## Runtime-evaluated content the compiler never checks — verify against real Oracle docs

`apex validate` and `apex import` only check the *shape* of the DSL —
`htmlExpression`, `htmlCode`, `plsqlCode`, `sqlQuery`,
`javaScriptExpression`, and every other multiline-string field are
**opaque text** to the compiler. A syntax error inside one of those
strings compiles clean, imports clean, and only fails at runtime — and it
fails *silently*: APEX falls back to the raw column/item value instead of
erroring, so a broken Template Directive can sit through review, a clean
`apex validate`, and even a live `apex import`, and still look completely
fine until someone actually opens the page in a browser.

**Real incident**: a ticket's own planning doc specified a Column HTML
Expression using `{if COL='X'/}...{%elseif COL='Y'/}...{%else/}...
{endif/}`. Implemented verbatim, it passed `apex validate`/`apex import`
without one warning, and rendered as plain unstyled raw column text —
`{%elseif/}` and `{%else/}` are not real APEX Template Directive tokens.
Nothing in the compile/import pipeline could have caught this; only a
live screenshot did.

**The actual, confirmed Template Directive grammar** (verified against
Oracle's own packaged page-example templates under `templates/page-
examples/**`, which are the only in-repo ground truth for *runtime*
behavior — the `.ebnf` grammar only governs the DSL's compile-time
shape, not what's valid inside these opaque strings):

- Single test, no alternative branch: `{if EXPR/} ... {endif/}`, negated
  with `{if !EXPR/} ... {endif/}`. `EXPR` is a bare item/column name used
  as a truthy/falsy test (non-null, non-zero) — no `=`, `>`, or any other
  inline comparison operator appears anywhere in the packaged templates.
  Prefer two separate `{if EXPR/}` / `{if !EXPR/}` blocks over guessing
  at a comparison operator's syntax.
- Multi-way exact match: `{case COL/} {when VALUE/} ... {when VALUE/}
  ... {otherwise/} ... {endcase/}` — `VALUE` is bare, no quotes, matched
  by equality. This is what an `{if}/{elsif}/{else}/{endif}` ladder
  should become; no `{elsif}`/`{else}` form is demonstrated anywhere in
  the packaged templates, so don't assume one exists without checking
  the official doc below first.

**Before writing anything into a `htmlExpression`, a Static Content
`htmlCode`, a `javaScriptExpression`, or any other field this DSL treats
as an opaque string** — never trust a planning doc's literal snippet,
and don't rely on memory either:

1. Check whether a working precedent for the exact same directive/
   feature already exists elsewhere in *this* app's own `.apx` tree —
   that beats any external reference.
2. If not, fetch the relevant official Oracle APEX 26.1 doc page before
   writing it, and confirm the exact syntax rather than extrapolating
   from a similar-looking pattern. Start from the index —
   `https://docs.oracle.com/en/database/oracle/apex/26.1/index.html` —
   and for Template Directives specifically,
   `https://docs.oracle.com/en/database/oracle/apex/26.1/htmdb/using-template-directives.html`.
3. Since neither `apex validate` nor `apex import` can catch a runtime
   rendering bug in this kind of content, "it compiled and imported"
   proves nothing for this specific risk. Treat the work as unverified
   until it's actually been seen rendering — ask the user for a
   screenshot, or use a browser tool if one is available — before
   calling it done.

---

## Removable default filters and row highlighting

A report filter the user can clear themselves (e.g. "exclude synonyms by
default") is a `filter` nested inside a `savedReport(visibility:
primaryDefault)` block — not a hardcoded `where` clause in the SQL, and not
a region-level attribute. `highlight` lives in that same `savedReport` block
too; a region-level `highlight` sibling is rejected on this build even
though at least one canonical example template shows it there.

```apexlang
savedReport primary-default (
    visibility: primaryDefault
    view {
        rowsPerPage: 50
    }

    filter exclude-synonyms (
        type: column
        column: OBJECT_TYPE
        operator: !=
        value: SYNONYM
    )

    highlight invalid-objects (
        name: Invalid Objects
        condition {
            column: STATUS
            operator: =
            value: INVALID
        }
        colors {
            background: #FFCDD2
        }
        execution {
            sequence: 10
        }
    )
)
```

A KPI card or standalone chart has no "clear filter" affordance for the
viewer, so for those it's fine (and simpler) to hardcode the same exclusion
directly in the SQL — reserve the `savedReport` filter pattern for the
interactive report itself.

---

## Row-level actions: don't rabbit-hole this, ask or hand it back instead

> **Correction:** everything below this note describes a JavaScript
> workaround built after concluding the declarative Interactive Report
> link was unsupported. **That conclusion should be treated as
> unverified, not settled.** Opening a report row into a detail page is
> one of the most standard, oldest features of Oracle APEX Interactive
> Reports — a "Link" attribute on a column, or a region-level link
> attribute, that Page Designer exposes as a plain checkbox/field, with
> checksum handling built in automatically. It would be surprising for any
> serious APEXlang generator to genuinely lack a way to express that. The
> two rejections recorded below are more likely evidence of wrong property
> names (`target`/`linkText` were guessed from one canonical example, not
> confirmed against the grammar or against real Page Designer field names)
> than evidence the capability doesn't exist.
>
> **The actual lesson:** when a request is for a well-known, completely
> standard declarative APEX capability and the tool at hand seems to
> reject every attempt, that's a signal to stop and either (a) verify
> against real APEX product knowledge / documentation what the correct
> property actually is, rather than pattern-matching off one possibly-wrong
> template, or (b) tell the user directly and let them wire it up in Page
> Designer themselves — a two-minute checkbox for an experienced APEX
> developer — instead of spending many tool calls building and debugging a
> custom JavaScript substitute. The workaround below cost far more effort
> than the feature was worth, and turned out to be broken anyway (see the
> checksum bug noted after it). Don't repeat that trade.

The two things tried, before giving up and reaching for JavaScript:

- A region-level Interactive Report `link` block — rejected by this
  packaged tool's own generation rule for this build.
- A column-level `link` block with `target`/`linkText` (the form shown in
  the package's own canonical example) — matches the template, but live
  `apex validate` against a real instance rejects `target` and `linkText`
  as invalid properties. **Next time, check the grammar file directly for
  the real property names before concluding the feature is unsupported.**

A genuinely native mechanism also exists at the compiler level —
`NATIVE_ROW_SELECTOR` / `rowSelection.currentSelectionPageItem`
(componentTypeId 7030), confirmed via `query-valid-props.mjs` against live
compiler metadata — but this DSL's own component schema
(`assets/component-attributes.json`) has no authoring path for it, and the
local linter hard-rejects it if you write it anyway.

The JavaScript substitute actually built (synthetic radio-button column —
the `APEX$` prefix on a column identifier signals "not a real projected
column," so it is exempt from source-column matching — plus a page-level
button and a `dynamicAction` that reads the checked radio and opens the
target page as a modal dialog) is recorded below **as a cautionary example,
not a recommended pattern**:

```apexlang
column APEX$SELECT_ROW (
    type: plainText
    heading {
        heading: Select
    }
    layout {
        sequence: 5
    }
    source {
        dataType: STRING
    }
    columnFormatting {
        htmlExpression: <input type="radio" name="P100_SELECT_ROW" value="#OBJECT_ID#" aria-label="Select this row">
    }
    enableUsersTo {
        sort: false
        filter: false
    }
)
```

```apexlang
button view-detail (
    buttonName: VIEW_DETAIL
    label: View Detail
    layout {
        sequence: 10
        region: @objects
        slot: RIGHT_OF_IR_SEARCH_BAR
    }
    behavior {
        action: definedByDynamicAction
    }
)

dynamicAction open-object-detail (
    name: Open Object Detail
    when {
        event: click
        selectionType: button
        button: @view-detail
    }

    action open-object-detail-dialog (
        action: executeJsCode
        settings {
            jsCode:
                ```javascript
                var lObjectId = $("input[name='P100_SELECT_ROW']:checked").val();
                if (lObjectId) {
                  apex.navigation.dialog(
                    "f?p=" + $v("pFlowId") + ":110:" + $v("pInstance") + "::NO:110:P110_OBJECT_ID:" + lObjectId,
                    { title: "Object Detail", height: "480", width: "640", modal: true }
                  );
                } else {
                  apex.message.showErrors([
                    { type: "error", location: "page", message: "Select a row before choosing View Detail." }
                  ]);
                }
                ```
        }
    )
)
```

Pair it with a `refresh` dynamic action on `apexafterclosedialog` targeting
the report region, so the report reflects anything the modal might imply
changed — `apex.navigation.dialog()` fires that event on close.

> **This workaround is broken as written, and that's the point.** Both
> pages in the example carry `security.pageAccessProtection:
> argumentsMustHaveChecksum` (the standard scaffold default). A native
> declarative link computes and appends the required checksum
> automatically; the hand-built `"f?p=" + ... + ":P110_OBJECT_ID:" +
> lObjectId` string in the JS above does not, so clicking View Detail
> fails live with `APEX.SESSION_STATE.SSP_CHECKSUM_MISSING` — a second,
> separate bug on top of the effort already sunk into building it. If a
> user reports this, don't patch the checksum in JS either — go back to
> the correction above and get the declarative link working instead of
> layering another workaround on the first one.

---

## Compiler-truth audit: known false positives

`node tools/apexctl.mjs apexlang compiler-truth audit` and the local
formatter are advisory once live `apex validate` passes — treat a live
pass as authoritative and don't chase these:

- `series`/`axis` under a `chart` region, and `filter` under a
  `savedReport`, get flagged as "not valid under parent region." The
  compiler interposes an implicit attributes node between the region and
  these children that the audit script's model doesn't know about.

- The whitespace formatter flags lines whose *values* legitimately contain
  parentheses, braces, or extra colons — a `name: "{filters}"` region name,
  a multi-colon `comments` convention on a column, a `HH24:MI:SS` format
  mask, or a single-line `layout_row_plan` trace comment. These reproduce
  on the untouched base scaffold's own `p09999-login.apx`, proving they
  predate any app-specific change.

Also: `.apexlang/application-spec.md` and `.apexlang/app-ux-contract.json`
belong at the app's **parent directory** (sibling to `app/`), not the
git-repo root — that's the location the packaged validator actually reads
them from.

---

## Known packaged-tooling bugs (import / roundtrip)

Connect with `sql -name "<connection-alias>"`, not `sql -s <alias>`. The
`-s` (silent) form combined with a piped script has been observed to hang
indefinitely; `-name` is also the exact connect order the packaged tooling
itself falls back to (`sql -name <name>` → `sql <name>` → `sql /nolog` +
`connect <name>`).

The `runtime roundtrip` wrapper can report `import_status: pass`
**without the underlying `apex import` ever running** — its own transcript
can show `Could not get workspace name`, then a plain disconnect, no
import attempted, no error surfaced. Repeated "successful" reruns can be
silent no-ops rather than real idempotent imports. **Always verify the
live result directly** (query `apex_applications`, or diff the component
that changed) — don't trust `import_status`/`live_check_status` alone as
proof anything was written.

Separately: **raw `apex import -input <path>` (no `-id`) is not idempotent
at all — it mints a new application id on every run**, since APEXlang's
`application.apx` carries only an alias, not a fixed numeric id.
Re-importing the same source twice without `-id` produces two separate
apps in the workspace (observed directly: a plain re-import created a
second id alongside the original, e.g. `114 "SCHEMA-EXPLORER114"`
alongside `111 "SCHEMA-EXPLORER"`, APEX auto-suffixing the alias to avoid
a collision). To update an app already in the workspace, always target it
explicitly:

```sql
apex import -input <path> -id <existing_application_id>
```

Find the existing id first with a direct, read-only query
(`select application_id, alias from apex_applications where workspace =
'<workspace>'`) rather than assuming the packaged tool's target resolver
will find it — in practice it has reported `not_found_in_workspace` /
`candidate_count: 0` even against an app that already existed.

It is still a real write against a live workspace either way, so run an
import once, deliberately, after the user has actually asked for it — not
just asked what the command is — and confirm the result by reading the
database back, not by trusting the tool's JSON report.

---

## Suggested flow for the next app

1. Write the prompt naming the workspace and connection explicitly,
   pinning every column/view the app is allowed to touch, and stating the
   approval gate before import. If the consumer project already has a
   worked-example prompt, model the new one after it.

2. Match each requested page to the closest family under
   `templates/page-examples/` (dashboard, interactive-report, form, modal,
   login, etc.) before writing anything — don't improvise a page shape
   that doesn't map to an existing family.

3. Hand-author the `.apx` tree from the scaffold minimum above, plus the
   matched page templates, checking the grammar file directly whenever a
   template's Markdown doesn't show the exact case needed.

4. Run `apex validate` early, not just at the end — it's cheap and catches
   naming/reference mistakes before they compound across pages.

5. Only escalate to the full orchestrated `apex-generation.md` loop if the
   app is large enough, or headed to production, to justify its live
   compiler-truth audit trail.

6. If a report needs a row-level action (open a detail modal, drill into a
   record), start from the assumption that Interactive Report `link` is
   supported — it's one of the most standard features APEX has. Verify the
   real property names against the grammar file before concluding
   otherwise. If it genuinely doesn't work after that real check, tell the
   user and offer to let them wire it up in Page Designer instead of
   building a JavaScript substitute — see the correction under "Row-level
   actions" above. Don't spend a long tool-call chain reinventing a
   two-minute declarative feature.

7. When the check passes and the user actually asks for the import (not
   just the command to run one), prefer the raw commands over the packaged
   `runtime roundtrip` wrapper — it has been observed reporting
   `import_status: pass` while its own transcript showed the import never
   ran, and separately creating a duplicate application when re-run
   without pinning a target. Use `sql -name <connection>` (not `-s`, which
   can hang), then `apex validate -input <path>` followed by
   `apex import -input <path> -id <existing_application_id>` for anything
   past the first import of an app. Always confirm the result with a
   direct, read-only query against `apex_applications` (and the specific
   component that changed) afterward — don't trust any tool's JSON report
   as proof a write happened.
