# JavaScript General Standards

## 1. Naming Conventions

### 1.1 Variables & Functions

Use `camelCase` for all variables, functions, and method names.

**GOOD**:

```javascript
var ticketId = 123;
var isInitialized = false;

var fetchTicketDetails = function(ticketId) {
  // logic
};
```

**BAD**:

```javascript
var TicketId = 123;
var is_initialized = false;

function Fetch_Ticket(Ticket_id) {
  // logic
}
```

### 1.2 Constants

Use `UPPER_CASE` with underscores for true constants.

**GOOD**:

```javascript
var MODULE_NAME = 'KanbanServices';
var MAX_RETRY_COUNT = 3;
```

**BAD**:

```javascript
var moduleName = 'KanbanServices';
var maxRetryCount = 3;
```

### 1.3 Private Members

Prefix private functions and variables with `_` (underscore) to clearly signal they are internal to the module and should not be called from outside.

**GOOD**:

```javascript
var _currentDragTicket = null;
var _isModalOpening = false;

var _handleTicketClick = function(event) {
  // internal logic
};
```

**BAD**:

```javascript
var currentDragTicketPrivate = null;
var handleTicketClickInternal = function(event) {
  // no visual distinction from public members
};
```

### 1.4 CONFIG Objects

Group AJAX process names and CSS selectors into a `CONFIG` object at the top of the module. Use `UPPER_CASE` for keys inside CONFIG.

**GOOD**:

```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , CONTAINER_CLASS: '.tickets-container-5a'
  , TICKET_CLASS: '.ticket-card'
  , AJAX_GET_TICKETS: 'get_tickets_for_column_ajax'
  , AJAX_MOVE_TICKET: 'move_ticket_ajax'
};
```

**BAD**:

```javascript
// Hardcoded strings scattered throughout the module
apex.server.process('get_tickets_for_column_ajax', ...);
var col = document.querySelector('.column-5a');
```

## 2. Formatting

### 2.1 Indentation

Use **2 spaces** for indentation. Avoid tabs.

### 2.2 Leading Commas

Use leading commas for multi-line object literals, arrays, and parameter lists to stay consistent with the PL/SQL standards.

**GOOD**:

```javascript
var CONFIG = {
    COLUMN_CLASS: '.column-5a'
  , CONTAINER_CLASS: '.tickets-container-5a'
  , TICKET_CLASS: '.ticket-card'
};
```

**BAD**:

```javascript
var CONFIG = {
  COLUMN_CLASS: '.column-5a',
  CONTAINER_CLASS: '.tickets-container-5a',
  TICKET_CLASS: '.ticket-card'
};
```

### 2.3 Strict Mode

Always include `'use strict';` as the first statement inside the module IIFE.

### 2.4 Code Sectioning

Use standardized section headers to group related functions within a module. The standard width is **64 characters** using `=` for sections.

```javascript
/* ================================================================ */
/* SECTION NAME                                                      */
/* ================================================================ */
```

## 3. JSDoc Documentation

Every function (public and private) should include a JSDoc comment block.

### 3.1 Required Tags

| Tag | Required | Description |
|---|---|---|
| Description | Yes | First line, plain text description of the function |
| `@param` | Yes | One per parameter: `{type} name - Description` |
| `@returns` | When applicable | `{type} - Description` of the return value |

**GOOD**:

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

**BAD**:

```javascript
// Gets tickets
var getTicketsForColumn = function(columnId, filters, callback) {
  // logic
};
```

## 4. File Header

Every JavaScript file should start with a header block describing the file, its purpose, and authorship.

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
