package cui.core

// Clamp the timestep so a frame hitch (a long pause between frames) cannot inject a huge
// impulse and make the integration diverge; motion just proceeds at up to this step.
private let SPRING_MAX_STEP_MS: Float32 = 40.0
private let SPRING_SETTLE_POS: Float32 = 0.0005
private let SPRING_SETTLE_VEL: Float32 = 0.001

/*
 * A spring-damper that eases a value toward a target across frames. CUI redraws every frame,
 * so a widget ticks one in `draw` with the frame delta and reads `value` — smooth state
 * transitions with no separate animation timer. Integration is semi-implicit Euler with a
 * clamped timestep for stability, and it settles exactly onto the target so an idle spring
 * costs nothing.
 *
 * Defaults are tuned for UI toggles: snappy, with a barely-perceptible settle. Because a
 * spring initialised at its target is immediately settled, a control that starts a spring at
 * its current state animates only on later changes — static renders (snapshots) are unchanged.
 */
public class Spring {
    private var current: Float32
    private var velocity: Float32 = 0.0
    private var goal: Float32
    private let stiffness: Float32
    private let damping: Float32

    public init(value: Float32, stiffness!: Float32 = 210.0, damping!: Float32 = 24.0) {
        this.current = value
        this.goal = value
        this.stiffness = stiffness
        this.damping = damping
    }

    /** The current animated value. */
    public prop value: Float32 {
        get() {
            current
        }
    }

    /** Sets the value the spring eases toward. */
    public func target(value: Float32): Unit {
        goal = value
    }

    /** Snaps immediately to `value` with no animation (initial placement, or a hard reset). */
    public func reset(value: Float32): Unit {
        current = value
        goal = value
        velocity = 0.0
    }

    /** Whether the spring has reached its target and stopped. */
    public func settled(): Bool {
        current == goal && velocity == 0.0
    }

    /*
     * The common draw-time step in one call: retarget, advance by the frame delta, and read the
     * new value. `let t = spring.animate(target: goal, deltaMs: ctx.frame.deltaMs)` replaces the
     * three-line target/tick/value dance a widget otherwise writes every frame.
     */
    public func animate(target!: Float32, deltaMs!: UInt64): Float32 {
        goal = target
        tick(deltaMs)
        current
    }

    /** Advances the spring by `deltaMs` milliseconds toward the target. */
    public func tick(deltaMs: UInt64): Unit {
        if (settled()) {
            return
        }
        let dt = min(Float32(Int64(deltaMs)), SPRING_MAX_STEP_MS) / 1000.0
        if (dt <= 0.0) {
            return
        }
        let force = -stiffness * (current - goal) - damping * velocity
        velocity += force * dt
        current += velocity * dt
        if (springMagnitude(current - goal) < SPRING_SETTLE_POS && springMagnitude(velocity) < SPRING_SETTLE_VEL) {
            current = goal
            velocity = 0.0
        }
    }
}

private func springMagnitude(value: Float32): Float32 {
    if (value < 0.0) {
        -value
    } else {
        value
    }
}
