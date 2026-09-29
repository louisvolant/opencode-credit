import Foundation

/// Fetches usage (and the Zen balance when connected) on a timer, and keeps
/// the last successful values around.
final class RefreshService {
    enum Status: Equatable {
        case idle
        case loading
        case ok
        case failed(String)
        case needsSetup
    }

    /// Immutable result of one refresh pass, safe to hand to the main actor.
    private struct Outcome: Sendable {
        let usage: UsageSnapshot?
        let usageError: String?
        let balance: ZenBalance?
        let balanceError: String?
        let sessionExpired: Bool
    }

    /// Last successful Go usage snapshot, if any.
    private(set) var snapshot: UsageSnapshot?
    /// Last successful Zen balance, if any.
    private(set) var balance: ZenBalance?
    /// Last balance error, if any.
    private(set) var balanceError: String?
    /// Current fetch status for the Go usage.
    private(set) var status: Status = .idle

    /// Called on the main thread whenever something changes.
    var onUpdate: (() -> Void)?

    private let api: OpenCodeAPI
    private let credentials: CredentialStore
    private let zenSession: ZenSession
    private let settings: Settings
    private var timer: Timer?
    private var isRefreshing = false

    init(
        api: OpenCodeAPI = .shared,
        credentials: CredentialStore = .shared,
        zenSession: ZenSession = .shared,
        settings: Settings = .shared
    ) {
        self.api = api
        self.credentials = credentials
        self.zenSession = zenSession
        self.settings = settings
    }

    /// Loads the cached snapshot, performs an immediate refresh and starts the
    /// repeating timer.
    func start() {
        if let cached = settings.cachedUsage, cached.isReachable {
            snapshot = cached
            status = .ok
            onUpdate?()
        }
        refresh()
        scheduleTimer()
    }

    func refresh() {
        guard !isRefreshing else { return }

        guard let resolved = credentials.resolve() else {
            status = .needsSetup
            onUpdate?()
            return
        }

        isRefreshing = true
        status = .loading
        onUpdate?()

        let session = zenSession.credentials

        Task { [weak self] in
            guard let self else { return }

            var usage: UsageSnapshot?
            var usageError: String?
            var balance: ZenBalance?
            var balanceError: String?
            var sessionExpired = false

            do {
                usage = try await self.api.fetchUsage(apiKey: resolved.key)
            } catch {
                usageError = Self.message(for: error)
            }

            if let session {
                do {
                    // The console is client-side rendered, so read the DOM of
                    // the Go page in a hidden web view rather than scraping it.
                    balance = try await ConsoleReader().run(workspaceID: session.workspaceID)
                } catch {
                    balanceError = Self.message(for: error)
                    if let apiError = error as? OpenCodeAPIError, apiError == .sessionExpired {
                        sessionExpired = true
                    }
                }
            }

            // Freeze the outcome so the main-actor closure only captures
            // immutable values.
            let outcome = Outcome(
                usage: usage,
                usageError: usageError,
                balance: balance,
                balanceError: balanceError,
                sessionExpired: sessionExpired
            )

            await MainActor.run {
                self.isRefreshing = false

                if let fetched = outcome.usage {
                    self.settings.cachedUsage = fetched
                    self.snapshot = fetched
                    self.status = .ok
                    NotificationManager.shared.evaluate(
                        snapshot: fetched,
                        enabled: self.settings.notificationsEnabled,
                        threshold: self.settings.notificationThreshold
                    )
                } else if let error = outcome.usageError {
                    self.status = .failed(error)
                }

                if let fetched = outcome.balance {
                    self.balance = fetched
                    self.balanceError = nil
                } else if let error = outcome.balanceError {
                    self.balanceError = error
                }

                if outcome.sessionExpired {
                    // Keep the captured session: a single failed read must not
                    // destroy a valid cookie. The user can sign in again from
                    // Settings to refresh it.
                    self.balance = nil
                    self.balanceError = OpenCodeAPIError.sessionExpired.errorDescription
                }

                self.onUpdate?()
            }
        }
    }

    /// Re-schedules the timer using the current settings.
    func rescheduleTimer() {
        scheduleTimer()
    }

    /// Toggles the "Extra Usage" switch by clicking the real switch in the
    /// console (which lets the console perform its own CSRF-protected request).
    func setUseCredit(_ enabled: Bool) {
        guard let session = zenSession.credentials else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let updated = try await ConsoleReader(request: .setExtraUsage(enabled))
                    .run(workspaceID: session.workspaceID)
                await MainActor.run {
                    self.balance = updated
                    self.balanceError = nil
                    self.onUpdate?()
                }
            } catch {
                await MainActor.run {
                    self.balanceError = Self.message(for: error)
                    self.onUpdate?()
                }
            }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(max(1, settings.refreshIntervalMinutes) * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // .common keeps the timer firing while menus and popovers are tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
