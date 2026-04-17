import Testing
@testable import AppNetworkMonitor

struct StringExtensionsTests {

    @Test func prettyPrintsValidJsonObject() {
        let pretty = "{\"a\":1,\"b\":2}".prettyPrintedJSON
        #expect(pretty != nil)
        #expect(pretty!.contains("\n"))
    }

    @Test func prettyPrintsValidJsonArray() {
        let pretty = "[1,2,3]".prettyPrintedJSON
        #expect(pretty != nil)
        #expect(pretty!.contains("\n"))
    }

    @Test func returnsNilForInvalidJson() {
        #expect("not json".prettyPrintedJSON == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect("".prettyPrintedJSON == nil)
    }

    @Test func doesNotEscapeForwardSlashes() {
        let pretty = "{\"url\":\"https://x.com/y\"}".prettyPrintedJSON
        #expect(pretty != nil)
        #expect(pretty!.contains("https://x.com/y"))
        #expect(!pretty!.contains("\\/"))
    }
}
