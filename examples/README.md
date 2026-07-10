# CUI Examples

Each example is a standalone Cangjie executable that depends on `cui` by local path. The
root verifier formats, builds, and lint-checks every example as teaching-quality source,
and every `main.cj` opens with a comment stating exactly what the example demonstrates.

- `notepad` — an editor shell: grouped icon toolbar, filling text area, and a status bar
  whose line/byte counts are derived from the document State each frame. Native open/save
  dialogs with async polling, message-box confirmation, clipboard copy/paste at the
  cursor, dropped-file loading, Ctrl-key shortcuts, and a Checkbox that actually changes
  behaviour (read-only mode).
- `calculator` — a uniform keypad grid built from `Flexible` cells, with the zero key
  spanning two columns via `Flexible(weight: 2.0)`. Derived view state (the pending-op
  line above the result), one style function mapping keys to reusable SurfaceStyles, and
  a Std/Sci mode switch that inserts a keypad row with plain `if` control flow.
- `paint` — canvas drawing with smooth round-capped strokes, a colour palette built from
  a custom app-defined `ColorSwatch` widget (implement the four `Widget` hooks and call
  `emit(this)`), per-stroke colour state, a slider-controlled brush, and a system
  crosshair cursor.
- `calendar` — a real month grid where the weekday header and day cells share the same
  seven-column `Flexible` rhythm; chevron buttons drive year/month State and the grid
  follows; today comes live from `Time.currentDateTime`; a Surface-generated badge image
  is shown inline with `ImageView`.
- `process_manager` — a responsive system monitor: `tasklist` runs on a worker thread
  (`spawn`) and posts results through a mutex-guarded mailbox collected once per frame,
  so the UI never blocks. TabView pages, read-only scrolling output, and summary cards
  over CPU/display/power queries.


Run one example from its project root:

```powershell
cd examples/calendar
cjpm run
```
