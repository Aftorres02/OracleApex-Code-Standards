---
name: apex-page-deploy
description: Move a single Oracle APEX page between environments (DEV to STG to PROD) with the Install Page wizard when the app was imported with different internal IDs per environment. Covers the two errors it causes (different workspace; parent key not found on the user interface) and a script that rewrites the export so it installs. Load before exporting/importing one page across environments, or when Install Page fails with either error.
---

# APEX Page Deploy

A page export taken in one environment often does **not** install as-is in
another one, even when the application ID is the same. This skill explains why
and gives a verified way to build an export that installs.

> Use a single-page export when only that page changed. If the change spans
> many pages or shared components, import the whole application instead (and
> read its diff first, see "Check what else rides along").

---

## Symptoms

### Different workspace

The wizard stops with: *This page was exported from a different application or
from an application in different workspace. Page cannot be installed in this
application.*

The workspace **name** can be identical across environments while the
workspace **ID** differs. The export header carries the ID
(`p_default_workspace_id`).

### Parent key not found

The install fails with `ORA-02291 ... WWV_FLOW_STEP_UI_FK violated - parent key
not found` while creating the page.

The target application was imported with a different ID offset, so its shared
components (user interface, templates, menus, LOVs, authorization schemes)
have different real IDs than in the source environment.

---

## Why editing the header does not work

An export stores every component reference as `wwv_flow_api.id(N)`. The real ID
is `N + p_default_id_offset`. It is tempting to change only
`p_default_id_offset` in the header to the target's value. **The Install Page
wizard ignores that header value**, so the original IDs are still used and the
same error comes back.

The fix is to rewrite the raw IDs themselves.

---

## Procedure

### Collect one export per environment

Ask for an export of the page from **each environment involved**, each one taken
in its own environment:

- the **source** (where the change lives), and
- the **target** (where it must be installed).

The target export is not extra work: it holds the target's real IDs and is the
rollback file if the install goes wrong.

### Compare the headers

In each file read `p_default_workspace_id`, `p_default_id_offset` and the raw ID
of `p_user_interface_id`. Same workspace ID and same raw user interface ID mean
the source file installs as-is. Otherwise continue.

### Rewrite the source export

Run [`shift_page_export.py`](shift_page_export.py):

```bash
python shift_page_export.py page_source.sql page_target_native.sql page_for_target.sql
```

The script:

- computes the shift between the two user interface IDs,

- checks that the **same** shift holds for every other shared component both
  files reference (templates, menus, LOVs, authorization schemes), and stops
  with an error if it does not,

- adds the shift to every `wwv_flow_api.id(...)` in the source export,

- copies the target's `p_default_id_offset` and `p_default_workspace_id` into
  the header.

When the only difference is the workspace ID (for example DEV against STG, same
offsets), skip the script and use a fresh export taken in the target
environment, or change only `p_default_workspace_id`.

### Install and verify

- Confirm the page is not locked in the target: the wizard deletes the page and
  recreates it.

- Install the generated file with the Install Page wizard. If anything fails the
  install rolls back and leaves no partial page.

- Test the feature the change was about. Keep the target export as the rollback.

---

## Known limit

A template that only the **new** components use does not appear in the target
export, so the script cannot confirm it. It relies on the shift being uniform.
If the install fails with another `parent key not found`, the message names the
missing ID. Check whether that template exists in the target with a query on
`apex_application_temp_region` (or the matching dictionary view), then fix the
shared component in the target first.

---

## Check what else rides along

Before choosing a full application import instead, diff the application export
against the previous one. Unrelated edits made by someone else in the same
export (for example a navigation entry whose display condition changed) would be
deployed together with the change you meant to ship. A page-level import avoids
that.
