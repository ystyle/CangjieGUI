package cui.text

import sdl.{FontSizes, Key, MouseButton, Point, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_SMALL_H, State, UiContext, Widget, clampScrollOffset, drawSurface, drawVerticalScrollBar,
    emit, localState, scrollLineIndex, scrollLineRemainder, scrollOffsetAfterWheel}

public class TextArea <: Widget {
    private let id: String
    private let text: Bindable<String>
    private var scrollStateValue: State<Float32>
    private var cursorStateValue: State<Int64>
    private var isEditable: Bool
    private var frame = Rect.zero()

    public init(
        id: String,
        text: Bindable<String>,
        scroll!: ?State<Float32> = None,
        cursor!: ?State<Int64> = None,
        editable!: Bool = true
    ) {
        this.id = id
        this.text = text
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("TextArea:${id}:scroll") {0.0}
        }
        this.cursorStateValue = match (cursor) {
            case Some(value) => value
            case None => localState<Int64>("TextArea:${id}:cursor") {text.value.size}
        }
        this.isEditable = editable
        emit(this)
    }

    /** Uses an externally owned scroll offset. */
    public func scrollState(value: State<Float32>): TextArea {
        scrollStateValue = value
        this
    }

    /** Uses an externally owned UTF-8 cursor byte offset. */
    public func cursorState(value: State<Int64>): TextArea {
        cursorStateValue = value
        this
    }

    /** Enables or disables text mutation while retaining navigation and selection. */
    public func editable(value: Bool): TextArea {
        isEditable = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        TextEditState(text, cursor: Some(cursorStateValue)).normalizeCursor()
        scrollStateValue.value = clampScrollOffset(scrollStateValue.value, textContentHeight(text.value),
            textViewport(frame).h)
        drawTextAreaBox(ctx, frame, id, TextAreaContent(text.value, cursorStateValue.value, scrollStateValue.value))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let edit = TextEditState(text, cursor: Some(cursorStateValue))
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => return focusIfInside(ctx, edit, x, y)
            case UiEvent.MouseWheel(_, y, x, pointerY) =>
                if (frame.contains(x, pointerY)) {
                    scrollStateValue.value = scrollOffsetAfterWheel(scrollStateValue.value, y,
                        textContentHeight(text.value), textViewport(frame).h)
                    return true
                }
            case UiEvent.TextInput(value) =>
                if (ctx.hasFocus(id) && isEditable) {
                    edit.insert(value)
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(id) && isEditable) {
                    edit.insert("\n")
                    return true
                }
            case UiEvent.KeyDown(Key.Backspace, _) =>
                if (ctx.hasFocus(id) && isEditable) {
                    edit.backspace()
                    return true
                }
            case UiEvent.KeyDown(Key.Delete, _) => return handleTextKey(ctx, {=> edit.deleteForward()},
                enabled: isEditable)
            case UiEvent.KeyDown(Key.Left, _) => return handleTextKey(ctx, {=> edit.moveLeft()})
            case UiEvent.KeyDown(Key.Right, _) => return handleTextKey(ctx, {=> edit.moveRight()})
            case UiEvent.KeyDown(Key.Up, _) => return handleTextKey(ctx, {=> edit.moveLineUp()})
            case UiEvent.KeyDown(Key.Down, _) => return handleTextKey(ctx, {=> edit.moveLineDown()})
            case UiEvent.KeyDown(Key.Home, _) => return handleTextKey(ctx, {=> edit.moveToLineStart()})
            case UiEvent.KeyDown(Key.End, _) => return handleTextKey(ctx, {=> edit.moveToLineEnd()})
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    private func focusIfInside(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            ctx.focus(id)
            edit.moveTo(
                textAreaCursorForPoint(
                    ctx,
                    frame,
                    TextAreaContent(text.value, cursorStateValue.value, scrollStateValue.value),
                    Point(x, y)
                )
            )
            return true
        }
        false
    }

    private func handleTextKey(
        ctx: UiContext,
        action: () -> Unit,
        enabled!: Bool = true
    ): Bool {
        if (!ctx.hasFocus(id) || !enabled) {
            return false
        }
        action()
        true
    }
}

private func drawTextAreaBox(
    ctx: UiContext,
    frame: Rect,
    id: String,
    content: TextAreaContent
): Unit {
    drawTextBoxChrome(ctx, frame, id)
    let viewport = textViewport(frame)
    ctx.renderer.pushClip(viewport)
    drawLines(ctx, viewport, content.text, content.scroll)
    drawTextAreaCursor(ctx, viewport, id, content)
    ctx.renderer.popClip()
    drawVerticalScrollBar(ctx, frame, content.scroll, textContentHeight(content.text), viewport.h)
}

internal func drawTextBoxChrome(ctx: UiContext, frame: Rect, id: String): Unit {
    drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.hasFocus(id)))
}

private func drawLines(ctx: UiContext, rect: Rect, text: String, scroll: Float32): Unit {
    let lines = text.split("\n")
    var i = scrollLineIndex(scroll)
    var y = rect.y - scrollLineRemainder(scroll)
    while (i < lines.size && y < rect.bottom()) {
        ctx.renderer.text(lines[i], rect.x, y, ctx.theme.text, pointSize: FontSizes.BODY)
        y += CUI_SMALL_H
        i += 1
    }
}

private func textContentHeight(text: String): Float32 {
    Float32(text.split("\n").size) * CUI_SMALL_H
}

private func textViewport(frame: Rect): Rect {
    textInputViewport(frame)
}
