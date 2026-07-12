# notes：主从式笔记

一个经典的“左列表 + 右编辑器”主从应用，集中演示框架累积的能力如何组合：列表键盘导航、
文本选区与撤销、悬停提示，以及主从结构最容易写乱的一环——**编辑器与选中项的双向绑定**。

## 你将学到

- 用 `notes.project(get, set)` 把 `TextArea` **双向绑定**到“当前选中笔记的正文”——单一数据源，
  无需手工同步任何编辑缓冲区
- 让编辑器 **id 含笔记 id**，从而光标与撤销历史按笔记独立、切换笔记时自然重置（互不影响）
- `ListView` 的方向键导航驱动主从选择；`Tab` 在列表与编辑器间切换焦点
- 标题取正文首行（普通函数每帧重算）、字节统计从当前笔记 `derive`——编辑即实时刷新
- 工具栏图标按钮用 `Tooltip` 补充说明
- 侧栏用 `ContextMenu` 附加右键菜单（新建/复制/删除），其中“复制笔记”只在菜单里提供
- 右键“删除笔记”走 `Modal` 模态确认对话框（暗化背景、承载真实按钮），确认后才删除

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Note` 与种子数据、正文取值/整表替换、首行标题 |
| [model.cj](src/model.cj) | `NotesModel`：`project` 绑定、派生统计、新建/复制/删除、每笔记编辑器 id |
| [views.cj](src/views.cj) | 顶部标题栏与工具栏、侧栏列表、编辑器与统计 |
| [theme.cj](src/theme.cj) | 浅色纸面主题与字号令牌 |

## 关键实现讲解

### 编辑器绑定到选中笔记（主从的核心）

编辑器不复制正文到一个缓冲区再想办法同步回去；它直接**双向绑定**到“选中笔记的正文”：

```cangjie
this.body = this.notes.project(
    get: {arr => noteBodyAt(arr, sel.value)},          // 读：取选中笔记
    set: {arr, value => withBodyAt(arr, sel.value, value)}  // 写：整表替换该笔记
)
```

读取取当前选中笔记，写入用一张替换了该笔记正文的新表回写 `notes`。单一数据源、零同步逻辑：
切换 `selected` 绑定即读到新笔记，编辑即写回原笔记。

### 每笔记独立的光标与撤销

如果所有笔记共用一个 `TextArea`（固定 id），撤销历史会互相混入——在 A 笔记里撤销可能把 A 的旧文本
写进当前的 B 笔记。这里让编辑器 **id 含笔记 id**：

```cangjie
TextArea(model.editorId(), model.body)   // editorId() = "notes.editor:${当前笔记 id}"
```

切换笔记 id 就变，框架按 id 保留的光标与撤销栈随之切换；离开的笔记状态在下次构建被回收，
返回时是干净的编辑会话——正是期望的行为。

### 标题与统计随编辑刷新

侧栏标题取正文首行（`titles()` 普通函数每帧重算），底部字节统计由 `derive` 从当前笔记派生，
因此编辑正文时二者都实时更新，永不与内容脱节。

## 运行

```powershell
cd examples/notes
cjpm run
```

点击或方向键切换笔记，右侧编辑（`Ctrl+Z` 撤销、双击选词、拖选），工具栏或在列表上右键新建/复制/删除。
支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot notes.bmp"
```
