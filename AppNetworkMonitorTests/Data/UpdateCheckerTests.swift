import Testing
@testable import AppNetworkMonitor

struct UpdateCheckerTests {

    // MARK: - compareVersions

    @Test func equalVersionsAreNotUpdates() {
        #expect(!UpdateChecker.compareVersions(current: "1.0.0", latest: "1.0.0"))
    }

    @Test func higherPatchIsUpdate() {
        #expect(UpdateChecker.compareVersions(current: "1.0.0", latest: "1.0.1"))
    }

    @Test func higherMinorIsUpdate() {
        #expect(UpdateChecker.compareVersions(current: "1.0.5", latest: "1.1.0"))
    }

    @Test func higherMajorIsUpdate() {
        #expect(UpdateChecker.compareVersions(current: "1.9.9", latest: "2.0.0"))
    }

    @Test func lowerVersionIsNotUpdate() {
        #expect(!UpdateChecker.compareVersions(current: "2.0.0", latest: "1.9.9"))
    }

    @Test func missingComponentsTreatedAsZero() {
        #expect(UpdateChecker.compareVersions(current: "1.0", latest: "1.0.1"))
        #expect(!UpdateChecker.compareVersions(current: "1.0.0", latest: "1.0"))
    }

    @Test func preReleaseSuffixIsStripped() {
        #expect(!UpdateChecker.compareVersions(current: "4.0.0", latest: "4.0.0-beta.1"))
        #expect(UpdateChecker.compareVersions(current: "4.0.0-beta.1", latest: "4.0.1"))
    }

    @Test func buildMetadataSuffixIsStripped() {
        #expect(!UpdateChecker.compareVersions(current: "1.0.0", latest: "1.0.0+abc123"))
    }

    // MARK: - numericComponents

    @Test func numericComponentsParsesPlainSemver() {
        #expect(UpdateChecker.numericComponents(of: "1.2.3") == [1, 2, 3])
    }

    @Test func numericComponentsStripsPreRelease() {
        #expect(UpdateChecker.numericComponents(of: "1.2.3-beta.1") == [1, 2, 3])
    }

    @Test func numericComponentsStripsBuildMetadata() {
        #expect(UpdateChecker.numericComponents(of: "1.2.3+exp.sha.5114") == [1, 2, 3])
    }

    @Test func numericComponentsHandlesEmptyString() {
        #expect(UpdateChecker.numericComponents(of: "") == [])
    }

    @Test func numericComponentsSkipsNonNumeric() {
        #expect(UpdateChecker.numericComponents(of: "1.x.3") == [1, 3])
    }
}
