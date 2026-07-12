import CoreGraphics

enum OverlayMapping {
    /// Normalized (top-left origin) image coords → view coords, mirroring
    /// AVLayerVideoGravity.resizeAspectFill: scale to fill, center, crop.
    static func viewPoint(_ normalized: CGPoint, imageAspect: CGFloat, in size: CGSize) -> CGPoint {
        let viewAspect = size.width / size.height
        if imageAspect > viewAspect {
            // Image is wider than the view: full height, sides cropped.
            let width = size.height * imageAspect
            let xOffset = (size.width - width) / 2
            return CGPoint(x: xOffset + normalized.x * width,
                           y: normalized.y * size.height)
        } else {
            // Image is taller than the view: full width, top/bottom cropped.
            let height = size.width / imageAspect
            let yOffset = (size.height - height) / 2
            return CGPoint(x: normalized.x * size.width,
                           y: yOffset + normalized.y * height)
        }
    }
}
