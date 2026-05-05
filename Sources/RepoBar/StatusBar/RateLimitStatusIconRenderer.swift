import AppKit

@MainActor
enum RateLimitStatusIconRenderer {
    private static let outputSize = NSSize(width: 18, height: 18)
    private static let outputScale: CGFloat = 2
    private static let canvasPx = Int(outputSize.width * outputScale)
    private static let grid = PixelGrid(scale: outputScale)
    private static var cache: [CacheKey: NSImage] = [:]

    static func makeIcon(restPercent: Double?, graphQLPercent: Double?) -> NSImage {
        let key = CacheKey(rest: Self.bucket(restPercent), graphQL: Self.bucket(graphQLPercent))
        if let cached = self.cache[key] {
            return cached
        }

        let image = NSImage(size: Self.outputSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: Self.outputSize)).fill()

        let baseFill = NSColor.labelColor
        if graphQLPercent == nil {
            Self.drawBar(
                rectPx: RectPx(x: (Self.canvasPx - 30) / 2, y: 11, w: 30, h: 14),
                percent: restPercent,
                baseFill: baseFill,
                trackFillAlpha: 0.26,
                trackStrokeAlpha: 0.44
            )
            image.isTemplate = true
            self.cache[key] = image
            return image
        }

        Self.drawBar(
            rectPx: RectPx(x: (Self.canvasPx - 30) / 2, y: 20, w: 30, h: 10),
            percent: restPercent,
            baseFill: baseFill,
            trackFillAlpha: 0.26,
            trackStrokeAlpha: 0.44
        )
        Self.drawBar(
            rectPx: RectPx(x: (Self.canvasPx - 30) / 2, y: 7, w: 30, h: 8),
            percent: graphQLPercent,
            baseFill: baseFill,
            trackFillAlpha: 0.22,
            trackStrokeAlpha: 0.38
        )

        image.isTemplate = true
        self.cache[key] = image
        return image
    }

    private static func drawBar(
        rectPx: RectPx,
        percent: Double?,
        baseFill: NSColor,
        trackFillAlpha: CGFloat,
        trackStrokeAlpha: CGFloat
    ) {
        let rect = rectPx.rect()
        let radius = Self.grid.pt(rectPx.h / 2)
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        baseFill.withAlphaComponent(trackFillAlpha).setFill()
        trackPath.fill()

        let strokeWidthPx = 2
        let insetPx = strokeWidthPx / 2
        let strokeRect = Self.grid.rect(
            x: rectPx.x + insetPx,
            y: rectPx.y + insetPx,
            w: max(0, rectPx.w - insetPx * 2),
            h: max(0, rectPx.h - insetPx * 2)
        )
        let strokePath = NSBezierPath(
            roundedRect: strokeRect,
            xRadius: Self.grid.pt(max(0, rectPx.h / 2 - insetPx)),
            yRadius: Self.grid.pt(max(0, rectPx.h / 2 - insetPx))
        )
        strokePath.lineWidth = CGFloat(strokeWidthPx) / Self.outputScale
        baseFill.withAlphaComponent(trackStrokeAlpha).setStroke()
        strokePath.stroke()

        guard let percent else { return }

        let clamped = max(0, min(percent / 100, 1))
        let fillWidthPx = max(0, min(rectPx.w, Int((CGFloat(rectPx.w) * CGFloat(clamped)).rounded())))
        guard fillWidthPx > 0 else { return }

        NSGraphicsContext.current?.cgContext.saveGState()
        trackPath.addClip()
        baseFill.setFill()
        NSBezierPath(rect: Self.grid.rect(x: rectPx.x, y: rectPx.y, w: fillWidthPx, h: rectPx.h)).fill()
        NSGraphicsContext.current?.cgContext.restoreGState()
    }

    private static func bucket(_ percent: Double?) -> Int {
        guard let percent else { return -1 }

        return Int(max(0, min(100, percent)).rounded())
    }

    private struct CacheKey: Hashable {
        let rest: Int
        let graphQL: Int
    }

    private struct PixelGrid {
        let scale: CGFloat

        func pt(_ px: Int) -> CGFloat {
            CGFloat(px) / self.scale
        }

        func rect(x: Int, y: Int, w: Int, h: Int) -> CGRect {
            CGRect(x: self.pt(x), y: self.pt(y), width: self.pt(w), height: self.pt(h))
        }
    }

    private struct RectPx {
        let x: Int
        let y: Int
        let w: Int
        let h: Int

        @MainActor
        func rect() -> CGRect {
            RateLimitStatusIconRenderer.grid.rect(x: self.x, y: self.y, w: self.w, h: self.h)
        }
    }
}
