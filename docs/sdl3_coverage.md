# SDL3 Coverage

SDL3 source package: `SDL3-dev-3.4.12-mingw`.

Current CUI milestone provides a compiled, safe GUI path over these SDL3 areas:

- Init, quit, version, revision, error reporting, application metadata properties, and SDL hint set/get/reset with priority.
- Window creation, destruction, sizing, pixel sizing, position, title get/set, min/max size, safe area, borders, aspect ratio, fullscreen, show/hide, raise, maximize, minimize, restore, opacity, always-on-top, bordered/resizable flags, focusability, keyboard/mouse grab, mouse grab rect, fill-document, system menu, flash, sync, progress state/value, window display lookup, window flags, pixel density, and high-DPI display scale.
- Primary display, multi-display enumeration, display-by-id queries for name, bounds, usable bounds, content scale, natural/current orientation, desktop mode, current mode, fullscreen mode lists, closest fullscreen mode matching, and point/rectangle/window display lookup.
- Renderer VSync, draw color, float draw color, color scale, viewport, clip rect, clear, present, point, line, rectangle, fill rectangle, rounded fill rectangle helper, circle/fill-circle helpers, and debug text.
- Surface and texture basics: RGBA surface creation, clear, pixel write, BMP save, BMP/PNG load, texture creation from surface, texture size query, color/alpha/blend modulation, textured render, rotated render, and flip modes.
- Event polling for quit, window resize, keyboard, text input, mouse motion, mouse button, mouse wheel, and drag-and-drop begin/file/text/position/complete.
- Mouse wheel events are surfaced through scrollable text area and list view controls with retained `State<Float32>` offsets.
- Text input activation, text input area setup, and cursor-aware declarative text editing with UTF-8-safe mutation helpers.
- Keyboard modifier state for shortcut handling.
- Mouse state, capture, window-relative mouse mode, system cursor creation/destruction, active cursor selection, and cursor show/hide/visible state.
- Clipboard text get/set/has, primary selection text get/set/has, MIME type listing, MIME data presence checks, MIME data reads, callback-backed MIME data offers, and clipboard data clearing.
- Filesystem base path, preference path, current directory, common user folders, path info, directory globbing, directory creation, path removal, rename, and file copy.
- Native open-file, save-file, and open-folder dialogs with validated filters, selected-filter indexes, cancellation/error states, and async `FileDialogRequest` polling.
- Platform name, CPU/cache/RAM/page-size info, SIMD feature checks, power information, URL opening, and native message boxes with custom buttons, return/escape defaults, button order, selected button IDs, and optional color schemes.
- Realtime clock, locale date/time preferences, calendar conversion helpers, Windows file time conversion, timer ticks, high-resolution performance counters, and millisecond/nanosecond delay. Timer ticks are surfaced to declarative apps as broadcast `UiEvent.Frame(FrameInfo)` lifecycle updates.

Binding policy:

- `sdl_*_raw.cj` files are the only place for raw `foreign` declarations.
- Raw FFI declarations preserve SDL's C ABI exactly; the verification script only allows parameter-count lint warnings in these files.
- Public code exposes `SdlWindow`, `WindowFlags`, `WindowProgressState`, `Renderer`, `Surface`, `Texture`, `Mouse`, `Cursor`, `Clipboard`, `ClipboardData`, `ApplicationMetadata`, `SdlHints`, `FileDialogs`, `FileDialogRequest`, `ApplicationPaths`, `FileSystem`, `Time`, `PerformanceClock`, `MessageBoxOptions`, `DisplayInfo`, `FullscreenModeRequest`, `PowerInfo`, `CpuInfo`, `FrameInfo`, `UiEvent`, and declarative widgets instead of C pointers.
- SDL-owned strings are converted immediately and released with `SDL_free` when required.
- Heap strings passed into SDL are wrapped in `CStringResource`.
- Window and renderer lifetimes are owned by `SdlWindow <: Resource`.

Remaining SDL3 coverage plan:

1. Generate raw declarations per remaining SDL header category into small files such as `sdl_audio_raw.cj`, `sdl_gpu_raw.cj`, and `sdl_joystick_raw.cj`.
2. Treat SDL opaque handles as internal `CPointer<Unit>` aliases and wrap each public resource with a Cangjie `Resource` owner.
3. Map value structs with `@C` only after checking layout against the SDL header.
4. Map callbacks with `CFunc` and keep callback state ownership in Cangjie wrapper classes.
5. Promote APIs from raw to safe public modules only when ownership, nullability, and failure behavior are documented.

This keeps the framework usable now while leaving a clear path to a complete raw SDL3 surface without leaking unsafe APIs into application code.

Verification currently includes Cangjie unit tests for geometry, event decoding helpers, drag-and-drop decoding/scaling, frame lifecycle routing, keyboard modifier mapping, clipboard MIME validation, native byte/list copying, callback-backed clipboard offer lookup, filesystem folder mapping/path queries/path-info type mapping/directory globbing, date/time enum mapping/calendar helpers/epoch conversion/Windows time conversion/performance counters, metadata property/type mapping, SDL hint name/priority mapping and custom hint round-trip, file dialog filter validation and callback result decoding, message box kind/order/button/color mapping and option validation, display orientation/mode mapping, display id and fullscreen mode pointer decoding, window flag parsing, window progress-state mapping, logical window-size scaling, scroll offset clamping, scrollable text/list input routing, UTF-8-safe text edit cursor operations, external text cursor bindings, read-only text area behavior, image format routing, texture render options, SDL system enum/flag mapping, cursor enum mapping, platform/CPU info, window configuration, event handler routing, trailing-lambda stack builders, styled panel builders, icon button builders, state/focus tracking, slider interaction, segmented control selection, tab selection, and image view measurement/resource closure. The root `scripts/verify.ps1` script also formats, builds, and lint-checks every example, rejects unexpected lint warnings, syncs SDL3 runtime DLLs, and smoke-starts each desktop tool.
