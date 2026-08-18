import SwiftUI

/// Verification-only gallery exercising every Sourdough text style and component. Not wired into
/// app navigation — for Xcode canvas / temporary screenshot verification during design-system work.
struct SourdoughGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                Group {
                    FreshnessChip(state: .fresh, dayCountText: "9 days")
                    FreshnessChip(state: .soon, dayCountText: "3 days")
                    FreshnessChip(state: .urgent, dayCountText: "Today")
                    FreshnessChip(state: .expired, dayCountText: "Expired")
                    FreshnessMeter(state: .soon, progress: 0.4, dayCountText: "3 days")
                }
                PantryRow(
                    icon: Image(systemName: "leaf"),
                    categoryTint: Sourdough.Ramp.sage500,
                    title: "Spinach",
                    meta: "200g · Fridge",
                    chip: (.soon, "3 days")
                )
                .sourdoughElevation(.hairline, cornerRadius: 0)
                OnDarkHeroCard(
                    image: nil,
                    title: "Weeknight Chicken Skillet",
                    meta: "25 min · 4 servings",
                    tags: ["Dinner", "High Protein"],
                    accentText: "Use today"
                )
                Divider()
                Group {
                    Text("Display style").sourdoughTextStyle(.display)
                    Text("Title 1 style").sourdoughTextStyle(.title1)
                    Text("Title 2 style").sourdoughTextStyle(.title2)
                    Text("SECTION HEAD").sourdoughTextStyle(.sectionHead)
                    Text("Row title style").sourdoughTextStyle(.rowTitle)
                    Text("Body style — the quick brown fox jumps over the lazy dog.").sourdoughTextStyle(.body)
                    Text("Subhead / meta style").sourdoughTextStyle(.subhead)
                    Text("1,234").sourdoughTextStyle(.numeric)
                    Text("Caption style").sourdoughTextStyle(.caption)
                    (Sourdough.SDFont.italic("2 cups") + Text(" flour, sifted").font(Sourdough.SDFont.font(for: .body)))
                        .foregroundStyle(Sourdough.Colors.ink)
                }

                Divider()

                Group {
                    Button("Primary") {}
                        .buttonStyle(Sourdough.PrimaryButtonStyle())
                    Button("Primary disabled") {}
                        .buttonStyle(Sourdough.PrimaryButtonStyle(isDisabled: true))
                    Button("Add to list") {}
                        .buttonStyle(Sourdough.SecondaryButtonStyle())
                    Button("Text link") {}
                        .buttonStyle(Sourdough.TextButtonStyle())
                    Button("Delete account") {}
                        .buttonStyle(Sourdough.DestructiveTextButtonStyle())
                }

                Divider()

                Group {
                    FreshnessChip(state: .fresh, dayCountText: "9 days")
                    FreshnessChip(state: .soon, dayCountText: "3 days")
                    FreshnessChip(state: .urgent, dayCountText: "Today")
                    FreshnessChip(state: .expired, dayCountText: "Expired")
                    FreshnessMeter(state: .soon, progress: 0.4, dayCountText: "3 days")
                }

                Divider()

                PantryRow(
                    icon: Image(systemName: "leaf"),
                    categoryTint: Sourdough.Ramp.sage500,
                    title: "Spinach",
                    meta: "200g · Fridge",
                    chip: (.soon, "3 days")
                )
                .sourdoughElevation(.hairline, cornerRadius: 0)

                OnDarkHeroCard(
                    image: nil,
                    title: "Weeknight Chicken Skillet",
                    meta: "25 min · 4 servings",
                    tags: ["Dinner", "High Protein"],
                    accentText: "Use today"
                )

                Divider()

                VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                    Text("Ramp swatches").sourdoughTextStyle(.sectionHead)
                    swatchRow("terracotta", [
                        Sourdough.Ramp.terracotta50, Sourdough.Ramp.terracotta100, Sourdough.Ramp.terracotta200,
                        Sourdough.Ramp.terracotta300, Sourdough.Ramp.terracotta400, Sourdough.Ramp.terracotta500,
                        Sourdough.Ramp.terracotta600, Sourdough.Ramp.terracotta700
                    ])
                    swatchRow("sage", [
                        Sourdough.Ramp.sage50, Sourdough.Ramp.sage100, Sourdough.Ramp.sage200, Sourdough.Ramp.sage300,
                        Sourdough.Ramp.sage400, Sourdough.Ramp.sage500, Sourdough.Ramp.sage600, Sourdough.Ramp.sage700
                    ])
                    swatchRow("honey", [
                        Sourdough.Ramp.honey50, Sourdough.Ramp.honey100, Sourdough.Ramp.honey200, Sourdough.Ramp.honey300,
                        Sourdough.Ramp.honey400, Sourdough.Ramp.honey500, Sourdough.Ramp.honey600, Sourdough.Ramp.honey700
                    ])
                    swatchRow("linen", [
                        Sourdough.Ramp.linen0, Sourdough.Ramp.linen50, Sourdough.Ramp.linen100, Sourdough.Ramp.linen200,
                        Sourdough.Ramp.linen300, Sourdough.Ramp.linen400, Sourdough.Ramp.linen500, Sourdough.Ramp.linen900
                    ])
                }
            }
            .padding(Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
    }

    private func swatchRow(_ label: String, _ colors: [Color]) -> some View {
        HStack(spacing: 4) {
            Text(label).sourdoughTextStyle(.caption).frame(width: 70, alignment: .leading)
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 28, height: 28)
            }
        }
    }
}

#Preview("Sourdough Gallery — Light") {
    SourdoughGalleryView().preferredColorScheme(.light)
}

#Preview("Sourdough Gallery — Dark") {
    SourdoughGalleryView().preferredColorScheme(.dark)
}
