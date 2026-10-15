import XCTest
@testable import LEDSignCore

/// golden.txt was produced by the Python coolledx-driver — the code that was first
/// proven to drive this sign — so matching it byte-for-byte proves the port.
final class ProtocolTests: XCTestCase {
    private func golden() throws -> [String: [[UInt8]]] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "golden", withExtension: "txt"))
        var out: [String: [[UInt8]]] = [:]
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            let parts = line.split(separator: " ")
            out[String(parts[0])] = parts[1].split(separator: ",").map { hex in
                stride(from: 0, to: hex.count, by: 2).map { i in
                    let s = hex.index(hex.startIndex, offsetBy: i)
                    return UInt8(hex[s..<hex.index(s, offsetBy: 2)], radix: 16)!
                }
            }
        }
        return out
    }

    /// Same pattern as golden.py: color index (x*3 + y) % 8.
    private func pattern(width: Int) -> PixelFrame {
        var f = PixelFrame(width: width, height: 16)
        for x in 0..<width { for y in 0..<16 { f[x, y] = SignColor(rawValue: UInt8((x * 3 + y) % 8))! } }
        return f
    }

    func testImageMatchesPython() throws {
        let g = try golden()
        XCTAssertEqual(CoolLEDProtocol.image(pattern(width: 96), signWidth: 96), g["image96"])
        XCTAssertEqual(CoolLEDProtocol.image(pattern(width: 130), signWidth: 96), g["image130"])
    }

    func testSimpleCommandsMatchPython() throws {
        let g = try golden()
        XCTAssertEqual(CoolLEDProtocol.brightness(200), g["brightness200"])
        XCTAssertEqual(CoolLEDProtocol.speed(1), g["speed1"])
        XCTAssertEqual(CoolLEDProtocol.mode(.scrollLeft), g["modeLeft"])
        XCTAssertEqual(CoolLEDProtocol.power(on: true), g["on"])
        XCTAssertEqual(CoolLEDProtocol.power(on: false), g["off"])
    }

    func testNarrowFramesArePaddedToSignWidth() {
        let narrow = CoolLEDProtocol.image(PixelFrame(width: 10, height: 16), signWidth: 96)
        let full = CoolLEDProtocol.image(PixelFrame(width: 96, height: 16), signWidth: 96)
        XCTAssertEqual(narrow, full)
    }

    func testParsesAdvertisedManufacturerData() {
        // Real advertisement from the sign: company 0x0E09 + ff0000048c191000600106
        let data = Data([0x09, 0x0E, 0xFF, 0x00, 0x00, 0x04, 0x8C, 0x19, 0x10, 0x00, 0x60, 0x01, 0x06])
        XCTAssertEqual(SignInfo(manufacturerData: data), SignInfo(width: 96, height: 16, colorMode: 1, firmware: 6))
    }

    func testTextRendersInk() {
        let f = TextRenderer.render("HI", fontName: "Helvetica", fontSize: 14, color: .red, bold: true)
        XCTAssertEqual(f.height, 16)
        XCTAssertTrue(f.pixels.contains(.red))
        XCTAssertFalse(f.pixels.contains(.green))
    }
}
