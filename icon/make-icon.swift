// Renders the app icon (dark rounded tile, orange Fire TV remote silhouette) at 1024px.
import AppKit

let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Background tile (macOS squircle-ish rounded rect, with margin like system icons)
let margin = size * 0.08
let tile = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let tilePath = CGPath(roundedRect: tile, cornerWidth: tile.width * 0.22, cornerHeight: tile.width * 0.22, transform: nil)
ctx.addPath(tilePath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [CGColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1), CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
ctx.resetClip()

// Remote body
let orange = CGColor(red: 1.0, green: 0.48, blue: 0.10, alpha: 1)
let bodyW = size * 0.30, bodyH = size * 0.68
let body = CGRect(x: (size - bodyW) / 2, y: (size - bodyH) / 2, width: bodyW, height: bodyH)
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.05, color: CGColor(gray: 0, alpha: 0.6))
ctx.setFillColor(CGColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1))
ctx.addPath(CGPath(roundedRect: body, cornerWidth: bodyW * 0.3, cornerHeight: bodyW * 0.3, transform: nil)); ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.10)); ctx.setLineWidth(size * 0.006)
ctx.addPath(CGPath(roundedRect: body.insetBy(dx: size * 0.003, dy: size * 0.003), cornerWidth: bodyW * 0.3, cornerHeight: bodyW * 0.3, transform: nil)); ctx.strokePath()

// D-pad ring + center
let cx = size / 2, cy = body.midY + bodyH * 0.22
let ringR = bodyW * 0.36
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.18)); ctx.setLineWidth(size * 0.014)
ctx.addEllipse(in: CGRect(x: cx - ringR, y: cy - ringR, width: 2 * ringR, height: 2 * ringR)); ctx.strokePath()
ctx.setFillColor(orange)
let selR = bodyW * 0.15
ctx.fillEllipse(in: CGRect(x: cx - selR, y: cy - selR, width: 2 * selR, height: 2 * selR))
// Arrows on the ring
ctx.setFillColor(CGColor(gray: 1, alpha: 0.75))
let a = size * 0.022
for (dx, dy, rot) in [(0.0, 1.0, 0.0), (0.0, -1.0, Double.pi), (-1.0, 0.0, Double.pi / 2), (1.0, 0.0, -Double.pi / 2)] {
    ctx.saveGState()
    ctx.translateBy(x: cx + dx * ringR * 0.72, y: cy + dy * ringR * 0.72)
    ctx.rotate(by: rot)
    ctx.move(to: CGPoint(x: -a, y: -a * 0.6)); ctx.addLine(to: CGPoint(x: a, y: -a * 0.6)); ctx.addLine(to: CGPoint(x: 0, y: a * 0.8)); ctx.closePath(); ctx.fillPath()
    ctx.restoreGState()
}
// Small buttons row
let br = size * 0.018
for i in -1...1 {
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.22))
    ctx.fillEllipse(in: CGRect(x: cx + Double(i) * bodyW * 0.3 - br, y: cy - ringR - size * 0.08 - br, width: 2 * br, height: 2 * br))
}
// Four app buttons (2x2) highlighted orange
let kw = bodyW * 0.30, kh = size * 0.034
for (ix, iy) in [(-1.0, 0.0), (1.0, 0.0), (-1.0, -1.0), (1.0, -1.0)] {
    let r = CGRect(x: cx + ix * bodyW * 0.19 - kw / 2, y: body.minY + bodyH * 0.17 + iy * (kh + size * 0.02), width: kw, height: kh)
    ctx.setFillColor(CGColor(red: 1.0, green: 0.48, blue: 0.10, alpha: iy == 0 ? 0.95 : 0.55))
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: kh / 2, cornerHeight: kh / 2, transform: nil)); ctx.fillPath()
}
// Mic dot at top
ctx.setFillColor(CGColor(gray: 1, alpha: 0.5))
let mr = size * 0.014
ctx.fillEllipse(in: CGRect(x: cx - mr, y: body.maxY - bodyH * 0.07 - mr, width: 2 * mr, height: 2 * mr))
img.unlockFocus()

let png = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote", CommandLine.arguments[1])
