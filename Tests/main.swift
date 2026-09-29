import Foundation

runSuite("OpenCode Credit core tests") {
    UsageTests.run()
    ConfigTests.run()
    FormattingTests.run()
    WorkspaceTests.run()
    SettingsTests.run()
    NotificationTests.run()
}

await runAsyncSuite("OpenCode Credit API tests") {
    await APIClientTests.run()
}

print("")
if failedChecks == 0 {
    print("✓ \(totalChecks) checks passed")
    exit(0)
} else {
    print("✗ \(failedChecks) of \(totalChecks) checks failed")
    exit(1)
}
