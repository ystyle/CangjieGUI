package cui.controls

import sdl.{MouseButton, Rect, Size, UiEvent, clampF32}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_GAP, CursorShape, Spring, UiContext, Widget, buildChildren,
    claimHoverIfInside, controlIdentity, drawSurface, emit, localState}

public class SegmentedControl <: Widget {
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private let controlId: String
    // The selection pill slides between segments. Retained across rebuilds and started at the
    // current selection, so a static first frame is settled (snapshot-stable).
    private let indicatorSpring: Spring
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: Bindable<Int64>) {
        this.items = items
        this.selected = selected
        let cid = controlIdentity("SegmentedControl")
        this.controlId = cid
        let start = Float32(clampIndex(selected.value, items.size))
        this.indicatorSpring = localState<Spring>("${cid}:indicator") {Spring(start)}.value
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        let desired = max(96.0, Float32(items.size) * 96.0)
        Size(min(available.w, desired), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (items.size == 0) {
            return
        }
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))
        let target = Float32(clampIndex(selected.value, items.size))
        drawSlidingSegments(ctx, frame, items, indicatorSpring.animate(target: target, deltaMs: ctx.frame.deltaMs))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y) && items.size > 0) {
                    let segmentW = frame.w / Float32(items.size)
                    selected.value = clampIndex(Int64((x - frame.x) / segmentW), items.size)
                    return true
                }
            case _ => ()
        }
        false
    }
}

public class TabView <: Widget {
    private let labels: Array<String>
    private let selected: Bindable<Int64>
    private let pages: Array<Widget>
    private let controlId: String
    private let indicatorSpring: Spring
    private var frame = Rect.zero()
    private var laidOutPage: Int64 = -1

    public init(labels: Array<String>, selected: Bindable<Int64>, body!: () -> Unit) {
        this.labels = labels
        this.selected = selected
        this.pages = buildChildren(body)
        let cid = controlIdentity("TabView")
        this.controlId = cid
        // The active-tab indicator slides between tabs; started at the current tab so a static
        // first frame is settled (snapshot-stable).
        let start = Float32(clampIndex(selected.value, labels.size))
        this.indicatorSpring = localState<Spring>("${cid}:indicator") {Spring(start)}.value
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        layoutActivePage(ctx)
    }

    public func draw(ctx: UiContext): Unit {
        drawTabs(ctx)
        if (pages.size > 0) {
            ensureActivePageLayout(ctx)
            pages[pageIndex()].draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // Only the tab strip is a click target; pages claim their own hover shapes.
        claimHoverIfInside(ctx, event, Rect(frame.x, frame.y, frame.w, CUI_CONTROL_H), controlId,
            CursorShape.Interactive)
        if (handleTabs(event)) {
            ensureActivePageLayout(ctx)
            return true
        }
        if (pages.size > 0) {
            ensureActivePageLayout(ctx)
            return pages[pageIndex()].handle(ctx, event)
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    private func pageIndex(): Int64 {
        clampIndex(selected.value, pages.size)
    }

    private func layoutActivePage(ctx: UiContext): Unit {
        if (pages.size == 0) {
            return
        }
        let index = pageIndex()
        pages[index].layout(ctx, pageFrame())
        laidOutPage = index
    }

    /*
     * The selected tab can change between a frame's layout pass and its draw/handle
     * passes — a click switches pages mid event drain, or code drives the State. The
     * incoming page is laid out again on demand so it is never drawn or handled with a
     * stale (or never assigned) frame.
     */
    private func ensureActivePageLayout(ctx: UiContext): Unit {
        if (pages.size > 0) {
            if (pageIndex() != laidOutPage) {
                layoutActivePage(ctx)
            }
        }
    }

    private func pageFrame(): Rect {
        Rect(frame.x, frame.y + CUI_CONTROL_H + CUI_GAP, frame.w, max(0.0, frame.h - CUI_CONTROL_H - CUI_GAP))
    }

    private func drawTabs(ctx: UiContext): Unit {
        if (labels.size == 0) {
            return
        }
        let header = Rect(frame.x, frame.y, frame.w, CUI_CONTROL_H)
        drawSurface(ctx, header, ctx.theme.fieldSurface(false))
        let target = Float32(clampIndex(selected.value, labels.size))
        drawSlidingSegments(ctx, header, labels, indicatorSpring.animate(target: target, deltaMs: ctx.frame.deltaMs))
    }

    private func handleTabs(event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let header = Rect(frame.x, frame.y, frame.w, CUI_CONTROL_H)
                if (header.contains(x, y) && labels.size > 0) {
                    let tabW = frame.w / Float32(labels.size)
                    selected.value = clampIndex(Int64((x - frame.x) / tabW), labels.size)
                    return true
                }
            case _ => ()
        }
        false
    }
}

// Draws a segmented row's selection pill and labels, with the pill slid to `animatedIndex` (a
// fractional segment index). The label the pill mostly covers is drawn in the accent-on text
// colour; the pill is clamped to the row so a spring overshoot never escapes the control.
private func drawSlidingSegments(ctx: UiContext, row: Rect, items: Array<String>, animatedIndex: Float32): Unit {
    let count = items.size
    let segmentW = row.w / Float32(count)
    let clamped = clampF32(animatedIndex, 0.0, Float32(count - 1))
    drawSurface(ctx, Rect(row.x + clamped * segmentW, row.y, segmentW, row.h).inset(3.0), ctx.theme.selectedSurface())
    let highlighted = Int64(clamped + 0.5)
    var i: Int64 = 0
    while (i < count) {
        let cell = Rect(row.x + Float32(i) * segmentW, row.y, segmentW, row.h)
        let color = if (i == highlighted) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        ctx.renderer.textCenter(items[i], cell, color)
        i += 1
    }
}

private func clampIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0 || index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
