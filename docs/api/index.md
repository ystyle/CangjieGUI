# cui

仓颉（Cangjie）桌面 GUI 框架，运行在 SDL3 之上。应用用尾随 lambda 写出界面树；状态变化或输入到来时重新构建并绘制界面，空闲时跳过绘制。框架提供布局容器、四十余个控件、可观察状态与双向绑定、弹簧/补间动画、浅色/深色主题、焦点/悬停/浮层处理，以及负责窗口和帧循环的桌面应用对象。全部坐标都使用逻辑像素。

模块在 `cjpm.toml` 中按路径依赖引入（示例）：

```toml
[dependencies]
cui = { path = "../cui" }
```

底层 sdl 模块（窗口、渲染器、事件、几何/颜色类型）随依赖自动引入；伞包 `cui` 把两层符号全部再导出，应用只需 `import cui.*`。

## 快速示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("计数器", 360, 240))
    app.run {
        let count = rememberState<Int64>("计数") {0}
        VStack(spacing: 12.vp) {
            Label("已点击 ${count.value} 次")
            Button("加一", {=> count.value = count.value + 1})
        }
    }
}
```

## 使用指南

本目录是按包、类型和成员组织的精确 API 参考。若要从第一个窗口开始系统学习、理解状态和布局，再完成表单、列表与桌面交互任务，请转到独立的 [CUI 使用指南](../guide/index.md)。

## 包

| 包 | 说明 |
|---|---|
| [`cui`](cui/index.md) | 统一导入入口：重新导出 sdl 与全部 CUI 子包的公开符号。 |
| [`cui.core`](cui/core/index.md) | UI 核心：组件与修饰器、布局、基础控件、状态、动画、主题、每帧上下文、浮层和焦点。 |
| [`cui.controls`](cui/controls/index.md) | 成品控件库：选择与数值输入、下拉与菜单、导航、数据展示、模态、Toast、折叠面板、分栏与可重排列表。 |
| [`cui.text`](cui/text/index.md) | 文本编辑控件：单行 TextField、多行 TextArea、带建议的 ComboBox 与共享编辑模型 TextEditState。 |
| [`cui.media`](cui/media/index.md) | 图像与自绘：文件图像视图 ImageView（进程级纹理缓存）与自由绘制表面 CanvasWidget。 |
| [`cui.desktop`](cui/desktop/index.md) | 桌面应用对象：DesktopApp 拥有窗口与渲染循环，驱动构建-布局-绘制-事件分发。 |

## 文档信息

- 记录 cui 0.2.0（`cui/cjpm.toml`），生成日期 2026-07-20。
- 文档语言为简体中文；标识符、签名与代码保持源语言原样。
- 运行示例可执行文件需把 `sdl/.sdl3`（SDL3.dll / SDL3_ttf.dll）加入 PATH；编译无须额外配置。
- [验证报告](_verification.md)
