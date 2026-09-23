import Foundation

/// Fetches usage on a timer and keeps the last successful snapshot around.
final class RefreshService {
    enum Status: Equatable {
        case idle
        case loading
        case ok
        case failed(String)
        case needsSetup
    }

    /// Last successful snapshot, if any.
    private(set) var snapshot: UsageSnapshot?
    /// Current fetch status.
    private(set) var status: Status = .idle

    /// Called on the main thread whenever `snapshot` or `status` changes.
    var onUpdate: (() -> Void)?

    private let api: OpenCodeAPI
    private let credentials: CredentialStore
    private let settings: Settings
    private var timer: Timer?
    private var isRefreshing = false

    init(
        api: OpenCodeAPI = .shared,
        credentials: CredentialStore = .shared,
        settings: Settings = .shared
    ) {
        self.api = api
        self.credentials = credentials
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

        Task { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await self.api.fetchUsage(apiKey: resolved.key)
                await MainActor.run {
                    self.settings.cachedUsage = fetched
                    self.snapshot = fetched
                    self.status = .ok
                    self.isRefreshing = false
                    self.onUpdate?()
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run {
                    self.isRefreshing = false
                    self.status = .failed(message)
                    self.onUpdate?()
                }
            }
        }
    }

    /// Re-schedules the timer using the current settings.
    func rescheduleTimer() {
        scheduleTimer()
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
}
