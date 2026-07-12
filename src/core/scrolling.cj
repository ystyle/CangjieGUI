package cui.core

import sdl.{Rect, clampF32}

internal let CUI_SCROLL_W: Float32 = 6.0
internal let CUI_SCROLL_MARGIN: Float32 = 2.0
internal let CUI_SCROLL_MIN_THUMB_H: Float32 = 18.0
internal let CUI_SCROLL_WHEEL_STEP: Float32 = 72.0

/**
 * Viewport width a scrollable container reserves for the bar once content overflows,
 * so the bar rides in its own lane instead of covering the content's right edge.
 * Module-visible: popup lists (Dropdown/ComboBox) reserve the same lane.
 */
protected func scrollBarGutter(): Float32 {
    CUI_SCROLL_W + CUI_SCROLL_MARGIN * 2.0
}

protected func scrollOffsetAfterWheel(
    current: Float32,
    wheelY: Float32,
    contentH: Float32,
    viewportH: Float32
): Float32 {
    clampF32(current - wheelY * CUI_SCROLL_WHEEL_STEP, 0.0, maxScrollOffset(contentH, viewportH))
}

internal func maxScrollOffset(contentH: Float32, viewportH: Float32): Float32 {
    max(0.0, contentH - viewportH)
}

protected func clampScrollOffset(current: Float32, contentH: Float32, viewportH: Float32): Float32 {
    clampF32(current, 0.0, maxScrollOffset(contentH, viewportH))
}

protected func scrollLineIndex(offset: Float32): Int64 {
    Int64(max(0.0, offset) / CUI_SMALL_H)
}

protected func scrollLineRemainder(offset: Float32): Float32 {
    max(0.0, offset) - Float32(scrollLineIndex(offset)) * CUI_SMALL_H
}

/** The scrollbar track rectangle: a fixed-width lane inset from the frame's right edge. */
internal func scrollBarTrackRect(frame: Rect): Rect {
    Rect(frame.right() - CUI_SCROLL_W - CUI_SCROLL_MARGIN, frame.y + CUI_SCROLL_MARGIN, CUI_SCROLL_W,
        max(0.0, frame.h - CUI_SCROLL_MARGIN * 2.0))
}

/** Thumb length, proportional to how much of the content is visible, with a floor. */
internal func scrollThumbHeight(track: Rect, contentH: Float32, viewportH: Float32): Float32 {
    if (contentH <= 0.0) {
        return track.h
    }
    max(CUI_SCROLL_MIN_THUMB_H, track.h * viewportH / contentH)
}

/** Thumb top for a given scroll offset. */
internal func scrollThumbTop(
    track: Rect,
    thumbH: Float32,
    offset: Float32,
    contentH: Float32,
    viewportH: Float32
): Float32 {
    let maxOffset = maxScrollOffset(contentH, viewportH)
    if (maxOffset <= 0.0) {
        return track.y
    }
    track.y + max(0.0, track.h - thumbH) * clampF32(offset / maxOffset, 0.0, 1.0)
}

/** The thumb rectangle, or `None` when the content fits and no bar is shown. */
internal func scrollThumbRect(frame: Rect, offset: Float32, contentH: Float32, viewportH: Float32): ?Rect {
    if (contentH <= viewportH || frame.h <= 0.0) {
        return None
    }
    let track = scrollBarTrackRect(frame)
    let thumbH = scrollThumbHeight(track, contentH, viewportH)
    Some(Rect(track.x, scrollThumbTop(track, thumbH, offset, contentH, viewportH), track.w, thumbH))
}

/** Inverse of `scrollThumbTop`: maps a dragged thumb top back to a scroll offset. */
internal func scrollOffsetForThumbTop(
    thumbTop: Float32,
    track: Rect,
    thumbH: Float32,
    contentH: Float32,
    viewportH: Float32
): Float32 {
    let scrollableTrack = max(0.0, track.h - thumbH)
    if (scrollableTrack <= 0.0) {
        return 0.0
    }
    clampF32((thumbTop - track.y) / scrollableTrack, 0.0, 1.0) * maxScrollOffset(contentH, viewportH)
}

/*
 * Shared thumb-drag controller for any vertical scroll surface. A widget owns one keyed by
 * a stable drag id and forwards its bar presses and moves here, so ScrollView, ListView and
 * TextArea get identical draggable-thumb and track-paging behavior from one implementation.
 */
public class ScrollBar {
    private let dragId: String
    private var grabDy: Float32 = 0.0

    public init(dragId: String) {
        this.dragId = dragId
    }

    /** Whether the thumb is being dragged right now (drives the active highlight). */
    public func dragging(ctx: UiContext): Bool {
        ctx.isDragging(dragId)
    }

    /*
     * Consumes a primary press on the bar: grabs the thumb (recording the grab point so the
     * drag tracks the pointer without jumping) or pages the view when the track is clicked
     * beside the thumb. Returns whether the press belonged to the bar.
     */
    public func press(
        ctx: UiContext,
        frame: Rect,
        offset: State<Float32>,
        contentH: Float32,
        viewportH: Float32,
        x: Float32,
        y: Float32
    ): Bool {
        match (scrollThumbRect(frame, offset.value, contentH, viewportH)) {
            case Some(thumb) =>
                if (thumb.contains(x, y)) {
                    ctx.beginDrag(dragId)
                    grabDy = y - thumb.y
                    return true
                }
                if (scrollBarTrackRect(frame).contains(x, y)) {
                    let direction: Float32 = if (y < thumb.y) {
                        -1.0
                    } else {
                        1.0
                    }
                    offset.value = clampScrollOffset(offset.value + direction * viewportH * Float32(0.9), contentH,
                        viewportH)
                    return true
                }
                false
            case None => false
        }
    }

    /** Continues an in-progress thumb drag, mapping the pointer to a scroll offset. */
    public func drag(
        ctx: UiContext,
        frame: Rect,
        offset: State<Float32>,
        contentH: Float32,
        viewportH: Float32,
        y: Float32
    ): Bool {
        if (ctx.isDragging(dragId) && ctx.leftMouseDown) {
            let track = scrollBarTrackRect(frame)
            let thumbH = scrollThumbHeight(track, contentH, viewportH)
            offset.value = scrollOffsetForThumbTop(y - grabDy, track, thumbH, contentH, viewportH)
            return true
        }
        false
    }
}

protected func drawVerticalScrollBar(
    ctx: UiContext,
    frame: Rect,
    offset: Float32,
    contentH: Float32,
    viewportH: Float32,
    active!: Bool = false
): Unit {
    if (contentH <= viewportH || frame.h <= 0.0) {
        return
    }
    let track = scrollBarTrackRect(frame)
    let thumbH = scrollThumbHeight(track, contentH, viewportH)
    let thumbTop = scrollThumbTop(track, thumbH, offset, contentH, viewportH)
    ctx.renderer.fill(track, ctx.theme.panelEdge.withAlpha(80))
    let thumbAlpha = if (active) {
        230
    } else {
        180
    }
    ctx.renderer.fill(Rect(track.x, thumbTop, track.w, thumbH), ctx.theme.accent.withAlpha(thumbAlpha))
}
