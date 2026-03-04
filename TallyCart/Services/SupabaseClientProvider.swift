import Foundation
import Supabase

enum SupabaseConfigError: LocalizedError {
    case missingURL
    case missingAnonKey
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Missing SUPABASE_URL in Info.plist."
        case .missingAnonKey:
            return "Missing SUPABASE_ANON_KEY in Info.plist."
        case .invalidURL:
            return "SUPABASE_URL is not a valid URL."
        }
    }
}

final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()

    // Update this scheme if you change the CFBundleURLSchemes value in Info.plist.
    static let callbackScheme = "tallycart"

    let client: SupabaseClient?
    let configurationError: SupabaseConfigError?

    private init() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty else {
            client = nil
            configurationError = .missingURL
            return
        }
        guard let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !anonKey.isEmpty else {
            client = nil
            configurationError = .missingAnonKey
            return
        }
        guard let url = URL(string: urlString) else {
            client = nil
            configurationError = .invalidURL
            return
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        configurationError = nil
    }
}
