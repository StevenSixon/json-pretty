// 生成 JSONPretty 应用图标：各尺寸 PNG（iconset）
// 用法: swift Scripts/generate-icon.swift <输出目录>
import AppKit

// MARK: - 绘制单个尺寸

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    // 圆角矩形（squircle 近似），macOS 图标内容区约留 5% 边距
    let inset = size * 0.02
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = size * 0.225
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 背景：对角渐变，深 Slate → 更深，代码编辑器质感
    ctx.saveGState()
    squircle.addClip()
    let bgColors = [
        NSColor(calibratedRed: 0.145, green: 0.157, blue: 0.196, alpha: 1).cgColor, // #252832
        NSColor(calibratedRed: 0.086, green: 0.094, blue: 0.129, alpha: 1).cgColor, // #161821
    ]
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: bgColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY),
                           options: [])

    // 顶部高光：轻微内发亮，增加立体感
    let glossRect = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
    let gloss = NSBezierPath(roundedRect: glossRect, xRadius: radius, yRadius: radius)
    gloss.addClip()
    let glossGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [NSColor.white.withAlphaComponent(0.07).cgColor,
                                            NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 1])!
    ctx.drawLinearGradient(glossGradient,
                           start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.midY),
                           options: [])
    ctx.restoreGState()

    // 主体：花括号 "{ }"，左右双色（橙=输入，青=格式化结果），中间冒号代表键值对
    let fontSize = size * 0.46
    let braceFont = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let baselineY = rect.midY - fontSize * 0.36

    let orange = NSColor(calibratedRed: 1.0, green: 0.624, blue: 0.259, alpha: 1)   // #FF9F42
    let teal = NSColor(calibratedRed: 0.388, green: 0.875, blue: 0.812, alpha: 1)   // #63DFCF
    let white = NSColor(calibratedWhite: 0.92, alpha: 1)

    func draw(_ string: String, color: NSColor, at x: CGFloat, font: NSFont = braceFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .shadow: {
                let s = NSShadow()
                s.shadowColor = NSColor.black.withAlphaComponent(0.35)
                s.shadowOffset = NSSize(width: 0, height: -size * 0.008)
                s.shadowBlurRadius = size * 0.012
                return s
            }(),
        ]
        let attributed = NSAttributedString(string: string, attributes: attrs)
        attributed.draw(at: NSPoint(x: x, y: baselineY))
        return attributed.size().width
    }

    // 整体居中：先量总宽
    let gap = size * 0.028
    let parts: [(String, NSColor, NSFont)] = [
        ("{", orange, braceFont),
        (":", white, NSFont.systemFont(ofSize: fontSize * 0.82, weight: .bold)),
        ("}", teal, braceFont),
    ]
    var totalWidth: CGFloat = 0
    for (string, _, font) in parts {
        totalWidth += NSAttributedString(string: string, attributes: [.font: font]).size().width
    }
    totalWidth += gap * CGFloat(parts.count - 1)

    var x = rect.midX - totalWidth / 2
    for (string, color, font) in parts {
        x += draw(string, color: color, at: x, font: font) + gap
    }

    return image
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "PNG 编码失败: \(url.lastPathComponent)"])
    }
    try png.write(to: url)
}

// MARK: - 生成 iconset 全部尺寸

guard CommandLine.arguments.count > 1 else {
    print("用法: swift generate-icon.swift <输出目录>")
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// iconset 规格：文件名后缀为 point 尺寸，像素 = point × scale
let specs: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for spec in specs {
    // 每个尺寸原生绘制，避免缩放模糊
    let image = renderIcon(size: spec.pixels)
    try savePNG(image, to: outputDir.appendingPathComponent(spec.name))
    print("✓ \(spec.name) (\(Int(spec.pixels))px)")
}
print("完成: \(outputDir.path)")
