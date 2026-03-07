import Testing
@testable import AngelLiveCore

// MARK: - semverCompare Tests

@Suite("semverCompare")
struct SemverCompareTests {

    @Test("equal versions return 0")
    func equal() {
        #expect(semverCompare("1.0.0", "1.0.0") == 0)
        #expect(semverCompare("0.0.0", "0.0.0") == 0)
        #expect(semverCompare("12.34.56", "12.34.56") == 0)
    }

    @Test("major version difference")
    func majorDiff() {
        #expect(semverCompare("2.0.0", "1.0.0") > 0)
        #expect(semverCompare("1.0.0", "2.0.0") < 0)
    }

    @Test("minor version difference")
    func minorDiff() {
        #expect(semverCompare("1.2.0", "1.1.0") > 0)
        #expect(semverCompare("1.1.0", "1.2.0") < 0)
    }

    @Test("patch version difference")
    func patchDiff() {
        #expect(semverCompare("1.0.2", "1.0.1") > 0)
        #expect(semverCompare("1.0.1", "1.0.2") < 0)
    }

    @Test("short version strings are zero-padded")
    func shortVersions() {
        #expect(semverCompare("1", "1.0.0") == 0)
        #expect(semverCompare("1.2", "1.2.0") == 0)
        #expect(semverCompare("2", "1.9.9") > 0)
    }

    @Test("non-numeric parts treated as 0")
    func nonNumeric() {
        // "abc" → Int("abc") ?? 0 → 0, so "1.0.abc" == "1.0.0"
        #expect(semverCompare("1.0.0", "1.0.abc") == 0)
        #expect(semverCompare("abc.0.0", "0.0.0") == 0)
    }

    @Test("empty string treated as 0.0.0")
    func emptyString() {
        #expect(semverCompare("", "") == 0)
        #expect(semverCompare("0.0.1", "") > 0)
    }
}

// MARK: - PlatformCapability Cache Tests

@Suite("PlatformCapability cache")
struct PlatformCapabilityCacheTests {

    @Test("invalidateCache does not crash when cache is empty")
    func invalidateEmpty() {
        PlatformCapability.invalidateCache()
        // 不崩溃即通过
    }

    @Test("invalidateCache can be called multiple times")
    func invalidateMultiple() {
        PlatformCapability.invalidateCache()
        PlatformCapability.invalidateCache()
        PlatformCapability.invalidateCache()
    }
}

// MARK: - Logger Tests

@Suite("Logger")
struct LoggerTests {

    @Test("LogLevel ordering")
    func levelOrdering() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
    }

    @Test("plugin category exists")
    func pluginCategory() {
        let category = LogCategory.plugin
        #expect(category.rawValue == "Plugin")
    }
}
