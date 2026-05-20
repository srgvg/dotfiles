# Keybindings Reference — Maintenance Guide

The rendered reference is in `keybindings.html` (open in any browser).

## Where bindings are defined

| File | Contains |
|------|---------|
| `60-bindings-config` | All global keybindings (~200 entries) |
| `70-modes-config` | Mode-entry bindings + in-mode bindings (resize, move, system, nag) |

The main modifier is `$mod` = Super (Windows key), defined in `10-variables-config`.

## How to update keybindings.html

The HTML file is hand-maintained. When you add, remove, or change a binding:

1. Edit the binding in `60-bindings-config` or `70-modes-config`.
2. Find the matching `<tr>` in `keybindings.html` (search by key name or action text).
3. Update or add the row in the correct `<section>`.
4. For new sections, copy an existing `<section>` block and assign a new `id`.
5. Add a nav link in the `<nav id="nav">` block if you added a section.

## Row format

```html
<tr>
  <td><kbd>Super</kbd><span class="plus">+</span><kbd>KEY</kbd></td>
  <td>Human-readable action</td>
  <td class="note">optional note / script name</td>
</tr>
```

CSS classes for the Notes column:
- `note` — grey, for script names or secondary info
- `bug` — red, for known bugs
- `flag` — yellow, for warnings

## Adding a new section

```html
<section id="mysection">
  <h2>My Section</h2>
  <table>
    <thead><tr><th>Keybinding</th><th>Action</th><th>Notes</th></tr></thead>
    <tbody>
      <!-- rows here -->
    </tbody>
  </table>
</section>
```

Add a nav pill:
```html
<a href="#mysection">My Section</a>
```

## Search

The search box filters all rows by text content (keybinding + action + notes). No rebuild needed — it works on the live page.

## Checklist when adding a binding

- [ ] Add `bindsym` in `60-bindings-config` (global) or `70-modes-config` (mode)
- [ ] Reload sway: `Super+Shift+r`
- [ ] Add row to correct section in `keybindings.html`
- [ ] Verify no duplicate keybinding: `grep "bindsym.*YOURKEY" ~/.config/sway/*-config`
