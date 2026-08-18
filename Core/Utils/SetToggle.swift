import Foundation

/// Inserts `item` into `set` if absent, removes it if present — the standard "tap to toggle a
/// filter chip" interaction, previously hand-rolled identically in Pantry's and Generate's filter
/// sheets.
func toggleSet<T: Hashable>(_ set: inout Set<T>, _ item: T) {
    if set.contains(item) {
        set.remove(item)
    } else {
        set.insert(item)
    }
}
