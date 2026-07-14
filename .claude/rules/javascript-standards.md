# JavaScript Standards

**Single responsibility:** Client-side JavaScript conventions for APEX pages
— module structure, naming, AJAX, DOM/event handling. New file (previously
no dedicated rule file existed for JS).

> Consolidated from `oracle-apex_standards.mdc` §8 (JavaScript standards) and
> `docs/coding-standards/javascript/{ajax,dom-events,general,modules}.md`.
> Originals archived under `_archive/coding-standards-legacy/`.

## 1. Naming Conventions

- **Variables & functions**: `camelCase`.
- **Constants**: `UPPER_CASE` with underscores.
- **Private members**: prefix with `_` to signal internal-only.

**GOOD**:
```javascript
var ticketId = 123;
var MODULE_NAME = 'KanbanServices';
var MAX_RETRY_COUNT = 3;
var _currentDragTicket = null;
```

**BAD**: `var TicketId`, `var is_initialized`, `var moduleName = 'KanbanServices'` (should be a `MODULE_NAME` constant), `var currentDragTicketPrivate`.

## 2. Formatting

- **Indentation**: 2 spaces, no tabs.
- **Leading commas**: for multi-line object literals, arrays, and parameter lists.
- **Strict mode**: `'use strict';` as the first statement inside the module IIFE.

**GOOD**:
```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , CONTAINER_CLASS: '.tickets-container-5a'
  , TICKET_CLASS: '.ticket-card'
};
```

## 3. Code Sectioning

Standard width **64 characters**, using `=`:
```javascript
/* ================================================================ */
/* SECTION NAME                                                      */
/* ================================================================ */
```

## 4. Revealing Module Pattern (IIFE)

All JavaScript is organized using the Revealing Module Pattern wrapped in an IIFE, to avoid polluting the global scope.

```javascript
var namespace = namespace || {};

namespace.moduleName = (function(namespace, $, undefined) {
  'use strict';

  var MODULE_NAME = 'ModuleName';

  // CONFIG, logger, private variables...
  // Private functions...

  return {
      publicMethod: publicMethod
    , anotherMethod: anotherMethod
  };

})(namespace, apex.jQuery);
```

**Key rules**:
- Each file guards with `var namespace = namespace || {};` so files can load in any order.
- Pass `namespace` and `apex.jQuery` (aliased `$`) as IIFE arguments.
- The third `undefined` parameter protects against accidental reassignment.
- `'use strict';` is always the first statement inside the IIFE.

## 5. CONFIG Object

Centralize magic strings (AJAX process names, CSS selectors, threshold values) into a `CONFIG` object declared immediately after `MODULE_NAME`.

**GOOD**:
```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , AJAX_GET_TICKETS: 'get_tickets_for_column_ajax'
  , AJAX_MOVE_TICKET: 'move_ticket_ajax'
};
```

**BAD**: selectors/process names hardcoded and scattered through the file.

## 6. Logger

Every module includes a self-contained logger prefixing every message with the module name — no external dependency required.

```javascript
var _PREFIX = '[' + MODULE_NAME + ']';
var logger = {
    log:     function(msg, data) { console.log(_PREFIX, msg, data || ''); }
  , warning: function(msg, data) { console.warn(_PREFIX, msg, data || ''); }
  , error:   function(msg, data) { console.error(_PREFIX, msg, data || ''); }
};
```

Pass structured data as a second argument (object), not string concatenation, so the browser console can expand/inspect it.

## 7. Private vs Public Members

| Scope | Prefix | Example |
|---|---|---|
| Private variable | `_` | `_currentDragTicket`, `_isModalOpening` |
| Private function | `_` | `_handleTicketClick`, `_loadColumnData` |
| Public variable | none | `isInitialized` |
| Public function | none | `initialize`, `refresh` |

Private members are declared with `var` inside the IIFE; public members are exposed via the `return` object.

## 8. Public API (Return Object)

Group return entries by purpose, use leading commas:

```javascript
/* ================================================================ */
/* Return public API                                                 */
/* ================================================================ */
return {
    // Lifecycle
    initialize: initialize
  , refresh: refresh

    // Rendering
  , renderTicketsForColumn: renderTicketsForColumn
};
```

## 9. Module Separation (Services vs View)

When a feature grows beyond a single file, split into two modules:

| Module | Suffix | Responsibility |
|---|---|---|
| **Services** | `Services` | AJAX calls, data transformation, business logic — no DOM dependencies |
| **View** | `View` | DOM manipulation, event listeners, rendering |

The View module calls Services for data:
```javascript
namespace.kanbanServices.getTicketsForColumn(columnId, filters, function(tickets) {
  renderTicketsForColumn(columnId, tickets, true);
});
```

## 10. AJAX — Use `apex.server.process`

All backend AJAX calls use `apex.server.process`.

```javascript
apex.server.process(
  CONFIG.AJAX_PROCESS_NAME,
  { x01: value1, x02: value2 },
  {
    success: function(pData) {
      if (pData.success) {
        // handle success
      } else {
        logger.error('Server returned error', {error: pData.message});
      }
    },
    error: function(jqXHR, textStatus, errorThrown) {
      logger.error('AJAX request failed', {status: textStatus, error: errorThrown});
    }
  }
);
```

**Key rules**:
- Reference AJAX process names from `CONFIG`, never hardcoded.
- Map `x01`, `x02`, etc. to match the PL/SQL backend's `apex_application.g_x01`, `g_x02`.
- Always handle **both** `success` and `error`.
- Inside `success`, always check `pData.success` — the HTTP request can succeed while server-side logic fails.

**BAD**: `success: function(pData) { callback(pData.tickets); }` — assumes success without checking.

Functions that wrap an AJAX call accept a `callback` parameter that always receives a predictable result regardless of success/failure; check `typeof` for optional middle parameters and shift arguments accordingly.

## 11. User Feedback (AJAX)

| Outcome | API |
|---|---|
| Success | `apex.message.showPageSuccess('Ticket moved successfully');` |
| Error | `apex.message.showErrors('Failed to move ticket.');` |

Avoid `alert()` or custom DOM-injected messages.

## 12. DOM & Event Handling

**Event delegation**: bind to a stable parent (typically `document`) rather than directly to dynamic elements — APEX pages frequently re-render regions, so directly-bound handlers on dynamic elements break after a refresh.

**GOOD**:
```javascript
document.addEventListener('click', function(event) {
  if (event.target.classList.contains('ticket-number') || event.target.closest('.ticket-number')) {
    event.preventDefault();
    _handleTicketNumberClick(event);
  }
});
```

**DOM queries**: use `CONFIG` constants for CSS selectors; prefer `document.querySelector`/`querySelectorAll`.

**Data attributes**: use `data-*` to link DOM elements back to database records.
```javascript
ticketElement.setAttribute('data-ticket-id', ticket.TICKET_ID);
var ticketId = ticketElement.getAttribute('data-ticket-id');
```

**APEX page items**: use `apex.item()`, not raw jQuery `.val()` — it handles cascading LOVs, display values, and session-state sync.

**GOOD**: `apex.item('P10_STATUS').setValue('CLOSED');`
**BAD**: `$('#P10_STATUS').val('CLOSED');`

**Dynamic item names**: build with `apex.env.APP_PAGE_ID` when items follow a predictable pattern:
```javascript
var apexPageID = apex.env.APP_PAGE_ID;
var userFilterItem = 'P' + apexPageID + '_ASSIGNED_TO_ID';
```

**Dialogs**: use `apex.navigation.dialog` to open modals; listen for `apexafterclosecanceldialog` on the triggering element to refresh data after close, and clean up the listener to avoid memory leaks.

**Preventing duplicate actions**: use a flag variable to guard against double-click causing duplicate modal opens or AJAX calls; reset the flag in the dialog close handler, not in the AJAX success handler.

## 13. JSDoc Documentation

Every function (public and private) includes a JSDoc block:

| Tag | Required | Description |
|---|---|---|
| Description | Yes | First line, plain text |
| `@param` | Yes | One per parameter: `{type} name - Description` |
| `@returns` | When applicable | `{type} - Description` |

```javascript
/**
 * Get tickets for a specific column via AJAX
 * @param {string} columnId - The column ID
 * @param {Object} filters - Filter criteria object
 * @param {Function} callback - Callback function to handle tickets data
 */
var getTicketsForColumn = function(columnId, filters, callback) {
  // logic
};
```

## 14. File Header

Every JavaScript file starts with a header block:

```javascript
/*
 * ==========================================================================
 * FILE NAME
 * ==========================================================================
 *
 * @description Short description of the file purpose
 * @author      Author Name
 * @created     Month YYYY
 * @issue       TF-101
 * @version     1.0
 */
```

Use [`javascript_module_template.js`](../../docs/coding-standards/templates/javascript_module_template.js) as the ready-to-copy skeleton — it already encodes §3–8 and §14.
