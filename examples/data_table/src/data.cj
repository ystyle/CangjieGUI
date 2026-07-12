/*
 * 表格的列定义与种子数据。行是 `Array<String>` 单元格，按列索引；数值列声明 `numeric: true`，
 * 由 `Table` 右对齐并按数值（而非字典序）排序。
 */
package cui_data_table

import cui.TableColumn

func serverColumns(): Array<TableColumn> {
    [
        TableColumn("主机名", 180.0),
        TableColumn("区域", 100.0),
        TableColumn("CPU %", 100.0, numeric: true),
        TableColumn("内存 %", 100.0, numeric: true),
        TableColumn("连接数", 120.0, numeric: true),
        TableColumn("状态", 110.0)
    ]
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
