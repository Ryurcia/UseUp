import Supabase
import Foundation

enum SupabaseManager {
    private static let supabaseURL = URL(string: "https://usycirewbjykxnwauaij.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeWNpcmV3Ymp5a3hud2F1YWlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4OTg4NzUsImV4cCI6MjA4ODQ3NDg3NX0.-wWtPfCqw7cExy7_xSc3J35KeFvN7LWtRDGah-qLsSg"

    static let client = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseAnonKey,
        options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
    )
}
