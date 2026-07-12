package cui.core

import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, SurfaceStyle, UiEvent}

private let MENU_PAD: Float32 = 5.0
private let MENU_MARGIN: Float32 = 4.0
private let MENU_MIN_W: Float32 = 120.0
private let MENU_TEXT_PAD: Float32 = 24.0

/** One entry in a context menu: a label and the action run when it is chosen. */
public struct MenuItem {
    let label: String
    let action: () -> Unit

    public init(label: String, action: () -> Unit) {
        this.label = label
        this.action = action
    }
}

/*
 * Wraps a control with a right-click context menu. A secondary press inside the child opens a
 * menu at the pointer, floated above the tree via the interactive overlay — so its clicks are
 * never stolen by controls beneath it. Choosing an item runs its action and closes; a click
 * outside or Escape dismisses; arrows and hover move the highlight, Enter runs it. Otherwise a
 * transparent wrapper: it forwards layout, drawing and all other events to the child.
 */
public class ContextMenu <: Widget {
    private let child: Widget
    private let items: Array<MenuItem>
    private let open: State<Bool>
    private let menuX: State<Float32>
    private let menuY: State<Float32>
    private let highlight: State<Int64>
    // Identifies this menu on the overlay stack across per-frame rebuilds, so closing
    // removes exactly its own registration (a dialog beneath it stays open).
    private let overlayOwner: String
    private var frame = Rect.zero()

    public init(items!: Array<MenuItem>, body!: () -> Unit) {
        this.child = buildChild(body)
        this.items = items
        let key = controlIdentity("ContextMenu")
        this.overlayOwner = key
        this.open = localState<Bool>("${key}:open") {false}
        this.menuX = localState<Float32>("${key}:x") {0.0}
        this.menuY = localState<Float32>("${key}:y") {0.0}
        this.highlight = localState<Int64>("${key}:hl") {0}
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
        if (open.value && !items.isEmpty()) {
            let menu = menuRect(ctx)
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleMenu(c, e, menu)},
                render: {c => drawMenu(c, menu)}, owner: overlayOwner))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Right, x, y) =>
                // With no items there is nothing to show — and draw would never register
                // the overlay, so a latched `open` could pop a menu much later, unprompted.
                if (frame.contains(x, y) && !items.isEmpty()) {
                    open.value = true
                    menuX.value = x
                    menuY.value = y
                    highlight.value = 0
                    return true
                }
            case _ => ()
        }
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    private func handleMenu(ctx: UiContext, event: UiEvent, menu: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (menu.contains(x, y)) {
                    runItem(ctx, itemIndexAt(menu, y))
                } else {
                    close(ctx)
                }
                true
            case UiEvent.MouseDown(_, _, _) =>
                close(ctx) // any other button dismisses
                true
            case UiEvent.MouseMove(x, y) =>
                if (menu.contains(x, y)) {
                    let index = itemIndexAt(menu, y)
                    if (index >= 0 && index < items.size) {
                        highlight.value = index
                    }
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                runItem(ctx, highlight.value)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                highlight.value = clampMenuIndex(highlight.value + 1, items.size)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                highlight.value = clampMenuIndex(highlight.value - 1, items.size)
                true
            case _ => false
        }
    }

    // Closes first, then runs the action, so the action sees a settled UI (and may itself open
    // another overlay).
    private func runItem(ctx: UiContext, index: Int64): Unit {
        close(ctx)
        if (index >= 0 && index < items.size) {
            items[index].action()
        }
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    // Maps a pointer y inside the menu to an item index; the padding strips above and
    // below the rows hit nothing (-1), so a press there neither runs nor highlights.
    private func itemIndexAt(menu: Rect, y: Float32): Int64 {
        if (y < menu.y + MENU_PAD || y >= menu.bottom() - MENU_PAD) {
            return -1
        }
        Int64((y - menu.y - MENU_PAD) / CUI_SMALL_H)
    }

    private func menuRect(ctx: UiContext): Rect {
        var width = MENU_MIN_W
        for (item in items) {
            width = max(width, ctx.renderer.textWidth(item.label, pointSize: FontSizes.CONTROL) + MENU_TEXT_PAD)
        }
        let height = Float32(items.size) * CUI_SMALL_H + MENU_PAD * 2.0
        var x = menuX.value
        var y = menuY.value
        if (x + width > ctx.viewportWidth) {
            x = max(MENU_MARGIN, ctx.viewportWidth - width - MENU_MARGIN)
        }
        if (y + height > ctx.viewportHeight) {
            y = max(MENU_MARGIN, ctx.viewportHeight - height - MENU_MARGIN)
        }
        Rect(x, y, width, height)
    }

    private func drawMenu(ctx: UiContext, menu: Rect): Unit {
        drawSurface(ctx, menu, menuSurface(ctx))
        ctx.renderer.pushClip(menu)
        var y = menu.y + MENU_PAD
        var i = 0
        while (i < items.size) {
            let row = Rect(menu.x + 4.0, y, max(0.0, menu.w - 8.0), CUI_SMALL_H)
            if (i == highlight.value) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.accent)
                drawItemLabel(ctx, items[i].label, row, ctx.theme.accentText)
            } else {
                drawItemLabel(ctx, items[i].label, row, ctx.theme.text)
            }
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
    }

    private func drawItemLabel(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
        let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, row.x + 8.0, textY, color, pointSize: FontSizes.CONTROL)
    }

    private func menuSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }
}

private func clampMenuIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0) {
        0
    } else if (index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
