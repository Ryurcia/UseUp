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
