import Foundation

/// Text/image movement modes understood by the sign.
public enum SignMode: UInt8, CaseIterable, Sendable {
    case staticDisplay = 1, scrollLeft, scrollRight, scrollUp, scrollDown, snowflake, picture, laser

    public var name: String {
        switch self {
        case .staticDisplay: "Static"
        case .scrollLeft: "Scroll left"
        case .scrollRight: "Scroll right"
        case .scrollUp: "Scroll up"
        case .scrollDown: "Scroll down"
        case .snowflake: "Snowflake"
        case .picture: "Picture"
        case .laser: "Laser"
        }
    }
}

/// Advertised sign properties, parsed from the BLE manufacturer data.
public struct SignInfo: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let colorMode: Int
    public let firmware: Int

    public static let fallback = SignInfo(width: 96, height: 16, colorMode: 1, firmware: 0)

    /// `data` is CoreBluetooth's kCBAdvDataManufacturerData: a 2-byte company ID
    /// (0x0E09 for this sign) followed by [mac x6][height][width hi][width lo][color][fw].
    public init?(manufacturerData data: Data) {
        let b = [UInt8](data)
        guard b.count >= 13 else { return nil }
        height = Int(b[8])
        width = Int(b[9]) << 8 | Int(b[10])
        colorMode = Int(b[11])
        firmware = Int(b[12])
        guard width > 0, height > 0, height % 8 == 0 else { return nil }
    }

    public init(width: Int, height: Int, colorMode: Int, firmware: Int) {
        self.width = width
        self.height = height
        self.colorMode = colorMode
        self.firmware = firmware
    }
}

/// CoolLEDX ("basic") wire protocol, ported from github.com/UpDryTwist/coolledx-driver
/// and verified byte-for-byte against it (see LEDSignCoreTests/golden.txt).
///
/// Every packet is `0x01 escape(len16 ++ body) 0x03`, where bytes 0x01–0x03 inside
/// are escaped as `0x02, b + 4`. Bulk data (images) is split into 128-byte chunks,
/// each with its own header and XOR checksum, and each chunk is its own packet.
public enum CoolLEDProtocol {
    enum Command: UInt8 {
        case text = 0x02, image = 0x03, animation = 0x04
        case mode = 0x06, speed = 0x07, brightness = 0x08, power = 0x09
    }

    static let chunkSize = 128

    // MARK: Public packet builders. Each returns the packets to write, in order.

    public static func brightness(_ value: UInt8) -> [[UInt8]] { [packet([Command.brightness.rawValue, value])] }
    public static func speed(_ value: UInt8) -> [[UInt8]] { [packet([Command.speed.rawValue, value])] }
    public static func mode(_ mode: SignMode) -> [[UInt8]] { [packet([Command.mode.rawValue, mode.rawValue])] }
    public static func power(on: Bool) -> [[UInt8]] { [packet([Command.power.rawValue, on ? 1 : 0])] }

    /// A still image. Frames narrower than the sign are padded; wider ones scroll.
    public static func image(_ frame: PixelFrame, signWidth: Int) -> [[UInt8]] {
        let padded = frame.padded(toWidth: signWidth)
        let bits = bitPlanes(padded)
        var payload = [UInt8](repeating: 0, count: 24)  // purpose unknown; always zero
        payload += be16(bits.count)
        payload += bits
        return chunked(payload, command: .image).map(packet)
    }

    /// A looping animation. Every frame must be exactly sign-sized. `delay` is the
    /// per-frame delay (larger = slower; 150 looked right on the 96×16 sign).
    public static func animation(_ frames: [PixelFrame], delay: UInt16) -> [[UInt8]] {
        precondition(!frames.isEmpty && frames.count <= 255, "1–255 frames")
        var r: [UInt8] = [], g: [UInt8] = [], b: [UInt8] = []
        for f in frames {
            let planes = bitPlanes(f), n = planes.count / 3
            r += planes[0..<n]; g += planes[n..<2 * n]; b += planes[(2 * n)...]
        }
        var payload = [UInt8](repeating: 0, count: 24)  // purpose unknown; always zero
        payload.append(UInt8(frames.count))
        payload += be16(Int(delay))
        payload += r + g + b
        return chunked(payload, command: .animation).map(packet)
    }

    // MARK: Internals (internal for tests)

    /// Column-major 1-bit planes: for each column top-to-bottom, 8 rows per byte, MSB
    /// = top pixel. All red bytes, then all green, then all blue.
    static func bitPlanes(_ frame: PixelFrame) -> [UInt8] {
        precondition(frame.height % 8 == 0, "sign height must be a multiple of 8")
        var r: [UInt8] = [], g: [UInt8] = [], b: [UInt8] = []
        let bytesPerColumn = frame.height / 8
        r.reserveCapacity(frame.width * bytesPerColumn)
        g.reserveCapacity(frame.width * bytesPerColumn)
        b.reserveCapacity(frame.width * bytesPerColumn)
        for x in 0..<frame.width {
            var tr: UInt8 = 0, tg: UInt8 = 0, tb: UInt8 = 0
            for y in 0..<frame.height {
                let c = frame[x, y]
                tr = tr << 1 | (c.red ? 1 : 0)
                tg = tg << 1 | (c.green ? 1 : 0)
                tb = tb << 1 | (c.blue ? 1 : 0)
                if y % 8 == 7 {
                    r.append(tr); g.append(tg); b.append(tb)
                    tr = 0; tg = 0; tb = 0
                }
            }
        }
        return r + g + b
    }

    /// Splits bulk data: each chunk is
    /// `[cmd][0x00][total len16][chunk index16][chunk len8][data][xor of everything after cmd]`.
    static func chunked(_ data: [UInt8], command: Command) -> [[UInt8]] {
        stride(from: 0, to: max(data.count, 1), by: chunkSize).enumerated().map { index, start in
            let part = data[start..<min(start + chunkSize, data.count)]
            var body: [UInt8] = [0x00]
            body += be16(data.count)
            body += be16(index)
            body.append(UInt8(part.count))
            body += part
            body.append(body.reduce(0, ^))
            return [command.rawValue] + body
        }
    }

    static func packet(_ raw: [UInt8]) -> [UInt8] {
        [0x01] + escape(be16(raw.count) + raw) + [0x03]
    }

    static func escape(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count + 8)
        for b in bytes {
            if b >= 0x01 && b <= 0x03 { out += [0x02, b + 4] } else { out.append(b) }
        }
        return out
    }

    static func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
}
