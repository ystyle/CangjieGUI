package cui.text

import std.collection.ArrayList
import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_SMALL_H, Overlay, State, UiContext, Widget, buildChild, drawSurface,
    emit, localState}

private let COMBO_POPUP_PAD: Float32 = 5.0
private let COMBO_GAP: Float32 = 4.0
private let COMBO_CHEVRON_W: Float32 = 30.0

/*
 * An editable dropdown (combo box): a text field the user can type into, plus a list of
 * suggestions. It composes an embedded `TextField` (so it inherits full editing — cursor,
 * selection, undo, clipboard) with the interactive overlay used by menus and dropdowns to float
 * the suggestion list. Typing filters the list; clicking a suggestion or pressing Enter fills the
 * field. The bound `text` is the value — freely typed text is kept even if it matches no option.
 */
public class ComboBox <: Widget {
    private let fieldId: String
    private let text: Bindable<String>
    private let options: Array<String>
    private let cursorState: State<Int64>
    private let anchorState: State<Int64>
    private let field: Widget
    private let open: State<Bool>
    private let highlight: State<Int64>
    private var frame = Rect.zero()

    public init(id: String, text: Bindable<String>, options: Array<String>) {
        if (id.isEmpty()) {
            throw IllegalArgumentException("ComboBox id must not be empty")
        }
        this.fieldId = id
        this.text = text
        this.options = options
        // Own the field's caret and anchor, so choosing a suggestion can move the caret to the
        // end and collapse the selection (otherwise a stale anchor leaves the value highlighted).
        let cursor = localState<Int64>("ComboBox:${id}:cursor") {text.value.size}
        let anchor = localState<Int64>("ComboBox:${id}:anchor") {text.value.size}
        this.cursorState = cursor
        this.anchorState = anchor
        this.field = buildChild({=> TextField(id, text, cursor: Some(cursor), anchor: Some(anchor))})
        this.open = localState<Bool>("ComboBox:${id}:open") {false}
        this.highlight = localState<Int64>("ComboBox:${id}:hl") {0}
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, CUI_CONTROL_H)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        field.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        field.draw(ctx)
        drawChevron(ctx)
        if (open.value) {
            let popup = popupRect(ctx, filteredOptions())
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleOverlay(c, e, popup)}, render: {c => drawPopup(c, popup)}))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (chevronRect().contains(x, y)) {
                    toggleOpen(ctx)
                    return true
                }
            case UiEvent.KeyDown(Key.Down, _) =>
                if (ctx.hasFocus(fieldId) && !open.value) {
                    openList(ctx)
                    return true
                }
            case _ => ()
        }
        // Everything else — typing, caret clicks, shortcuts — is the embedded field's job.
        field.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(fieldId) // the embedded field owns the focus stop
    }

    private func toggleOpen(ctx: UiContext): Unit {
        if (open.value) {
            close(ctx)
        } else {
            openList(ctx)
        }
    }

    private func openList(ctx: UiContext): Unit {
        open.value = true
        highlight.value = 0
        ctx.focus(fieldId) // keep the field focused so typing filters the open list
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.clearActiveOverlay()
    }

    /*
     * Overlay handler while the list is open. It claims list clicks, dismissal, and list
     * navigation, but returns false for typing so those events fall through to the focused field
     * (which re-filters the list as the text changes).
     */
    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        let filtered = filteredOptions()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    commit(ctx, filtered, itemIndexAt(popup, y))
                    return true
                }
                close(ctx)
                // A press on the chevron toggles closed; any other outside press dismisses and is
                // let through (e.g. to reposition the caret or focus another control).
                chevronRect().contains(x, y)
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                // Clamp: typing may have shrunk the list below the highlighted index.
                commit(ctx, filtered, clampComboIndex(highlight.value, filtered.size))
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                highlight.value = clampComboIndex(highlight.value + 1, filtered.size)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                highlight.value = clampComboIndex(highlight.value - 1, filtered.size)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit the typed text and let the shell's Tab traversal move on
                false
            case _ => false // typing falls through to the field
        }
    }

    // Fills the field with the chosen suggestion (caret to end, no selection) and closes.
    private func commit(ctx: UiContext, filtered: Array<String>, index: Int64): Unit {
        if (index >= 0 && index < filtered.size) {
            text.value = filtered[index]
            cursorState.value = filtered[index].size
            anchorState.value = filtered[index].size
        }
        close(ctx)
    }

    private func filteredOptions(): Array<String> {
        let query = text.value.toAsciiLower()
        if (query.isEmpty()) {
            return options
        }
        let result = ArrayList<String>()
        for (option in options) {
            if (option.toAsciiLower().contains(query)) {
                result.add(option)
            }
        }
        result.toArray()
    }

    private func chevronRect(): Rect {
        Rect(frame.right() - COMBO_CHEVRON_W, frame.y, COMBO_CHEVRON_W, frame.h)
    }

    private func itemIndexAt(popup: Rect, y: Float32): Int64 {
        Int64((y - popup.y - COMBO_POPUP_PAD) / CUI_SMALL_H)
    }

    private func popupRect(ctx: UiContext, filtered: Array<String>): Rect {
        // At least one row: with no matches the popup keeps its shape and shows a placeholder
        // instead of collapsing to a sliver of empty chrome.
        let fullHeight = Float32(max(1, filtered.size)) * CUI_SMALL_H + COMBO_POPUP_PAD * 2.0
        let height = min(fullHeight, max(CUI_SMALL_H, ctx.viewportHeight - 8.0))
        var y = frame.bottom() + COMBO_GAP
        if (y + height > ctx.viewportHeight && frame.y - COMBO_GAP - height >= 0.0) {
            y = frame.y - COMBO_GAP - height
        }
        Rect(frame.x, y, frame.w, height)
    }

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        let filtered = filteredOptions()
        let active = clampComboIndex(highlight.value, filtered.size)
        drawSurface(ctx, popup, popupSurface(ctx))
        ctx.renderer.pushClip(popup)
        if (filtered.isEmpty()) {
            // No suggestion matches the typed text; clicking the placeholder just dismisses.
            let row = Rect(popup.x + 4.0, popup.y + COMBO_POPUP_PAD, max(0.0, popup.w - 8.0), CUI_SMALL_H)
            drawRowLabel(ctx, "—", row, ctx.theme.mutedText)
            ctx.renderer.popClip()
            return
        }
        var y = popup.y + COMBO_POPUP_PAD
        var i = 0
        while (i < filtered.size && y < popup.bottom()) {
            let row = Rect(popup.x + 4.0, y, max(0.0, popup.w - 8.0), CUI_SMALL_H)
            if (i == active) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.accent)
                drawRowLabel(ctx, filtered[i], row, ctx.theme.accentText)
            } else if (row.contains(ctx.mouseX, ctx.mouseY)) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.fieldActive)
                drawRowLabel(ctx, filtered[i], row, ctx.theme.text)
            } else {
                drawRowLabel(ctx, filtered[i], row, ctx.theme.text)
            }
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
    }

    private func drawChevron(ctx: UiContext): Unit {
        let cx = frame.right() - 18.0
        let cy = frame.centerY()
        let pen = Pen(width: 1.6, color: ctx.theme.mutedText)
        ctx.renderer.strokeLine(cx - 4.0, cy - 2.0, cx, cy + 2.5, pen)
        ctx.renderer.strokeLine(cx, cy + 2.5, cx + 4.0, cy - 2.0, pen)
    }

    private func drawRowLabel(ctx: UiContext, label: String, row: Rect, color: Color): Unit {
        let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, row.x + 8.0, textY, color, pointSize: FontSizes.CONTROL)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }
}

private func clampComboIndex(index: Int64, count: Int64): Int64 {
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
