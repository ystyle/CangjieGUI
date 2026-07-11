# CUI 示例应用

本目录中的每个示例都是独立的仓颉可执行项目，并通过本地路径依赖仓库根目录的 `cui` 模块。
示例既用于功能演示，也用于验证布局、字体、桌面集成和公开 API 的实际可用性。

## 示例清单

### `calculator`：计算器

展示由 `Flexible` 构成的等宽按键网格、跨两列按键、派生显示状态、可复用 `SurfaceStyle`，以及
通过普通 `if` 控制标准模式和科学模式的界面结构。

### `calendar`：日历

展示七列权重布局、年月状态导航、`Time.currentDateTime` 日期信息、当前日期高亮，以及运行时生成
`Surface` 后由 `ImageView` 展示图像资源。

### `notepad`：记事本

展示可编辑文本区、只读模式、异步打开/保存对话框、消息框确认、剪贴板、文件拖放、快捷键和
文档状态栏。文件对话框结果在 UI 帧中轮询，不阻塞事件循环。

### `paint`：画板

展示 `CanvasWidget`、平滑圆头笔画、画笔粗细滑块、系统十字光标，以及由应用自行实现 `Widget`
接口的 `ColorSwatch` 自定义控件。

### `process_manager`：进程管理器

展示 `spawn` 后台任务、由互斥锁保护的结果邮箱、逐帧收集结果、只读滚动文本、`TabView`，以及
CPU、显示器和电源信息查询。耗时系统命令不会阻塞 UI 线程。

## 运行方式

进入任一示例项目目录执行：

```powershell
cd examples/calendar
cjpm run
```

所有示例均支持框架提供的快照参数：

```powershell
cjpm run -- --snapshot calendar.bmp
```

程序会等待界面完成若干帧布局和绘制后保存 BMP 快照并退出，适合视觉回归检查。
