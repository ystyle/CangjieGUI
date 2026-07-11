# CUI 架构与设计说明

## 模块关系

```text
应用
  │
  ▼
cui ──► cui.core / cui.controls / cui.text / cui.media / cui.desktop
  │
  ▼
sdl ──► sdl.dialogs / sdl.displays / sdl.input / sdl.system / sdl.text
  │
  ▼
SDL3 + SDL3_ttf
```

`cui` 对 `sdl` 是单向依赖。底层模块可以独立使用，不了解 GUI 控件或声明式构建机制。

## CUI 包职责

| 包 | 职责 |
|---|---|
| `cui` | 应用入口门面，重新导出应用所需 API |
| `cui.core` | Widget 协议、上下文、状态、主题、布局容器和基础控件 |
| `cui.controls` | 选择、导航和数值控件 |
| `cui.text` | UTF-8 文本编辑状态、单行输入和多行文本区 |
| `cui.media` | 画布与图像视图 |
| `cui.desktop` | 窗口生命周期、事件循环、资源托管和快照 |

## 声明式视图树

控件构造函数会把新实例登记到当前打开的构建块中。`VStack`、`HStack`、`Panel`、`Flexible` 等
容器执行尾随 Lambda，收集其中创建的控件并形成树。普通控制流只是在构建块内按顺序执行，因此
无需额外模板语言。

`DesktopApp.run` 每帧执行视图构建闭包，随后依次完成布局、事件分发、帧事件和绘制。应用状态应
保存在构建闭包外部的 `State<T>` 或其他稳定对象中，不能依赖某一帧控件实例的临时身份。

## 布局模型

`VStack` 和 `HStack` 先测量非弹性子项，再把剩余空间按 `flexWeight` 分配给弹性子项。
`Flexible(weight: 2.0)` 除获得两份空间外，还会吸收跨越单元之间的间距，因此可与两个普通单元
精确对齐。`flexible: false` 表示容器按内容尺寸收缩，适合工具栏、标题栏和状态栏。

## 渲染管线

每帧由 `Renderer.beginScene` 建立绘制目标。设备允许时，场景被绘制到高分辨率离屏纹理，
`endScene` 再以线性过滤解析到窗口。圆角矩形、圆形和粗线使用 GPU 几何网格与透明边缘实现平滑
轮廓。文本由 SDL3_ttf 使用系统 UI 字体绘制，并使用真实字形度量完成居中和布局。

## 事件与线程

事件从最外层视图向内分发，容器通常按逆序把指针和键盘事件交给子项，以符合视觉层叠顺序；
`UiEvent.Frame` 会广播给整棵树。UI 构建和绘制必须位于同一线程。耗时工作应通过 `spawn` 执行，
并使用 `Mutex`、原子对象或并发集合把结果传回 UI 帧。

## 资源生命周期

`Surface`、`Texture`、`Cursor`、`ImageView` 和 `SdlWindow` 等对象实现 `Resource`。应用可调用
`DesktopApp.manage` 将长期资源交给应用统一关闭；临时资源应使用 try-with-resources 或显式
`close`。关闭操作均设计为可重复调用。

## FFI 边界

C ABI 声明、原始结构和指针操作位于 `sdl` 模块内部。领域包将 `foreign` 调用转换为仓颉类型、
`Option` 或 `CuiException`。应用 API 不暴露 `CPointer` 或 `CString`。由于仓颉 1.0.5 的静态链接
限制，领域专属 ABI 声明与调用方保持同包，而不是集中到一个跨包调用的 raw 包中。
