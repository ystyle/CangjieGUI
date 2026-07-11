package cui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_SMALL_H, State, UiContext, Widget, clampScrollOffset, controlIdentity,
    drawSurface, drawVerticalScrollBar, emit, scrollLineIndex, scrollLineRemainder, scrollOffsetAfterWheel}

public class Checkbox <: Widget {
    private let label: String
    private let checked: Bindable<Bool>
    private var controlId: String
    private var frame = Rect.zero()

    public init(label: String, checked: Bindable<Bool>) {
        this.label = label
        this.checked = checked
        this.controlId = controlIdentity("Checkbox:${label}")
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity; defaults are unique per build.
     * Throws `IllegalArgumentException` when `value` is empty.
     */
    public func id(value: String): Checkbox {
        if (value.isEmpty()) {
            throw IllegalArgumentException("Checkbox id must not be empty")
        }
        controlId = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, ctx.renderer.textWidth(label) + 34.0), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let box = Rect(frame.x, frame.y + 7.0, 18.0, 18.0)
        drawSurface(ctx, box, ctx.theme.fieldSurface(false).withBorder(if (checked.value) {
            ctx.theme.accent
        } else {
            ctx.theme.panelEdge
        }))
        if (checked.value) {
            ctx.renderer.fillRoundedRect(box.inset(4.0), ctx.theme.smallRadius, ctx.theme.accent)
        }
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, frame.x + 26.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    ctx.press(controlId)
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (ctx.isPressed(controlId)) {
                    if (frame.contains(x, y)) {
                        checked.value = !checked.value
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    checked.value = !checked.value
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    checked.value = !checked.value
                    return true
                }
            case _ => ()
        }
        false
    }
}

public class ListView <: Widget {
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private var scrollStateValue: State<Float32>
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: Bindable<Int64>, scroll!: ?State<Float32> = None) {
        this.items = items
        this.selected = selected
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => State<Float32>(0.0)
        }
        emit(this)
    }

    /** Uses an externally owned scroll offset, enabling restoration and coordination. */
    public func scrollState(value: State<Float32>): ListView {
        scrollStateValue = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        scrollStateValue.value = clampScrollOffset(scrollStateValue.value, listContentHeight(items),
            listViewport(frame).h)
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))

        let viewport = listViewport(frame)
        ctx.renderer.pushClip(viewport)
        var i = scrollLineIndex(scrollStateValue.value)
        var y = viewport.y - scrollLineRemainder(scrollStateValue.value)
        while (i < items.size && y < viewport.bottom()) {
            drawRow(ctx, i, Rect(viewport.x, y, viewport.w, CUI_SMALL_H))
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, scrollStateValue.value, listContentHeight(items), viewport.h)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    // Presses on the chrome inset around the rows are consumed without
                    // selecting; row math is only valid inside the viewport.
                    let viewport = listViewport(frame)
                    if (viewport.contains(x, y)) {
                        let idx = Int64((y - viewport.y + scrollStateValue.value) / CUI_SMALL_H)
                        if (idx >= 0 && idx < items.size) {
                            selected.value = idx
                        }
                    }
                    return true
                }
            case UiEvent.MouseWheel(_, y, x, pointerY) =>
                if (frame.contains(x, pointerY)) {
                    scrollStateValue.value = scrollOffsetAfterWheel(scrollStateValue.value, y, listContentHeight(items),
                        listViewport(frame).h)
                    return true
                }
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    private func drawRow(ctx: UiContext, i: Int64, row: Rect): Unit {
        if (i == selected.value) {
            ctx.renderer.fillRoundedRect(row.inset(2.0), ctx.theme.smallRadius, ctx.theme.accent)
            drawRowText(ctx, items[i], row, ctx.theme.accentText)
        } else {
            drawRowText(ctx, items[i], row, ctx.theme.text)
        }
    }
}

private func drawRowText(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
    let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
    ctx.renderer.text(text, row.x + 6.0, textY, color, pointSize: FontSizes.BODY)
}

private func listContentHeight(items: Array<String>): Float32 {
    Float32(items.size) * CUI_SMALL_H
}

private func listViewport(frame: Rect): Rect {
    Rect(frame.x + 4.0, frame.y + 6.0, max(0.0, frame.w - 12.0), max(0.0, frame.h - 12.0))
}
