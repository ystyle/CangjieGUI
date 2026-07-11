# CUI 示例应用

本目录中的每个示例都是独立的仓颉可执行项目，并通过本地路径依赖仓库根目录的 `cui` 模块。
示例既用于功能演示，也用于验证布局、字体、桌面集成和公开 API 的实际可用性。

所有示例遵循统一的工程结构（对齐 `sdl/examples` 的拆分习惯）：`main.cj` 只含入口；数据与
状态在 `model.cj`/`state.cj`/`data.cj`；配色与表面样式在 `theme.cj`；视图在 `views.cj`；
纯逻辑、后台任务、键盘映射等各占一个文件。尺寸一律使用 `vp`/`fp` 单位书写。

每个示例目录都有自己的 `README.md` 教学文档，讲解文件结构与关键实现；下面是一句话索引。

## 示例清单

### [`calculator`](calculator/README.md)：计算器

展示由链式 `.flex(weight)` 构成的等宽按键网格、跨两列按键、枚举化按键与集中样式映射、
`EventHandler` 键盘输入（数字/运算符直接键入、Enter 求值、Backspace 删位），以及标准/科学
模式的 `if` 控制流。运算逻辑带除零、整数溢出与错误态恢复保护。

### [`calendar`](calendar/README.md)：日历

展示七列权重布局、年月状态导航、`derive` 派生的标题、`Time.currentDateTime` 日期信息、
当前日期高亮，以及运行时生成 `Surface` 后由 `ImageView` 展示图像资源。

### [`notepad`](notepad/README.md)：记事本

展示可编辑文本区、只读模式、异步打开/保存对话框、应用内确认条（不阻塞事件循环的新建确认）、
剪贴板、文件拖放、快捷键和由 `map` 派生的文档统计状态栏。文件对话框结果在 UI 帧中轮询。

### [`paint`](paint/README.md)：画板

展示 `CanvasWidget`、平滑圆头笔画、画笔粗细滑块、系统十字光标、由应用自行实现 `Widget`
接口的 `ColorSwatch` 自定义控件，以及画布手势与工具栏按钮的事件边界处理（画布外的指针
事件不吞、按钮手势正常收尾）。

### [`process_manager`](process_manager/README.md)：进程管理器

展示 `spawn` 后台任务、由互斥锁保护的结果邮箱、后台异常兜底回传、逐帧收集结果、只读滚动
文本、`TabView`，以及 CPU、显示器和电源信息查询。耗时系统命令不会阻塞 UI 线程，子进程
输出使用受检 UTF-8 解码。

### [`focus_planner`](focus_planner/README.md)：专注规划台

展示 `Grid` 指标卡、`FlowRow` 标签、`ZStack` 叠层进度、`ScrollView`、`Keyed`、`rememberState`、
`DerivedState` 进度文本、`maxLines` 文本换行，以及 `Switch`、`RadioButton`、`Picker`、`Stepper`
等桌面控件。界面包含概览和偏好设置两个实用场景。

### [`kanban_board`](kanban_board/README.md)：产品看板

展示单一数据源驱动的三列 `Grid` 看板：列头计数由 `derive` 派生、卡片列表由 `ForEach` 按任务
id 维持身份、筛选器实时作用于三列、新增按钮真正追加卡片、在制上限超出时列头切换警示色，
以及流式标签、动态紧凑卡片和完整链式样式。

## 运行方式

进入任一示例项目目录执行：

```powershell
cd examples/calendar
cjpm run
```

所有示例均支持框架提供的快照参数：

```powershell
cjpm run --run-args "--snapshot calendar.bmp"
```

程序会等待界面完成若干帧布局和绘制后保存 BMP 快照并退出，适合视觉回归检查。
