package cui.gui

import cui.sdl.{Key, Rect, UiEvent}

@Test
func textEditStateInsertsAndDeletesAtUtf8Boundaries(): Unit {
    let edit = TextEditState("a你b")

    edit.moveTo(1)
    edit.moveRight()
    edit.backspace()

    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textEditStateDeleteForwardRemovesWholeRune(): Unit {
    let edit = TextEditState("a你b")

    edit.moveTo(1)
    edit.deleteForward()

    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textEditStateMovesBetweenLinesWithColumn(): Unit {
    let edit = TextEditState("abc\nde\nfghi")

    edit.moveTo(5)
    edit.moveLineDown()
    @Expect(edit.cursor.value, Int64(8))

    edit.moveLineUp()
    edit.moveLineUp()
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textFieldUsesExternalCursorState(): Unit {
    let ctx = testContext()
    let text = State<String>("abc")
    let cursor = State<Int64>(1)
    let field = TextField("field", text, cursor: Some(cursor))

    field.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    ctx.focus("field")

    @Expect(field.handle(ctx, UiEvent.TextInput("X")))
    @Expect(text.value, "aXbc")
    @Expect(cursor.value, Int64(2))

    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(text.value, "Xbc")
    @Expect(cursor.value, Int64(0))
}

@Test
func textAreaReadOnlyStillMovesCursor(): Unit {
    let ctx = testContext()
    let text = State<String>("abc")
    let cursor = State<Int64>(2)
    let area = TextArea("output", text, cursor: Some(cursor), editable: false)

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 80.0))
    ctx.focus("output")

    @Expect(!area.handle(ctx, UiEvent.TextInput("X")))
    @Expect(!area.handle(ctx, UiEvent.KeyDown(Key.Delete, false)))
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(text.value, "abc")
    @Expect(cursor.value, Int64(1))
}
