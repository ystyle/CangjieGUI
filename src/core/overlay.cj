package cui.core

import sdl.UiEvent

/*
 * An interactive overlay — a dropdown or menu popup — that floats above the whole tree. The
 * shell gives it events *before* the tree, so its clicks and keys are not stolen by controls
 * underneath, and paints it *last*, on top. A control registers one during its draw (via
 * `UiContext.setOverlay`) for as long as it is open; the shell clears the slot at the start of
 * each frame, so a control that stops registering (closes) removes the overlay. Contrast the
 * tooltip, which is a simpler draw-only overlay.
 */
public class Overlay {
    private let onEvent: (UiContext, UiEvent) -> Bool
    private let onRender: (UiContext) -> Unit

    public init(handleEvent!: (UiContext, UiEvent) -> Bool, render!: (UiContext) -> Unit) {
        this.onEvent = handleEvent
        this.onRender = render
    }

    func dispatch(ctx: UiContext, event: UiEvent): Bool {
        onEvent(ctx, event)
    }

    func render(ctx: UiContext): Unit {
        onRender(ctx)
    }
}
