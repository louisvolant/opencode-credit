import Foundation

runSuite("OpenCode Credit core tests") {
    UsageTests.run()
}

print("")
if failedChecks == 0 {
    print("✓ \(totalChecks) checks passed")
    exit(0)
} else {
    print("✗ \(failedChecks) of \(totalChecks) checks failed")
    exit(1)
}
