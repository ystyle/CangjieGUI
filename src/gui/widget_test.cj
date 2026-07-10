package cui.gui

import cui.sdl.{Color, FrameInfo, IconName, Insets, Key, MouseButton, Rect, Renderer, Size, SurfaceStyle, UiEvent}

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
    let view = VStack(padding: Insets(2.0)) {
        Label("Title")
        HStack(spacing: 0.0) {
            Button("Run", {=> pressed.value = true})
            Spacer()
        }
    }

    view.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 34.0)))
    @Expect(pressed.value)
}

@Test
func panelSupportsStyledTrailingLambdaContent(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let panel = Panel(
        padding: Insets(6.0),
        style: Some(SurfaceStyle(Color.rgb(250, 250, 250), border: Color.rgb(120, 130, 140), radius: 10.0))
    ) {
        Button("Go", {=> pressed.value = true})
    }

    panel.layout(ctx, Rect(0.0, 0.0, 120.0, 60.0))

    @Expect(panel.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
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
    @Expect(pressed.value)
}

@Test
func tickDeltaGuardsAgainstClockReset(): Unit {
    @Expect(tickDelta(UInt64(10), UInt64(25)), UInt64(15))
    @Expect(tickDelta(UInt64(25), UInt64(10)), UInt64(0))
}

@Test
func scrollWheelClampsOffsetWithinContent(): Unit {
    @Expect(scrollOffsetAfterWheel(0.0, -1.0, 240.0, 96.0), Float32(72.0))
    @Expect(scrollOffsetAfterWheel(140.0, -1.0, 240.0, 96.0), Float32(144.0))
    @Expect(scrollOffsetAfterWheel(20.0, 1.0, 240.0, 96.0), Float32(0.0))
}

@Test
func textAreaWheelUpdatesSharedScrollState(): Unit {
    let ctx = testContext()
    let text = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight")
    let scroll = State<Float32>(0.0)
    let area = TextArea("notes", text, scroll: Some(scroll))

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))

    @Expect(area.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
}

@Test
func listViewUsesScrollOffsetWhenSelectingRows(): Unit {
    let ctx = testContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F"], selected, scroll: Some(scroll))

    list.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))

    @Expect(list.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(3))
}

@Test
func sliderMouseAndKeyboardEventsUpdateState(): Unit {
    let ctx = testContext()
    let value = State<Float32>(0.0)
    let slider = Slider("volume", value, lower: 0.0, upper: 10.0)

    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 34.0))
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 17.0)))
    @Expect(value.value, Float32(5.0))
    @Expect(ctx.isDragging("volume"))

    ctx.leftMouseDown = true
    @Expect(slider.handle(ctx, UiEvent.MouseMove(108.0, 17.0)))
    @Expect(value.value, Float32(10.0))

    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(9.9))
}

@Test
func segmentedControlSelectsClickedSegment(): Unit {
    let ctx = testContext()
    let selected = State<Int64>(0)
    let control = SegmentedControl(["One", "Two", "Three"], selected)

    control.layout(ctx, Rect(0.0, 0.0, 300.0, 34.0))
    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 250.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func tabViewSelectsHeaderWithoutPages(): Unit {
    let ctx = testContext()
    let selected = State<Int64>(0)
    let tabs = TabView(["First", "Second"], selected) {}

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 120.0))
    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
}

@Test
func imageViewMeasuresAndClosesWithoutLoadingTexture(): Unit {
    let ctx = testContext()
    let image = ImageView("missing.bmp", preferredHeight: 96.0)

    let measured = image.measure(ctx, Size(240.0, 40.0))
    image.close()
    image.close()

    @Expect(measured.w, Float32(240.0))
    @Expect(measured.h, Float32(40.0))
    @Expect(image.isClosed())
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

@Test
func flexibleWeightSpansColumnsExactly(): Unit {
    let ctx = testContext()
    let zero = LayoutProbe()
    let dot = LayoutProbe()
    let equals = LayoutProbe()
    let row = HStack(spacing: 10.0) {
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
    let uniform = HStack(spacing: 10.0) {
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
    let weighted = HStack(spacing: 10.0) {
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

@Test
func tabViewLaysOutIncomingPageOnSwitch(): Unit {
    let ctx = testContext()
    let selected = State<Int64>(0)
    let second = LayoutProbe()
    let tabs = TabView(["A", "B"], selected) {
        Spacer()
        emit(second)
    }

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    @Expect(second.rect.h, Float32(0.0))

    // Clicking the second tab switches pages mid-frame; the incoming page must be laid
    // out immediately so later draw/handle calls never see a stale frame.
    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
    @Expect(second.rect.h > 0.0)
}
