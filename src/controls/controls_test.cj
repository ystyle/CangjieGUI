package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{Spacer, State, StateStore, Theme, UiContext, Widget, buildRoot, emit}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func listViewUsesScrollOffsetWhenSelectingRows(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F"], selected, scroll: Some(scroll))

    list.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))

    @Expect(list.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func listViewArrowKeysMoveSelectionAndKeepItVisible(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 90.0))
    ctx.focus("ListView")

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(1))

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(7))
    @Expect(scroll.value > Float32(0.0)) // last row scrolled into view

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(0))
    @Expect(scroll.value, Float32(0.0))

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Up, false))) // clamps at the top
    @Expect(selected.value, Int64(0))
}

@Test
func listViewIgnoresArrowsWithoutFocus(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(3)
    let list = ListView(["A", "B", "C", "D", "E"], selected)
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 200.0))

    @Expect(!list.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(3))
}

// Without an external scroll state, the wheel offset must survive the per-frame rebuild — a
// regression guard for the fresh-State-each-frame bug that made a scrolled list spring back.
@Test
func listViewRetainsScrollAcrossRebuildsWithoutExternalState(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let selected = State<Int64>(0)
    let captured = State<?ListView>(None)
    let build = {
        =>
        let _ = buildRoot({
            =>
            let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected)
            captured.value = Some(list)
        }, store)
    }

    build()
    let first = captured.value.getOrThrow()
    first.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))
    let _ = first.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)) // offset -> 72

    // Next frame: a brand-new ListView instance under the same store must see the retained offset.
    build()
    let second = captured.value.getOrThrow()
    second.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))
    // A click near the top now lands on a scrolled-past row (offset 72 / 28px rows -> index 2),
    // which only holds if the offset carried over rather than resetting to 0.
    @Expect(second.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func listViewScrollbarThumbIsDraggable(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(Array<String>(20, {i => "row ${i}"}), selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    // Grab the thumb in the right-edge lane, then drag it down.
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 195.0, 8.0)))
    ctx.leftMouseDown = true
    @Expect(list.handle(ctx, UiEvent.MouseMove(195.0, 60.0)))
    @Expect(scroll.value > Float32(0.0))
}

@Test
func dropdownOpensThenSelectsAnItemViaTheOverlay(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown("theme", ["浅色", "深色", "跟随系统"], selected)
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    // A click opens it; drawing registers the popup as the interactive overlay.
    @Expect(dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0)))
    dropdown.draw(ctx)
    @Expect(ctx.hasOverlay())

    // The popup sits below the box; y=120 lands on the second row. The overlay consumes the
    // click, selects it and closes.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 120.0)))
    @Expect(selected.value, Int64(1))
    @Expect(!ctx.hasOverlay())
}

@Test
func dropdownDismissesOnOutsideClickAndEscape(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(1)
    let dropdown = Dropdown("d2", ["A", "B", "C"], selected)
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0))) // outside the popup
    @Expect(selected.value, Int64(1)) // unchanged
    @Expect(!ctx.hasOverlay())

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!ctx.hasOverlay())
}

@Test
func dropdownArrowsMoveHighlightWhileOpen(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown("d3", ["A", "B", "C"], selected)
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(1))
    @Expect(ctx.hasOverlay()) // arrows do not close the popup
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)) // clamps at the last item
    @Expect(selected.value, Int64(2))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))
    @Expect(selected.value, Int64(1))
}

@Test
func sliderMouseAndKeyboardEventsUpdateState(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(0.0)
    let slider = Slider("volume", value, lower: 0.0, upper: 10.0)

    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0)))
    @Expect(value.value, Float32(5.0))
    @Expect(ctx.isDragging("volume"))

    ctx.leftMouseDown = true
    @Expect(slider.handle(ctx, UiEvent.MouseMove(108.0, 19.0)))
    @Expect(value.value, Float32(10.0))

    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(9.9))
}

@Test
func segmentedControlSelectsClickedSegment(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let control = SegmentedControl(["One", "Two", "Three"], selected)

    control.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 250.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func switchActivatesOnReleaseAndSupportsKeyboard(): Unit {
    let ctx = controlTestContext()
    let checked = State<Bool>(false)
    let control = Switch("Notifications", checked).id("notifications")
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(!checked.value)
    @Expect(control.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(checked.value)
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(!checked.value)
}

@Test
func radioButtonsShareOneSelectionState(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(1)
    let control = RadioButton("Detailed", selected, 2)
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    let _ = control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0))
    let _ = control.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0))

    @Expect(selected.value, Int64(2))
}

@Test
func pickerWrapsSelectionAndRespondsToArrowKeys(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let picker = Picker("density", ["Compact", "Comfortable", "Spacious"], selected)
    picker.layout(ctx, Rect(0.0, 0.0, 190.0, 38.0))

    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 12.0)))
    @Expect(selected.value, Int64(2))
    @Expect(picker.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(selected.value, Int64(0))
}

@Test
func stepperClampsRangeWithoutIntegerOverflow(): Unit {
    let ctx = controlTestContext()
    let value = State<Int64>(9)
    let stepper = Stepper("quantity", value).range(0, 10).step(3)
    stepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))

    @Expect(stepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 136.0, 12.0)))
    @Expect(value.value, Int64(10))
    @Expect(stepper.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Int64(7))
}

@Test
func tabViewSelectsHeaderWithoutPages(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let tabs = TabView(["First", "Second"], selected) {}

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 120.0))
    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
}

@Test
func tabViewLaysOutIncomingPageOnSwitch(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let second = ControlLayoutProbe()
    let tabs = TabView(["A", "B"], selected) {
        Spacer()
        emit(second)
    }

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    @Expect(second.rect.h, Float32(0.0))

    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
    @Expect(second.rect.h > 0.0)
}

// Clicking a numeric column header sorts by value (not lexically); Home/End then select the
// smallest/largest row by that column, and the selection is stored as the original row index.
@Test
func tableSortsNumericColumnByValue(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0), TableColumn("负载", 80.0, numeric: true)]
    // original indices — 0:"10", 1:"9", 2:"100"; numeric order is 9 < 10 < 100.
    let rows = [["B", "10"], ["A", "9"], ["C", "100"]]
    let table = Table("servers", columns, rows, selected)
    table.layout(ctx, Rect(0.0, 0.0, 200.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0))) // sort by 负载, asc
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1)) // smallest load "9" — lexical sort would pick "10" (index 0)
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(2)) // largest load "100"

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0))) // toggle to desc
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(2)) // largest first
}

// A text sort reorders the display, but the selection follows its row (stored by original index),
// and Up/Down move through the sorted order.
@Test
func tableSelectionFollowsRowAcrossSort(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0) // original row 0 = "B"
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table("names", columns, rows, selected)
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C
    @Expect(selected.value, Int64(0)) // still the "B" row, now at display position 1

    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(2)) // "C"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, Int64(0)) // back to "B"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, Int64(1)) // "A" at the top
}

// A press on a body row selects the row shown there, mapping the display position back through
// the active sort to the original index.
@Test
func tableRowClickSelectsThroughSort(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table("names2", columns, rows, selected)
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C
    // Body starts at y=32 with 28px rows; display pos 0 = "A" (original index 1).
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 40.0)))
    @Expect(selected.value, Int64(1))
    // Display pos 2 = "C" (original index 2).
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 100.0)))
    @Expect(selected.value, Int64(2))
}

// A selection moved from outside the list (e.g. app-level key routing) must still scroll into
// view on the next draw, and a redraw with unchanged selection must not move the scroll (no bounce).
@Test
func listViewRevealsExternallyChangedSelectionOnDraw(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 90.0))

    list.draw(ctx) // reveals the initial selection (0) — stays at the top
    @Expect(scroll.value, Float32(0.0))

    selected.value = 7 // app moved it directly, bypassing the list's own key handling
    list.draw(ctx)
    @Expect(scroll.value > Float32(0.0)) // last row scrolled into view

    let held = scroll.value
    list.draw(ctx) // unchanged selection — must not re-scroll
    @Expect(scroll.value, held)
}

// From no selection (-1), Down must land on the first row, not skip to the second.
@Test
func tableDownFromNoSelectionSelectsFirstRow(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table("names3", columns, rows, selected)
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))
    ctx.focus("names3")

    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(0)) // unsorted display position 0 = original index 0
}

private class ControlLayoutProbe <: Widget {
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
