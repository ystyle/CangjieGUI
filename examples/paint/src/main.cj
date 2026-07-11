/*
 * CUI 示例：画板。
 *
 * 演示内容：
 *  - CanvasWidget 的自绘与鼠标手势：按下起笔、拖动采样、松开收笔
 *  - 自定义 Widget（ColorSwatch）以四个钩子加入声明式布局
 *  - DerivedState 派生的画笔粗细与笔迹计数文本，随状态自动刷新
 */
package cui_paint

import cui.{Cursor, DesktopApp, SystemCursor, WindowSpec}

main(): Int64 {
    let model = PaintModel()
    let app = DesktopApp(WindowSpec("CUI 画板", 900, 600, scale: 1.5), theme: paintTheme())
    // 低于此尺寸时工具栏会挤掉色板，锁住下限保证控件始终完整可见。
    app.setMinimumSize(640, 480)
    // 画板全程使用十字光标；交给 app 托管，退出时随窗口一并释放。
    let crosshair = Cursor.system(SystemCursor.Crosshair)
    app.manage(crosshair)
    crosshair.setActive()
    app.run {
        paintView(model)
    }
    return 0
}
