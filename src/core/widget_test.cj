package cui.core

import sdl.{Color, FrameInfo, IconName, MouseButton, Rect, Renderer, Size, SurfaceStyle, UiEvent}

internal func testContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func uiContextTracksFocusAndDrag(): Unit {
    let ctx = testContext()

    ctx.focus("input")
    ctx.beginDrag("slider")

    @Expect(ctx.hasFocus("input"))
    @Expect(ctx.isDragging("slider"))

    ctx.clearDrag()
    @Expect(!ctx.isDragging("slider"))
}

@Test
func stateTracksRevisionAndCancellableObservers(): Unit {
    let state = State<Int64>(2)
    let observedTotal = State<Int64>(0)
    let observation = state.observe({previous, current => observedTotal.value += previous + current})

    state.update({value => value + 3})

    @Expect(state.value, Int64(5))
    @Expect(state.revision, UInt64(1))
    @Expect(observedTotal.value, Int64(7))

    observation.close()
    state.value = 9
    @Expect(observedTotal.value, Int64(7))
    @Expect(observation.isClosed())
}

@Test
func rememberedStateSurvivesRebuildAndResetsAfterUnmount(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)

    let _ = buildRoot(
        {
            =>
                let local = rememberState<Int64>("count") {1}
                captured.value = Some(local)
                Spacer()
        },
        store
    )
    let first = captured.value.getOrThrow()
    first.value = 42

    let _ = buildRoot(
        {
            =>
                captured.value = Some(rememberState<Int64>("count") {1})
                Spacer()
        },
        store
    )
    let second = captured.value.getOrThrow()
    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow()))
    @Expect(second.value, Int64(42))

    let _ = buildRoot({=> Spacer()}, store)
    let _ = buildRoot(
        {
            =>
                captured.value = Some(rememberState<Int64>("count") {7})
                Spacer()
        },
        store
    )
    let third = captured.value.getOrThrow()
    @Expect(!refEq((first as Object).getOrThrow(), (third as Object).getOrThrow()))
    @Expect(third.value, Int64(7))
}

@Test
func keyedScopesIsolateRepeatedLocalStateNames(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)

    let _ = buildRoot({
        => VStack {
            Keyed("first") {
                first.value = Some(rememberState<Int64>("selected") {1})
                Spacer()
            }
            Keyed("second") {
                second.value = Some(rememberState<Int64>("selected") {2})
                Spacer()
            }
        }
    }, store)

    @Expect(first.value.getOrThrow().value, Int64(1))
    @Expect(second.value.getOrThrow().value, Int64(2))
}

@Test
func frameHandlerReceivesFrameInfo(): Unit {
    let ctx = testContext()
    let count = State<Int64>(0)
    let handler = FrameHandler(onFrame: {
        info => if (info.deltaMs == UInt64(16)) {
            count.value += 1
        }
    }) {
        Spacer()
    }

    @Expect(!handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(100), UInt64(16)))))
    @Expect(count.value, Int64(1))
}

@Test
func stackBroadcastsFrameEventsToAllChildren(): Unit {
    let ctx = testContext()
    let first = State<Int64>(0)
    let second = State<Int64>(0)
    let stack = VStack {
        FrameHandler(onFrame: {_ => first.value += 1}) {
            Spacer()
        }
        FrameHandler(onFrame: {_ => second.value += 1}) {
            Spacer()
        }
    }

    @Expect(!stack.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(100), UInt64(16)))))
    @Expect(first.value, Int64(1))
    @Expect(second.value, Int64(1))
}

@Test
func stackBuildersSupportTrailingLambdaSyntax(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let view = VStack(padding: LengthInsets(2.vp)) {
        Label("Title")
        HStack(spacing: 0.vp) {
            Button("Run", {=> pressed.value = true})
            Spacer()
        }
    }

    view.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 44.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 44.0)))
    @Expect(pressed.value)
}

@Test
func panelSupportsStyledTrailingLambdaContent(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let panel = Panel(
        padding: LengthInsets(6.vp),
        style: Some(SurfaceStyle(Color.rgb(250, 250, 250), border: Color.rgb(120, 130, 140), radius: 10.0))
    ) {
        Button("Go", {=> pressed.value = true})
    }

    panel.layout(ctx, Rect(0.0, 0.0, 120.0, 60.0))

    @Expect(panel.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(panel.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

@Test
func iconButtonSupportsTrailingLambdaAction(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let button = IconButton(IconName.Save, label: Some("Save"), role: ButtonRole.Primary) {
        => pressed.value = true
    }

    button.layout(ctx, Rect(0.0, 0.0, 100.0, 34.0))

    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

/*
 * Regression: two icon-only buttons in one row used to share the "IconButton" identity.
 * The later button then swallowed the release meant for the earlier one, so a calendar's
 * previous-month chevron never fired. Build-order identities keep them separate.
 */
@Test
func iconOnlyButtonsInOneRowKeepSeparatePressIdentity(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let leftClicks = State<Int64>(0)
    let rightClicks = State<Int64>(0)
    let view = buildRoot({
        => HStack {
            IconButton(IconName.ChevronLeft) {
                => leftClicks.value += 1
            }
            IconButton(IconName.ChevronRight) {
                => rightClicks.value += 1
            }
        }
    }, store)

    view.layout(ctx, Rect(0.0, 0.0, 200.0, 40.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)))
    @Expect(leftClicks.value, Int64(1))
    @Expect(rightClicks.value, Int64(0))
}

/*
 * Desktop blur convention: a primary press that no control claims clears focus, so a
 * focused text field loses its active style when the user clicks empty space.
 */
@Test
func unclaimedPressClearsFocusAndClaimedPressKeepsIt(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let view = buildRoot({
        => VStack {
            Button("确定", {=> ()})
            Spacer()
        }
    }, store)
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 200.0))

    ctx.beginPointerPress()
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    ctx.settleFocusAfterPress()
    @Expect(ctx.focusId != "")

    ctx.beginPointerPress()
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 150.0))
    ctx.settleFocusAfterPress()
    @Expect(ctx.focusId, "")
}

@Test
func scrollWheelClampsOffsetWithinContent(): Unit {
    @Expect(scrollOffsetAfterWheel(0.0, -1.0, 240.0, 96.0), Float32(72.0))
    @Expect(scrollOffsetAfterWheel(140.0, -1.0, 240.0, 96.0), Float32(144.0))
    @Expect(scrollOffsetAfterWheel(20.0, 1.0, 240.0, 96.0), Float32(0.0))
}

@Test
func eventHandlerConsumesMatchingEvents(): Unit {
    let ctx = testContext()
    let handler = EventHandler(onEvent: {
        event => match (event) {
            case UiEvent.DropFile(path, _, _) => path == "note.txt"
            case _ => false
        }
    }) {
        Spacer()
    }

    @Expect(handler.handle(ctx, UiEvent.DropFile("note.txt", 0.0, 0.0)))
    @Expect(!handler.handle(ctx, UiEvent.DropText("text", 0.0, 0.0)))
}

// Records the rect a stack hands it, so layout math can be asserted directly.
class LayoutProbe <: Widget {
    var rect = Rect.zero()

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

class SizedLayoutProbe <: Widget {
    let desired: Size
    var rect = Rect.zero()

    init(desired: Size) {
        this.desired = desired
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func chainedSizeModifiersReplaceEmittedNode(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(12.0, 12.0))
    let view = VStack {
        emit(child)
        child.width(100.0).height(24.0)
    }

    view.layout(ctx, Rect(0.0, 0.0, 300.0, 80.0))

    @Expect(child.rect.w, Float32(100.0))
    @Expect(child.rect.h, Float32(24.0))
}

@Test
func paddingModifierContributesToMeasuredSize(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(40.0, 20.0))
    let decorated = child.padding(6.0)
    let measured = decorated.measure(ctx, Size(200.0, 100.0))

    @Expect(measured.w, Float32(52.0))
    @Expect(measured.h, Float32(32.0))
}

@Test
func stackAlignmentPositionsContentWithoutConstructorNoise(): Unit {
    let ctx = testContext()
    let child = SizedLayoutProbe(Size(40.0, 20.0))
    let view = VStack {
        emit(child)
    }.mainAxisAlignment(MainAxisAlignment.Center).crossAxisAlignment(CrossAxisAlignment.End)

    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    @Expect(child.rect.x, Float32(160.0))
    @Expect(child.rect.y, Float32(40.0))
    @Expect(child.rect.w, Float32(40.0))
    @Expect(child.rect.h, Float32(20.0))
}

@Test
func gridAssignsEqualColumnsAndContentSizedRows(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(30.0, 20.0))
    let second = SizedLayoutProbe(Size(40.0, 32.0))
    let third = SizedLayoutProbe(Size(50.0, 18.0))
    let grid = Grid(2) {
        emit(first)
        emit(second)
        emit(third)
    }.spacing(10.0)

    grid.layout(ctx, Rect(0.0, 0.0, 210.0, 100.0))

    @Expect(first.rect.w, Float32(100.0))
    @Expect(second.rect.x, Float32(110.0))
    @Expect(first.rect.h, Float32(32.0))
    @Expect(third.rect.y, Float32(42.0))
}

@Test
func flowRowWrapsAtAvailableWidth(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(70.0, 20.0))
    let second = SizedLayoutProbe(Size(70.0, 24.0))
    let third = SizedLayoutProbe(Size(70.0, 18.0))
    let flow = FlowRow {
        emit(first)
        emit(second)
        emit(third)
    }.spacing(8.0)

    flow.layout(ctx, Rect(0.0, 0.0, 150.0, 100.0))

    @Expect(second.rect.x, Float32(78.0))
    @Expect(third.rect.x, Float32(0.0))
    @Expect(third.rect.y, Float32(32.0))
}

@Test
func scrollViewUsesExternalOffsetAndClampsWheelInput(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let child = SizedLayoutProbe(Size(120.0, 240.0))
    let view = ScrollView("audit") {
        emit(child)
    }.scrollState(offset)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 20.0, 20.0)))
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))

    @Expect(offset.value, Float32(72.0))
    @Expect(child.rect.y, Float32(-72.0))
}

@Test
func invisibleWidgetLeavesNoStackGap(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(40.0, 20.0))
    let hidden = SizedLayoutProbe(Size(40.0, 20.0))
    let last = SizedLayoutProbe(Size(40.0, 20.0))
    let view = VStack {
        emit(first)
        emit(hidden)
        hidden.visible(false)
        emit(last)
    }.spacing(10.0).crossAxisAlignment(CrossAxisAlignment.Start)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    @Expect(last.rect.y, Float32(30.0))
    @Expect(hidden.rect.h, Float32(0.0))
}

@Test
func duplicateRememberedStateKeyFailsFast(): Unit {
    let store = StateStore()
    var didThrow = false

    try {
        let _ = buildRoot(
            {
                =>
                    let _ = rememberState<Int64>("duplicate") {1}
                    let _ = rememberState<Int64>("duplicate") {2}
                    Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
}

@Test
func flexibleWeightSpansColumnsExactly(): Unit {
    let ctx = testContext()
    let zero = LayoutProbe()
    let dot = LayoutProbe()
    let equals = LayoutProbe()
    let row = HStack(spacing: 10.vp) {
        Flexible(weight: 2.0) {
            emit(zero)
        }
        Flexible {
            emit(dot)
        }
        Flexible {
            emit(equals)
        }
    }

    row.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))

    // unit = (430 - two gaps - one absorbed gap) / 4 weights = 100; the weight-2 cell
    // spans two units plus the gap between them, exactly two single columns wide.
    @Expect(zero.rect.w, Float32(210.0))
    @Expect(dot.rect.x, Float32(220.0))
    @Expect(dot.rect.w, Float32(100.0))
    @Expect(equals.rect.x, Float32(330.0))
}

@Test
func flexibleWeightRowsAlignWithUniformRows(): Unit {
    let ctx = testContext()
    let third = LayoutProbe()
    let uniform = HStack(spacing: 10.vp) {
        Flexible {
            Spacer()
        }
        Flexible {
            Spacer()
        }
        Flexible {
            emit(third)
        }
        Flexible {
            Spacer()
        }
    }
    let dot = LayoutProbe()
    let weighted = HStack(spacing: 10.vp) {
        Flexible(weight: 2.0) {
            Spacer()
        }
        Flexible {
            emit(dot)
        }
        Flexible {
            Spacer()
        }
    }

    uniform.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))
    weighted.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))

    // The cell after a weight-2 span starts exactly where the third uniform column does.
    @Expect(dot.rect.x, third.rect.x)
    @Expect(dot.rect.w, third.rect.w)
}

// A probe that refuses stretching, so overlay alignment math can be asserted.
class RigidLayoutProbe <: Widget {
    let desired: Size
    var rect = Rect.zero()

    init(desired: Size) {
        this.desired = desired
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }
}

@Test
func scrollViewReservesBarGutterOnlyWhenContentOverflows(): Unit {
    let ctx = testContext()
    let tall = SizedLayoutProbe(Size(300.0, 240.0))
    let overflowing = ScrollView("gutter.tall") {
        emit(tall)
    }
    overflowing.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    // 240 > 80: the bar appears, so content gives up its 10-px gutter (6 + 2 margin each side).
    @Expect(tall.rect.w, Float32(110.0))

    let short = SizedLayoutProbe(Size(300.0, 40.0))
    let fitting = ScrollView("gutter.short") {
        emit(short)
    }
    fitting.layout(ctx, Rect(0.0, 0.0, 120.0, 80.0))
    // 40 <= 80: no bar, content keeps the full viewport width.
    @Expect(short.rect.w, Float32(120.0))
}

@Test
func scrollLineHelpersSplitOffsetIntoIndexAndRemainder(): Unit {
    @Expect(scrollLineIndex(0.0), 0)
    @Expect(scrollLineIndex(28.0), 1)
    @Expect(scrollLineIndex(70.0), 2)
    @Expect(scrollLineRemainder(70.0), Float32(14.0))
    @Expect(scrollLineIndex(-5.0), 0)
    @Expect(scrollLineRemainder(-5.0), Float32(0.0))
}

@Test
func stackSpaceBetweenPinsEndsAndSharesLeftover(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(20.0, 10.0))
    let second = SizedLayoutProbe(Size(20.0, 10.0))
    let third = SizedLayoutProbe(Size(20.0, 10.0))
    let view = HStack {
        emit(first)
        emit(second)
        emit(third)
    }.spacing(0.0).mainAxisAlignment(MainAxisAlignment.SpaceBetween)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))

    @Expect(first.rect.x, Float32(0.0))
    @Expect(second.rect.x, Float32(50.0))
    @Expect(third.rect.x, Float32(100.0))
}

@Test
func stackSpaceEvenlyDistributesAroundChildren(): Unit {
    let ctx = testContext()
    let first = SizedLayoutProbe(Size(20.0, 10.0))
    let second = SizedLayoutProbe(Size(20.0, 10.0))
    let view = HStack {
        emit(first)
        emit(second)
    }.spacing(0.0).mainAxisAlignment(MainAxisAlignment.SpaceEvenly)

    view.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))

    @Expect(first.rect.x, Float32(20.0))
    @Expect(second.rect.x, Float32(60.0))
}

@Test
func zstackPositionsRigidChildByAlignment(): Unit {
    let ctx = testContext()
    let badge = RigidLayoutProbe(Size(20.0, 10.0))
    let banner = RigidLayoutProbe(Size(20.0, 10.0))
    let corner = ZStack {
        emit(badge)
    }.alignment(Alignment.BottomTrailing)
    let center = ZStack {
        emit(banner)
    }

    corner.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    center.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))

    @Expect(badge.rect.x, Float32(80.0))
    @Expect(badge.rect.y, Float32(40.0))
    @Expect(banner.rect.x, Float32(40.0))
    @Expect(banner.rect.y, Float32(20.0))
}

@Test
func forEachKeyedStateFollowsItemAcrossReorder(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)
    let build = {
        items: Array<String> =>
            let _ = buildRoot({
                => VStack {
                    ForEach(items, key: {item => item}) {
                        item =>
                            let local = rememberState<Int64>("count") {0}
                            if (item == "a") {
                                first.value = Some(local)
                            } else {
                                second.value = Some(local)
                            }
                            Spacer()
                    }
                }
            }, store)
    }

    build(["a", "b"])
    first.value.getOrThrow().value = 11
    second.value.getOrThrow().value = 22

    // After a reorder each item still sees its own state, keyed by identity not position.
    build(["b", "a"])
    @Expect(first.value.getOrThrow().value, Int64(11))
    @Expect(second.value.getOrThrow().value, Int64(22))
}
