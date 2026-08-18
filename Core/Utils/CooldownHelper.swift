import Foundation

/// Days remaining in a cooldown window that started at `date`, or `nil` if the cooldown has
/// already elapsed (or there's no `date` to cool down from). Shared by nickname (30-day) and
/// dietary-preference (15-day) edit cooldowns.
func cooldownRemainingDays(since date: Date?, cooldownDays: Int) -> Int? {
    guard let date else { return nil }
    let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    let remaining = cooldownDays - daysSince
    return remaining > 0 ? remaining : nil
}
