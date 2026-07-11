package cui.core

import sdl.{Rect, Size, UiEvent}
import std.collection.ArrayList

/*
 * Declarative builder support.
 *
 * The UI tree is described with trailing-lambda blocks (see VStack, HStack, Panel).
 * Each concrete widget registers itself with the innermost open block by calling
 * `emit` from its constructor, so a block such as
 *
 *     VStack {
 *         Label("Title")
 *         Button("OK") { => save() }
 *     }
 *
 * collects the Label and Button as the stack's children with no explicit array.
 * Ordinary control flow works inside a block because each statement simply runs:
 *
 *     VStack {
 *         for (row in rows) { buttonRow(row) }
 *         if (expanded) { detailPanel() }
 *     }
 *
 * The stack of open blocks is module-private state. That is safe here: the UI runs on
 * a single thread and the whole tree is rebuilt top to bottom each frame, and every
 * block balances its push and pop through `buildChildren`.
 */
var openBlocks = ArrayList<ArrayList<Widget>>()
var activeStateStore: ?StateStore = None

/*
 * Register a freshly constructed widget with the enclosing builder block. Every widget
 * constructor calls this. Outside any block (for example a widget built to be stored
 * and reused) it is a no-op, so widgets stay ordinary values. Pass an existing widget
 * to place it explicitly: `VStack { for (w in built) { emit(w) } }`.
 */
public func emit(widget: Widget): Unit {
    if (!openBlocks.isEmpty()) {
        openBlocks[openBlocks.size - 1].add(widget)
    }
}

/*
 * A modifier is evaluated immediately after the expression that emitted its child. Find
 * that exact child in the active block and replace it with the decorated node. Searching
 * backwards also keeps modifiers safe when a stored widget is decorated after another
 * declaration in the same block.
 */
protected func replaceLastEmission(original: Widget, replacement: Widget): Unit {
    if (openBlocks.isEmpty()) {
        return
    }
    let block = openBlocks[openBlocks.size - 1]
    var i = block.size - 1
    while (i >= 0) {
        if (let Some(candidate) <- (block[i] as Object)) {
            if (let Some(source) <- (original as Object)) {
                if (refEq(candidate, source)) {
                    block[i] = replacement
                    return
                }
            }
        }
        i -= 1
    }
    if (!block.isEmpty()) {
        block[block.size - 1] = replacement
    }
}

/*
 * Run a builder block and return every widget it declares, in order.
 */
protected func buildChildren(body: () -> Unit): Array<Widget> {
    let block = ArrayList<Widget>()
    openBlocks.add(block)
    try {
        body()
    } finally {
        openBlocks.remove(at: openBlocks.size - 1)
    }
    block.toArray()
}

/*
 * Run a builder block that wraps a single child. No declaration yields an empty
 * placeholder; several are stacked vertically.
 */
protected func buildChild(body: () -> Unit): Widget {
    let children = buildChildren(body)
    match (children.size) {
        case 0 => EmptyView()
        case 1 => children[0]
        case _ => Stack(Axis.Vertical, children)
    }
}

/** Builds an application root while retaining and pruning its keyed local state. */
protected func buildRoot(body: () -> Unit, stateStore: StateStore): Widget {
    let previous = activeStateStore
    activeStateStore = Some(stateStore)
    stateStore.beginBuild()
    try {
        try {
            let root = buildChild(body)
            stateStore.finishBuild()
            root
        } catch (error: Exception) {
            stateStore.cancelBuild()
            throw error
        }
    } finally {
        activeStateStore = previous
    }
}

/** Builds one identity scope without changing the normal widget collection rules. */
protected func buildKeyedChild(key: String, body: () -> Unit): Widget {
    match (activeStateStore) {
        case Some(store) =>
            store.pushScope(key)
            try {
                buildChild(body)
            } finally {
                store.popScope()
            }
        case None => buildChild(body)
    }
}

/** Throws `IllegalStateException` when no application root is being built. */
protected func currentStateStore(): StateStore {
    match (activeStateStore) {
        case Some(store) => store
        case None => throw IllegalStateException("rememberState must be called while building a DesktopApp view")
    }
}

/** Retains implicit control state when building an app and falls back for headless use. */
protected func localState<T>(key: String, initial: () -> T): State<T> {
    match (activeStateStore) {
        case Some(store) => store.remember<T>(key, initial)
        case None => State<T>(initial())
    }
}

/*
 * A focus/press identity for a control that declared no explicit id. During a build the
 * identity is scoped by `Keyed` and deduplicated in declaration order, so identical
 * default names (two icon-only buttons, two "确定" buttons) never share interaction
 * state. Outside a build the base name is returned unchanged.
 */
protected func controlIdentity(base: String): String {
    match (activeStateStore) {
        case Some(store) => store.uniqueControlId(base)
        case None => base
    }
}

/*
 * Zero-size filler used where a child is required but none was declared. It never
 * emits, so `buildChild` can create it while an outer block is still open.
 */
class EmptyView <: Widget {
    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
