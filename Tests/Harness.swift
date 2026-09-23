import Foundation

// A deliberately tiny test harness: no XCTest, no SwiftPM, so the tests can be
// compiled with a single `swiftc` invocation from the Command Line Tools.

var totalChecks = 0
var failedChecks = 0

func check(
    _ condition: Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    totalChecks += 1
    if !condition {
        failedChecks += 1
        print("  ✗ \(message)  (\(file):\(line))")
    }
}

func checkEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    totalChecks += 1
    if actual != expected {
        failedChecks += 1
        print("  ✗ \(message)\n      expected: \(expected)\n      actual:   \(actual)  (\(file):\(line))")
    }
}

func runSuite(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

func runAsyncSuite(_ name: String, _ body: () async -> Void) async {
    print("• \(name)")
    await body()
}
