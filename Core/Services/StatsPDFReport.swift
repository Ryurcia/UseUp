import SwiftUI

/// Builds the exported "Spending & Waste" PDF from the user's `pantry_events`: an all-time cover
/// summary, a page each for the Weekly / Monthly / Yearly breakdown, and a most-thrown-away
/// ingredients ranking. Pages are SwiftUI views (`StatsReportPages.swift`) rendered via
/// `ImageRenderer` — the same approach as `RecipeDetailView.generatePDF()`.
@MainActor
enum StatsPDFReport {
    static func generate(events: [PantryEvent], now: Date = Date()) -> URL? {
        guard StatsReadiness.hasData(events) else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Use Up — Spending & Waste.pdf")
        try? FileManager.default.removeItem(at: url)

        // Nominal box; each page overrides it via kCGPDFContextMediaBox so pages fit their content.
        var mediaBox = CGRect(x: 0, y: 0, width: ReportLayout.pageWidth, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return nil }

        let pages: [AnyView] = [
            AnyView(StatsReportCoverPage(events: events, now: now)),
            AnyView(StatsReportPeriodPage(period: .weekly, events: events, now: now)),
            AnyView(StatsReportPeriodPage(period: .monthly, events: events, now: now)),
            AnyView(StatsReportPeriodPage(period: .yearly, events: events, now: now)),
            AnyView(StatsReportOffendersPage(events: events, now: now)),
        ]

        for page in pages {
            let renderer = ImageRenderer(content: page.environment(\.colorScheme, .light))
            renderer.proposedSize = .init(width: ReportLayout.pageWidth, height: nil)
            renderer.render { size, renderInContext in
                let box = CGRect(origin: .zero, size: size)
                context.beginPDFPage([kCGPDFContextMediaBox: mediaBoxData(box)] as CFDictionary)
                renderInContext(context)
                context.endPDFPage()
            }
        }

        context.closePDF()
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// `kCGPDFContextMediaBox` wants a `CFData` holding a `CGRect` by value.
    private static func mediaBoxData(_ rect: CGRect) -> CFData {
        var r = rect
        return withUnsafeBytes(of: &r) {
            CFDataCreate(nil, $0.bindMemory(to: UInt8.self).baseAddress, MemoryLayout<CGRect>.size)!
        }
    }
}
