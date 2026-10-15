import Foundation

/// A saved design: a `.ledsign` file, which is human-readable JSON.
///
///     {
///       "format" : "ledsign", "version" : 1,
///       "width" : 96, "height" : 16,
///       "settings" : { "brightness" : 200, "speed" : 128, "mode" : "scrollLeft", "loopDelay" : 150 },
///       "colors" : "0 off, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white",
///       "rows" : [ "4444444444…", … ]      // one string per LED row, one digit per LED
///     }
public struct LEDSignDocument: Codable, Equatable, Sendable {
    public struct Settings: Codable, Equatable, Sendable {
        public var brightness: Int
        public var speed: Int
        public var mode: String          // SignMode.key, e.g. "scrollLeft"
        public var loopDelay: Int        // per-frame delay for scroll-over-background

        public init(brightness: Int, speed: Int, mode: SignMode, loopDelay: Int) {
            self.brightness = brightness
            self.speed = speed
            self.mode = mode.key
            self.loopDelay = loopDelay
        }

        public var signMode: SignMode { SignMode(key: mode) ?? .scrollLeft }
    }

    public static let fileExtension = "ledsign"

    public var format = "ledsign"
    public var version = 1
    public var width: Int
    public var height: Int
    public var settings: Settings
    public var colors = "0 off, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white"
    public var rows: [String]

    public init(frame: PixelFrame, settings: Settings) {
        width = frame.width
        height = frame.height
        self.settings = settings
        rows = (0..<frame.height).map { y in
            String((0..<frame.width).map { x in Character(String(frame[x, y].rawValue)) })
        }
    }

    public enum LoadError: LocalizedError {
        case badRows
        public var errorDescription: String? { "The design's pixel rows don't match its width/height." }
    }

    public func frame() throws -> PixelFrame {
        guard rows.count == height, rows.allSatisfy({ $0.count == width }) else { throw LoadError.badRows }
        var f = PixelFrame(width: width, height: height)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let v = ch.wholeNumberValue, let c = SignColor(rawValue: UInt8(v)) else { throw LoadError.badRows }
                f[x, y] = c
            }
        }
        return f
    }

    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    public static func decode(_ data: Data) throws -> LEDSignDocument {
        try JSONDecoder().decode(LEDSignDocument.self, from: data)
    }
}

extension SignMode {
    /// Stable name used in saved files.
    public var key: String {
        switch self {
        case .staticDisplay: "static"
        case .scrollLeft: "scrollLeft"
        case .scrollRight: "scrollRight"
        case .scrollUp: "scrollUp"
        case .scrollDown: "scrollDown"
        case .snowflake: "snowflake"
        case .picture: "picture"
        case .laser: "laser"
        }
    }

    public init?(key: String) {
        guard let m = SignMode.allCases.first(where: { $0.key == key }) else { return nil }
        self = m
    }
}
