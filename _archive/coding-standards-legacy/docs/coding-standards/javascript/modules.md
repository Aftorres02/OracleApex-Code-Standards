# Module Pattern

## 1. Revealing Module Pattern (IIFE)

All JavaScript should be organized using the **Revealing Module Pattern** wrapped in an IIFE (Immediately Invoked Function Expression). This avoids polluting the global scope and provides clear separation between public and private members.

### Structure

```javascript
var namespace = namespace || {};

namespace.moduleName = (function(namespace, $, undefined) {
  'use strict';

  var MODULE_NAME = 'ModuleName';

  // CONFIG, logger, private variables...

  // Private functions...

  // Public API
  return {
      publicMethod: publicMethod
    , anotherMethod: anotherMethod
  };

})(namespace, apex.jQuery);
```

### Key rules

- The global `namespace` variable is initialized once per page. Each file should include the guard `var namespace = namespace || {};` so files can load in any order.
- Pass `namespace` and `apex.jQuery` (aliased as `$`) as IIFE arguments.
- The third `undefined` parameter protects against accidental reassignment of `undefined` in older environments.
- Always include `'use strict';` as the first statement inside the IIFE.

## 2. MODULE_NAME Constant

Define a `MODULE_NAME` constant at the top of every module. This is used by the logger to tag all log entries from the module.

```javascript
var MODULE_NAME = 'KanbanView';
```

## 3. CONFIG Object

Centralize all magic strings (AJAX process names, CSS selectors, threshold values) into a `CONFIG` object declared immediately after `MODULE_NAME`.

**GOOD**:

```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , CONTAINER_CLASS: '.tickets-container-5a'
  , TICKET_CLASS: '.ticket-card'
  , DRAG_OVER_CLASS: 'drag-over'
  , DRAGGING_CLASS: 'dragging'
  , AJAX_GET_URL: 'get_url_ajax'
};
```

**BAD**:

```javascript
// Selectors and process names sprinkled across the file
var column = document.querySelector('.column-5a');
apex.server.process('get_url_ajax', ...);
```

## 4. Logger

Each module should include a simple, self-contained logger that prefixes every message with the module name. This requires no external dependency -- the file is ready to use as-is.

```javascript
var _PREFIX = '[' + MODULE_NAME + ']';
var logger = {
    log:     function(msg, data) { console.log(_PREFIX, msg, data || ''); }
  , warning: function(msg, data) { console.warn(_PREFIX, msg, data || ''); }
  , error:   function(msg, data) { console.error(_PREFIX, msg, data || ''); }
};
```

### Usage

```javascript
logger.log('Initializing kanban board...');
logger.log('Ticket moved successfully', {ticketId: ticketId, columnId: columnId});
logger.warning('No columns found during initialization');
logger.error('AJAX error updating ticket status', {status: textStatus, error: errorThrown});
```

### Console output

```
[KanbanView] Initializing kanban board...
[KanbanView] Ticket moved successfully {ticketId: 42, columnId: 3}
```

Pass structured data as a second argument (object) rather than concatenating strings, so the browser console can expand and inspect it.

## 5. Private vs Public Members

- **Private** functions and variables are declared with `var` inside the IIFE and prefixed with `_`.
- **Public** members are exposed via the `return` object at the bottom of the module.

```javascript
// Private — only accessible inside the module
var _currentDragTicket = null;

var _handleTicketClick = function(event) {
  // internal logic
};

// Public — returned at the end
var initialize = function() {
  // setup logic
};

return {
    initialize: initialize
  , refresh: refresh
};
```

### Naming guideline

| Scope | Prefix | Example |
|---|---|---|
| Private variable | `_` | `_currentDragTicket`, `_isModalOpening` |
| Private function | `_` | `_handleTicketClick`, `_loadColumnData` |
| Public variable | none | `isInitialized` |
| Public function | none | `initialize`, `refresh` |

## 6. Public API (Return Object)

The return statement at the end of the module defines the public API. Group the return entries by purpose and use leading commas.

```javascript
/* ================================================================ */
/* Return public API                                                 */
/* ================================================================ */
return {
    // Lifecycle
    initialize: initialize
  , refresh: refresh
  , refreshAfterRegionUpdate: refreshAfterRegionUpdate

    // Rendering
  , renderTicketsForColumn: renderTicketsForColumn

    // Actions
  , showTicketDetails: showTicketDetails
  , addTicket: addTicket
  , openTicketDetails: openTicketDetails
};
```

## 7. Module Separation (Services vs View)

When a feature grows beyond a single file, split it into two modules:

| Module | Suffix | Responsibility | Example |
|---|---|---|---|
| **Services** | `Services` | AJAX calls, data transformation, business logic | `namespace.kanbanServices` |
| **View** | `View` | DOM manipulation, event listeners, rendering, user interaction | `namespace.kanbanView` |

The **View** module calls the **Services** module for data. The Services module should have no direct DOM dependencies.

```javascript
// View calls Services for data
namespace.kanbanServices.getTicketsForColumn(columnId, filters, function(tickets) {
  renderTicketsForColumn(columnId, tickets, true);
});

// View calls Services for HTML generation
var ticketHTML = namespace.kanbanServices.createTicketHTML(ticket);
```
