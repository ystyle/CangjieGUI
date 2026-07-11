# CUI 使用指南

## 1. 声明式构建模型

CUI 使用仓颉尾随 Lambda 描述视图树。容器执行构建块时，控件构造函数会将自身登记到当前容器：

```cangjie
VStack(spacing: 10.0) {
    Label("设置")
    HStack {
        Button("保存", save)
        Button("取消", cancel)
    }
}
```

`if`、`match`、`for-in` 和普通函数调用都可直接参与界面构建：

```cangjie
VStack {
    for (name in names) {
        Button(name, {=> selected.value = name})
    }
    if (showDetails.value) {
        Label("详细信息")
    }
}
```

可复用组件通常写成返回 `Unit` 的函数，并在函数体中声明控件。已有控件实例需要重新放入构建树时，
调用 `emit(widget)`。

## 2. 状态与逐帧重建

`State<T>` 是轻量可变状态容器：

```cangjie
let count = State<Int64>(0)

app.run {
    VStack {
        Label("计数：${count.value}")
        Button("增加", {=> count.value += 1})
    }
}
```

根构建闭包每帧重新执行，因此视图会读取最新状态。以下对象应在闭包外创建：

- `State<T>`、文本光标和滚动状态。
- 需要跨帧复用的图像、表面、纹理或自定义模型。
- 后台任务邮箱、互斥锁和并发状态。

不要把耗时 I/O 放入构建闭包；该闭包运行在 UI 线程。

## 3. 布局

### 3.1 栈布局

`VStack` 纵向排列子项，`HStack` 横向排列子项。`spacing` 控制相邻子项间距，`padding` 控制
容器内边距：

```cangjie
VStack(spacing: 12.0, padding: Insets(16.0)) {
    Label("标题")
    HStack(spacing: 8.0) {
        Button("确定", accept)
        Button("取消", cancel)
    }
}
```

容器默认是弹性的，会参与父容器剩余空间分配。设置 `flexible: false` 后按内容尺寸收缩：

```cangjie
VStack {
    Panel(flexible: false) {
        Label("工具栏")
    }
    TextArea("document", document)
}
```

### 3.2 权重布局

`Flexible` 使内容获得剩余空间。权重用于构建等宽网格或跨列单元：

```cangjie
HStack(spacing: 10.0) {
    Flexible(weight: 2.0) { Button("0", onZero) }
    Flexible { Button(".", onDecimal) }
    Flexible { Button("=", onEquals) }
}
```

空的 `Flexible {}` 会保留一个网格单元，可用于日历开头或结尾的占位。

### 3.3 固定与弹性控件

`Label`、`Button`、`Checkbox` 等通常按内容测量；`Spacer`、`TextArea`、`ListView`、`CanvasWidget`、
`TabView` 等默认可填充剩余空间。自定义 Widget 可覆盖 `isFlexible` 和 `flexWeight`。

## 4. 主题与样式

`Theme.light()` 和 `Theme.dark()` 提供完整主题。`Theme` 包含背景、面板、文字、强调色、危险色、
输入区域、阴影、圆角和边框宽度，并可生成常见 `SurfaceStyle`。

控件级样式可覆盖主题：

```cangjie
let warningStyle = SurfaceStyle(
    Color.rgb(255, 244, 229),
    border: Color.rgb(255, 180, 90),
    radius: 10.0,
    borderWidth: 1.0
)

Button("需要确认", confirm, style: Some(warningStyle))
```

标准字号使用 `FontSizes.CAPTION`、`BODY`、`CONTROL`、`TITLE` 和 `DISPLAY`。中文与拉丁文本均由
SDL3_ttf 使用真实字形度量渲染。

## 5. 基础控件

- `Label`：支持弱化文字、对齐、自定义颜色和字号。
- `Button`：支持普通、主操作和危险操作角色，也可指定样式与字号。
- `Icon`、`IconButton`：使用内置矢量图标；图标按钮可同时显示标签。
- `Divider`：水平或垂直分隔线。
- `Panel`：带内边距和表面样式的单子项容器。
- `Spacer`：在栈中占用弹性空间。

## 6. 选择、导航和数值控件

```cangjie
let enabled = State<Bool>(true)
let selected = State<Int64>(0)
let volume = State<Float32>(0.5)

VStack {
    Checkbox("启用", enabled)
    SegmentedControl(["基本", "高级"], selected)
    Slider("volume", volume, lower: 0.0, upper: 1.0)
    ProgressBar(volume)
}
```

`ListView` 支持选中索引和可选外部滚动状态。`TabView` 的构建块应按标签顺序声明页面；切换后会立即
对新页面重新布局。

## 7. 文本输入与编辑

`TextField` 用于单行输入，`TextArea` 用于多行输入和滚动文本：

```cangjie
let title = State<String>("")
let body = State<String>("")
let bodyScroll = State<Float32>(0.0)
let bodyCursor = State<Int64>(0)

VStack {
    TextField("title", title)
    TextArea("body", body, scroll: Some(bodyScroll), cursor: Some(bodyCursor))
}
```

控件 ID 用于焦点和拖动状态，应在同一界面中保持唯一且跨帧稳定。`TextEditState` 提供 UTF-8 安全的
插入、删除、按字符移动、行首行尾和上下行移动。`TextArea(editable: false)` 禁止文本修改，但仍
允许滚动和光标移动，适合日志或命令输出。

## 8. 事件与帧回调

`EventHandler` 包裹一个子树，并在子树处理前接收 `UiEvent`。返回 `true` 表示事件已消费。
`FrameHandler` 每帧接收 `FrameInfo`：

```cangjie
EventHandler(onEvent: {event => handleShortcut(event)}) {
    FrameHandler(onFrame: {frame => updateModel(frame.deltaMs)}) {
        content()
    }
}
```

关闭应用可通过自定义 Widget 的 `UiContext.requestClose()`，或等待窗口 `Quit` 事件由
`DesktopApp` 自动处理。

## 9. 画布、图像和自定义 Widget

`CanvasWidget` 的绘制回调接收 `Renderer` 与已布局的 `Rect`，事件回调接收事件和同一矩形：

```cangjie
CanvasWidget(
    {renderer, rect => renderer.fillCircle(rect.centerX(), rect.centerY(), 24.0, Color.rgb(40, 120, 220))},
    onEvent: {event, rect => handleCanvasEvent(event, rect)}
)
```

`ImageView` 支持 `Stretch`、`Contain`、`Cover` 三种适配策略，并实现 `Resource`。自定义控件需实现
`Widget.measure`、`layout`、`draw`、`handle`，构造函数中调用 `emit(this)` 才能自动加入当前构建块。

## 10. 桌面对话框与资源管理

`DesktopApp.openFileDialog`、`saveFileDialog`、`openFolderDialog` 返回 `FileDialogRequest`。原生文件
对话框是异步的，应在帧回调或构建流程中检查 `result()`，不能同步等待。

实现 `Resource` 的长期对象可交给应用托管：

```cangjie
let image = ImageView("badge.png")
app.manage(image)
```

应用退出时会按逆序关闭托管资源，然后关闭窗口。不要同时让多个所有者关闭同一底层资源。

## 11. 后台任务

UI 线程负责视图构建、事件和绘制。文件扫描、系统命令、网络请求等耗时任务应通过 `spawn` 执行，
把不可变结果写入由 `Mutex` 或并发容器保护的邮箱，再由 `FrameHandler` 每帧读取。具体实现可参考
`examples/process_manager`。

## 12. 快照与视觉验证

`DesktopApp` 识别命令行参数 `--snapshot <path.bmp>`。应用稳定绘制若干帧后调用
`Renderer.captureBmp` 保存快照并退出：

```powershell
cjpm run -- --snapshot output.bmp
```
