import Supabase
import Foundation

enum SupabaseManager {
    private static let supabaseURL = URL(string: "https://usycirewbjykxnwauaij.supabase.co")!
    private static let supabaseAnonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not set in Secrets.xcconfig")
        }
        return key
    }()

    static let client = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseAnonKey,
        options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
    )
}
