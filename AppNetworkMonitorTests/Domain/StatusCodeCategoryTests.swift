import Testing
@testable import AppNetworkMonitor

struct StatusCodeCategoryTests {

    @Test func zeroIsPending() {
        #expect(StatusCodeCategory.category(for: 0) == .pending)
    }

    @Test func twoHundredsAreSuccess() {
        #expect(StatusCodeCategory.category(for: 200) == .success)
        #expect(StatusCodeCategory.category(for: 204) == .success)
        #expect(StatusCodeCategory.category(for: 299) == .success)
    }

    @Test func threeHundredsAreRedirection() {
        #expect(StatusCodeCategory.category(for: 300) == .redirection)
        #expect(StatusCodeCategory.category(for: 301) == .redirection)
        #expect(StatusCodeCategory.category(for: 399) == .redirection)
    }

    @Test func fourHundredsAreClientError() {
        #expect(StatusCodeCategory.category(for: 400) == .clientError)
        #expect(StatusCodeCategory.category(for: 404) == .clientError)
        #expect(StatusCodeCategory.category(for: 499) == .clientError)
    }

    @Test func fiveHundredsAreServerError() {
        #expect(StatusCodeCategory.category(for: 500) == .serverError)
        #expect(StatusCodeCategory.category(for: 599) == .serverError)
    }

    @Test func unknownCodesFallToClientError() {
        #expect(StatusCodeCategory.category(for: 999) == .clientError)
        #expect(StatusCodeCategory.category(for: -1) == .clientError)
    }

    @Test func allCasesHaveStableId() {
        for category in StatusCodeCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }
}
