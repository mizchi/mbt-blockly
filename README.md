# mbt-blockly

Blockly-style visual code editor for MoonBit AST, rendered in SVG.

## Architecture

```
src/
  model/       Data model (Block, Workspace, catalog)
  svg_gen/     SVG string generation (measure + render)
  app/         Browser entry (svg_gen → innerHTML + JS interaction)
  cli/         TUI entry (svg_gen → mizchi/svg rasterize → kitty protocol)
interaction.js  DnD, pan, zoom, snap (plain JS, no MoonBit FFI)
main.ts         Vite entry (imports MoonBit + interaction.js)
```

### Block types

| Type | Connector | Shape | Example |
|------|-----------|-------|---------|
| Statement | top notch (convex) + bottom socket (concave) | Rectangle with notches | `let x =`, `if`, `return`, `fn()` |
| Expression | left plug (pill shape) | Rounded pill | `1`, `x`, `_ + _`, `_ == _` |

### Connection model

- **Statement chain**: top notch ↔ bottom socket (vertical stacking)
- **Input slot**: parent slot ↔ child block (nested)
- **Infix expression**: `[left] op [right]` layout for binary operators

### Visual design (Dark theme, Catppuccin-inspired)

- Block fill: `hsl(hue, 30%, 30%)`
- Block stroke: `hsl(hue, 40%, 45%)`
- Text: `#cdd6f4` / `#a6adc8`
- Background: `#1e1e2e`
- Connection notch highlight: `rgba(160,200,255,0.6)`
- Rail between chained statements: blue line + dots
- Top-level blocks: drop shadow

### Interaction

| Action | PC | Mobile |
|--------|-----|--------|
| Move block | Drag block | Same |
| Pan canvas | Drag empty area | Same |
| Zoom | Mouse wheel | Pinch |
| Snap connect | Drag block's notch near target notch/slot | Same |

### Snap detection

Two snap types, both based on dragged block's **top-notch position**:

1. **Notch-to-notch** (statement → statement bottom): `connectNext`
2. **Slot** (block → empty slot): `connect` to parent's input slot

Visual feedback:
- Target block/slot glows green
- Animated dashed preview rect at drop position
- Parent container expansion preview (blue dashed outline)

### Empty slot adapters

Empty slots show the shape they accept:
- Statement: trapezoid notch adapter (blue, filled)
- Expression: left-arc pill adapter (blue, filled)

## Usage

```bash
pnpm install
pnpm dev          # Browser: http://localhost:5173

# TUI (kitty terminal)
moon run src/cli --target js
```

## Block catalog

| ID | Label | Type | Inputs |
|----|-------|------|--------|
| `fn_def` | `fn _()` | Statement | body(S) |
| `let_binding` | `let _ = _` | Statement | value(E) |
| `if_stmt` | `if` | Statement | condition(E), then(S), else(S) |
| `match_stmt` | `match` | Statement | expr(E), arms(S) |
| `for_loop` | `for _ in _` | Statement | iter(E), body(S) |
| `return_stmt` | `return` | Statement | value(E) |
| `number_lit` | `0` | Expression | — |
| `string_lit` | `""` | Expression | — |
| `bool_lit` | `true` | Expression | — |
| `identifier` | `x` | Expression | — |
| `binary_op` | `_ + _` | Expression | left(E), right(E) |
| `comparison` | `_ == _` | Expression | left(E), right(E) |
| `fn_call` | `_()` | Expression | arg0(E) |

(S) = Statement slot, (E) = Expression slot

## API (window.__mbt)

Exposed by MoonBit for JS interaction:

```js
__mbt.detach(blockId)                    // Remove from parent
__mbt.connect(parentId, slotName, childId) // Connect to input slot
__mbt.connectNext(blockId, nextId)       // Connect as next statement
__mbt.insertAfter(afterId, blockId)      // Insert into chain
__mbt.moveBlock(blockId, x, y)          // Update position
__mbt.rerender()                         // Re-render SVG
__mbt.getBlockType(blockId) → string     // "statement" | "expression"
```
