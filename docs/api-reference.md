# CUI API 参考

本文记录 `cui` 根包重新导出的 GUI API。几何、渲染、窗口、事件、对话框、输入和系统能力见
[SDL API 参考](../sdl/docs/api-reference.md)。

## 1. 尺寸单位

| 类型/API | 说明 |
|---|---|
| `LengthUnit` | `Px`（物理像素）、`Vp`（虚拟像素）、`Fp`（字体像素）；`symbol()` 返回后缀名 |
| `Length` | 值 + 单位；`Length(value, unit)`、`Length.zero()`、`* Float32`、`/ Float32`、`toString` |
| `LengthUnits` | 字面量后缀接口：导入后 `Int64`/`Float64` 获得 `.px`、`.vp`、`.fp` 属性 |
| `LengthInsets` | 四边长度：`(all)`、`(horizontal, vertical)`、`(top:, right:, bottom:, left:)`、`zero()`、`of(Insets)` |

解析规则（`UiContext.resolve`）：`vp` 原值；`px` 除以 `displayScale`；`fp` 乘以 `fontScale`。
所有接受 `Length` 的修饰器同时提供 `Float32` 重载：尺寸按 `vp` 解释，字号按 `fp` 解释。

## 2. `Widget`

自定义控件实现以下协议：

| 方法 | 默认值/说明 |
|---|---|
| `measure(ctx, available): Size` | 在父级可用空间内返回期望尺寸 |
| `layout(ctx, rect): Unit` | 接收父级确定的最终矩形 |
| `draw(ctx): Unit` | 使用 `UiContext.renderer` 绘制 |
| `handle(ctx, event): Bool` | 返回事件是否已消费 |
| `isFlexible(): Bool` | 默认 `false` |
| `flexWeight(): Float32` | 默认 `1.0` |
| `acceptsStretch(axis): Bool` | 默认 `true`；显式最大/固定尺寸修饰器会拒绝对应轴拉伸 |
| `participatesInLayout(): Bool` | 默认 `true`；`visible(false)` 返回 `false` |

通用链式修饰器均返回 `Widget`（尺寸参数为 `Length`，另有按 vp 解释的 `Float32` 重载）：

| 分类 | API |
|---|---|
| 固定/边界尺寸 | `width`、`height`、`minWidth`、`maxWidth`、`minHeight`、`maxHeight` |
| 填充 | `fillWidth()`、`fillHeight()` |
| 间距 | `padding(all)`、`padding(horizontal, vertical)`、`padding(left, top, right, bottom)` |
| 表面 | `background(color)`、`background(color, radius)`、`surface(style)` |
| 弹性 | `flex()`、`flex(weight)` |
| 条件 | `visible(isVisible)`、`enabled(isEnabled)` |

`emit(widget)` 把已有实例登记到当前构建块；块外调用不产生登记行为。

## 3. 状态与身份

### 可观察接口

| 接口 | 成员 |
|---|---|
| `Observable<T>` | `get(): T`、`revision: UInt64`、`observe((T, T) -> Unit): StateObservation<T>`、`map<U>(transform): DerivedState<U>` |
| `Bindable<T> <: Observable<T>` | `value: T`（可读写属性）、`project<U>(get:, set:): Binding<U>` |

### `State<T>`（实现 `Bindable<T>`）

| API | 说明 |
|---|---|
| `State(value)` | 创建状态 |
| `value: T` | 可读写属性；每次写入增加修订号并同步通知观察者 |
| `revision: UInt64` | 只读修订号，极端溢出时回绕为 0 |
| `update((T) -> T)` | 函数式更新 |
| `observe((T, T) -> Unit): StateObservation<T>` | 观察后续写入；参数为旧值、新值 |
| `setIfChanged(next): Bool` | 仅 `T <: Equatable<T>`；值不同才赋值，返回是否触发通知 |

`StateObservation<T>` 实现 `Resource`，提供 `isClosed`、`close`。

### 派生与绑定

| API | 说明 |
|---|---|
| `derive(a, compute)` / `derive(a, b, compute)` / `derive(a, b, c, compute)` | 从一至三个 `Observable` 计算 `DerivedState<T>` |
| `DerivedState<T>` | 只读、带缓存：仅当来源 `revision` 变化时重新计算；实现 `Observable<T>`，另有 `value` 属性 |
| `Binding<T>` | `project` 产物；实现 `Bindable<T>`，读写均委托给源状态 |

### 局部状态

| API | 说明 |
|---|---|
| `rememberState<T>(key, initial): State<T>` | 在当前构建与身份 scope 中保留状态 |
| `Keyed(key) { ... }` | 为子树建立稳定命名空间 |
| `ForEach(items, key: (T) -> String) { item => ... }` | 每个条目一个 `Keyed` 子树，身份跟随业务键 |
| `ForEachIndexed(items) { index, item => ... }` | 按位置命名的变体，仅适用于不重排的集合 |
| `StateStore.remember` | 显式状态存储访问；重复 key 或 key 换型抛 `IllegalStateException` |
| `StateStore.clear` | 清空全部保留状态 |

`rememberState` 仅能在 `DesktopApp` 根视图构建或框架测试构建中使用；块外调用抛
`IllegalStateException`。空 key 抛 `IllegalArgumentException`。

控件的交互身份（焦点、按压）默认在每次构建中按声明顺序自动唯一化，并受 `Keyed` 命名空间
隔离；`.id(...)` 仅在身份需要跨树形变化保持时使用。

## 4. 上下文与枚举

`UiContext` 公开渲染器、主题、焦点/拖动/按压 ID、鼠标状态、关闭标志、`FrameInfo`，以及
`displayScale`、`fontScale` 两个缩放因子。方法包括：`requestClose`、`hasFocus`、`focus`、
`clearFocus`、`beginDrag`、`isDragging`、`clearDrag`、`press`、`isPressed`、`clearPress`、
`resolve(Length): Float32`、`resolve(LengthInsets): Insets`。

焦点遵循“按下即结算”：一次主键按下后，若没有控件调用 `focus` 认领焦点，当前焦点被清除
（点击空白使文本框失焦）。该结算由 `DesktopApp` 在每次 MouseDown 分发后执行。

| 枚举 | 成员 |
|---|---|
| `Axis` | `Horizontal`、`Vertical` |
| `ButtonRole` | `Normal`、`Primary`、`Danger` |
| `TextAlign` | `Leading`、`Center`、`Trailing` |
| `MainAxisAlignment` | `Start`、`Center`、`End`、`SpaceBetween`、`SpaceAround`、`SpaceEvenly` |
| `CrossAxisAlignment` | `Start`、`Center`、`End`、`Stretch` |
| `Alignment` | 九宫格方向：`TopLeading` 至 `BottomTrailing` |
| `LengthUnit` | `Px`、`Vp`、`Fp` |

## 5. 主题

`Theme` 包含背景、面板、边框、主/次文字、强调、危险、输入区域、阴影与圆角。常用方法：

- `Theme.light()`、`Theme.dark()`。
- `panelSurface()`、`raisedSurface()`。
- `fieldSurface(active)`、`buttonSurface(role)`、`selectedSurface()`。

## 6. 布局与容器

| 类型 | 必要构造信息 | 链式 API/行为 |
|---|---|---|
| `VStack` | `body`（可选 `spacing: Length`、`padding: LengthInsets`） | `spacing`、`mainAxisAlignment`、`crossAxisAlignment`、`flexible` |
| `HStack` | 同上 | 同上 |
| `ZStack` | `body` | `alignment`；后声明的子项绘制在上层 |
| `Grid` | `columns`、`body` | `spacing(all)`、`spacing(horizontal, vertical)`；列数小于 1 抛异常 |
| `FlowRow` | `body` | `spacing`；空间不足自动换行 |
| `ScrollView` | `id`、`body` | 垂直滚动；`scrollState` 接管偏移；溢出时为滚动条预留轨道，不遮挡内容 |
| `Panel` | `body`（可选 `padding: LengthInsets`） | `contentPadding`、`style`、`flexible` |
| `Flexible` | `body` | 兼容的权重包装容器，新代码可用 `.flex` |
| `Spacer` | 无 | 弹性空白 |

## 7. 基础控件

| 类型 | 必要构造信息 | 链式 API |
|---|---|---|
| `Label` | `text` | `muted()`、`muted(bool)`、`textAlign`、`foregroundColor`、`fontSize`、`maxLines(n)`、`wrap()` |
| `Button` | `title`、`onClick` | `id`、`role`、`style`、`fontSize` |
| `Icon` | `IconName` | `iconSize`、`foregroundColor` |
| `IconButton` | `IconName`、`onClick` | `id`、`label`、`role`、`style` |
| `Divider` | 无 | `axis`、`color` |

单行 `Label` 超宽时自动省略号截断；`maxLines(n)` 换行至 n 行（末行截断），`wrap()` 不限行数，
`maxLines` 参数必须大于 0。Button 与 IconButton 在鼠标释放时激活，支持取得焦点后的
Enter/Space，悬停与按压有主题化的视觉反馈。

## 8. 选择、导航和数值控件

交互控件的状态参数为 `Bindable<T>`（可传 `State`、`Binding`），展示控件为 `Observable<T>`。

| 类型 | 构造函数 | 补充 API/行为 |
|---|---|---|
| `Checkbox` | `Checkbox(label, Bindable<Bool>)` | `id`；鼠标释放或 Enter/Space 切换 |
| `Switch` | `Switch(label, Bindable<Bool>)` | `id`；二态开关 |
| `RadioButton` | `RadioButton(label, selected, value)` | `id`；多个实例共享同一 `Bindable<Int64>` |
| `Picker` | `Picker(id, items, selected)` | 点击前后区域或 Left/Right 循环选择 |
| `Stepper` | `Stepper(id, Bindable<Int64>)` | `range(lower, upper)`、`step(value)` |
| `SegmentedControl` | `SegmentedControl(items, selected)` | 分段单选 |
| `TabView` | `TabView(labels, selected) { pages }` | 页面按标签顺序声明 |
| `ListView` | `ListView(items, selected)` | `scrollState`；选中索引和滚轮滚动 |
| `ProgressBar` | `ProgressBar(Observable<Float32>)` | `range(lower, upper)` |
| `Slider` | `Slider(id, Bindable<Float32>)` | `range(lower, upper)`；拖动和 Left/Right |

`Stepper.step` 的值必须大于 0，否则抛 `IllegalArgumentException`。数值控件会安全处理反向范围和
越界输入。

## 9. 文本

| 类型 | 构造函数 | 链式 API/行为 |
|---|---|---|
| `TextField` | `TextField(id, text: Bindable<String>)` | `cursorState`；单行 UTF-8 编辑 |
| `TextArea` | `TextArea(id, text: Bindable<String>)` | `scrollState`、`cursorState`、`editable` |

插入光标与字形行等高、闪烁周期约 1.06 秒；点击定位按真实文本测量落在最近字符边界；
超宽内容裁剪于控件表面内。`TextEditState(text, cursor=None)` 或 `TextEditState(value)` 提供：

- `normalizeCursor`、`moveTo`。
- `insert`、`backspace`、`deleteForward`。
- `moveLeft`、`moveRight`、`moveToStart`、`moveToEnd`。
- `moveToLineStart`、`moveToLineEnd`、`moveLineUp`、`moveLineDown`。

## 10. 媒体与事件包装器

- `CanvasWidget(onDraw).onEvent(handler)`：自定义绘制和事件区域。
- `ImageView(path).fit(ImageFit)`：`Stretch`、`Contain`、`Cover`；实现 `Resource`；
  `preferredWidth`/`preferredHeight` 为 `Length`。
- `EventHandler(onEvent) { ... }`：在子树前截获事件。
- `FrameHandler(onFrame) { ... }`：接收每帧 `FrameInfo`。

## 11. `DesktopApp`

```cangjie
DesktopApp(spec, theme: Theme.light(), frameDelay: UInt32(16), fontScale: 1.0, metadata: None, hints: [])
```

| 方法 | 说明 |
|---|---|
| `run(body)` | 启动逐帧构建、布局、事件和绘制循环 |
| `manage(resource)` | 托管资源，退出时逆序关闭 |
| `setMinimumSize(width, height)` | 以逻辑像素约束窗口最小尺寸 |
| `clearRememberedState()` | 清空局部状态存储 |
| `openFileDialog`、`saveFileDialog`、`openFolderDialog` | 创建异步文件对话框请求 |

`fontScale` 作用于全部 `fp` 尺寸；`WindowSpec.scale` 决定 `px` 与 `vp` 的换算。

底层重新导出类型与方法的完整定义见 [SDL API 参考](../sdl/docs/api-reference.md)。
