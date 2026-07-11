# focus_planner：专注规划台

一个双页的效率工具界面，演示局部状态身份（`Keyed` + `rememberState`）、派生进度文本、
文本换行，以及 `Grid`/`FlowRow`/`ZStack`/`ScrollView` 的组合布局。

## 你将学到

- 侧栏 + 内容区的桌面应用骨架：固定宽度导航、`flex()` 内容面板
- `Keyed` 与 `rememberState` 的局部状态生命周期：切换页面卸载后按身份规则重置
- `map` 派生的进度百分比文本与 `ZStack` 叠层进度条
- `maxLines` 让说明文字在窄侧栏内换行而不是溢出
- 设置页的成组控件模式：`Stepper`、`Switch`、`RadioButton`、`Picker`

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：模型、窗口与最小尺寸 |
| [model.cj](src/model.cj) | `PlannerModel`：页面、进度、偏好状态与派生百分比文本 |
| [views.cj](src/views.cj) | 全部视图：头部、导航、概览页、偏好页 |
| [theme.cj](src/theme.cj) | 紫罗兰主题、卡片表面与共享字号令牌 |

## 关键实现讲解

### 局部状态的身份边界

“随手记”的文本只属于概览页这棵子树。`Keyed` 建立稳定命名空间，`rememberState` 在子树
挂载期间跨帧保留状态；切到偏好页后这棵子树从成功构建中消失，状态按声明周期被清理：

```cangjie
Keyed("planner.quick_note") {
    let note = rememberState<String>("text") {"会后确认空状态与键盘路径"}
    TextField("planner.quick_note.field", note).fillWidth()
}
```

### 派生进度文本 + 叠层进度条

百分比文本由 `completed` 派生，进度条与文本用 `ZStack` 叠放居中：

```cangjie
this.percentText = this.completed.map<String>({value => "${Int64(value * 100.0)}%"})

ZStack {
    ProgressBar(model.completed).height(24.vp).fillWidth()
    Label(model.percentText.value).textAlign(TextAlign.Center)
}.alignment(Alignment.Center).height(26.vp)
```

### 窄栏文字不溢出

侧栏固定 `220.vp` 宽，底部说明文字用 `.maxLines(3)` 在栏宽内换行；单行 `Label` 超宽时
框架也会自动省略号截断，文字永远不会画出面板：

```cangjie
Label("本地状态由 Keyed 与 rememberState 管理")
    .muted().fontSize(FontSizes.CAPTION).maxLines(3)
```

### 字号令牌

区块小标题共用一个 `Length` 常量，语义与数值一处定义：

```cangjie
let PLANNER_HEADING: Length = 17.fp
```

## 运行

```powershell
cd examples/focus_planner
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot planner.bmp"
```
