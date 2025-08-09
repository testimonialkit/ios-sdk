import SwiftUI
import UIKit

extension UIColor {
    /// Resolve dynamic color to sRGB components, optionally blended over a base color.
    func srgbComponents(blendedOver base: UIColor? = nil,
                        trait: UITraitCollection = .current) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let resolved = self.resolvedColor(with: trait)

        // Convert to sRGB
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        var cg = resolved.cgColor
        if cg.colorSpace?.name != sRGB.name,
           let converted = cg.converted(to: sRGB, intent: .relativeColorimetric, options: nil) {
            cg = converted
        }

        let comps = cg.components ?? [0,0,0,1]
        let r = comps.count >= 3 ? comps[0] : comps[0]
        let g = comps.count >= 3 ? comps[1] : comps[0]
        let b = comps.count >= 3 ? comps[2] : comps[0]
        let a = comps.count >= 4 ? comps[3] : 1

        // Blend if needed
        if a < 1 {
            let baseComps = (base ?? .systemBackground).srgbComponents(trait: trait)
            let outR = r * a + baseComps.r * (1 - a)
            let outG = g * a + baseComps.g * (1 - a)
            let outB = b * a + baseComps.b * (1 - a)
            return (outR, outG, outB, 1)
        }

        return (r, g, b, a)
    }

    /// WCAG relative luminance
    var relativeLuminance: CGFloat {
        let (r, g, b, _) = srgbComponents()
        func lin(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func contrastRatio(against other: UIColor) -> CGFloat {
        let L1 = max(self.relativeLuminance, other.relativeLuminance)
        let L2 = min(self.relativeLuminance, other.relativeLuminance)
        return (L1 + 0.05) / (L2 + 0.05)
    }

    /// Return UIColor.white or UIColor.black, whichever contrasts better with this background.
    func readableForeground(over base: UIColor? = nil,
                            trait: UITraitCollection = .current) -> UIColor {
        // Build a solid sRGB UIColor from (possibly transparent/dynamic) background
        let comps = self.srgbComponents(blendedOver: base, trait: trait)
        let bg = UIColor(red: comps.r, green: comps.g, blue: comps.b, alpha: comps.a)

        let whiteCR = bg.contrastRatio(against: UIColor.white)
        let blackCR = bg.contrastRatio(against: UIColor.black)
        return whiteCR >= blackCR ? UIColor.white : UIColor.black
    }
}

extension Color {
    /// SwiftUI bridge
    func readableForegroundColor(over base: Color = Color(UIColor.systemBackground)) -> Color {
        let pick = UIColor(self).readableForeground(over: UIColor(base))
        return Color(pick)
    }
}
