# CUI 使用指南

## 1. 声明式视图与链式配置

CUI 使用仓颉尾随 Lambda 描述视图树。控件构造函数只接收内容、状态、事件等必要信息，布局和外观
通过链式调用逐项配置：

```cangjie
VStack {
    Label("设置").fontSize(FontSizes.TITLE)
    HStack {
        Button("保存", save).role(ButtonRole.Primary).width(120.vp)
        Button("取消", cancel).width(120.vp)
    }.spacing(8.vp)
}.spacing(12.vp).padding(16.vp)
```

`if`、`match`、`for-in` 和普通函数都可直接参与构建。可复用组件通常写成返回 `Unit` 的函数；已有
Widget 实例可用 `emit(widget)` 放入当前构建块。

修饰器按调用顺序形成包装节点，顺序会影响约束、绘制范围和命中区域。例如：

```cangjie
Label("状态").padding(10.vp).background(Color.rgb(235, 240, 255), 8.vp)
Label("状态").background(Color.rgb(235, 240, 255), 8.vp).padding(10.vp)
```

第一种写法的背景包含 padding；第二种写法在背景外增加 padding。该规则适用于所有通用修饰器。

## 2. 尺寸与单位

导入 `LengthUnits`（`cui` 根包已重新导出）后，整数与浮点字面量获得三个单位后缀，
构成带单位的 `Length` 值：

| 单位 | 写法 | 含义 | 解析规则 |
|---|---|---|---|
| 虚拟像素 | `100.vp` | 密度无关的逻辑坐标单位，布局的默认度量 | 原值 |
| 物理像素 | `100.px` | 设备物理像素 | 除以窗口 `scale` |
| 字体像素 | `15.fp` | 跟随用户字体缩放的字号单位 | 乘以 `fontScale` |

```cangjie
Panel {
    Label("正文").fontSize(15.fp)
}.contentPadding(16.vp).width(320.vp)

VStack(spacing: 12.vp, padding: LengthInsets(18.vp)) { ... }
Label("标题").padding(10.vp, 5.vp)          // 水平、垂直
Icon(IconName.Save).iconSize(22.vp)
```

要点：

- `Length` 只携带值与单位，转换发生在布局/绘制阶段，由 `UiContext.resolve` 按当前窗口
  `displayScale` 与应用 `fontScale` 计算，因此同一棵树在不同缩放下无需改代码。
- `1.5.vp`、`(columns * 96).vp` 等浮点与表达式写法同样成立；`Length` 支持 `* / ` 标量运算。
- 四边独立的内边距用 `LengthInsets`：`LengthInsets(all)`、`LengthInsets(horizontal, vertical)`、
  `LengthInsets(top: ..., right: ..., bottom: ..., left: ...)`。
- 所有尺寸修饰器同时保留 `Float32` 重载，裸浮点按 `vp` 解释、字号按 `fp` 解释，
  便于迁移；新代码建议统一书写单位。
- 权重（`flex(2.0)`）、进度（`0.0..1.0`）、缩放因子等无量纲数值仍使用浮点，这不是尺寸。
- `DesktopApp(spec, fontScale: 1.25)` 全局放大 `fp` 尺寸；`app.setMinimumSize(w, h)` 以逻辑
  像素约束窗口最小尺寸，防止布局被挤出屏幕。

## 3. 通用修饰器

所有 `Widget` 都支持：

- 尺寸：`width`、`height`、`minWidth`、`maxWidth`、`minHeight`、`maxHeight`（接受 `Length` 或按 vp 解释的 `Float32`）。
- 填充：`fillWidth`、`fillHeight`。
- 间距：`padding(all)`、`padding(horizontal, vertical)`、`padding(left, top, right, bottom)`。
- 绘制：`background(color)`、`background(color, radius)`、`surface(style)`。
- 布局：`flex()`、`flex(weight)`。
- 条件：`visible(bool)`、`enabled(bool)`。

尺寸始终受父级可用空间约束。`visible(false)` 会退出测量、布局、绘制和事件分发，不会留下相邻
间距；`enabled(false)` 保留布局并抑制输入。

## 4. 状态模型

### 4.1 可观察抽象

状态体系由两个接口组织：

- `Observable<T>`：可读可观察 —— `get()`、`revision`、`observe`、`map`。
- `Bindable<T> <: Observable<T>`：在此之上可写 —— `value` 属性、`project`。

`State<T>` 实现 `Bindable`，是可写的单一事实源；`DerivedState<T>` 实现 `Observable`，
是从其他状态计算出的只读值。展示型控件（如 `ProgressBar`）接受 `Observable`，
交互控件（如 `Switch`、`TextField`）接受 `Bindable`，因此两者可以互换使用。

### 4.2 共享状态

```cangjie
let count = State<Int64>(0)

app.run {
    HStack {
        Label("计数：${count.value}")
        Button("增加", {=> count.update({value => value + 1})})
    }
}
```

每次赋值都会增加 `revision`。`observe` 同步通知 `(旧值, 新值)`，返回的 `StateObservation` 实现
`Resource`，调用 `close` 后不再接收通知。观察回调和 UI 状态修改应位于 UI 线程。
当 `T` 可判等时，`setIfChanged(next)` 仅在值变化时赋值并返回是否触发了通知。

状态应提升到所有读写者的最低共同祖先；向下传状态，向上传事件。复杂界面可把一组相关状态和 UI
逻辑收拢到普通模型类中，避免多个控件各自维护同一业务事实。

### 4.3 派生状态

`derive` 与 `map` 从一个或多个状态计算只读值，结果带缓存：仅当来源 `revision` 变化时才重新
计算，适合放在每帧重建的视图里，也适合收拢在模型类中：

```cangjie
let tasks = State<Array<Task>>(seed())
let filter = State<Int64>(0)

let countText = derive(tasks, filter, {list, f => "${filterTasks(list, f).size} 项"})
let percent = completed.map<String>({value => "${Int64(value * 100.0)}%"})

Label(countText.value)          // 直接读取，卡片与计数永不脱节
ProgressBar(completed)
```

`derive` 支持一到三个来源。`DerivedState.observe` 仅在被观察期间订阅上游，
不会在每帧构建中泄漏监听器。

### 4.4 双向绑定投影

`project` 把大模型状态的一个分量投影成独立的 `Bindable`，读写都落回源状态：

```cangjie
let profile = State<Profile>(Profile("林", true))
let name = profile.project<String>(
    get: {p => p.name},
    set: {p, next => Profile(next, p.subscribed)}
)
TextField("profile.name", name)   // 编辑姓名即更新整个 profile
```

### 4.5 局部状态与身份

根构建闭包每帧执行。仅属于局部子树的状态可使用 `rememberState`：

```cangjie
Keyed("task:${task.id}") {
    let expanded = rememberState<Bool>("expanded") { false }
    taskCard(task, expanded)
}
```

- 同一 scope 内的 key 必须唯一且类型稳定，重复或换型会抛出 `IllegalStateException`。
- `Keyed` 使用显式业务身份隔离重复组件，不应使用会随排序变化的位置作为 key。
- 成功构建后未再次访问的局部状态会被清理；重新挂载时使用初始值。
- `TextField`、`TextArea`、`ScrollView` 会基于稳定 ID 保留隐式光标或滚动状态；也可链式传入外部状态。

### 4.6 列表与身份

`ForEach` 为集合中的每个条目建立以业务键命名的 `Keyed` 子树，插入、删除或重排时局部状态
跟随条目而不是位置：

```cangjie
ForEach(tasks, key: {task => "task.${task.id}"}) {
    task => taskCard(task)
}
```

仅在条目不会重排时才可使用按位置命名的 `ForEachIndexed`。

## 5. 布局规则

CUI 遵循单向布局协商：父级给出可用空间，子项返回期望尺寸，父级决定最终位置。控件不能越过父级
约束任意扩张；需要占满空间时显式使用 `fillWidth`、`fillHeight` 或 `flex`。

### 5.1 线性栈

`VStack` 与 `HStack` 提供：

- `.spacing(value)`：相邻子项间距（`Length` 或按 vp 解释的 `Float32`）。
- `.mainAxisAlignment(...)`：`Start`、`Center`、`End`、`SpaceBetween`、`SpaceAround`、`SpaceEvenly`。
- `.crossAxisAlignment(...)`：`Start`、`Center`、`End`、`Stretch`。
- `.flexible(bool)`：是否参与父栈剩余空间分配。

```cangjie
HStack {
    Button("左", left).flex()
    Button("中", center).flex(2.0)
    Button("右", right).flex()
}.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center)
```

`Flexible` 仍可用于带构建块的兼容写法；新代码通常直接对任意 Widget 调用 `.flex(weight)`。

### 5.2 组合容器

- `ZStack`：按声明顺序从后向前绘制，事件反向命中；`.alignment` 设置二维对齐。
- `Grid(columns)`：固定等宽列、内容高度行；`.spacing` 设置行列间距。
- `FlowRow`：从左到右布局，空间不足时自动换行。
- `ScrollView(id)`：垂直裁剪滚动视口，滚轮命中受视口限制；`.scrollState` 可接管偏移。
  内容超出高度时自动为滚动条预留右侧轨道，滚动条不会覆盖内容；裁剪采用栈式管理，
  内部的文本框、画布等自带裁剪的控件不会破坏视口边界。
- `Panel`：主题面板；`.contentPadding`、`.style`、`.flexible` 配置内部布局。

## 6. 文字、按钮与图标

```cangjie
Label("警告")
    .muted(false)
    .textAlign(TextAlign.Center)
    .foregroundColor(Color.rgb(190, 55, 70))
    .fontSize(FontSizes.TITLE)

Label("可能很长的说明文字……").maxLines(2)   // 在可用宽度内换行，超出部分省略

Button("删除", remove)
    .role(ButtonRole.Danger)
    .width(120.vp)
```

单行 `Label` 超出可用宽度时自动以省略号截断，不会绘制到边界之外；`.maxLines(n)` 允许换行到
n 行，`.wrap()` 不限行数。换行优先落在空格处，CJK 文本可在任意字符处断行。

`Button`、`IconButton` 和二态选择控件在主鼠标键释放且指针仍位于控件内时激活，并支持焦点后的
Enter/Space。控件默认按声明顺序获得构建期唯一的交互身份，同名按钮、成对图标按钮无需额外配置
即可各自响应；仅当身份需要跨树形变化保持（例如按钮在容器间移动）时才用 `.id` 显式指定。

焦点遵循桌面惯例：一次鼠标按下要么把焦点移交给认领它的控件，要么清除当前焦点——点击空白
或不可聚焦区域会让文本框失焦并恢复常规样式。取得焦点的按钮显示强调色描边，提示 Enter/Space
的作用目标；`UiContext.clearFocus()` 可编程清除焦点。

`Icon` 支持 `.iconSize`、`.foregroundColor`；`IconButton` 支持 `.label`、`.role`、`.style`、`.id`；
`Divider` 支持 `.axis`、`.color`。

## 7. 选择、导航与数值控件

```cangjie
let enabled = State<Bool>(true)
let mode = State<Int64>(0)
let volume = State<Float32>(0.5)
let quantity = State<Int64>(3)

VStack {
    Checkbox("启用", enabled)
    Switch("桌面通知", enabled)
    RadioButton("标准", mode, 0)
    RadioButton("专业", mode, 1)
    Picker("theme", ["浅色", "深色", "系统"], mode)
    Stepper("quantity", quantity).range(1, 20).step(1)
    Slider("volume", volume).range(0.0, 1.0)
    ProgressBar(volume).range(0.0, 1.0)
}
```

这些控件接受任何 `Bindable`（`ProgressBar` 接受 `Observable`），因此既可以传 `State`，
也可以传 `project` 投影或 `map` 派生的值。`SegmentedControl` 适合少量并列选项；`TabView` 的
body 按标签顺序声明页面；`ListView` 保存选中索引并支持外部滚动状态。`Picker` 是紧凑的前后
选择控件，空数据时保持安全占位。

## 8. 文本输入

```cangjie
let title = State<String>("")
let body = State<String>("")
let bodyScroll = State<Float32>(0.0)
let bodyCursor = State<Int64>(0)

VStack {
    TextField("title", title)
    TextArea("body", body)
        .scrollState(bodyScroll)
        .cursorState(bodyCursor)
        .editable(true)
}
```

ID 同时参与焦点和隐式状态身份，必须稳定且唯一。`TextEditState` 按 UTF-8 字符边界执行插入、删除、
左右移动、行首行尾与上下行移动。只读 `TextArea` 仍允许滚动和光标导航。

插入光标与字形行等高对齐、按标准节奏闪烁；点击定位使用与绘制一致的真实文本测量，比例字体与
中文文本都会落在最近的字符边界。超出可视宽度的内容被裁剪在控件表面之内。

## 9. 事件、画布与图像

`EventHandler` 在子树前接收 `UiEvent`；返回 `true` 表示消费。`FrameHandler` 每帧接收 `FrameInfo`。

```cangjie
CanvasWidget({renderer, rect => drawScene(renderer, rect)})
    .onEvent({event, rect => handleSceneEvent(event, rect)})
```

自定义画布处理指针事件时，凡是“按下开始、松开结束”的手势都必须检查事件坐标是否落在自己的
`rect` 内，画布外的事件返回 `false` 放行，否则会吞掉同窗口其他控件的手势收尾。

`ImageView(path).fit(ImageFit.Contain)` 实现 `Resource`。尺寸建议使用通用 `width`/`height` 修饰器；
长期资源交给 `DesktopApp.manage`，临时资源使用 try-with-resources 或显式 `close`。

## 10. 后台任务与桌面能力

UI 构建、布局、事件和绘制位于同一线程。文件扫描、系统命令、网络请求等耗时工作应由 `spawn`
执行，以 `Mutex`、原子对象或并发容器把不可变结果交回 `FrameHandler`；后台闭包必须自行
try/catch，把失败信息与成功结果走同一条回传通道，避免忙碌标志被异常卡死。文件对话框返回异步
`FileDialogRequest`，不得在 UI 线程同步等待。

## 11. 快照与视觉验证

`DesktopApp` 识别 `--snapshot <path.bmp>`，稳定绘制若干帧后保存 BMP 并退出。cjpm 1.0.5 使用
`--run-args` 传递应用参数：

```powershell
cjpm run --run-args "--snapshot output.bmp"
```

`focus_planner` 与 `kanban_board` 是新布局、状态和控件的综合端到端示例；`kanban_board`
额外演示了 `derive` 派生计数与 `ForEach` 列表身份。
