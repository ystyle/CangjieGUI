/*
 * CUI 示例：专注规划台。
 *
 * 演示内容：
 *  - Keyed 与 rememberState 管理的局部状态
 *  - ScrollView、Grid、FlowRow、ZStack 组合的桌面布局
 *  - DerivedState 派生的进度文本与 maxLines 文本换行
 */
package cui_focus_planner

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = PlannerModel()
    let app = DesktopApp(WindowSpec("CUI 专注规划台", 1120, 720, scale: 1.5), theme: plannerTheme())
    app.setMinimumSize(760, 560)
    app.run {
        plannerView(model)
    }
    return 0
}
