// Dessine le calque de l'icône de Jalons : un jalon d'arpenteur rayé, planté droit dans le sol, en vermillon sur
// fond transparent (le fond crème vient de Ressources/AppIcon.icon/icon.json). Deux couleurs, aucun effet.
// Usage : swift scripts/dessiner-icone.swift Ressources/AppIcon.icon/Assets/jalon.png
import AppKit
import CoreGraphics

guard CommandLine.arguments.count == 2 else {
    print("usage : swift scripts/dessiner-icone.swift <sortie.png>")
    exit(2)
}
let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Origine en haut à gauche, comme dans un dessin.
context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

let vermillon = CGColor(colorSpace: space, components: [0xD8 / 255.0, 0x43 / 255.0, 0x2B / 255.0, 1])!
let width: CGFloat = 112
let stripe: CGFloat = 100
let top: CGFloat = 170
let ground = top + stripe * 6
let border: CGFloat = 16

context.setFillColor(vermillon)
// Le piquet : trois bandes pleines, et trois bandes claires bordées (le fond transparent y laisse voir le crème).
let pole = CGMutablePath()
for index in 0..<6 {
    let band = CGRect(x: size / 2 - width / 2, y: top + CGFloat(index) * stripe, width: width, height: stripe)
    if index.isMultiple(of: 2) {
        pole.addRect(band)
    } else {
        pole.addRect(CGRect(x: band.minX, y: band.minY, width: border, height: stripe))
        pole.addRect(CGRect(x: band.maxX - border, y: band.minY, width: border, height: stripe))
    }
}
// Le sol : un trait, et deux plus courts de part et d'autre.
pole.addRect(CGRect(x: size / 2 - 230, y: ground, width: 460, height: 28))
pole.addRect(CGRect(x: size / 2 - 330, y: ground + 62, width: 120, height: 22))
pole.addRect(CGRect(x: size / 2 + 210, y: ground + 62, width: 120, height: 22))
context.addPath(pole)
context.fillPath()

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: output)
print("écrit : \(output.lastPathComponent)")
