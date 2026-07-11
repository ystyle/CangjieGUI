/*
 * 视图层：工具栏、进程文本页与概览卡片。
 *
 *  - 只描述界面结构；刷新调度在 worker.cj，展示文案全部由 model.cj 派生
 *  - 事实卡片用 ForEach 按标题建立稳定身份；显示器型号等长文本用 maxLines
 *    截断，不会撑破卡片
 *  - 尺寸一律使用 vp 单位表达
 */
package cui_process_manager

import cui.{ButtonRole, FontSizes, ForEach, HStack, IconButton, IconName, Label, LengthUnits, Panel, ProgressBar,
    Spacer, TabView, TextArea, VStack}

func processView(model: ProcessModel, worker: RefreshWorker, facts: Array<SystemFact>): Unit {
    VStack {
        toolbar(model, worker)
        TabView(["进程", "概览"], model.tab) {
            TextArea("process.output", model.output).scrollState(model.outputScroll).editable(false)
            summaryPage(model, facts)
        }
    }.padding(14.vp)
}

// 顶栏：手动刷新按钮、状态文字与自动刷新说明。按钮标识由框架按构建顺序自动分配。
func toolbar(model: ProcessModel, worker: RefreshWorker): Unit {
    Panel {
        HStack {
            IconButton(IconName.Refresh) {
                => worker.request()
            }.label("刷新").role(ButtonRole.Primary)
            Label(statusText(model, worker)).muted()
            Spacer()
            Label("每 ${Refresh.INTERVAL_MS / Refresh.MS_PER_SECOND} 秒自动刷新")
                .muted()
                .fontSize(FontSizes.CAPTION)
        }
    }.contentPadding(10.vp).flexible(false)
}

// 刷新进行中的提示优先；空闲时显示距上次快照上屏过去了多久。
func statusText(model: ProcessModel, worker: RefreshWorker): String {
    if (worker.isBusy()) {
        "正在刷新……"
    } else {
        model.refreshAge.value
    }
}

func summaryPage(model: ProcessModel, facts: Array<SystemFact>): Unit {
    VStack {
        ForEach(facts, key: {fact => "fact.${fact.title}"}) {
            fact => factCard(fact)
        }
        snapshotCard(model)
        Spacer()
    }.spacing(10.vp).padding(6.vp)
}

func factCard(fact: SystemFact): Unit {
    Panel {
        VStack {
            Label(fact.title).muted().fontSize(FontSizes.CAPTION)
            // 显示器型号等文案长度不可控，限两行以省略号收尾，防止溢出卡片。
            Label(fact.value).fontSize(FontSizes.TITLE).maxLines(2)
        }.spacing(6.vp).flexible(false)
    }.contentPadding(12.vp).flexible(false)
}

func snapshotCard(model: ProcessModel): Unit {
    Panel {
        VStack {
            Label("进程快照大小").muted().fontSize(FontSizes.CAPTION)
            ProgressBar(model.snapshotFraction)
            Label(model.snapshotBytes.value).muted().fontSize(FontSizes.CAPTION)
        }.spacing(8.vp).flexible(false)
    }.contentPadding(12.vp).flexible(false)
}
