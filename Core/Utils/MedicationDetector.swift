import Foundation

/// Blocks medication/narcotic names from being logged as pantry ingredients — this app tracks
/// food only. Word-level check (not substring), same shape as `PantryStaples.isStaple`, splitting
/// on hyphens too so brand names like "Pepto-Bismol" still match on "pepto"/"bismol".
enum MedicationDetector {
    private static let terms: Set<String> = [
        // Generic category words — unambiguous, not plausible food names. Deliberately excludes
        // words that double as real food terms (e.g. "syrup", "cream", "drops") to avoid flagging
        // "maple syrup" or "heavy cream".
        "medication", "medications", "medicine", "medicines", "pill", "pills",
        "tablet", "tablets", "capsule", "capsules", "prescription", "narcotic",
        "narcotics", "drug", "drugs", "antibiotic", "antibiotics", "otc",
        // Common OTC brands/generics
        "acetaminophen", "tylenol", "ibuprofen", "advil", "motrin", "aspirin",
        "naproxen", "aleve", "excedrin", "benadryl", "claritin", "zyrtec", "allegra",
        "sudafed", "nyquil", "dayquil", "mucinex", "robitussin", "pepto", "bismol",
        "tums", "pepcid", "zantac", "prilosec", "imodium", "dramamine", "melatonin",
        // Prescription / controlled substances / narcotics
        "oxycodone", "oxycontin", "hydrocodone", "vicodin", "percocet", "morphine",
        "fentanyl", "methadone", "codeine", "adderall", "ritalin", "xanax", "valium",
        "ativan", "klonopin", "ambien", "prozac", "zoloft", "lexapro", "wellbutrin",
        "insulin", "metformin", "lipitor", "amoxicillin", "penicillin", "azithromycin",
        "warfarin", "viagra", "cialis", "heroin", "cocaine", "methamphetamine",
        "marijuana", "cannabis", "lsd", "mdma", "ecstasy",
    ]

    static func isMedication(_ name: String) -> Bool {
        let words = name.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " -"))
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        return words.contains { terms.contains($0) }
    }
}
