---
name: sqlcl-connections
description: Run SQL/PL-SQL non-interactively against a real Oracle schema using a saved SQLcl connection — check what's already saved, create one if it's missing, invoke it safely from a script, and the concrete case this was built for (granting/synonym-ing a consumer schema onto ErrorShield/Logger). Includes the `-name` gotcha that silently hangs a non-interactive run and looks like a keystore/password problem.
---

# Running SQL Non-Interactively via Saved SQLcl Connections

When a task needs SQL/PL-SQL run against a real schema — grants,
synonyms, a verification query, a one-off fix — the default should not be
"ask the developer whether they want to run it or I should." Check
whether a saved SQLcl connection already reaches that schema first (Step
0 below). If one exists, run it directly. Only fall back to asking the
developer when the connection genuinely isn't there.

---

## When this applies

- **Onboarding a consumer schema onto ErrorShield/Logger** (the case this
  skill was first written for, in `OracleAPEX-ErrorShield`): granting
  privileges from the owner schema
  (`scripts/grant_ersh_to_user.sql`, `scripts/grant_logger_to_user.sql`)
  and creating synonyms from the consumer schema
  (`scripts/consumer/create_ersh_synonyms.sql`,
  `scripts/consumer/create_logger_synonyms.sql`) — see that project's
  `CLAUDE.md` for what "owner" vs. "consumer" means there.
- Any read-only verification query against a real schema (confirming a
  grant took effect, checking an object's status).
- Any other one-off script that needs to run against a specific schema
  and where a saved connection for that schema already exists.

---

## Step 0 — check what's already available

```
sql -nolog <<'EOF'
connmgr list
exit
EOF
```

This prints every saved connection as a tree, grouped by folder. Look for
one that reaches the schema the task needs. Saved connections live
outside any project repo (`~/.dbtools/`), so this list is the same
regardless of which project you're in.

## Step 1 — if the connection isn't there

Don't guess a username/password, and don't ask the developer to paste a
password into chat. State plainly which schema/user the task needs to
reach, and give the developer this command to create it themselves
(fill in their own credentials):

```
connect -save <connection_name> -savepwd <user>/<password>@<connect_identifier>
```

`-savepwd` is required for the password to actually be stored — without
it, the connection is saved but still prompts for a password every time,
same as if it had never been saved. If the developer would rather run
the task themselves instead of creating a connection, that's a fine
outcome too.

## Step 2 — consume it non-interactively

```
sql -nolog <<'EOF'
connect -name "<connection_name>"
-- your SQL, or @path/to/script.sql arg1 arg2
exit
EOF
```

Or use [`run_sql.sh`](run_sql.sh) in this folder, which wraps this exact
pattern plus the Step 0 check:

```
./run_sql.sh <connection_name> <<'EOF'
@scripts/grant_ersh_to_user.sql WKSP_DEVAI1
EOF
```

Before using whatever schema name the task assumes as a script parameter
(e.g. the `&1` in `grant_ersh_to_user.sql`), confirm it — a connection's
display name is not necessarily the schema name:

```
sql -nolog <<'EOF'
connect -name "<connection_name>"
select user as current_schema from dual;
exit
EOF
```

---

## Lessons learned (read before repeating this in a new project)

### `connect <name>` looks like it should work and doesn't

Bare `connect <name>` (with or without quotes) is parsed as an attempt to
log in with `<name>` as the database *username* — since that's not a real
DB user, it silently falls through to an interactive, masked password
prompt. In a non-interactive shell (no TTY to type into), that prompt can
never be satisfied: the process reports `SP2-0640: Not connected`, and
once stdin hits EOF the masked-input reader throws
`Exception in thread "JLine Mask Thread" ... Terminal has been closed`.

The output *looks* like a broken credential store or an unsaved
password. It isn't — it's a syntax gotcha.

> **Fix:** always connect to a saved connection with the explicit
> `-name` flag: `connect -name "<connection_name>"`. This is the
> documented syntax (`help connect`) for saved connections specifically
> — plain `connect <spec>` is for a literal `user/password@identifier`
> logon string.

### A single failing local connection is what proved it wasn't password storage

The first symptom looked exactly like "this particular saved connection
has no password stored." Renaming the connection didn't fix it. What
isolated the real cause: connecting to a completely unrelated, purely
local connection (no cloud credentials, no wallet) with the same bare
`connect <name>` syntax — it failed identically. That ruled out anything
connection-specific and pointed straight at the connect syntax itself.

> **General lesson:** when a failure could plausibly be about *this one*
> saved credential, test a second, unrelated saved connection with the
> same command before concluding it's a stored-password problem. If both
> fail the same way, the bug is in how you're invoking the tool, not in
> what's stored.
