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

控件构造函数会把新实例登记到当前打开的构建块中。容器执行尾随 Lambda，收集其中创建的控件并
形成树。普通控制流只是在构建块内按顺序执行，因此无需额外模板语言。

链式修饰器不是把属性塞回控件构造参数，而是按调用顺序创建包装节点，并把构建块中刚登记的节点
替换为包装后的根。这样尺寸、padding、表面、事件开关等行为可组合且顺序可观察，和 SwiftUI 的
View modifier、Jetpack Compose 的 Modifier tree 采用相同的核心思想。

`DesktopApp.run` 每帧执行视图构建闭包，随后依次完成布局、事件分发、帧事件和绘制。共享状态保存在
模型或提升后的 `State<T>` 中；局部状态由 `StateStore` 按 `Keyed` scope 与显式 key 保存。成功构建
后没有再次访问的局部状态会被清理，因此状态生命周期与声明式子树的挂载生命周期一致。

`State<T>` 的值向下流入视图，用户事件向上修改状态或调用模型方法。该单向数据流避免控件内部状态
与业务模型形成多个事实源。对于重复或条件子树，身份由 key 决定，而不是由临时 Widget 实例决定；
`ForEach` 按业务键为每个条目建立 `Keyed` 子树，使局部状态跟随条目而非位置。

### 可观察抽象与派生状态

状态读写分离为 `Observable<T>`（读 + 观察）与 `Bindable<T>`（读写）两个接口，`State` 实现后者。
`DerivedState` 采用适配逐帧重建的**拉取式缓存**：读取时对比来源 `revision` 快照，变化才重新计算，
在视图体内派生零订阅、零泄漏；`observe` 仅在被观察期间向上游注册监听。`Binding` 把大状态的一个
分量投影成独立的 `Bindable`，写入时重建源值，保证事实源唯一。这组设计对应 Compose 的
`derivedStateOf`、SwiftUI 的 `Binding` 与 SolidJS 的 `createMemo`，但以显式修订号取代依赖追踪，
与确定性逐帧重建模型保持一致。

### 控件交互身份

焦点与按压以字符串 ID 关联而非以 Widget 实例关联（实例每帧重建）。控件默认身份 =
`Keyed` 作用域路径 + 默认名 + 构建序号：同名控件按声明顺序自动去重，序号每帧重置，树形不变时
身份跨帧稳定。这一机制来源于立即模式 GUI 的 ID 栈思想，消除了“两个无标签图标按钮共享按压状态、
后者吞掉前者松开事件”一类的隐性冲突；`.id(...)` 仅在身份需要跨树形变化保持时显式指定。

### 尺寸单位解析

公共尺寸 API 接受携带单位的 `Length`（`px`/`vp`/`fp`），修饰器与容器仅存储该值，转换推迟到
测量/布局/绘制阶段由 `UiContext.resolve` 完成：`vp` 即逻辑坐标原值，`px` 除以窗口 `displayScale`，
`fp` 乘以应用 `fontScale`。因此同一视图代码在不同缩放与字体设置下无需修改，单位错误在类型层
即被拒绝。字面量后缀通过 `LengthUnits` 接口扩展提供——接口扩展是跨包导出扩展成员的唯一通道，
这也是它不做成直接扩展的原因。

## 布局模型

布局遵循“约束向下、期望尺寸向上、父级定位”：父容器给子项最大可用尺寸，子项返回期望尺寸，父级
根据排列和对齐策略确定最终矩形。`VStack` 和 `HStack` 共用同一套轴参数化的布局引擎：先测量
非弹性子项并累计固定尺寸，再把剩余空间按 `flexWeight` 分配给弹性子项，最后一趟完成放置——
每个子项每次布局恰好测量一次，深层嵌套不会产生重复测量的指数放大。
`Flexible(weight: 2.0)` 除获得两份空间外，还会吸收跨越单元之间的间距，因此可与两个普通单元
精确对齐。`flexible: false` 表示容器按内容尺寸收缩，适合工具栏、标题栏和状态栏。

`Grid` 使用等宽列与内容高度行，`FlowRow` 根据约束自动换行，`ZStack` 共享布局边界并按视觉层级
反向命中，`ScrollView` 用裁剪约束绘制与指针命中。`visible(false)` 从父级布局参与集合中移除，
因此不会残留间距或空网格项。

`ScrollView` 的布局采用两段决策：内容先按全宽测量，只有确认溢出时才让出滚动条轨道宽度并
重测一次——收窄只会让内容更高、不会反向变矮，因此该决策一次收敛、不会振荡。滚动条因此
拥有专用轨道，不会覆盖内容右缘。

## 渲染管线

每帧由 `Renderer.beginScene` 建立绘制目标。设备允许时，场景被绘制到高分辨率离屏纹理，
`endScene` 再以线性过滤解析到窗口。圆角矩形、圆形和粗线使用 GPU 几何网格与透明边缘实现平滑
轮廓。文本由 SDL3_ttf 使用系统 UI 字体绘制，并使用真实字形度量完成居中和布局。

裁剪是栈式的：`pushClip` 把新矩形与当前生效裁剪求交后入栈，`popClip` 恢复外层。SDL 的原生
裁剪是单值状态，"设置—清除"式的配对在嵌套时会互相破坏——滚动视口内放一个自带裁剪的文本框，
文本框画完便会把视口的裁剪一并清掉，其后的兄弟内容溢出容器。栈式相交语义保证任意嵌套下
子级裁剪永不超出父级，且退出后父级裁剪原样恢复；`beginScene` 会清空残留栈防止跨帧泄漏。

`Label` 的截断与换行基于真实度量：单行超宽时以二分查找定位省略号前缀（每行 O(log n) 次测量），
`maxLines`/`wrap` 优先在空格处断行、CJK 可逐字断行，末行截断。文本永不绘制到分配框之外，
这是防止界面文字溢出的框架级保证。

## 事件与线程

事件从最外层视图向内分发，容器通常按逆序把指针和键盘事件交给子项，以符合视觉层叠顺序；
`UiEvent.Frame` 会广播给整棵树。UI 构建和绘制必须位于同一线程。耗时工作应通过 `spawn` 执行，
并使用 `Mutex`、原子对象或并发集合把结果传回 UI 帧。

## 资源生命周期

`Surface`、`Texture`、`Cursor`、`ImageView` 和 `SdlWindow` 等对象实现 `Resource`。应用可调用
`DesktopApp.manage` 将长期资源交给应用统一关闭；临时资源应使用 try-with-resources 或显式
`close`。关闭操作均设计为可重复调用。

## 设计依据与演进边界

当前设计参考以下一手资料，而非复刻某个框架的表层语法：

- [Jetpack Compose Modifier](https://developer.android.com/develop/ui/compose/modifiers)：修饰器链的顺序、尺寸、布局、行为与外观组合。
- [Compose constraints and modifier order](https://developer.android.com/develop/ui/compose/layouts/constraints-modifiers)：修饰器作为布局包装节点的约束传播模型。
- [Compose state hoisting](https://developer.android.com/develop/ui/compose/state-hoisting)：状态提升到读写者最低共同祖先，向下暴露不可变状态和向上事件。
- [Compose derivedStateOf](https://developer.android.com/develop/ui/compose/side-effects#derivedstateof)：从其他状态计算、按需失效的派生只读状态。
- [SwiftUI Binding](https://developer.apple.com/documentation/swiftui/binding)：把大模型的一个分量投影为可读写值、写回单一事实源的双向绑定。
- [SolidJS createMemo](https://docs.solidjs.com/reference/basic-reactivity/create-memo)：带缓存的派生计算与显式失效信号。
- [Dear ImGui ID stack](https://github.com/ocornut/imgui/blob/master/docs/FAQ.md#q-about-the-id-stack-system)：立即模式 GUI 以作用域 ID 栈维持跨帧控件身份的机制。
- [Flutter constraints](https://docs.flutter.dev/ui/layout/constraints)：父级约束、子级尺寸和父级定位的一趟布局协商。
- [React preserving and resetting state](https://react.dev/learn/preserving-and-resetting-state)：树位置、类型和 key 对状态保留/重置的影响。
- [ArkUI 像素单位](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ts-pixel-units)：px/vp/fp 三级尺寸单位与密度、字体缩放的解析关系。
- [Elm: Concurrent FRP for Functional GUIs](https://elm-lang.org/assets/papers/concurrent-frp.pdf)：函数式 GUI 中显式状态与消息驱动视图的理论背景。
- [A Consistent Semantics of Self-Adjusting Computation](https://arxiv.org/abs/1106.0478)：后续若引入依赖追踪和细粒度增量重建，需要保持变化传播语义一致。

CUI 当前仍采用确定性的逐帧完整重建，尚未声称实现细粒度重组或自调整计算。未来若加入依赖追踪，
必须先建立稳定身份、状态读取追踪、失效传播与一致性测试，不能仅用缓存 Widget 实例替代正确模型。

### 静态检查基线

`cjlint` 全量扫描后的处置分两类。已修复：超长布局函数拆分为三趟辅助函数、`DerivedState`
去除 `getOrThrow`、文本控件补充裁剪。经架构审查后保留的偏离（均有明确理由，不为消除提示
而破坏设计）：

- **G.ITF.04（接口作类型）**：构建树、异构子项数组、资源托管与状态注入天然需要
  `Widget`/`Resource`/`Observable`/`Bindable` 存在类型，这是框架的多态边界。
- **G.ITF.02（扩展实现接口）**：`LengthUnits` 必须以接口扩展加到内置 `Int64`/`Float64` 上
  （跨包导出扩展成员的唯一通道）；`setIfChanged` 依赖 `where T <: Equatable<T>` 约束，
  只能定义在受约束扩展中。
- **G.NAM.04（`ForEach` 大驼峰）**：列表构建器沿用声明式视图词汇（与 `VStack`、`Keyed`
  同层级的视图结构词），大写命名是有意为之。
- **G.VAR.02（最小作用域）**：命中的是文件级 `private let` 常量与循环累加器——常量下沉到
  函数内会逐次重建并伤害可读性，累加器必须先于循环声明，二者均已是实际最小作用域。
- **G.OPR.01（`Length * Float32`）**：长度按标量缩放与 `Duration * n`、CSS `calc()` 同义，
  符合量纲运算惯例。
- **G.FUN.01（`Theme` 构造参数超限）**：主题是一次性构造的纯值记录，命名参数携带默认值；
  拆分成多次调用反而弱化“一处声明完整配色”的可审阅性。

## FFI 边界

C ABI 声明、原始结构和指针操作位于 `sdl` 模块内部。领域包将 `foreign` 调用转换为仓颉类型、
`Option` 或 `CuiException`。应用 API 不暴露 `CPointer` 或 `CString`。由于仓颉 1.0.5 的静态链接
限制，领域专属 ABI 声明与调用方保持同包，而不是集中到一个跨包调用的 raw 包中。
