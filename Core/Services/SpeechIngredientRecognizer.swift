import AVFoundation
import Speech

@available(iOS 26, *)
final class SpeechIngredientRecognizer {

    var onUpdate: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    private var tapInstalled = false

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: .current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    static func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            DispatchQueue.main.async { self.onError?("Speech recognition unavailable.") }
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                if let text = result?.bestTranscription.formattedString {
                    self?.onUpdate?(text)
                }
                if result?.isFinal == true,
                   let text = result?.bestTranscription.formattedString {
                    self?.onFinal?(text)
                }
                if let error, result == nil {
                    self?.onError?(error.localizedDescription)
                }
            }
        }

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        tapInstalled = true
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
    }

    // MARK: - Parsing

    // Maps spoken/abbreviated unit words to the label strings expected by UnitMeasurement.parse(from:)
    private static let unitMapping: [(spoken: String, label: String)] = [
        // Spoken forms
        ("kilograms", "kg"), ("kilogram", "kg"),
        ("grams", "g"), ("gram", "g"),
        ("ounces", "oz"), ("ounce", "oz"),
        ("fluid ounces", "fl oz"), ("fluid ounce", "fl oz"),
        ("pounds", "lb"), ("pound", "lb"),
        ("milliliters", "ml"), ("milliliter", "ml"),
        ("liters", "L"), ("liter", "L"),
        ("cups", "cups"), ("cup", "cups"),
        ("tablespoons", "tbsp"), ("tablespoon", "tbsp"),
        ("teaspoons", "tsp"), ("teaspoon", "tsp"),
        ("pieces", "pcs"), ("piece", "pcs"),
        // Abbreviations — handles attached forms like "500g", "2cups"
        ("g", "g"), ("kg", "kg"), ("oz", "oz"), ("fl oz", "fl oz"),
        ("lb", "lb"), ("lbs", "lb"),
        ("ml", "ml"), ("l", "L"),
        ("tbsp", "tbsp"), ("tsp", "tsp"), ("pcs", "pcs"),
    ]

    private static let leadingFillerWords: Set<String> = [
        "add", "i", "have", "need", "want", "put", "a", "an", "the", "some"
    ]

    /// Splits "500g" → ("500", "g"), "2.5" → ("2.5", ""), "eggs" → ("", "")
    private static func splitNumberAndUnit(_ word: String) -> (number: String, unit: String) {
        var numberEnd = word.startIndex
        var hasDigit = false
        for i in word.indices {
            let c = word[i]
            if c.isNumber {
                hasDigit = true
                numberEnd = word.index(after: i)
            } else if (c == "." || c == ",") && hasDigit {
                numberEnd = word.index(after: i)
            } else {
                break
            }
        }
        guard hasDigit else { return ("", "") }
        var number = String(word[..<numberEnd]).replacingOccurrences(of: ",", with: ".")
        if number.hasSuffix(".") { number = String(number.dropLast()) }
        return (number, String(word[numberEnd...]).lowercased())
    }

    /// Parses a spoken phrase into an ingredient name and a raw quantity string.
    /// - "500g of chicken breast"       → (name: "chicken breast", quantity: "500 g")
    /// - "I have 500g of chicken breast"→ (name: "chicken breast", quantity: "500 g")
    /// - "2 cups of flour"              → (name: "flour",           quantity: "2 cups")
    /// - "eggs"                         → (name: "eggs",            quantity: "")
    /// - "3 eggs"                       → (name: "eggs",            quantity: "3")
    static func parseIngredient(from text: String) -> (name: String, quantity: String) {
        var words = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        while let first = words.first, leadingFillerWords.contains(first.lowercased()) {
            words.removeFirst()
        }

        guard !words.isEmpty else { return (name: text, quantity: "") }

        let (numberStr, attachedUnit) = splitNumberAndUnit(words[0])

        // First word has no leading digit — whole text is the name
        guard !numberStr.isEmpty else {
            return (name: words.joined(separator: " "), quantity: "")
        }

        if !attachedUnit.isEmpty {
            // Attached unit: "500g", "2cups"
            if let mapping = unitMapping.first(where: { $0.spoken == attachedUnit }) {
                var nameWords = Array(words.dropFirst())
                if nameWords.first?.lowercased() == "of" { nameWords.removeFirst() }
                let name = nameWords.joined(separator: " ")
                let quantity = "\(numberStr) \(mapping.label)"
                return (name: name.isEmpty ? words.joined(separator: " ") : name, quantity: quantity)
            }
            // Unrecognised suffix — treat number as unitless, rest as name
            var nameWords = Array(words.dropFirst())
            if nameWords.first?.lowercased() == "of" { nameWords.removeFirst() }
            return (name: nameWords.joined(separator: " "), quantity: numberStr)
        }

        // Pure number — look at the next word(s) for a unit
        guard words.count > 1 else {
            return (name: words.joined(separator: " "), quantity: "")
        }

        // Try two-word unit first (e.g. "fluid ounces")
        if words.count > 2 {
            let twoWordUnit = (words[1] + " " + words[2]).lowercased()
            if let mapping = unitMapping.first(where: { $0.spoken == twoWordUnit }) {
                var nameWords = Array(words.dropFirst(3))
                if nameWords.first?.lowercased() == "of" { nameWords.removeFirst() }
                let name = nameWords.joined(separator: " ")
                let quantity = "\(numberStr) \(mapping.label)"
                return (name: name.isEmpty ? words.joined(separator: " ") : name, quantity: quantity)
            }
        }

        let potentialUnit = words[1].lowercased()
        if let mapping = unitMapping.first(where: { $0.spoken == potentialUnit }) {
            var nameWords = Array(words.dropFirst(2))
            if nameWords.first?.lowercased() == "of" { nameWords.removeFirst() }
            let name = nameWords.joined(separator: " ")
            let quantity = "\(numberStr) \(mapping.label)"
            return (name: name.isEmpty ? words.joined(separator: " ") : name, quantity: quantity)
        }

        // Number found but no unit — unitless quantity, rest is name
        var nameWords = Array(words.dropFirst())
        if nameWords.first?.lowercased() == "of" { nameWords.removeFirst() }
        return (name: nameWords.joined(separator: " "), quantity: numberStr)
    }
}
