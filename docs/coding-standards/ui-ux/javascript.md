# JavaScript Guidelines

## 1. Naming Conventions

- **Variables & Functions:** Use `camelCase`.
- **Constants:** Use `UPPERCASE` with `snake_case`.

### Examples

**GOOD**:

```javascript
const MAX_ROWS = 100;
function fetchTicketDetails(ticketId) {
  // logic
}
```

**BAD**:

```javascript
const max_rows = 100;
function Fetch_Ticket(Ticket_id) {
  // logic
}
```

## 2. API & AJAX Calls

When making asynchronous calls to the backend via `apex.server.process`, ensure a standardized approach by handling both success and error outcomes gracefully to align with our backend APEX error responses.
