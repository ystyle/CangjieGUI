package cui.text

import sdl.{FrameInfo, Rect, Renderer}
import cui.core.{Theme, UiContext}

/*
 * The headless renderer measures text as bytes * pointSize * 0.55, so with BODY = 15
 * every ASCII byte is 8.25 logical pixels wide and a CJK character (3 bytes) is 24.75.
 * That makes measurement-based hit positions exactly assertable.
 */
@Test
func clickMapsToNearestTextBoundaryForAsciiAndCjk(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(0.0, 0.0, 200.0, 38.0)

    // 12px 落在 'a'(8.25) 与 'ab'(16.5) 中点 12.375 之前 → 光标停在字节 1
    @Expect(textFieldCursorForPoint(ctx, frame, "abc", 8.0 + 12.0), 1)
    // 点在整行文字右侧 → 光标到末尾
    @Expect(textFieldCursorForPoint(ctx, frame, "abc", 8.0 + 100.0), 3)
    // CJK：30px 在 '你'(24.75) 与 '你好'(49.5) 中点 37.125 之前 → 第一个字符之后（字节 3）
    @Expect(textFieldCursorForPoint(ctx, frame, "你好", 8.0 + 30.0), 3)
    // 空文本安全返回 0
    @Expect(textFieldCursorForPoint(ctx, frame, "", 8.0 + 10.0), 0)
    // 点击 x 在文本起点左侧 → 光标 0
    @Expect(textFieldCursorForPoint(ctx, frame, "abc", 0.0), 0)
}

@Test
func cursorBlinksInPhaseWithSharedFrameClock(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())

    // 530ms 相位：[0, 530) 可见，[530, 1060) 隐藏，然后循环
    ctx.frame = FrameInfo(UInt64(0), UInt64(0))
    @Expect(textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(529), UInt64(0))
    @Expect(textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(530), UInt64(0))
    @Expect(!textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(1059), UInt64(0))
    @Expect(!textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(1060), UInt64(0))
    @Expect(textCursorVisible(ctx))
}
