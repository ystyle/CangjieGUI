package cui.text

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func comboTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    ctx
}

// Clicking the chevron opens the suggestion list (an interactive overlay); clicking a row fills
// the bound text with that suggestion and closes.
@Test
func comboBoxChevronOpensAndClickSelects(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("")
    let combo = ComboBox("city", text, ["北京", "上海", "广州", "深圳"])
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))

    // The chevron occupies the right ~30px; a press there opens the list.
    @Expect(combo.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 19.0)))
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    // Popup opens just below the field; rows are 28px tall from y=47. Row 1 ("上海") spans [75,103).
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 60.0, 85.0)))
    @Expect(text.value, "上海")
    @Expect(!ctx.hasOverlay())
}

// Typed text filters the list; Enter commits the highlighted (only) match.
@Test
func comboBoxFiltersAndEnterCommits(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("")
    let combo = ComboBox("city2", text, ["北京", "上海", "广州", "深圳"])
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))
    ctx.focus("city2")

    @Expect(combo.handle(ctx, UiEvent.KeyDown(Key.Down, false))) // Down opens when focused
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    text.value = "州" // as if typed — only 广州 matches
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(text.value, "广州")
    @Expect(!ctx.hasOverlay())
}

// Escape closes without changing the typed text.
@Test
func comboBoxEscapeKeepsText(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("自定义值")
    let combo = ComboBox("c3", text, ["one", "two"])
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))

    let _ = combo.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 19.0))
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(text.value, "自定义值") // freely typed value is kept
    @Expect(!ctx.hasOverlay())
}
