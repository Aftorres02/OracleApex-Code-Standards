# AJAX & Server Communication

## 1. Use `apex.server.process`

All AJAX calls to the backend should use `apex.server.process`. This is the standard APEX client-side API that handles session state, CSRF tokens, and the APEX request lifecycle automatically.

### Standard Pattern

```javascript
apex.server.process(
  CONFIG.AJAX_PROCESS_NAME,
  {
      x01: value1
    , x02: value2
  },
  {
    success: function(pData) {
      if (pData.success) {
        // Handle success
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

### Key rules

- Reference the AJAX process name from the `CONFIG` object, not as a hardcoded string.
- Map `x01`, `x02`, etc. to match the PL/SQL backend reading from `apex_application.g_x01`, `g_x02`.
- Always handle **both** `success` and `error` callbacks.
- Inside `success`, always check `pData.success` because the HTTP request can succeed while the server-side logic fails.

## 2. Process Name Mapping

The CONFIG constant in the Services module should map to the APEX On-Demand Process names defined in the application. Keep a clear 1:1 mapping.

```javascript
var CONFIG = {
    ajaxGetTicketsForColumn: 'get_tickets_for_column_ajax'
  , ajaxMoveTicket: 'move_ticket_ajax'
};
```

The process names should match the PL/SQL AJAX procedure names exactly.

## 3. Success Handler

Always check the `success` flag returned by the server. The PL/SQL backend follows the convention of returning `{ "success": true/false }` via `apex_json`.

**GOOD**:

```javascript
success: function(pData) {
  logger.log('Response received', {success: pData.success});

  if (pData.success) {
    callback(pData.tickets || []);
  } else {
    logger.error('Server error', {error: pData.message});
    callback([]);
  }
}
```

**BAD**:

```javascript
success: function(pData) {
  // Assumes success without checking — server errors silently ignored
  callback(pData.tickets);
}
```

## 4. Error Handler

The `error` callback fires on network failures, timeouts, or HTTP errors. Always log the failure details and provide a safe fallback.

**GOOD**:

```javascript
error: function(jqXHR, textStatus, errorThrown) {
  logger.error('AJAX error getting tickets', {
      status: textStatus
    , error: errorThrown
  });
  callback([]);
}
```

**BAD**:

```javascript
error: function() {
  alert('Something went wrong');
}
```

## 5. Callback Pattern

AJAX functions in Services modules accept a `callback` parameter. The callback always receives a predictable result regardless of success or failure.

```javascript
var getTicketsForColumn = function(columnId, filters, callback) {
  if (typeof filters === 'function') {
    callback = filters;
    filters = {};
  }
  filters = filters || {};

  apex.server.process(
    CONFIG.ajaxGetTicketsForColumn,
    {
        x01: columnId
      , x02: filters.userIds
    },
    {
      success: function(pData) {
        if (pData.success) {
          callback(pData.tickets || []);
        } else {
          callback([]);
        }
      },
      error: function(jqXHR, textStatus, errorThrown) {
        logger.error('AJAX error', {status: textStatus});
        callback([]);
      }
    }
  );
};
```

> When a function has optional middle parameters (like `filters` above), check `typeof` at the top and shift arguments accordingly.

## 6. User Feedback

Use APEX built-in APIs for user-facing messages after AJAX operations:

| Outcome | API |
|---|---|
| Success | `apex.message.showPageSuccess('Ticket moved successfully');` |
| Error | `apex.message.showErrors('Failed to move ticket.');` |

Avoid using `alert()` or custom DOM-injected messages.
