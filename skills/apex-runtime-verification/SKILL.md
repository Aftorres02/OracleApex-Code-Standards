---
name: apex-runtime-verification
description: Prove an Oracle APEX page actually works, beyond "apex validate / apex import passed" — render a page server-side from SQL (including modal pages and their checksums), call AJAX callbacks from SQL and read their JSON, screenshot and measure the layout in headless Chrome without logging in, drive a real end-to-end browser test over the Chrome DevTools Protocol, and keep test data clean. Load after importing an app change that affects rendering, JavaScript, AJAX callbacks or data, before calling the work done.
---

# Verifying APEX Pages at Runtime

`apex validate` and `apex import` check the shape of the app, not its
behavior. Template text, JavaScript, AJAX callbacks and CSS can all import
cleanly and still be broken. These techniques were used to verify a real
app on **APEX 26.1.5 / Autonomous Database** through a saved SQLcl
connection, without workspace user credentials.

Pick the cheapest one that proves the change:

| What changed | Technique |
|---|---|
| Template / region markup, page items, LOVs | Section 1 — server-side render |
| AJAX callback / package logic | Section 2 — callbacks from SQL |
| Layout / CSS | Section 3 — static screenshot and measurement |
| Client JavaScript flows (add, edit, save) | Section 4 — end-to-end browser test |

---

## 1. Render a Page Server-Side from SQL

Run the page inside an APEX session and read the generated HTML from the
`htp` buffer. No browser, no login:

```plsql
declare
  l_names  owa.vc_arr;
  l_values owa.vc_arr;
  l_page   htp.htbuf_arr;
  l_rows   integer := 999999;
begin
  l_names(1) := 'REQUEST_PROTOCOL'; l_values(1) := 'HTTPS';
  l_names(2) := 'HTTP_HOST';        l_values(2) := 'localhost';
  l_names(3) := 'SCRIPT_NAME';      l_values(3) := '/ords';
  l_names(4) := 'REQUEST_METHOD';   l_values(4) := 'GET';
  owa.init_cgi_env(l_names.count, l_names, l_values);
  htp.init;
  apex_session.create_session(p_app_id => 100, p_page_id => 1, p_username => 'TEST');
  wwv_flow.show(p_flow_id => '100', p_flow_step_id => '1', p_instance => v('APP_SESSION'));
  htp.get_page(l_page, l_rows);
  for i in 1 .. l_rows loop
    dbms_output.put_line('<<C>>' || l_page(i) || '<<E>>');
  end loop;
  apex_session.delete_session;
end;
/
```

`htbuf_arr` chunks split the HTML at arbitrary points. Wrap each chunk in
markers and join them back with no separator (`<<C>>(.*?)<<E>>`), or a tag
can break in the middle.

Then check the HTML: the rows rendered, the attributes on each element, the
template substitutions resolved (a raw `&COL.` or `#COL#` in the output
means a mapping is wrong).

### Modal dialog pages need their checksums

Calling a modal page without checksums returns `Status: 400`. Build the URL
inside the session, decode it, and pass both checksums:

```plsql
l_url := utl_url.unescape(apex_page.get_url(p_page => 2));
wwv_flow.show(
    p_flow_id                           => '100'
  , p_flow_step_id                      => '2'
  , p_instance                          => v('APP_SESSION')
  , p_cs                                => regexp_substr(l_url, '[?&]cs=([^&]+)', 1, 1, null, 1)
  , p_dialog_cs                         => regexp_substr(l_url, '[?&]dialogCs=([^&]+)', 1, 1, null, 1)
);
```

Build the URL without `p_clear_cache`: the checksum covers the clear-cache
argument, and `wwv_flow.show`'s `p_clear_cache` is a PL/SQL table, not a
string.

---

## 2. Call AJAX Callbacks from SQL

Set the globals the callback reads and capture its JSON with a CLOB output
instead of `htp`:

```plsql
apex_session.create_session(p_app_id => 100, p_page_id => 1, p_username => 'TEST');
apex_application.g_x01 := '1';
apex_application.g_x02 := 'job';
apex_application.g_x03 := 'TESTER';
apex_json.initialize_clob_output;
prefix_grid_utils.update_member_ajax;
dbms_output.put_line(apex_json.get_clob_output);
apex_json.free_output;
```

Chain several calls to replay a whole user flow (add, edit, validate,
save), print the collection between steps, and finish with `rollback`.

> **Warning:** all those calls run in **one** transaction. A callback that
> issues `rollback` on error (the normal pattern) undoes every earlier step
> of the test too — in the real app each AJAX call is its own committed
> request. Put the failing case last, or re-create the state after it.

Do not use scalar subqueries inside PL/SQL expressions in the harness
(`dbms_output.put_line((select ...))` does not compile) — select into
variables first.

---

## 3. Screenshot and Measure the Layout Without Logging In

1. Render the page server-side (Section 1) and save the HTML to a file.

2. Rewrite asset URLs to the real instance: relative `"/i/` paths and the
   `https://localhost:/ords` host produced by the CGI stub. Theme files
   under `/i/<version>/` and the app's static files are public, so they
   load without a session.

3. Open the file in headless Chrome:

   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
     --window-size=1400,1000 --virtual-time-budget=10000 \
     --user-data-dir=/tmp/chrome-shot --screenshot=page.png "file:///path/page.html"
   ```

4. To compare alignment, measure instead of eyeballing: open the same file
   over the DevTools Protocol (Section 4) and read
   `getBoundingClientRect()` of the elements that should line up.

Icon fonts usually do not load from a `file://` page (CORS) and show as
squares — that is the harness, not the app.

---

## 4. End-to-End Browser Test over the DevTools Protocol

Node 22+ has a global `WebSocket`, so a test can drive headless Chrome with
no Playwright or Puppeteer install:

1. Start Chrome with `--headless=new --remote-debugging-port=<port>
   --user-data-dir=<temp dir>`.

2. Read the page target's `webSocketDebuggerUrl` from
   `http://127.0.0.1:<port>/json/list`.

3. Send `Page.navigate`, then drive the page with `Runtime.evaluate`
   (`awaitPromise: true, returnByValue: true`): click buttons, set values
   and dispatch `input`/`change` events, read the DOM back.

4. Capture `Runtime.consoleAPICalled` and `Runtime.exceptionThrown` to
   surface JavaScript errors, and `Page.captureScreenshot` at each step.

Rules that keep the test honest:

- Wait on conditions with a timeout (`waitFor(expr, label, ms)`); never
  await an event without a timeout — an event that never fires hangs the
  whole run.

- Query the database directly at key points (via SQLcl) — for example,
  that the table is untouched before Save and changed after it.

- Kill Chrome and delete the temporary profile in a `finally` block.

> **Note:** without workspace credentials, the page under test must be
> made public (`security { authentication: public }`) for the duration of
> the run. That exposes a live page — do it only with the user's explicit
> approval for that run, restore authentication right after, and confirm
> it with `apex_application_pages.page_requires_authentication` and a
> `curl` that gets redirected to the login page.

---

## 5. Keep Test Data Clean

- Snapshot the affected table before a test that writes data, and diff
  after.

- Revert through the UI the test exercises (edit the value back, delete
  the line the test added) — it tests the delete/update path for free.
  Use unique markers in test data (`E2E TEST`) so leftovers are easy to
  find.

- Never delete pre-existing rows to test a delete — create a row, then
  delete that one.

- If the diff shows a row your test did not create, someone else is using
  the workspace: leave it alone, re-baseline, and tell the user.
