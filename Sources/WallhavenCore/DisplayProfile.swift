import Foundation

public struct DisplayProfile: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let scale: Double

    public init(width: Int, height: Int, scale: Double = 1) {
        self.width = width
        self.height = height
        self.scale = scale
    }

    public var pixelWidth: Int {
        Int(Double(width) * scale)
    }

    public var pixelHeight: Int {
        Int(Double(height) * scale)
    }

    public var resolutionQuery: String {
        "\(pixelWidth)x\(pixelHeight)"
    }

    public var aspectRatioQuery: String {
        let divisor = greatestCommonDivisor(pixelWidth, pixelHeight)
        return "\(pixelWidth / divisor)x\(pixelHeight / divisor)"
    }
}

private func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
    var current = abs(lhs)
    var remainderSource = abs(rhs)

    while remainderSource != 0 {
        let remainder = current % remainderSource
        current = remainderSource
        remainderSource = remainder
    }

    return max(current, 1)
}
