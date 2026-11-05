import CoreGraphics

/// Grid math shared by the item grid and the page view, so arrow keys move by whole rows.
public enum GridLayout {
    /// How many columns an adaptive grid shows in `width`, with items at least `minimum` wide.
    public static func columnCount(width: CGFloat, minimum: CGFloat, spacing: CGFloat) -> Int {
        guard width > 0, minimum > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minimum + spacing)))
    }

    /// Keeps a thumbnail size within `range`, rounded to whole `step`s, e.g. for ⌘+ and ⌘-.
    public static func clampedSize(_ size: Double, step: Double = 0, in range: ClosedRange<Double>) -> Double {
        let stepped = step > 0 ? (size / step).rounded() * step : size
        return min(max(stepped, range.lowerBound), range.upperBound)
    }
}
