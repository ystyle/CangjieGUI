package sdl

/*
 * Clip bookkeeping is renderer-side state independent of any SDL device, so a headless
 * renderer exercises the stack semantics directly: push intersects with the active clip,
 * pop restores the previous one, and a new scene always starts unclipped.
 */
@Test
func clipStackIntersectsOnPushAndRestoresOnPop(): Unit {
    let renderer = Renderer.headless()
    @Expect(renderer.currentClip().isNone())

    renderer.pushClip(Rect(0.0, 0.0, 100.0, 100.0))
    renderer.pushClip(Rect(60.0, 40.0, 100.0, 100.0))
    let nested = renderer.currentClip().getOrThrow()
    @Expect(nested.x, Float32(60.0))
    @Expect(nested.y, Float32(40.0))
    @Expect(nested.w, Float32(40.0))
    @Expect(nested.h, Float32(60.0))

    renderer.popClip()
    let outer = renderer.currentClip().getOrThrow()
    @Expect(outer.x, Float32(0.0))
    @Expect(outer.w, Float32(100.0))

    renderer.popClip()
    @Expect(renderer.currentClip().isNone())
}

@Test
func disjointNestedClipDegeneratesToZeroArea(): Unit {
    let renderer = Renderer.headless()
    renderer.pushClip(Rect(0.0, 0.0, 50.0, 50.0))
    renderer.pushClip(Rect(80.0, 80.0, 20.0, 20.0))

    let clip = renderer.currentClip().getOrThrow()
    @Expect(clip.w, Float32(0.0))
    @Expect(clip.h, Float32(0.0))

    renderer.popClip()
    renderer.popClip()
}

@Test
func beginSceneDropsAnyLeakedClip(): Unit {
    let renderer = Renderer.headless()
    renderer.pushClip(Rect(0.0, 0.0, 10.0, 10.0))

    renderer.beginScene(100.0, 100.0, Color.rgb(0, 0, 0))

    @Expect(renderer.currentClip().isNone())
}
