package cui.controls

import sdl.{FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, UiContext, Widget, controlIdentity, drawSurface, emit}

private let SWITCH_TRACK_W: Float32 = 40.0
private let SWITCH_TRACK_H: Float32 = 22.0
private let PICKER_DEFAULT_W: Float32 = 190.0
private let STEPPER_DEFAULT_W: Float32 = 144.0

/** A binary desktop switch bound to a Boolean state. */
public class Switch <: Widget {
    private let label: String
    private let checked: Bindable<Bool>
    private var controlId: String
    private var frame = Rect.zero()

    public init(label: String, checked: Bindable<Bool>) {
        this.label = label
        this.checked = checked
        this.controlId = controlIdentity("Switch:${label}")
        emit(this)
    }

    /** Sets an explicit focus and press identity; defaults are unique per build. */
    public func id(value: String): Switch {
        validateControlId(value, "Switch")
        controlId = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, SWITCH_TRACK_W + 12.0 + ctx.renderer.textWidth(label)), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let track = Rect(frame.x, frame.centerY() - SWITCH_TRACK_H / 2.0, SWITCH_TRACK_W, SWITCH_TRACK_H)
        let trackColor = if (checked.value) {
            ctx.theme.accent
        } else {
            ctx.theme.panelEdge
        }
        ctx.renderer.fillRoundedRect(track, SWITCH_TRACK_H / 2.0, trackColor)
        let knobX = if (checked.value) {
            track.right() - 11.0
        } else {
            track.x + 11.0
        }
        ctx.renderer.fillCircle(knobX, track.centerY() + 1.0, 8.5, ctx.theme.shadow.withAlpha(28))
        ctx.renderer.fillCircle(knobX, track.centerY(), 8.0, ctx.theme.panelRaised)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, track.right() + 12.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        toggleInteraction(ctx, event, frame, controlId, {=> checked.value = !checked.value})
    }
}

/** One option in a mutually exclusive integer-valued selection group. */
public class RadioButton <: Widget {
    private let label: String
    private let selected: Bindable<Int64>
    private let optionValue: Int64
    private var controlId: String
    private var frame = Rect.zero()

    public init(label: String, selected: Bindable<Int64>, value: Int64) {
        this.label = label
        this.selected = selected
        this.optionValue = value
        this.controlId = controlIdentity("RadioButton:${label}:${value}")
        emit(this)
    }

    /** Sets an explicit focus and press identity; defaults are unique per build. */
    public func id(value: String): RadioButton {
        validateControlId(value, "RadioButton")
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
        let centerX = frame.x + 9.0
        let centerY = frame.centerY()
        ctx.renderer.fillCircle(centerX, centerY, 9.0, ctx.theme.field)
        ctx.renderer.strokeCircle(centerX, centerY, 8.5, Pen(width: 1.5, color: if (isSelected()) {
            ctx.theme.accent
        } else {
            ctx.theme.panelEdge
        }), segments: 32)
        if (isSelected()) {
            ctx.renderer.fillCircle(centerX, centerY, 4.5, ctx.theme.accent)
        }
        let textY = centerY - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, frame.x + 26.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        toggleInteraction(ctx, event, frame, controlId, {=> selected.value = optionValue})
    }

    private func isSelected(): Bool {
        selected.value == optionValue
    }
}

/** A compact previous/next picker for a finite string collection. */
public class Picker <: Widget {
    private let id: String
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private var frame = Rect.zero()

    public init(id: String, items: Array<String>, selected: Bindable<Int64>) {
        validateControlId(id, "Picker")
        this.id = id
        this.items = items
        this.selected = selected
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, PICKER_DEFAULT_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.hasFocus(id)))
        let label = if (items.isEmpty()) {
            "—"
        } else {
            items[currentIndex()]
        }
        // Item text comes from application data; clip it so a long item cannot paint
        // over the chevrons or escape the control surface.
        let labelArea = Rect(frame.x + 34.0, frame.y, max(0.0, frame.w - 68.0), frame.h)
        ctx.renderer.pushClip(labelArea)
        ctx.renderer.textCenter(label, labelArea, ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
        ctx.renderer.textCenter("‹", leftButton(), ctx.theme.mutedText, pointSize: FontSizes.TITLE)
        ctx.renderer.textCenter("›", rightButton(), ctx.theme.mutedText, pointSize: FontSizes.TITLE)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    if (leftButton().contains(x, y)) {
                        move(-1)
                    } else if (rightButton().contains(x, y)) {
                        move(1)
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    move(-1)
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    move(1)
                    return true
                }
            case _ => ()
        }
        false
    }

    private func move(delta: Int64): Unit {
        if (items.isEmpty()) {
            return
        }
        selected.value = (currentIndex() + delta + items.size) % items.size
    }

    private func currentIndex(): Int64 {
        clampControlIndex(selected.value, items.size)
    }

    private func leftButton(): Rect {
        Rect(frame.x, frame.y, min(34.0, frame.w), frame.h)
    }

    private func rightButton(): Rect {
        Rect(max(frame.x, frame.right() - 34.0), frame.y, min(34.0, frame.w), frame.h)
    }
}

/** An integer value editor with decrement/increment buttons and keyboard support. */
public class Stepper <: Widget {
    private let id: String
    private let value: Bindable<Int64>
    private var lowerBound: Int64 = Int64.Min
    private var upperBound: Int64 = Int64.Max
    private var stepSize: Int64 = 1
    private var frame = Rect.zero()

    public init(id: String, value: Bindable<Int64>) {
        validateControlId(id, "Stepper")
        this.id = id
        this.value = value
        emit(this)
    }

    /** Sets the inclusive range and immediately clamps the current value. */
    public func range(lower: Int64, upper: Int64): Stepper {
        lowerBound = min(lower, upper)
        upperBound = max(lower, upper)
        value.value = clampInt(value.value)
        this
    }

    /** Sets a positive increment. Throws `IllegalArgumentException` for non-positive values. */
    public func step(value: Int64): Stepper {
        if (value <= 0) {
            throw IllegalArgumentException("Stepper step must be greater than zero")
        }
        stepSize = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, STEPPER_DEFAULT_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.hasFocus(id)))
        ctx.renderer.textCenter("−", decrementButton(), ctx.theme.text, pointSize: FontSizes.TITLE)
        ctx.renderer.textCenter("${value.value}", valueFrame(), ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.textCenter("+", incrementButton(), ctx.theme.text, pointSize: FontSizes.TITLE)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    if (decrementButton().contains(x, y)) {
                        decrement()
                    } else if (incrementButton().contains(x, y)) {
                        increment()
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    decrement()
                    return true
                }
            case UiEvent.KeyDown(Key.Down, _) =>
                if (ctx.hasFocus(id)) {
                    decrement()
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    increment()
                    return true
                }
            case UiEvent.KeyDown(Key.Up, _) =>
                if (ctx.hasFocus(id)) {
                    increment()
                    return true
                }
            case _ => ()
        }
        false
    }

    private func decrement(): Unit {
        value.value = clampInt(if (value.value < lowerBound + stepSize) {
            lowerBound
        } else {
            value.value - stepSize
        })
    }

    private func increment(): Unit {
        value.value = clampInt(if (value.value > upperBound - stepSize) {
            upperBound
        } else {
            value.value + stepSize
        })
    }

    private func clampInt(candidate: Int64): Int64 {
        min(upperBound, max(lowerBound, candidate))
    }

    private func decrementButton(): Rect {
        Rect(frame.x, frame.y, min(36.0, frame.w), frame.h)
    }

    private func incrementButton(): Rect {
        Rect(max(frame.x, frame.right() - 36.0), frame.y, min(36.0, frame.w), frame.h)
    }

    private func valueFrame(): Rect {
        Rect(frame.x + 36.0, frame.y, max(0.0, frame.w - 72.0), frame.h)
    }
}

private func toggleInteraction(
    ctx: UiContext,
    event: UiEvent,
    frame: Rect,
    id: String,
    activate: () -> Unit
): Bool {
    match (event) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            if (frame.contains(x, y)) {
                ctx.focus(id)
                ctx.press(id)
                return true
            }
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            if (ctx.isPressed(id)) {
                if (frame.contains(x, y)) {
                    activate()
                }
                return true
            }
        case UiEvent.KeyDown(Key.Enter, _) =>
            if (ctx.hasFocus(id)) {
                activate()
                return true
            }
        case UiEvent.KeyDown(Key.Space, _) =>
            if (ctx.hasFocus(id)) {
                activate()
                return true
            }
        case _ => ()
    }
    false
}

/** Throws `IllegalArgumentException` when a focusable control receives an empty ID. */
private func validateControlId(id: String, kind: String): Unit {
    if (id.isEmpty()) {
        throw IllegalArgumentException("${kind} id must not be empty")
    }
}

private func clampControlIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0 || index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
