#!/usr/bin/env bash
#
# Regenerates Vendor/PhosphorSwift from upstream, keeping only the icons this app
# actually references.
#
# Upstream PhosphorSwift ships 9,108 imagesets (71 MB of SVG) in a single asset
# catalog. Xcode compiles that with one `actool` invocation — a single, silent,
# single-threaded build task that takes many minutes and makes the build look
# frozen. We use ~100 of its ~1,500 icons, so we vendor a trimmed copy instead.
#
# Re-run this after adding a new `Ph.<icon>` reference.
#
#   ./Scripts/prune_phosphor_icons.sh [path-to-upstream-checkout]
#
# With no argument it clones the pinned tag into a temp dir.

set -euo pipefail

PINNED_TAG="2.1.0"
UPSTREAM_URL="https://github.com/phosphor-icons/swift"

# Icon weights to bundle. Upstream ships 6 (regular/thin/light/bold/fill/duotone);
# this app only uses these three. `regular` is the bare rawValue, the rest are
# suffixed. Adding a weight here also requires re-adding its accessor in
# Sources/PhosphorSwift/PhosphorSwift.swift.
WEIGHTS=(regular fill bold)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/Vendor/PhosphorSwift"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- locate upstream ---------------------------------------------------------
if [[ $# -ge 1 ]]; then
  UPSTREAM="$1"
  [[ -d "$UPSTREAM/Sources/PhosphorSwift" ]] || {
    echo "error: $UPSTREAM is not a PhosphorSwift checkout" >&2; exit 1; }
else
  echo "==> cloning $UPSTREAM_URL @ $PINNED_TAG"
  git clone --depth 1 --branch "$PINNED_TAG" "$UPSTREAM_URL" "$WORK/upstream" >/dev/null 2>&1
  UPSTREAM="$WORK/upstream"
fi

SRC="$UPSTREAM/Sources/PhosphorSwift"
ICONS_SWIFT="$SRC/Icons.swift"
SVG_DIR="$SRC/Resources/Assets.xcassets/SVG"

# --- derive the keep-list ----------------------------------------------------
# Two passes are needed. `Ph.check` is easy to grep, but Swift's leading-dot
# shorthand hides icons in Ph-typed positions — e.g. `statCol(icon: .flame,...)`
# and `var icon: Ph { return .heartBreak }`. Those are invisible to a `Ph\.` grep.
#
# So we take every `.token` in any file that imports PhosphorSwift and intersect
# it with the real upstream case names. That over-approximates slightly (a stray
# `.tag` or `.video` on an unrelated type gets swept in), which is the safe
# direction to err: a handful of extra imagesets costs nothing, a missing one is
# a bug. The union of both passes is the keep-list.

grep -oE '^    case [a-zA-Z0-9]+ = "' "$ICONS_SWIFT" \
  | sed 's/    case //; s/ = "//' | sort -u > "$WORK/all_cases.txt"

grep -rhoE 'Ph\.[a-zA-Z0-9]+' --include='*.swift' "$ROOT/App" "$ROOT/Core" "$ROOT/Features" \
  | sed 's/^Ph\.//' | sort -u > "$WORK/explicit.txt"

grep -rl 'import PhosphorSwift' --include='*.swift' "$ROOT/App" "$ROOT/Core" "$ROOT/Features" \
  | xargs grep -ohE '\.[a-zA-Z0-9]+' \
  | sed 's/^\.//' | sort -u > "$WORK/dots.txt"
comm -12 "$WORK/dots.txt" "$WORK/all_cases.txt" > "$WORK/shorthand.txt"

sort -u "$WORK/explicit.txt" "$WORK/shorthand.txt" > "$WORK/keep.txt"
echo "==> keeping $(wc -l < "$WORK/keep.txt" | tr -d ' ') of $(wc -l < "$WORK/all_cases.txt" | tr -d ' ') icons"

# --- rebuild the vendored package --------------------------------------------
rm -rf "$DEST"
mkdir -p "$DEST/Sources/PhosphorSwift/Resources/Assets.xcassets/SVG"

# Package.swift: upstream's testTarget references a Tests/ dir we don't vendor.
cat > "$DEST/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhosphorSwift",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(
            name: "PhosphorSwift",
            targets: ["PhosphorSwift"]),
    ],
    targets: [
        .target(
            name: "PhosphorSwift",
            path: "Sources"),
    ]
)
EOF

cp "$SRC/Resources/Assets.xcassets/Contents.json" \
   "$DEST/Sources/PhosphorSwift/Resources/Assets.xcassets/Contents.json"

# Icons.swift: header (through `public var id`) + kept cases + closing brace.
# Trimming the enum — not just the catalog — is deliberate: a missed icon then
# fails to compile ("type 'Ph' has no member 'x'") instead of silently rendering
# a blank image at runtime.
{
  sed -n '1,12p' "$ICONS_SWIFT"
  # IFS= is load-bearing: a bare `read` strips the leading indentation, which both
  # breaks the name extraction below and de-indents the emitted case lines.
  grep -oE '^    case [a-zA-Z0-9]+ = "[a-z0-9-]+"' "$ICONS_SWIFT" | while IFS= read -r line; do
    name="${line#    case }"
    name="${name%% = *}"
    if grep -qxF "$name" "$WORK/keep.txt"; then echo "$line"; fi
  done
  echo "}"
} > "$DEST/Sources/PhosphorSwift/Icons.swift"

# PhosphorSwift.swift: same API as upstream minus the weights we don't bundle,
# so an unbundled weight is a compile error rather than a blank glyph.
cat > "$DEST/Sources/PhosphorSwift/PhosphorSwift.swift" <<'EOF'
//
//  PhosphorSwift.swift
//  Phosphor Icons
//
//  Created by Tobias Fried on 1/22/23.
//
//  VENDORED + TRIMMED. See Scripts/prune_phosphor_icons.sh.
//  Only the weights bundled by that script are exposed here.
//

import SwiftUI

public extension Ph {
    enum IconWeight: String, CaseIterable, Identifiable {
        public var id: Self { self }

        case regular
        case bold
        case fill
    }

    var regular: Image { Ph.icon(self.rawValue) }
    var bold: Image { Ph.icon("\(self.rawValue)-bold") }
    var fill: Image { Ph.icon("\(self.rawValue)-fill") }

    func weight(_ weight: IconWeight) -> Image {
        switch weight {
        case .regular: return self.regular
        case .bold: return self.bold
        case .fill: return self.fill
        }
    }

    private static func icon(_ name: String) -> Image {
        Image(name, bundle: .module)
            .interpolation(.medium)
            .resizable()
    }
}

struct ColorBlended: ViewModifier {
    fileprivate var color: Color

    public func body(content: Content) -> some View {
        VStack {
            ZStack {
                content
                self.color.blendMode(.sourceAtop)
            }
            .drawingGroup(opaque: false)
        }
    }
}

public extension View {
    func color(_ color: Color) -> some View {
        modifier(ColorBlended(color: color))
    }
}
EOF

# Imagesets are named by rawValue (kebab-case), not by the Swift case name:
# Ph.forkKnife -> fork-knife.imageset. Map through Icons.swift.
copied=0
missing=0
while read -r name; do
  raw="$(grep -oE "^    case $name = \"[a-z0-9-]+\"" "$ICONS_SWIFT" | sed 's/.*= "//; s/"//')"
  [[ -n "$raw" ]] || continue
  for w in "${WEIGHTS[@]}"; do
    if [[ "$w" == "regular" ]]; then dir="$raw.imageset"; else dir="$raw-$w.imageset"; fi
    if [[ -d "$SVG_DIR/$dir" ]]; then
      cp -R "$SVG_DIR/$dir" "$DEST/Sources/PhosphorSwift/Resources/Assets.xcassets/SVG/$dir"
      copied=$((copied + 1))
    else
      echo "   warn: no imageset for $name ($dir)" >&2
      missing=$((missing + 1))
    fi
  done
done < "$WORK/keep.txt"

echo "==> $copied imagesets copied ($missing missing) -> Vendor/PhosphorSwift"
du -sh "$DEST"
