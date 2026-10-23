---
name: apex-outbound-rest
description: Call external REST APIs from PL/SQL inside an APEX workspace with apex_web_service — who can grant the network ACL, HTTPS on Autonomous Database, Web Credentials passed by static ID so the secret never enters PL/SQL, the APEX session context apex_credential needs, and verified gotchas (APIs that don't exist, ORA-20987 on disallowed URLs, request headers that leak between calls). Load before writing or reviewing PL/SQL that makes an outbound HTTP call, or a preflight/health check for one.
---

# Outbound REST Calls from PL/SQL in APEX

Lessons from building a real outbound-REST engine — a Postman-style
workbench whose packages execute arbitrary endpoints, authenticate them,
and log every call. Everything below was verified live on **APEX 26.1 /
Oracle Database 23ai on Autonomous Database**, working as the APEX
workspace's parsing schema (`WKSP_<NAME>`) through a saved SQLcl
connection (see the `sqlcl-connections` skill). Re-check anything
version-specific on your own instance before relying on it.

---

## When this applies

- Writing a package that calls an external API through
  `apex_web_service.make_rest_request`.

- Adding authentication (basic, bearer token, API key) to those calls.

- Writing a preflight or health check that should predict whether an
  outbound call will work.

---

## Step 1 — Network access

### Who can grant the ACE

The workspace schema cannot grant itself network access:
`dbms_network_acl_admin` is not even visible from it, so the call fails
with `PLS-00201` rather than a privilege error. Run the grant connected as
the database's `ADMIN` user (Autonomous) or a DBA, naming the workspace
schema as principal:

```sql
begin
  dbms_network_acl_admin.append_host_ace(
      host => 'api.example.com'
    , ace  => xs$ace_type(
                  privilege_list => xs$name_list('http', 'resolve')
                , principal_name => 'WKSP_<NAME>'
                , principal_type => xs_acl.ptype_db
              )
  );
end;
/
```

Then confirm it from the workspace schema itself:

```sql
select p.host                  as host
     , p.privilege             as privilege
     , p.status                as status
  from user_network_acl_privileges p;
```

### The schema's ACE does not predict apex_web_service

Observed: before any ACE existed for the workspace schema, a
`make_rest_request` call to the same host already succeeded. Calls made
through `apex_web_service` evidently do not depend on the parsing schema's
own ACE on this platform (most likely they go out under APEX's engine
schema, which has its own network access — not confirmed).

The consequence for a preflight: a check that only reads
`user_network_acl_privileges` reported `fail` for a call that would have
worked, and blocked execution that didn't need blocking. If a preflight
must answer "will this call work?", make a real lightweight request and
treat that as authoritative; treat the ACL view as informational.

### HTTPS on Autonomous

HTTPS to public hosts with publicly trusted certificates worked with no
wallet configuration at all. Where a wallet is missing or misconfigured,
expect `ORA-29024` (certificate validation failure) or `ORA-28759`
(failure to open the wallet file). An unresolvable host surfaced as
`ORA-29273`.

---

## Step 2 — Authentication through Web Credentials

### Pass the static ID, never the secret

`make_rest_request` takes `p_credential_static_id`. Pass the Web
Credential's static ID and APEX attaches the real header or query
parameter itself, from the credential store — your PL/SQL never reads the
secret:

```plsql
l_response := apex_web_service.make_rest_request(
    p_url                              => l_url
  , p_http_method                      => 'GET'
  , p_credential_static_id             => l_credential_static_id
);
```

A `null` static ID means "no auth" — one code path covers both cases.

Do **not** design an auth helper that returns header rows for the caller to
add to `g_request_headers`. The only way it can build them is to pull the
secret into a PL/SQL variable, which defeats the credential store. Resolve
to the static ID instead and let APEX do the rest.

The four simple auth types all work this way; they differ only in the type
the Web Credential is created with:

| Auth | Credential type | Name / client ID | Secret |
|---|---|---|---|
| Basic | `BASIC` | user name | password |
| Bearer token | `HTTP_HEADER` | `Authorization` | `Bearer <token>` |
| API key in a header | `HTTP_HEADER` | header name (e.g. `X-API-Key`) | key |
| API key in the query string | `HTTP_QUERY_STRING` | parameter name | key |

> **Note:** the bearer row was exercised end to end (a real call returned
> `{"authenticated": true, ...}` from a bearer-checking echo endpoint). The
> other rows use the same mechanism but were not each called live. OAuth2,
> OCI, mTLS, SigV4 and signed JWT need more than this and are not covered
> here.

### apex_credential needs an APEX session

`apex_credential.create_credential`, `set_persistent_credentials` and
`get_credential_details` all require APEX session context. From a bare
SQLcl session every call fails with "package variable g_security_group_id
must be set" — for **any** static ID, existing or not. Set the workspace
first:

```plsql
begin
  apex_util.set_security_group_id(
      p_security_group_id              => apex_util.find_security_group_id(p_workspace => '<WORKSPACE>')
  );

  -- apex_credential calls go here
end;
/
```

A check that calls `get_credential_details` must tell the two failures
apart:

- `no_data_found` — the credential really doesn't exist. Report `fail`.

- Any other error (typically the `g_security_group_id` one) — the check
  couldn't run in this context. Report `unknown`, not `fail`, and say it
  must run inside an APEX session (a page request).

### Allowed URLs are enforced

A credential used against a URL outside its `p_allowed_urls` raises
`ORA-20987: Credential is not allowed to be used for this URL endpoint`.
Catch it like any other request failure and record it — it's a
configuration error the user can fix, not a crash.

> **Note:** `ORA-20987` is APEX's generic error code (it also carries
> "Application not found" on import, see `apex-ci-image`). Match on the
> message, not the code alone.

---

## Step 3 — Request hygiene

### Reset the global request headers before every call

`apex_web_service.g_request_headers` is a package global: it lives for the
whole database session, so headers set for one call are sent again on the
next one. Clear it at the start of every request build:

```plsql
apex_web_service.g_request_headers.delete;
```

After the call, the HTTP status is in `apex_web_service.g_status_code`.

---

## Gotchas verified the hard way

### APIs that look right and don't exist

- `apex_util.get_apex_version` does not exist (`PLS-00302`). Read the
  version from the `apex_release` view instead
  (`select r.version_no as version_no from apex_release r`) — it is a
  public synonym, readable from a plain workspace schema.

- There is no `apex_credentials` view, plural or singular (`ORA-00942`).
  Use the `apex_credential` package (`get_credential_details`), with the
  session context above.

- Before building on an APEX API you haven't used before, confirm it
  exists on the instance (the release's API reference, or `all_procedures`
  for the package) instead of trusting a plausible name.

### INVALID right after a grant is not a blocker

Packages that depend on an object you were just granted (e.g. Logger) can
still show `INVALID` after the grant lands — the grant doesn't recompile
them. Recompile (`alter package <name> compile body;`) before treating it
as a real error.
