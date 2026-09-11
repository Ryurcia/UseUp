import SwiftUI
import AVFoundation
import UIKit
import PhosphorSwift

/// Stands in front of `PhotoScanCaptureView`'s camera: teaches the framing that makes a scan
/// read correctly, and doubles as the camera-permission gate (requests access on first run,
/// routes a denied user to Settings instead of a black preview).
///
/// The One item / Several items toggle is the spine of the screen — the two rule sets
/// ("clear the background" vs "every item in frame") only make sense once you know which shot
/// is being taken. It tailors the tips, the do/don't diagram and the CTA label; it does not
/// change scanner behaviour.
enum PhotoScanTipsContext {
    case pantry    // Photo Scan → pantry log
    case snapChef  // Snap Chef → recipe

    var kicker: String { self == .pantry ? "Photo scan" : "Snap Chef" }
    var title: String {
        self == .pantry ? "Two seconds now saves a fix later." : "A clear photo, a better recipe."
    }
    var subhead: String {
        self == .pantry
            ? "A clear photo means we read the item and its date right the first time."
            : "A clear photo means we catch every ingredient you can cook with."
    }
    var backgroundTipDetail: String {
        self == .pantry
            ? "A plain counter or table. Anything else in shot may get logged too."
            : "A plain counter or table. Anything else in shot may end up in the recipe."
    }
    var labelTipDetail: String {
        self == .pantry
            ? "It is where we read the brand and the best-by date. Angle it toward the light, not the lens."
            : "Helps us read the exact product name. Angle it toward the light, not the lens."
    }
    var deniedMessage: String {
        self == .pantry
            ? "UseUp needs camera access to scan groceries into your pantry. You can enable it in Settings."
            : "UseUp needs camera access to identify your ingredients for a recipe. You can enable it in Settings."
    }
    var hideFlagKey: String { self == .pantry ? "hidePhotoScanTips" : "hideSnapChefTips" }
}

struct PhotoScanTipsView: View {
    let context: PhotoScanTipsContext
    var onContinue: () -> Void
    var onCancel: () -> Void

    @AppStorage private var hidePhotoScanTips: Bool
    @State private var mode: GuidanceMode = .one
    @State private var showCameraDeniedAlert = false

    init(context: PhotoScanTipsContext = .pantry, onContinue: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.context = context
        self.onContinue = onContinue
        self.onCancel = onCancel
        _hidePhotoScanTips = AppStorage(wrappedValue: false, context.hideFlagKey)
    }

    enum GuidanceMode: CaseIterable {
        case one, several

        var toggleLabel: String { self == .one ? "One item" : "Several items" }
        var doCaption: String {
            self == .one
                ? "One item, centred, plain background."
                : "All items apart, in one layer, fully in frame."
        }
        var dontCaption: String {
            self == .one
                ? "Other things in shot get logged as items."
                : "Stacked or half-cropped items get missed."
        }
    }

    private struct Tip: Identifiable {
        let id = UUID()
        let icon: Image
        let tint: Color
        let glyphInk: Color
        let title: String
        let detail: String
        var isOptional = false
    }

    private var labelTip: Tip {
        Tip(
            icon: Ph.tag.regular,
            tint: Sourdough.Ramp.honey100,
            glyphInk: Sourdough.Ramp.honey700,
            title: "Show the label if there is one",
            detail: context.labelTipDetail,
            isOptional: true
        )
    }

    private var tips: [Tip] {
        switch mode {
        case .one:
            return [
                Tip(icon: Ph.frameCorners.regular, tint: Sourdough.Ramp.sage100, glyphInk: Sourdough.Ramp.freshLabelLight,
                    title: "One item, filling the frame",
                    detail: "Get close enough that it takes up most of the photo."),
                Tip(icon: Ph.square.regular, tint: Sourdough.Ramp.terracotta100, glyphInk: Sourdough.Ramp.terracotta600,
                    title: "Clear the background",
                    detail: context.backgroundTipDetail),
                labelTip,
            ]
        case .several:
            return [
                Tip(icon: Ph.squaresFour.regular, tint: Sourdough.Ramp.sage100, glyphInk: Sourdough.Ramp.freshLabelLight,
                    title: "Every item fully in frame",
                    detail: "Nothing cropped at the edges — we skip what we cannot see whole."),
                Tip(icon: Ph.arrowsHorizontal.regular, tint: Sourdough.Ramp.terracotta100, glyphInk: Sourdough.Ramp.terracotta600,
                    title: "Spread them out, no stacking",
                    detail: "A single layer with small gaps. Items behind others get missed."),
                labelTip,
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.insideChip)

            modeToggle
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.rowInternals) {
                    diagram
                    tipsCard
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks)
            }

            footer
        }
        .background(Sourdough.Colors.canvas)
        .alert("Camera Access", isPresented: $showCameraDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: {
            Text(context.deniedMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Sourdough.Spacing.rowInternals) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                Text(context.kicker)
                    .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                Text(context.title)
                    .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
                Text(context.subhead)
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { onCancel() } label: {
                Ph.x.bold
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .frame(width: 30, height: 30)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 4) {
            ForEach(GuidanceMode.allCases, id: \.self) { m in
                let selected = mode == m
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { mode = m }
                } label: {
                    Text(m.toggleLabel)
                        .sourdoughTextStyle(.subhead, color: selected ? Sourdough.Colors.ink : Sourdough.Colors.mutedInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Capsule()
                                .fill(selected ? Sourdough.Colors.card : Color.clear)
                                .shadow(color: selected ? Sourdough.Ramp.linen900.opacity(0.18) : .clear,
                                        radius: 3, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Sourdough.Colors.sunken)
        .clipShape(Capsule())
    }

    // MARK: - Do / Not-this diagram

    private var diagram: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            diagramCard(isGood: true)
            diagramCard(isGood: false)
        }
    }

    private func diagramCard(isGood: Bool) -> some View {
        let stroke = isGood ? Sourdough.Ramp.sage200 : Sourdough.Ramp.terracotta200
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                (isGood ? Sourdough.Ramp.sage50 : Sourdough.Ramp.terracotta50)

                diagramTiles(isGood: isGood)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .id(mode)
                    .transition(.opacity)

                Text(isGood ? "DO" : "NOT THIS")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.onAction)
                    .padding(.horizontal, Sourdough.Spacing.insideChip)
                    .frame(height: 20)
                    .background(isGood ? Sourdough.Ramp.sage500 : Sourdough.Ramp.terracotta500)
                    .clipShape(Capsule())
                    .padding(Sourdough.Spacing.insideChip)
            }
            .frame(height: 104)
            .clipped()

            Text(isGood ? mode.doCaption : mode.dontCaption)
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
        }
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func diagramTiles(isGood: Bool) -> some View {
        switch (isGood, mode) {
        case (true, .one):
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Sourdough.Ramp.sage200)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Sourdough.Ramp.sage500, lineWidth: 2))
                .frame(width: 46, height: 56)

        case (true, .several):
            tileGrid { _ in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Sourdough.Ramp.sage200)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Sourdough.Ramp.sage500, lineWidth: 1.5))
                    .frame(height: 30)
            }

        case (false, .one):
            ZStack {
                scatterTile(color: Sourdough.Ramp.terracotta500, w: 36, h: 44, x: -34, y: -2)
                scatterTile(color: Sourdough.Colors.interactiveBorder, w: 40, h: 34, x: 4, y: 16)
                scatterTile(color: Sourdough.Colors.interactiveBorder, w: 32, h: 28, x: 40, y: -16)
            }

        case (false, .several):
            tileGrid { i in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Sourdough.Ramp.terracotta100)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Sourdough.Ramp.terracotta500,
                                style: StrokeStyle(lineWidth: 1.5, dash: i.isMultiple(of: 2) ? [] : [4])))
                    .frame(height: 30)
                    .opacity(i.isMultiple(of: 2) ? 1 : 0.35)
                    .offset(y: i == 3 ? 9 : (i == 5 ? 14 : 0))
            }
        }
    }

    private func tileGrid<Tile: View>(@ViewBuilder tile: @escaping (Int) -> Tile) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(0..<6, id: \.self) { i in tile(i) }
        }
    }

    private func scatterTile(color: Color, w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(color.opacity(0.28))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }

    // MARK: - Tips

    private var tipsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(tips.enumerated()), id: \.element.id) { index, tip in
                tipRow(tip)
                    .overlay(alignment: .top) {
                        if index != 0 {
                            Rectangle()
                                .fill(Sourdough.Colors.hairline)
                                .frame(height: 1)
                        }
                    }
            }
        }
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
    }

    private func tipRow(_ tip: Tip) -> some View {
        HStack(alignment: .top, spacing: Sourdough.Spacing.rowInternals) {
            tip.icon
                .frame(width: 14, height: 14)
                .foregroundStyle(tip.glyphInk)
                .frame(width: 26, height: 26)
                .background(tip.tint)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.ink)
                Text(tip.detail)
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if tip.isOptional {
                Text("OPTIONAL")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                    .padding(.horizontal, Sourdough.Spacing.insideChip)
                    .frame(height: 19)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(Capsule())
            }
        }
        .padding(Sourdough.Spacing.rowInternals)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Button { requestCameraAccess() } label: {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Ph.camera.regular.frame(width: 18, height: 18)
                    Text("Continue")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))

            Button { hidePhotoScanTips.toggle() } label: {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(hidePhotoScanTips ? Sourdough.Ramp.sage500 : Sourdough.Colors.card)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(hidePhotoScanTips ? Sourdough.Ramp.sage500 : Sourdough.Colors.interactiveBorder,
                                    lineWidth: 1.5)
                        if hidePhotoScanTips {
                            Ph.check.bold
                                .frame(width: 11, height: 11)
                                .foregroundStyle(Sourdough.Colors.onAction)
                        }
                    }
                    .frame(width: 20, height: 20)

                    Text("Don't show this again")
                        .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.rowInternals)
        .padding(.bottom, Sourdough.Spacing.screenMargin)
        .background(
            Sourdough.Colors.card
                .overlay(alignment: .top) {
                    Rectangle().fill(Sourdough.Colors.hairline).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Camera permission

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onContinue()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        onContinue()
                    } else {
                        showCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert = true
        @unknown default:
            showCameraDeniedAlert = true
        }
    }
}
