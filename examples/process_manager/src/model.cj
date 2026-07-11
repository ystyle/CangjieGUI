/*
 * 进程管理器的共享状态与刷新常量。
 *
 * 视图层只读取这里的 State/DerivedState：快照进度、字节数说明与“N 秒前刷新”
 * 全部由源状态派生，写入 output 或帧计数后无需手工同步任何展示字段。
 */
package cui_process_manager

import cui.{DerivedState, State, derive}

/* 自动刷新节奏。 */
struct Refresh {
    /** 两次自动刷新的最小间隔：tasklist 枚举全部进程有成本，5 秒足够跟上变化。 */
    static let INTERVAL_MS: UInt64 = 5000
    /** 毫秒到秒的换算基数，避免文案计算里出现裸写的 1000。 */
    static let MS_PER_SECOND: UInt64 = 1000
}

/* 快照大小进度条的参照刻度。 */
struct SnapshotGauge {
    /** 满格对应的快照字节数：典型 Windows 桌面的 tasklist 输出约为几万字节。 */
    static let FULL_BYTES: Float32 = 60000.0
}

class ProcessModel {
    let output = State<String>("正在载入进程快照……")
    let outputScroll = State<Float32>(0.0)
    let tab = State<Int64>(0)
    /** 当前帧的启动毫秒计数，tick 每帧写入，是“几秒前”文案的时间基准。 */
    let nowTick = State<UInt64>(0)
    /** 上一份快照真正上屏时的帧计数；0 表示还没有任何快照完成。 */
    let refreshedTick = State<UInt64>(0)
    /** 上一次发起刷新请求的帧计数，供自动刷新做节流判断。 */
    let requestedTick = State<UInt64>(0)
    /** 快照大小换算成的进度条占比，由 output 派生。 */
    let snapshotFraction: DerivedState<Float32>
    /** 快照字节数说明文字，由 output 派生。 */
    let snapshotBytes: DerivedState<String>
    /** 距上次刷新完成的秒数文案，由当前帧与完成帧两个计数派生。 */
    let refreshAge: DerivedState<String>

    init() {
        this.snapshotFraction = this
            .output
            .map<Float32>({text => clampUnit(Float32(text.size) / SnapshotGauge.FULL_BYTES)})
        this.snapshotBytes = this.output.map<String>({text => "tasklist 返回 ${text.size} 字节"})
        this.refreshAge = derive(this.nowTick, this.refreshedTick, {now, done => refreshAgeText(now, done)})
    }
}

/*
 * 把“当前帧 − 上次刷新完成”换算成状态栏文案。elapsedMs 是程序启动至今的绝对
 * 毫秒数，直接展示毫无意义，必须与完成时刻相减才是“距上次刷新”的真实时长。
 */
func refreshAgeText(now: UInt64, done: UInt64): String {
    if (done == 0) {
        return "正在启动"
    }
    // 完成帧内 now == done；显式钳制以防任何次序意外触发无符号下溢。
    let age = if (now >= done) {
        now - done
    } else {
        UInt64(0)
    }
    "${age / Refresh.MS_PER_SECOND} 秒前刷新"
}

/** 进度条占比只在 [0, 1] 内有意义，超长快照一律视为满格。 */
func clampUnit(value: Float32): Float32 {
    if (value > 1.0) {
        1.0
    } else if (value < 0.0) {
        0.0
    } else {
        value
    }
}
