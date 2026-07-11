package cui.text

import sdl.{FontSizes, Key, MouseButton, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, State, UiContext, Widget, emit, localState}

public class TextField <: Widget {
    private let id: String
    private let text: Bindable<String>
    private var cursorStateValue: State<Int64>
    private var frame = Rect.zero()

    public init(id: String, text: Bindable<String>, cursor!: ?State<Int64> = None) {
        this.id = id
        this.text = text
        this.cursorStateValue = match (cursor) {
            case Some(value) => value
            case None => localState<Int64>("TextField:${id}:cursor") {text.value.size}
        }
        emit(this)
    }

    /** Uses an externally owned UTF-8 cursor byte offset. */
    public func cursorState(value: State<Int64>): TextField {
        cursorStateValue = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        TextEditState(text, cursor: Some(cursorStateValue)).normalizeCursor()
        drawTextBoxChrome(ctx, frame, id)
        // Values longer than the field must not paint past its surface; the caret is
        // clipped together with the text.
        ctx.renderer.pushClip(frame.inset(2.0))
        drawTextFieldText(ctx, frame, text.value)
        drawTextFieldCursor(ctx, frame, id, text.value, cursorStateValue.value)
        ctx.renderer.popClip()
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let edit = TextEditState(text, cursor: Some(cursorStateValue))
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => return focusIfInside(ctx, edit, x, y)
            case UiEvent.TextInput(value) =>
                if (ctx.hasFocus(id)) {
                    edit.insert(value)
                    return true
                }
            case UiEvent.KeyDown(Key.Backspace, _) =>
                if (ctx.hasFocus(id)) {
                    edit.backspace()
                    return true
                }
            case UiEvent.KeyDown(Key.Delete, _) => return handleTextKey(ctx, {=> edit.deleteForward()})
            case UiEvent.KeyDown(Key.Left, _) => return handleTextKey(ctx, {=> edit.moveLeft()})
            case UiEvent.KeyDown(Key.Right, _) => return handleTextKey(ctx, {=> edit.moveRight()})
            case UiEvent.KeyDown(Key.Home, _) => return handleTextKey(ctx, {=> edit.moveToStart()})
            case UiEvent.KeyDown(Key.End, _) => return handleTextKey(ctx, {=> edit.moveToEnd()})
            case _ => ()
        }
        false
    }

    private func focusIfInside(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            ctx.focus(id)
            edit.moveTo(textFieldCursorForPoint(ctx, frame, text.value, x))
            return true
        }
        false
    }

    private func handleTextKey(ctx: UiContext, action: () -> Unit): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        action()
        true
    }
}

private func drawTextFieldText(ctx: UiContext, frame: Rect, text: String): Unit {
    let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
    ctx.renderer.text(text, frame.x + 8.0, textY, ctx.theme.text, pointSize: FontSizes.BODY)
}
