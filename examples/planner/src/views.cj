/*
 * 专注规划台视图层。
 *
 *  - 左侧导航是固定宽度侧栏；底部说明文字用 maxLines 在栏宽内换行，不会溢出面板
 *  - 概览页与偏好页分别放进 ScrollView，超出高度时可滚动
 *  - 进度用 ProgressBar（自带居中动画百分比），尺寸一律使用 vp/fp 单位
 */
package cui_planner

import cui.{Button, ButtonRole, Color, ComboBox, CrossAxisAlignment, Dropdown, FlowRow, FontSizes, Grid, HStack, Icon,
    IconName, Keyed, Label, LengthUnits, Panel, ProgressBar, RadioButton, ScrollView, Spacer, Stepper, Switch,
    TextField, VStack, rememberState}

func plannerView(model: PlannerModel): Unit {
    VStack {
        appHeader()
        HStack {
            navigation(model)
            Panel {
                if (model.page.value == 0) {
                    overviewPage(model)
                } else {
                    preferencesPage(model)
                }
            }.contentPadding(18.vp).flex()
        }.spacing(14.vp)
    }.spacing(14.vp).padding(18.vp)
}

func appHeader(): Unit {
    HStack {
        Icon(IconName.Calendar).foregroundColor(Color.rgb(91, 79, 207)).iconSize(22.vp)
        VStack {
            Label("专注规划台").fontSize(FontSizes.TITLE)
            Label("把今天最重要的事，放在注意力最清醒的时段").muted().fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).flexible(false)
        Spacer()
        FlowRow {
            statusPill("深度工作", Color.rgb(91, 79, 207))
            statusPill("连续 6 天", Color.rgb(20, 139, 105))
        }.spacing(8.vp)
    }.crossAxisAlignment(CrossAxisAlignment.Center).flexible(false)
}

func navigation(model: PlannerModel): Unit {
    Panel {
        VStack {
            Label("工作区").muted().fontSize(FontSizes.CAPTION)
            navigationEntry(model, 0, "今日概览")
            navigationEntry(model, 1, "偏好设置")
            Spacer()
            Label("本地状态由 Keyed 与 rememberState 管理")
                .muted()
                .fontSize(FontSizes.CAPTION)
                .maxLines(3)
        }.spacing(10.vp)
    }.contentPadding(14.vp).flexible(false).width(220.vp)
}

func navigationEntry(model: PlannerModel, page: Int64, title: String): Unit {
    let role = if (model.page.value == page) {
        ButtonRole.Primary
    } else {
        ButtonRole.Normal
    }
    Button(title, {=> model.page.value = page}).role(role).fillWidth()
}

func overviewPage(model: PlannerModel): Unit {
    ScrollView("planner.overview.scroll") {
        VStack {
            Label("今天，保持轻盈但坚定").fontSize(FontSizes.TITLE)
            Grid(3) {
                metricCard("专注时长", "3 小时 25 分", "比昨日多 35 分钟")
                metricCard("完成任务", "8 / 12", "两项正在进行")
                metricCard("能量峰值", "10:00–12:00", "适合高认知任务")
            }.spacing(12.vp)
            focusCard(model)
            quickNote()
            Label("建议节奏").fontSize(PLANNER_HEADING)
            FlowRow {
                suggestion("先完成方案评审", "高专注")
                suggestion("整理访谈纪要", "中专注")
                suggestion("回复协作消息", "低专注")
                suggestion("散步与补水", "恢复")
            }.spacing(10.vp)
        }.spacing(14.vp).flexible(false)
    }
}

func metricCard(title: String, value: String, caption: String): Unit {
    Panel {
        VStack {
            Label(title).muted().fontSize(FontSizes.CAPTION)
            Label(value).fontSize(PLANNER_HEADING)
            Label(caption).muted().fontSize(FontSizes.CAPTION)
        }.spacing(5.vp).flexible(false)
    }.contentPadding(14.vp).style(softCard())
}

func focusCard(model: PlannerModel): Unit {
    Panel {
        VStack {
            HStack {
                VStack {
                    Label("季度方案 · 信息架构").fontSize(PLANNER_HEADING)
                    Label("当前专注块还有 31 分钟").muted().fontSize(FontSizes.CAPTION)
                }.spacing(3.vp).flexible(false)
                Spacer()
                Button("完成本轮", {=> model.completed.value = 1.0}).role(ButtonRole.Primary)
            }.flexible(false)
            // ProgressBar 自带居中百分比显示（并附动画），无需再叠加标签。
            ProgressBar(model.completed).height(26.vp).fillWidth()
        }.spacing(12.vp).flexible(false)
    }.contentPadding(16.vp).style(accentCard())
}

func quickNote(): Unit {
    Keyed("planner.quick_note") {
        let note = rememberState<String>("text") {"会后确认空状态与键盘路径"}
        Panel {
            VStack {
                Label("随手记").fontSize(PLANNER_HEADING)
                TextField("planner.quick_note.field", note).fillWidth()
                Label("这段文字由局部状态保存，切换页面卸载后会按身份规则重置。")
                    .muted()
                    .fontSize(FontSizes.CAPTION)
                    .maxLines(2)
            }.spacing(8.vp).flexible(false)
        }.contentPadding(14.vp)
    }
}

func suggestion(title: String, level: String): Unit {
    Panel {
        VStack {
            Label(title)
            Label(level).muted().fontSize(FontSizes.CAPTION)
        }.spacing(3.vp).flexible(false)
    }.contentPadding(12.vp).style(softCard()).width(210.vp)
}

func preferencesPage(model: PlannerModel): Unit {
    ScrollView("planner.preferences.scroll") {
        VStack {
            Label("偏好设置").fontSize(FontSizes.TITLE)
            settingsSection("专注时段") {
                HStack {
                    Label("单次专注分钟数")
                    Spacer()
                    Stepper("planner.minutes", model.sessionMinutes).range(15, 120).step(5)
                }.flexible(false)
                Switch("到时桌面通知", model.notifications)
                Switch("播放环境声音", model.ambientSound)
            }
            settingsSection("任务优先级") {
                FlowRow {
                    RadioButton("从容", model.priority, 0)
                    RadioButton("平衡", model.priority, 1)
                    RadioButton("冲刺", model.priority, 2)
                }.spacing(18.vp, 8.vp)
            }
            settingsSection("界面密度") {
                HStack {
                    Label("内容间距")
                    Spacer()
                    Dropdown("planner.density", ["紧凑", "舒适", "宽松"], model.density)
                }.flexible(false)
            }
            settingsSection("常用地点") {
                HStack {
                    Label("默认工作城市")
                    Spacer()
                    ComboBox("planner.city", model.location,
                        ["北京", "上海", "广州", "深圳", "杭州", "成都", "武汉", "西安"]).width(180.vp)
                }.flexible(false)
            }
        }.spacing(14.vp).flexible(false)
    }
}

func settingsSection(title: String, body: () -> Unit): Unit {
    Panel {
        VStack {
            Label(title).fontSize(PLANNER_HEADING)
            body()
        }.spacing(10.vp).flexible(false)
    }.contentPadding(16.vp).style(softCard())
}

func statusPill(text: String, color: Color): Unit {
    Label(text)
        .foregroundColor(color)
        .fontSize(FontSizes.CAPTION)
        .padding(10.vp, 5.vp)
        .background(color.withAlpha(24), 999.vp)
}
