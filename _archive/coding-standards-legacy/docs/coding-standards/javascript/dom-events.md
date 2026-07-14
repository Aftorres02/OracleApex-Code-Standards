# DOM & Event Handling

## 1. Event Delegation

Use **event delegation** on a stable parent element (typically `document`) rather than binding events directly to dynamic elements. APEX pages frequently re-render regions, so directly-bound handlers on dynamic elements will break after a refresh.

**GOOD**:

```javascript
var _setupEventListeners = function() {
  document.addEventListener('click', function(event) {
    if (event.target.classList.contains('ticket-number') ||
        event.target.closest('.ticket-number')) {
      event.preventDefault();
      _handleTicketNumberClick(event);
    }
  });
};
```

**BAD**:

```javascript
// Binds directly to elements that may not exist yet or will be replaced on refresh
$('.ticket-number').on('click', function() {
  // this handler is lost after region refresh
});
```

### Key rules

- Bind the listener to `document` or the closest stable container.
- Use `event.target.closest('.selector')` to find the actual target when the click lands on a child element (e.g., an icon inside a button).
- Always call `event.preventDefault()` when intercepting navigation-related clicks.

## 2. DOM Queries

Use `CONFIG` constants for CSS selectors. Prefer `document.querySelector` / `querySelectorAll` for vanilla JS. Use jQuery (`$()`) when you need jQuery-specific features or are working within a jQuery chain.

**GOOD**:

```javascript
var columnElement = document.querySelector('[data-column-id="' + columnId + '"]');
var ticketsContainer = columnElement.querySelector(CONFIG.CONTAINER_CLASS);
```

**BAD**:

```javascript
var columnElement = document.querySelector('[data-column-id="' + columnId + '"]');
var ticketsContainer = columnElement.querySelector('.tickets-container-5a');
```

## 3. Data Attributes

Use `data-*` attributes to store entity identifiers on DOM elements. This is the standard way to link DOM elements back to their database records.

```javascript
ticketElement.setAttribute('data-ticket-id', ticket.TICKET_ID);

// Later retrieval
var ticketId = ticketElement.getAttribute('data-ticket-id');
```

With jQuery:

```javascript
var columnId = column.data('column-id');
```

## 4. APEX Page Item Interaction

Use `apex.item()` to read and write APEX page items from JavaScript. This respects the APEX session state lifecycle.

**GOOD**:

```javascript
var userIds = apex.item('P10_ASSIGNED_TO_ID').getValue();
apex.item('P10_STATUS').setValue('CLOSED');
```

**BAD**:

```javascript
var userIds = $('#P10_ASSIGNED_TO_ID').val();
$('#P10_STATUS').val('CLOSED');
```

> `apex.item()` handles cascading LOVs, display values, and session state synchronization. Direct jQuery `.val()` bypasses all of that.

### Dynamic Item Names

When page items follow a predictable pattern, build names using `apex.env.APP_PAGE_ID`:

```javascript
var apexPageID = apex.env.APP_PAGE_ID;

var _filterConfig = {
    userFilterItem: 'P' + apexPageID + '_ASSIGNED_TO_ID'
  , searchFilterItem: 'P' + apexPageID + '_SEARCH'
  , priorityFilterItem: 'P' + apexPageID + '_PRIORITY'
};
```

## 5. APEX Navigation & Dialogs

Use `apex.navigation.dialog` to open modal dialogs. This integrates with the APEX dialog lifecycle (close events, session state).

```javascript
apex.navigation.dialog(
  pData.url,
  {
      title: 'Edit Ticket: ' + ticketNumber
    , modal: true
    , resizable: true
  },
  '',
  $(triggeringElement)
);
```

### Dialog Close Handling

Listen for `apexafterclosecanceldialog` on the triggering element to refresh data after the dialog closes. Clean up the listener to prevent memory leaks.

```javascript
var cleanupListener = function(event, data) {
  logger.log('Modal closed, refreshing board');
  _loadColumnData(_collectFilters());
  isModalOpening = false;
  $(triggeringElement).off('apexafterclosecanceldialog', cleanupListener);
};

$(triggeringElement).on('apexafterclosecanceldialog', cleanupListener);
```

## 6. Preventing Duplicate Actions

Use a flag variable to prevent duplicate modal openings or AJAX calls when users double-click.

```javascript
var _isModalOpening = false;

var _openTicketDialog = function(columnId, ticketId, triggeringElement) {
  if (_isModalOpening) {
    logger.warning('Modal already opening, ignoring duplicate request');
    return;
  }

  _isModalOpening = true;

  apex.server.process(CONFIG.AJAX_GET_URL, { x01: columnId }, {
    success: function(pData) {
      if (pData.success) {
        apex.navigation.dialog(pData.url, { modal: true }, '', $(triggeringElement));
      }
      // Reset flag in dialog close handler, not here
    },
    error: function() {
      _isModalOpening = false;
    }
  });
};
```
