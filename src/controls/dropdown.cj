package cui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_SMALL_H, CursorShape, Overlay, State, UiContext, Widget,
    claimHoverIfInside, drawSurface, emit, localState, registerFocusable}

private let DROPDOWN_DEFAULT_W: Float32 = 190.0
private let DROPDOWN_POPUP_PAD: Float32 = 5.0
private let DROPDOWN_GAP: Float32 = 4.0

/*
 * A dropdown select: a closed box showing the current item, and, when opened, a popup list
 * floated above the tree via the interactive overlay. Clicking an item selects and closes;
 * clicking outside or pressing Escape dismisses; arrows move the highlight while open. Because
 * the popup is an overlay, its clicks are never stolen by whatever is drawn beneath it.
 */
public class Dropdown <: Widget {
    private let id: String
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private let open: State<Bool>
    private var frame = Rect.zero()

    public init(id: String, items: Array<String>, selected: Bindable<Int64>) {
        if (id.isEmpty()) {
            throw IllegalArgumentException("Dropdown id must not be empty")
        }
        this.id = id
        this.items = items
        this.selected = selected
        this.open = localState<Bool>("Dropdown:${id}:open") {false}
        registerFocusable(id)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, DROPDOWN_DEFAULT_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id) || open.value))
        let labelArea = Rect(frame.x + 10.0, frame.y, max(0.0, frame.w - 40.0), frame.h)
        ctx.renderer.pushClip(labelArea)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(currentLabel(), labelArea.x, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
        drawChevron(ctx)

        // While open, register the popup as the interactive overlay: it is drawn on top and
        // gets events before the tree (see the shell's dispatch order).
        if (open.value) {
            let popup = popupRect(ctx)
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleOverlay(c, e, popup)}, render: {c => drawPopup(c, popup)}))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    open.value = true // when already open the overlay handles the click, not this
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Space, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Down, _) => return openIfFocused(ctx)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func openIfFocused(ctx: UiContext): Bool {
        if (ctx.hasFocus(id)) {
            open.value = true
            return true
        }
        false
    }

    // The overlay event handler while the popup is open. Runs before the tree, so it can claim
    // clicks that land on the popup and dismiss on clicks that land elsewhere.
    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    let index = itemIndexAt(popup, y)
                    if (index >= 0 && index < items.size) {
                        selected.value = index
                    }
                }
                close(ctx) // select-and-close, or dismiss on an outside click
                true
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Space, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                moveHighlight(1)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                moveHighlight(-1)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit and let the shell's Tab traversal move focus on
                false
            case _ => false
        }
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.clearActiveOverlay()
    }

    private func moveHighlight(delta: Int64): Unit {
        if (!items.isEmpty()) {
            selected.value = clampDropdownIndex(selected.value + delta, items.size)
        }
    }

    private func itemIndexAt(popup: Rect, y: Float32): Int64 {
        Int64((y - popup.y - DROPDOWN_POPUP_PAD) / CUI_SMALL_H)
    }

    private func popupRect(ctx: UiContext): Rect {
        let fullHeight = Float32(items.size) * CUI_SMALL_H + DROPDOWN_POPUP_PAD * 2.0
        let height = min(fullHeight, max(CUI_SMALL_H, ctx.viewportHeight - 8.0))
        var y = frame.bottom() + DROPDOWN_GAP
        if (y + height > ctx.viewportHeight && frame.y - DROPDOWN_GAP - height >= 0.0) {
            y = frame.y - DROPDOWN_GAP - height // flip above the control when it would overflow
        }
        Rect(frame.x, y, frame.w, height)
    }

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        drawSurface(ctx, popup, popupSurface(ctx))
        ctx.renderer.pushClip(popup)
        var y = popup.y + DROPDOWN_POPUP_PAD
        var i = 0
        while (i < items.size && y < popup.bottom()) {
            let row = Rect(popup.x + 4.0, y, max(0.0, popup.w - 8.0), CUI_SMALL_H)
            if (i == selected.value) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.accent)
                drawRowLabel(ctx, items[i], row, ctx.theme.accentText)
            } else if (row.contains(ctx.mouseX, ctx.mouseY)) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.fieldActive)
                drawRowLabel(ctx, items[i], row, ctx.theme.text)
            } else {
                drawRowLabel(ctx, items[i], row, ctx.theme.text)
            }
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
    }

    // A down chevron drawn as two strokes, so it never depends on a font glyph.
    private func drawChevron(ctx: UiContext): Unit {
        let cx = frame.right() - 18.0
        let cy = frame.centerY()
        let pen = Pen(width: 1.6, color: ctx.theme.mutedText)
        ctx.renderer.strokeLine(cx - 4.0, cy - 2.0, cx, cy + 2.5, pen)
        ctx.renderer.strokeLine(cx, cy + 2.5, cx + 4.0, cy - 2.0, pen)
    }

    private func drawRowLabel(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
        let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, row.x + 8.0, textY, color, pointSize: FontSizes.CONTROL)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }

    private func currentLabel(): String {
        if (items.isEmpty()) {
            "—"
        } else {
            items[clampDropdownIndex(selected.value, items.size)]
        }
    }

    public func isFlexible(): Bool {
        false
    }
}

private func clampDropdownIndex(index: Int64, count: Int64): Int64 {
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
