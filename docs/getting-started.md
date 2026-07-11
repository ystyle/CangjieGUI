# CUI 快速入门

## 环境要求

- 仓颉 SDK 与 cjpm `1.0.5`。
- Windows x86_64，或具备兼容 SDL3/SDL3_ttf 动态库的目标平台。
- Windows 运行时需要 `SDL3.dll` 和 `SDL3_ttf.dll`。

仓库中的 `sdl/.sdl3/` 已包含 Windows 链接所需的 cjpm 名称与运行库名称。

## 创建应用

应用目录建议采用标准 cjpm 结构：

```text
hello_cui/
├── cjpm.toml
└── src/
    └── main.cj
```

`cjpm.toml`：

```toml
[package]
cjc-version = "1.0.5"
name = "hello_cui"
version = "0.1.0"
output-type = "executable"

[dependencies]
cui = { path = "../CangjieGUI" }
```

路径相对于当前应用的 `cjpm.toml`。如果 CUI 位于其他目录，应相应调整 `path`。

## 编写首个界面

`src/main.cj`：

```cangjie
package hello_cui

import cui.{Button, ButtonRole, DesktopApp, Insets, Label, Panel, State, VStack, WindowSpec}

main(): Unit {
    let message = State<String>("你好，CUI")
    let app = DesktopApp(WindowSpec("首个 CUI 应用", 640, 420))

    app.run {
        VStack(spacing: 12.0, padding: Insets(20.0)) {
            Panel(flexible: false) {
                Label(message.value)
            }
            Button("更新文本", {=> message.value = "欢迎使用仓颉 GUI"}, role: ButtonRole.Primary)
        }
    }
}
```

关键点：

- `DesktopApp` 持有窗口、渲染器、主题和事件循环。
- `app.run` 的尾随 Lambda 是根视图构建函数，每帧都会重新执行。
- `State<String>` 位于构建闭包外，因此状态不会随控件实例重建而丢失。
- 在容器构建块中创建的控件会自动成为该容器的子项。

## 构建与运行

```powershell
cjpm build
cjpm run
```

若在 Windows 上直接运行复制后的可执行文件，请把 `SDL3.dll` 和 `SDL3_ttf.dll` 放在可执行文件
同目录。通过 `cjpm run` 启动仓库示例时，cjpm 会使用模块声明的本地动态库路径。

## 选择主题与窗口参数

```cangjie
import cui.{DesktopApp, Theme, WindowSpec}

let app = DesktopApp(
    WindowSpec("深色界面", 960, 640, resizable: true, highDpi: true, scale: 1.0),
    theme: Theme.dark(),
    frameDelay: UInt32(16)
)
```

`WindowSpec.width` 和 `height` 是逻辑尺寸；`scale` 会影响实际窗口像素和事件坐标换算。无明确需求时
保留 `scale: 1.0`，并启用 `highDpi`。

## 下一步

- 学习状态、布局和控件组合：[CUI 使用指南](user-guide.md)。
- 查阅构造参数和方法：[CUI API 参考](api-reference.md)。
- 学习画布、窗口和系统底层能力：[SDL 文档](../sdl/docs/README.md)。
