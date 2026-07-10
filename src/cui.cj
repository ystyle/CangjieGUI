package cui

/*
 * Umbrella package.
 *
 * CUI is split into two layers:
 *   - cui.sdl: the SDL3 wrapper — raw FFI, geometry/color primitives, renderer,
 *     surfaces, textures, window, input, and desktop/platform integration.
 *   - cui.gui: the declarative GUI framework — the Widget tree, layout, theming,
 *     the trailing-lambda builder, the widget catalog, and DesktopApp.
 *
 * Both layers are re-exported here so applications only need `import cui.*`.
 */
public import cui.sdl.*
public import cui.gui.*
