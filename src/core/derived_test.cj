package cui.core

struct TestProfile {
    let name: String
    let subscribed: Bool

    init(name: String, subscribed: Bool) {
        this.name = name
        this.subscribed = subscribed
    }
}

@Test
func derivedStateCachesUntilSourceChanges(): Unit {
    let count = State<Int64>(2)
    let calls = State<Int64>(0)
    let doubled = count.map<Int64>({
        value =>
        calls.value += 1
        value * 2
    })

    @Expect(doubled.value, Int64(4))
    @Expect(doubled.value, Int64(4))
    @Expect(calls.value, Int64(1))

    count.value = 5
    @Expect(doubled.value, Int64(10))
    @Expect(calls.value, Int64(2))
}

@Test
func derivedStateCombinesSeveralSources(): Unit {
    let quantity = State<Int64>(2)
    let unitPrice = State<Int64>(30)
    let total = derive(quantity, unitPrice, {q, p => q * p})

    @Expect(total.value, Int64(60))

    unitPrice.value = 40
    @Expect(total.value, Int64(80))

    let beforeRevision = total.revision
    quantity.value = 3
    @Expect(total.value, Int64(120))
    @Expect(total.revision != beforeRevision)
}

@Test
func derivedStateObserverFollowsSourceAssignments(): Unit {
    let count = State<Int64>(1)
    let doubled = count.map<Int64>({value => value * 2})
    let received = State<Int64>(0)
    let observation = doubled.observe({previous, current => received.value = previous * 100 + current})

    count.value = 3
    @Expect(received.value, Int64(206))

    observation.close()
    count.value = 4
    @Expect(received.value, Int64(206))
    @Expect(observation.isClosed())
}

@Test
func bindingProjectsOneComponentBothWays(): Unit {
    let profile = State<TestProfile>(TestProfile("林", true))
    let name = profile.project<String>(get: {p => p.name}, set: {p, next => TestProfile(next, p.subscribed)})

    @Expect(name.value, "林")

    name.value = "陈"
    @Expect(profile.value.name, "陈")
    @Expect(profile.value.subscribed)

    let received = State<String>("")
    let observation = name.observe({_, current => received.value = current})
    profile.value = TestProfile("赵", false)
    @Expect(received.value, "赵")
    observation.close()
}

@Test
func setIfChangedSkipsEqualAssignments(): Unit {
    let value = State<Int64>(1)
    let notifications = State<Int64>(0)
    let observation = value.observe({_, _ => notifications.value += 1})

    @Expect(!value.setIfChanged(1))
    @Expect(notifications.value, Int64(0))

    @Expect(value.setIfChanged(2))
    @Expect(value.value, Int64(2))
    @Expect(notifications.value, Int64(1))
    observation.close()
}

// A callback that cancels observations and registers a new one DURING a notification must not
// corrupt the walk: notify iterates a snapshot, skips cancelled listeners via isActive, and a
// listener added mid-notification first sees the NEXT assignment.
@Test
func stateNotifySurvivesReentrantObserveAndClose(): Unit {
    let state = State<Int64>(0)
    let log = State<String>("")
    let second = State<?StateObservation<Int64>>(None)
    let third = State<?StateObservation<Int64>>(None)
    let _ = state.observe({_, current =>
        log.value = log.value + "a${current};"
        match (second.value) {
            case Some(observation) => observation.close()
            case None => ()
        }
        match (third.value) {
            case Some(observation) => observation.close()
            case None => ()
        }
        let _ = state.observe({_, c => log.value = log.value + "n${c};"})
    })
    second.value = Some(state.observe({_, current => log.value = log.value + "b${current};"}))
    third.value = Some(state.observe({_, current => log.value = log.value + "c${current};"}))

    // The callback cancels b/c mid-walk and registers n: no crash, no b/c call, no n call yet.
    state.value = 1
    @Expect(log.value, "a1;")

    // The next assignment reaches the survivors: the original listener plus the added one.
    state.value = 2
    @Expect(log.value, "a1;a2;n2;")
}
