import Foundation

enum AppStateStore {
    static let storageKey = "tallycart_app_state"

    static func load() -> AppState {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return .empty }
        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return .empty
        }
    }

    static func persist(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
