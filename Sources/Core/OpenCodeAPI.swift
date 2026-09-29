import Foundation

/// Errors surfaced by the OpenCode API client. Messages are user facing.
enum OpenCodeAPIError: LocalizedError, Equatable, Sendable {
    case missingKey
    case unauthorized
    case noGoSubscription
    case rateLimited
    case missingSession
    case sessionExpired
    case balanceUnavailable
    case http(status: Int)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No API key configured."
        case .unauthorized:
            return "The API key was rejected. Check it in Settings."
        case .noGoSubscription:
            return "No OpenCode Go subscription found for this key."
        case .rateLimited:
            return "Too many requests. Try again in a moment."
        case .missingSession:
            return "Sign in to OpenCode to see your credit balance."
        case .sessionExpired:
            return "Your OpenCode session expired. Sign in again."
        case .balanceUnavailable:
            return "Could not read the credit balance from the console."
        case .http(let status):
            return "The server returned HTTP \(status)."
        case .decoding(let detail):
            return "Could not read the response: \(detail)"
        case .network(let detail):
            return "Network error: \(detail)"
        }
    }
}

/// Client for the official OpenCode Go usage endpoint.
///
/// The Zen credit is read separately by `ConsoleReader`, because the console is
/// client-side rendered and exposes no usable API outside a browser.
final class OpenCodeAPI {
    static let shared = OpenCodeAPI()

    private let session: URLSession
    private let usageURL = URL(string: "https://opencode.ai/zen/go/v1/usage")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the rolling / weekly / monthly Go usage windows.
    func fetchUsage(apiKey: String) async throws -> UsageSnapshot {
        guard !apiKey.isEmpty else { throw OpenCodeAPIError.missingKey }

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OpenCodeCredit/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await perform(request)

        switch response.statusCode {
        case 200:
            break
        case 401, 403:
            throw OpenCodeAPIError.unauthorized
        case 404:
            // The endpoint only exists for accounts with a Go subscription.
            throw OpenCodeAPIError.noGoSubscription
        case 429:
            throw OpenCodeAPIError.rateLimited
        default:
            throw OpenCodeAPIError.http(status: response.statusCode)
        }

        do {
            return try UsageSnapshot.decode(from: data)
        } catch {
            throw OpenCodeAPIError.decoding(error.localizedDescription)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OpenCodeAPIError.network("Unexpected response")
            }
            return (data, http)
        } catch let error as OpenCodeAPIError {
            throw error
        } catch {
            throw OpenCodeAPIError.network(error.localizedDescription)
        }
    }
}
