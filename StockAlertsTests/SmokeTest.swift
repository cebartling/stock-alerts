import Testing

struct SmokeTest {
    @Test
    func testTargetRuns() {
        #expect(1 + 1 == 2)
    }
}
