---
name: apex-collection-grid
description: Build an editable, spreadsheet-style list in Oracle APEX (edit lines in place, add lines with "+", remove with a trash icon, one Save button) on top of a Template Component region, keeping the working copy in an APEX collection. Covers the collection layout with a pending-action column (UNCHANGED/INSERT/UPDATE/DELETE), one AJAX callback per user action, ordering requests with the apex.server.process queue, a single-transaction Save, and the package split between business and APEX layers. Load before building any "edit many rows, then save once" page that is not an Interactive Grid.
---

# Editable Grid on an APEX Collection

A pattern for pages where users edit several rows, add and remove lines,
and persist everything with one **Save** — without an Interactive Grid
and without keeping state in browser memory. Verified end to end on
**APEX 26.1.5** with a custom Template Component region, a collection,
and a headless-browser test (see the `apex-runtime-verification` skill).

> **Note:** for the Template Component plugin itself (region type,
> placeholder names, default pagination, refresh event, empty report),
> see the `apexlang-lessons` skill. This skill covers the data flow.

---

## 1. How the Pieces Fit

The server holds the working copy; the browser only renders it and reports
each change as it happens.

- **Load**: a Before Header process copies the table into the collection.
  The region queries the collection, never the table.

- **Edit / add / delete**: each user action calls one AJAX callback that
  updates the collection immediately.

- **Save**: one AJAX callback reads the collection and applies the pending
  inserts, updates and deletes in a single transaction, then reloads the
  collection.

Because every change already lives on the server, refreshing the region
shows the unsaved edits, and Save never needs a payload from the browser.

---

## 2. Collection Layout

Give every member a **pending action** column that tells Save what to do
with the line. Use full words, not letters — the value is read in SQL,
in PL/SQL and by people querying `apex_collections`:

| Value | Meaning | Save does |
|---|---|---|
| `UNCHANGED` | Loaded from the table, not touched | nothing |
| `UPDATE` | A loaded line the user edited | `update` |
| `INSERT` | A line added with "+" | `insert` |
| `DELETE` | A loaded line the user removed | `delete` |

Prefer `UNCHANGED` over `ORIGINAL`: updated and deleted lines are also
"original" rows, so `ORIGINAL` is ambiguous.

Document the attribute map once, in the package spec:

```plsql
-- Member layout:
--   n001 = primary key (null for new lines)    c001 = name
--   n002 = foreign key value                   c002 = job
--   c003 = pending action for Save: UNCHANGED, INSERT, UPDATE or DELETE
gc_collection_name constant varchar2(30 char) := 'PREFIX_GRID';
```

State transitions, all handled server-side:

- Editing an `UNCHANGED` line turns it into `UPDATE`; an `INSERT` line
  stays `INSERT`.

- Removing an `INSERT` line deletes the member outright; removing any other
  line marks it `DELETE`.

- The region query skips `DELETE` lines: `where c.c003 <> 'DELETE'`.

---

## 3. Package Split

Keep the layers from `error-handling.md` and `plsql-standards.md` §3:

| Package | Layer | Holds |
|---|---|---|
| `prefix_<entity>_api` | Business, no APEX dependency | `create_<entity>` (returns the new key), `update_<entity>`, `delete_<entity>` |
| `prefix_<entity>_grid_utils` | APEX | `load_collection`, one `*_ajax` procedure per callback, the collection constants |

`apex_collection`, `apex_json` and `apex_application.g_x01` are APEX APIs,
so everything that touches them belongs in the `*_utils` package.

---

## 4. AJAX Callbacks

One On-Demand (AJAX Callback) process per action, each a one-line call into
the `*_utils` package:

| User action | Callback | Inputs | Effect |
|---|---|---|---|
| "+" | `ADD_<ENTITY>_MEMBER` | — | `add_member` with action `INSERT`; returns `{"success": true, "seqId": n}` |
| Edit a field (on `change`) | `UPDATE_<ENTITY>_MEMBER` | `x01` = SEQ_ID, `x02` = column, `x03` = new value | Updates one attribute; `UNCHANGED` becomes `UPDATE` |
| Trash icon | `DELETE_<ENTITY>_MEMBER` | `x01` = SEQ_ID | Drops an `INSERT` member, marks any other `DELETE` |
| Save | `SAVE_<ENTITY>_GRID` | — | Validates, applies, reloads (Section 5) |

Map the client's column name to a collection attribute with a whitelist —
see `security.md` §3:

```plsql
case l_column_name
  when 'ename' then
    apex_collection.update_member_attribute(
        p_collection_name               => gc_collection_name
      , p_seq                           => l_seq_id
      , p_attr_number                   => 1
      , p_attr_value                    => l_new_value
    );
  when 'deptno' then
    apex_collection.update_member_attribute(
        p_collection_name               => gc_collection_name
      , p_seq                           => l_seq_id
      , p_attr_number                   => 2
      , p_number_value                  => to_number(l_new_value)
    );
end case;
```

Before touching a member, read its action with
`where collection_name = gc_collection_name and seq_id = l_seq_id` — a
`no_data_found` there means the SEQ_ID is not in this session's collection.

---

## 5. Save in One Transaction

### Validate first

Collect the SEQ_IDs of `INSERT`/`UPDATE` lines missing a required value and
return them, so the page can highlight exactly those lines:

```json
{"success": false, "message": "Name and Department are required for every line.", "invalidSeqIds": [16]}
```

Ignore an `INSERT` line the user left completely blank — it is not an
error, just an unused line.

### Apply deletes, then updates, then inserts

Deleting first lets a user remove a row and re-add one with the same
unique value in the same save. Loop over the pending lines, call the
business package per line, count the changes:

```plsql
for l_rec in (
  select c.c003                                                     as action
       , c.n001                                                     as pk_value
       , c.c001                                                     as ename
       , c.n002                                                     as deptno
    from apex_collections c
   where c.collection_name = gc_collection_name
     and c.c003 in ('INSERT', 'UPDATE', 'DELETE')
   order by decode(c.c003, 'DELETE', 1, 'UPDATE', 2, 3)
          , c.seq_id
)
loop
  case l_rec.action
    when 'DELETE' then prefix_emp_api.delete_employee(p_empno => l_rec.pk_value);
    when 'UPDATE' then prefix_emp_api.update_employee(...);
    when 'INSERT' then prefix_emp_api.create_employee(..., o_empno => l_empno);
  end case;
end loop;
```

### Reload, or roll back and keep the edits

On success, call `load_collection` again so the grid shows the saved data
(including newly generated keys) and every line is back to `UNCHANGED`.

On any error, `rollback` in the callback's exception handler. That undoes
only this request's table changes — the collection edits were committed by
earlier requests, so the user keeps their pending work and can fix and
retry. Translate known errors into readable messages — see
`error-handling.md` §4.

> **Note:** return `{"success": true, "changes": 0}` when nothing is
> pending, and let the page say "There are no changes to save" instead of
> refreshing for nothing.

---

## 6. Client Side

### Keep no data in JavaScript

The module only renders and reports. It does not track dirty rows or
deleted keys — the collection does. Follow `javascript-standards.md`
(revealing module, `CONFIG`, logger).

### Order requests with the AJAX queue

An edit fires its callback on `change`, which happens on blur — the same
moment the user clicks Save. Without ordering, Save can run before the last
edit is stored. Send every callback through one named queue:

```javascript
apex.server.process(processName, data, {
    queue: { name: 'prefixGrid', action: 'wait' }
  , success: function(pData) { /* check pData.success */ }
  , error: function(jqXHR, textStatus, errorThrown) { /* ... */ }
});
```

### Name the HTML hooks explicitly

- The line's key is the collection SEQ_ID, exposed by APEX as `data-id`
  through `#APEX$ROW_IDENTIFICATION#` (mark `SEQ_ID` as the region's
  primary key column). The attribute name is fixed by APEX — wrap it in a
  named helper (`_getSeqId(item)`) and a `CONFIG` constant with a comment.

- Name your own attributes for what they hold, e.g. `data-emp-column` for
  the table column a field edits — not a generic `data-col`.

- Comment each `x01`/`x02`/`x03` with the `apex_application.g_x0n` it maps
  to and what it carries.

### Lines added on the client

"+" calls the add callback first, then injects a line carrying the returned
SEQ_ID. Its markup must mirror the Template Component's partial template —
say so in a comment on both sides.

Always keep at least one line in the list (add one after the last is
removed, or when the report comes back empty) so "+" stays reachable.

---

## 7. Decide How a Reload Behaves

Reloading the collection in Before Header on every page load discards
unsaved edits when the user refreshes the browser — predictable, and the
simplest choice.

The alternative — load only when the collection does not exist yet — keeps
unsaved edits across reloads, but shows stale data if someone else changed
the table, and needs an explicit "Cancel / discard changes" action. Pick
one deliberately and document it.
