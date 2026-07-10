package cui.gui

import cui.sdl.{Color, MouseButton, Rect, Size, SurfaceStyle, UiEvent}

public class Label <: Widget {
    private let text: String
    private let muted: Bool
    private let align: TextAlign
    private let color: ?Color
    private var frame = Rect.zero()

    public init(text: String, muted!: Bool = false, align!: TextAlign = TextAlign.Leading, color!: ?Color = None) {
        this.text = text
        this.muted = muted
        this.align = align
        this.color = color
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, ctx.renderer.textWidth(text)), CUI_SMALL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let drawColor = match (color) {
            case Some(value) => value
            case None =>
                if (muted) {
                    ctx.theme.mutedText
                } else {
                    ctx.theme.text
                }
        }
        ctx.renderer.text(text, textX(ctx), frame.y + 7.0, drawColor)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func textX(ctx: UiContext): Float32 {
        let textW = ctx.renderer.textWidth(text)
        match (align) {
            case TextAlign.Center => frame.x + max(0.0, frame.w - textW) / 2.0
            case TextAlign.Trailing => frame.right() - textW
            case TextAlign.Leading => frame.x
        }
    }
}

public class Spacer <: Widget {
    public init() {
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        true
    }
}

public class Button <: Widget {
    private let title: String
    private let onClick: () -> Unit
    private let role: ButtonRole
    private let style: ?SurfaceStyle
    private var frame = Rect.zero()

    public init(
        title: String,
        onClick: () -> Unit,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None
    ) {
        this.title = title
        this.onClick = onClick
        this.role = role
        this.style = style
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, max(72.0, ctx.renderer.textWidth(title) + 24.0)), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, buttonStyle(ctx))
        let textColor = match (role) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
        ctx.renderer.textCenter(title, frame, textColor)
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    onClick()
                    return true
                }
            case _ => ()
        }
        false
    }

    private func buttonStyle(ctx: UiContext): SurfaceStyle {
        match (style) {
            case Some(value) => value
            case None =>
                let base = ctx.theme.buttonSurface(role)
                match (role) {
                    case ButtonRole.Normal =>
                        if (frame.contains(ctx.mouseX, ctx.mouseY)) {
                            base.withFill(ctx.theme.fieldActive)
                        } else {
                            base
                        }
                    case _ => base
                }
        }
    }
}
