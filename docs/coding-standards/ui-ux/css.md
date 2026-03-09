# CSS & Styling Guidelines

## 1. Custom Class Naming

Ensure all custom CSS classes are safely prefixed to avoid clashing with the APEX Universal Theme classes.

### Examples

**GOOD**:

```css
.app-custom-card {
  padding: 1rem;
  background-color: var(--ut-body-bg);
}
```

**BAD**:

```css
/* This conflicts with native Oracle APEX Universal Theme styling */
.t-Card {
  background-color: red !important;
}
```

## 2. Universal Theme Best Practices

- Always attempt to use built-in declarative options within the APEX Builder (e.g., Template Options, Theme Roller) before resorting to writing custom CSS.
- When injecting custom properties, utilize Oracle's exposed CSS custom variables (`var(--ut-...)`) to maintain theme compatibility across updates.
