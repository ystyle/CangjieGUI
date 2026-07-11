# CUI API 参考

本文档描述由 `cui` 根包重新导出的 GUI API。几何、窗口、渲染器、输入、对话框和系统 API 同样可
通过 `cui` 使用，但其完整定义统一记录在 [SDL API 参考](../sdl/docs/api-reference.md)。

## 导入约定

推荐显式导入所需成员：

```cangjie
import cui.{Button, DesktopApp, Insets, Label, State, VStack, WindowSpec}
```

## 核心协议与状态

### `Widget`

所有控件的行为协议：

| 方法 | 说明 |
|---|---|
| `measure(ctx, available): Size` | 在可用空间内计算期望尺寸 |
| `layout(ctx, rect): Unit` | 接收最终布局矩形 |
| `draw(ctx): Unit` | 使用上下文渲染器绘制 |
| `handle(ctx, event): Bool` | 处理事件；返回是否消费 |
| `isFlexible(): Bool` | 是否参与剩余空间分配，默认 `false` |
| `flexWeight(): Float32` | 弹性空间权重，默认 `1.0` |

### `State<T>`

`State(value)` 创建跨帧状态，公开可变成员为 `value: T`。

### `UiContext`

提供 `renderer`、`theme`、焦点 ID、拖动 ID、鼠标状态、关闭标志和当前 `FrameInfo`。主要方法：
`requestClose`、`hasFocus`、`focus`、`beginDrag`、`isDragging`、`clearDrag`。

### 基础枚举

- `Axis`：`Horizontal`、`Vertical`。
- `ButtonRole`：`Normal`、`Primary`、`Danger`。
- `TextAlign`：`Leading`、`Center`、`Trailing`。

## 主题

### `Theme`

包含 `bg`、`panel`、`panelEdge`、`text`、`mutedText`、`accent`、`accentText`、`danger`、
`field`、`fieldActive`、`panelRaised`、`accentSoft`、`shadow`、各级圆角和边框宽度。

| API | 说明 |
|---|---|
| `Theme.light(): Theme` | 默认浅色主题 |
| `Theme.dark(): Theme` | 默认深色主题 |
| `panelSurface()` | 普通面板样式 |
| `raisedSurface()` | 浮起面板样式 |
| `fieldSurface(active)` | 普通或激活输入区域样式 |
| `buttonSurface(role)` | 按按钮角色生成样式 |
| `selectedSurface()` | 已选中项目样式 |

## 布局与容器

| 类型 | 构造参数 | 说明 |
|---|---|---|
| `VStack` | `spacing=8`、`padding=0`、`flexible=true`、`body` | 纵向排列构建块中的子项 |
| `HStack` | 同上 | 横向排列构建块中的子项 |
| `Flexible` | `weight=1`、`body` | 按权重占用父栈剩余空间 |
| `Panel` | `padding=12`、`style=None`、`flexible=true`、`body` | 带表面和内边距的容器 |
| `Spacer` | 无 | 弹性空白区域 |

`emit(widget)` 将已有 Widget 实例登记到当前构建块；不在构建块中调用时不产生效果。

## 基础控件

### `Label`

```cangjie
Label(text, muted: false, align: TextAlign.Leading, color: None, fontSize: FontSizes.BODY)
```

### `Button`

```cangjie
Button(title, onClick, role: ButtonRole.Normal, style: None, fontSize: FontSizes.CONTROL)
```

### 图标与分隔线

| 类型 | 构造参数 |
|---|---|
| `Icon` | `icon`、`size=20`、`color=None` |
| `IconButton` | `icon`、`label=None`、`role=Normal`、`style=None`、`onClick` |
| `Divider` | `axis=Horizontal`、`color=None` |

`IconName` 的完整图标集合见 [SDL API 参考](../sdl/docs/api-reference.md#图标与版本)。

## 事件包装器

| 类型 | 构造参数 | 行为 |
|---|---|---|
| `EventHandler` | `onEvent: (UiEvent) -> Bool`、`body` | 在子树处理前截获事件 |
| `FrameHandler` | `onFrame: (FrameInfo) -> Unit`、`body` | 每帧执行回调 |

二者均把构建块包装成单个 Widget，并继承子项的弹性行为。

## 控件包 `cui.controls`

| 类型 | 构造函数 | 状态/行为 |
|---|---|---|
| `Checkbox` | `Checkbox(label, checked: State<Bool>)` | 点击切换布尔状态 |
| `ListView` | `ListView(items, selected, scroll: ?State<Float32> = None)` | 可滚动列表和选中索引 |
| `SegmentedControl` | `SegmentedControl(items, selected)` | 分段单选 |
| `TabView` | `TabView(labels, selected, body)` | 标签页；body 按顺序声明页面 |
| `ProgressBar` | `ProgressBar(value, lower=0, upper=1)` | 只读进度显示 |
| `Slider` | `Slider(id, value, lower=0, upper=1)` | 鼠标和键盘可操作滑块 |

`selected` 使用 `State<Int64>`，`value` 使用 `State<Float32>`。当上下界相等或输入越界时，控件会
按内部安全范围归一化。

## 文本包 `cui.text`

### `TextField`

`TextField(id, text, cursor: ?State<Int64> = None)`：单行 UTF-8 文本输入。外部 cursor 用于跨帧或
多组件共享光标位置。

### `TextArea`

`TextArea(id, text, scroll=None, cursor=None, editable=true)`：多行、可滚动文本区域。`editable=false`
时保留导航和滚动，忽略编辑操作。

### `TextEditState`

构造方式为 `TextEditState(text, cursor=None)` 或 `TextEditState(value)`。公开方法：

- `normalizeCursor`、`moveTo`：将光标归一化到有效 UTF-8 边界或指定位置。
- `insert`、`backspace`、`deleteForward`：文本修改。
- `moveLeft`、`moveRight`、`moveToStart`、`moveToEnd`：整体导航。
- `moveToLineStart`、`moveToLineEnd`、`moveLineUp`、`moveLineDown`：行导航。

## 媒体包 `cui.media`

### `CanvasWidget`

```cangjie
CanvasWidget(
    onDraw: (Renderer, Rect) -> Unit,
    onEvent: (UiEvent, Rect) -> Bool = {_, _ => false}
)
```

### `ImageView`

`ImageView(path, fit=ImageFit.Contain, preferredWidth=None, preferredHeight=96)`。实现 `Widget` 与
`Resource`，提供 `isClosed` 和 `close`。`ImageFit` 包含 `Stretch`、`Contain`、`Cover`。

## 桌面应用 `DesktopApp`

```cangjie
DesktopApp(
    spec: WindowSpec,
    theme: Theme = Theme.light(),
    frameDelay: UInt32 = 16,
    metadata: ?AppMetadata = None,
    hints: Array<SdlHintSetting> = []
)
```

| 方法 | 说明 |
|---|---|
| `run(body)` | 启动事件循环并逐帧构建根视图，直到关闭 |
| `manage(resource)` | 托管 Resource，退出时逆序关闭 |
| `openFileDialog(options)` | 打开异步文件选择对话框 |
| `saveFileDialog(options)` | 打开异步保存对话框 |
| `openFolderDialog(options)` | 打开异步目录选择对话框 |

## 从 `cui` 重新导出的 SDL API

`cui` 还重新导出以下底层能力，便于 GUI 应用只依赖一个根包：

- 几何与绘制：`Color`、`Point`、`Size`、`Rect`、`Insets`、`Pen`、`Renderer`、`SurfaceStyle`。
- 图像与资源：`Surface`、`Texture`、纹理模式和图像格式。
- 窗口与事件：`WindowSpec`、`SdlWindow`、窗口状态类型、`UiEvent`、`Key`、`MouseButton`。
- 桌面集成：文件对话框、消息框、剪贴板、输入、显示器、路径、文件系统、Hints、时间和系统信息。

这些类型的字段、枚举成员和方法见 [SDL API 参考](../sdl/docs/api-reference.md)。
