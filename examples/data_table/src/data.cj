/*
 * 表格的列定义与种子数据。行是 `Array<String>` 单元格，按列索引；数值列声明 `numeric: true`，
 * 由 `Table` 右对齐并按数值（而非字典序）排序。
 *
 * “CPU %” 列演示自定义单元格（`TableColumn.cell`）：单元格字符串仍是 “23” 这样的数值文本，
 * numeric 排序照常生效，绘制则由回调接管——迷你负载条 + 右对齐数值，负载越高颜色越警示。
 * 表格先画好行底与选中高亮并把回调裁剪在单元格内，回调只负责内容。
 */
package cui_data_table

import cui.{Color, FontSizes, Rect, TableColumn, UiContext, clampF32}

func serverColumns(): Array<TableColumn> {
    [
        TableColumn("主机名", 180.0),
        TableColumn("区域", 100.0),
        TableColumn("CPU %", 100.0, numeric: true, cell: cpuCellPainter),
        TableColumn("内存 %", 100.0, numeric: true),
        TableColumn("连接数", 120.0, numeric: true),
        TableColumn("状态", 110.0)
    ]
}

/** “CPU %” 单元格：左侧负载条按百分比填充，右侧保留数值文本。 */
func cpuCellPainter(ctx: UiContext, _: Int64, value: String, cell: Rect): Unit {
    let percent = clampF32(Float32(leadingInt(value)) / 100.0, 0.0, 1.0)
    let track = Rect(cell.x + 10.0, cell.centerY() - 3.0, max(0.0, cell.w - 56.0), 6.0)
    ctx.renderer.fillRoundedRect(track, 3.0, ctx.theme.panelEdge.withAlpha(90))
    if (percent > 0.0) {
        ctx.renderer.fillRoundedRect(Rect(track.x, track.y, track.w * percent, track.h), 3.0, loadColor(ctx, percent))
    }
    let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) / 2.0
    let tw = ctx.renderer.textWidth(value, pointSize: FontSizes.CAPTION)
    ctx.renderer.text(value, cell.right() - 10.0 - tw, ty, ctx.theme.mutedText, pointSize: FontSizes.CAPTION)
}

/** 负载配色：85% 以上用主题危险色，60% 以上用琥珀警示，其余用平稳的绿色。 */
func loadColor(ctx: UiContext, percent: Float32): Color {
    if (percent >= 0.85) {
        ctx.theme.danger
    } else if (percent >= 0.6) {
        Color.rgb(228, 146, 34)
    } else {
        Color.rgb(58, 165, 102)
    }
}

/** 解析单元格开头的十进制整数（“23” → 23）；无数字时为 0。 */
func leadingInt(text: String): Int64 {
    var value = 0
    var i = 0
    while (i < text.size && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
        value = value * 10 + Int64(text[i]) - 48
        i += 1
    }
    value
}

func seedServers(): Array<Array<String>> {
    [
        ["web-01", "华东", "23", "41", "1280", "正常"],
        ["web-02", "华东", "67", "58", "3410", "正常"],
        ["web-03", "华南", "45", "39", "2050", "正常"],
        ["api-01", "华北", "88", "72", "5120", "繁忙"],
        ["api-02", "华北", "12", "33", "540", "正常"],
        ["api-03", "华东", "76", "64", "4300", "繁忙"],
        ["db-master", "华东", "54", "81", "220", "正常"],
        ["db-replica-1", "华南", "9", "48", "180", "正常"],
        ["db-replica-2", "华北", "7", "46", "160", "正常"],
        ["cache-01", "华东", "31", "88", "9600", "正常"],
        ["cache-02", "华南", "28", "85", "8700", "正常"],
        ["queue-01", "华北", "19", "52", "760", "正常"],
        ["worker-01", "华东", "94", "77", "40", "繁忙"],
        ["worker-02", "华南", "5", "22", "0", "离线"],
        ["gateway-01", "华北", "61", "55", "6100", "正常"],
        ["monitor-01", "华东", "14", "29", "95", "正常"]
    ]
}

func serverSummary(rows: Array<Array<String>>, index: Int64): String {
    if (index < 0 || index >= rows.size) {
        return "未选择 · 点击任意行查看详情"
    }
    let row = rows[index]
    "${row[0]} · ${row[1]} · CPU ${row[2]}% · 内存 ${row[3]}% · ${row[4]} 连接 · ${row[5]}"
}
