import Foundation

enum AppError: LocalizedError, Equatable {
    case network(String)
    case server(String)
    case invalidState(String)
    case validation(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .server(let message):
            return message
        case .invalidState(let message):
            return message
        case .validation(let message):
            return message
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var userMessage: String {
        errorDescription ?? "Something went wrong. Please try again."
    }
}
