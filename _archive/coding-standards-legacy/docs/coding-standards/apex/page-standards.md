# APEX Page Standards

## 1. Page Numbering Convention

Organize APEX pages using a structured numbering scheme so that pages are logically grouped by module.

| Scope | Increment | Example |
|---|---|---|
| **Module** (top-level sections) | `100` | Clients = 100, Invoices = 200, Reports = 300 |
| **Detail / Modal pages** (within a module) | `10` | Client List = 100, Client Edit = 110, Client Dashboard = 120 |

### Example

| Page # | Name | Type |
|---|---|---|
| 100 | Clients | Interactive Report |
| 110 | Edit Client | Modal Dialog |
| 120 | Client Dashboard | Normal |
| 200 | Invoices | Interactive Report |
| 210 | Edit Invoice | Modal Dialog |
| 300 | Roles | Interactive Report |

## 2. Region Naming & IDs

### 2.1 Hidden Regions

Regions that are **not displayed** to the user must be named with curly braces as visual markers:

- Use `{region name}` for any hidden region.
- Use `{params}` for the standard region that holds hidden items used by JavaScript or page logic.

### Examples

**GOOD**:

| Region Name | Purpose |
|---|---|
| `Tickets` | Visible report region |
| `{params}` | Hidden region holding `P10_TICKET_ID`, `P10_USER_ID`, etc. |
| `{ticket details}` | Hidden region, not rendered |

**BAD**:

| Region Name | Problem |
|---|---|
| `Hidden Region` | No convention, hard to scan |
| `params` | Missing curly braces, not clear it's hidden |

### 2.2 Region Static IDs

Assign meaningful static IDs to regions using a suffix that denotes the region type:

| Suffix | Region Type |
|---|---|
| `IR` | Interactive Report |
| `CR` | Classic Report |
| `SR` | Static Content Region |

### Examples

**GOOD**:

| Region Name | Static ID |
|---|---|
| Tickets | `ticketsIR` |
| Client List | `clientsCR` |
| {params} | `paramsSR` |

**BAD**:

| Region Name | Static ID |
|---|---|
| Tickets | `region1` |
| Client List | `R1234567` |

## 3. Button Standards

### 3.1 Button IDs

Button static IDs must be **the same as the button name** and in **UPPERCASE**.

### Examples

**GOOD**:

| Button Name | Static ID |
|---|---|
| `CREATE` | `CREATE` |
| `SAVE` | `SAVE` |
| `DELETE` | `DELETE` |

**BAD**:

| Button Name | Static ID |
|---|---|
| `CREATE` | `btn_create` |
| `SAVE` | `B1234567` |

### 3.2 Standard Button Icons

Use application-level substitution strings for standard action button icons to ensure consistency across all pages:

| Action | Substitution String |
|---|---|
| Create | `&CREATE_ICON.` |
| Delete | `&DELETE_ICON.` |
| Edit | `&EDIT_ICON.` |
| Save | `&SAVE_ICON.` |

### Example

| Attribute | Value |
|---|---|
| **Button Name** | `CREATE` |
| **Static ID** | `CREATE` |
| **Icon CSS Classes** | `&CREATE_ICON.` |
