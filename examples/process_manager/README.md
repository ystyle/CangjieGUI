# process_manager：进程管理器

一个系统信息面板，演示 UI 线程与后台任务的正确协作：`spawn` + 互斥邮箱 + 帧内收取，
以及“后台异常也要走同一条回传通道”的可靠性准则。

## 你将学到

- `RefreshWorker` 邮箱模式：后台线程投递、UI 帧收取，`busy` 标志防重入
- 为什么 `spawn` 闭包必须自带 try/catch：异常也要 `publish`，否则忙碌标志永久卡死
- 子进程输出用**受检** `String.fromUtf8` 解码，`chcp 65001 && tasklist` 保证字节确为 UTF-8
- “N 秒前刷新”相对时间的正确算法（记录完成时刻，而不是拿启动至今的毫秒数）
- `ForEach` 渲染系统信息卡片、`derive`/`map` 派生占比与文案

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [model.cj](src/model.cj) | `ProcessModel`、刷新节奏常量、派生的占比/字节数/刷新时长文案 |
| [worker.cj](src/worker.cj) | `RefreshWorker` 邮箱、帧调度 `tick`、`tasklist` 执行与解码 |
| [views.cj](src/views.cj) | 工具栏、进程页、概览页 |
| [system_info.cj](src/system_info.cj) | CPU/显示器/电源信息的格式化（含空数组防御） |
| [theme.cj](src/theme.cj) | 深色主题、应用元数据与 SDL 提示 |

## 关键实现讲解

### 邮箱模式与异常兜底

后台线程与 UI 帧只通过互斥锁保护的“邮箱”交换一个字符串。关键在 catch 分支：
失败信息与成功结果走同一条 `publish` 通道，`busy` 必然复位、错误必然上屏：

```cangjie
let _ = spawn {
    try {
        publish(loadProcesses())
    } catch (e: Exception) {
        publish("进程快照采集失败：${e.message}")   // 异常也要投递
    }
}
```

早期版本没有这层保护：一次 `ProcessException` 就会让 `busy` 永远为 true，
此后所有自动/手动刷新静默失效。

### 受检解码不可信输出

`tasklist` 的输出只有在 `chcp 65001` 成功后才是 UTF-8，因此命令用 `&&` 串接
（失败即中止），解码用受检 API 并兜底：

```cangjie
executeWithOutput("cmd", ["/D", "/C", "chcp 65001 >NUL && tasklist"])
String.fromUtf8(bytes)   // 非法字节抛异常 → 转成可读的中文提示
```

### 相对刷新时间

模型记录“快照上屏那一帧的 tick”，状态栏显示 `当前 tick − 完成 tick`：

```cangjie
this.refreshAge = derive(this.nowTick, this.refreshedTick,
    {now, done => refreshAgeText(now, done)})
```

`FrameInfo.elapsedMs` 是程序启动至今的绝对毫秒——直接除以 1000 显示会随运行时间
无限增大，这是早期版本的一个真实缺陷。

## 运行

```powershell
cd examples/process_manager
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot pm.bmp"
```
