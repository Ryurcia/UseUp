import Foundation

/// Generates a candidate default username in the `chef_<random>` format used for all new
/// accounts. Not guaranteed unique on its own — callers must verify against Supabase and retry
/// with a fresh candidate on collision (see `AppSession.finalizeAccountSetup`).
func generateChefUsername() -> String {
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    let suffix = String((0..<8).map { _ in alphabet.randomElement()! })
    return "chef_\(suffix)"
}
