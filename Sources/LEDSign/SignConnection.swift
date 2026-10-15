import CoreBluetooth
import LEDSignCore

/// Finds the first CoolLED* sign, connects, and writes packets to it.
///
/// The sign exposes one characteristic (fff1) that is write-without-response +
/// notify. After each bulk-data chunk it sends a notification as an ack; we wait for
/// it (with a timeout) before sending the next chunk, as the Python driver does.
@MainActor
final class SignConnection: NSObject, ObservableObject {
    enum State: Equatable {
        case bluetoothUnavailable(String)
        case scanning
        case connecting(String)
        case ready
        case disconnected
    }

    @Published private(set) var state: State = .scanning
    @Published private(set) var info: SignInfo = .fallback
    @Published private(set) var deviceName = ""
    @Published private(set) var sendProgress: Double?  // nil when idle
    @Published private(set) var lastError: String?

    private static let service = CBUUID(string: "FFF0")
    private static let characteristic = CBUUID(string: "FFF1")

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var ackContinuation: CheckedContinuation<Bool, Never>?
    private var readyContinuation: CheckedContinuation<Void, Never>?
    private var ackToken = 0
    private var busy = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isReady: Bool { state == .ready }

    func reconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
        writeChar = nil
        startScan()
    }

    private func startScan() {
        guard central.state == .poweredOn else { return }
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    // MARK: Sending

    /// Sends packets in order. `expectAck` waits for the sign's notification after
    /// each packet (needed for image chunks; harmless but slower for settings).
    func send(_ packets: [[UInt8]], expectAck: Bool) async {
        guard let p = peripheral, let c = writeChar, state == .ready else {
            lastError = "Sign not connected"
            return
        }
        // Serialize: a second send while one is in flight would interleave chunks.
        while busy { try? await Task.sleep(for: .milliseconds(20)) }
        busy = true
        defer { busy = false; sendProgress = nil }
        lastError = nil
        let maxWrite = p.maximumWriteValueLength(for: .withoutResponse)

        for (i, packet) in packets.enumerated() {
            if packets.count > 1 { sendProgress = Double(i) / Double(packets.count) }
            // A packet can exceed one BLE write; the sign reassembles by 0x01…0x03 framing.
            var offset = 0
            while offset < packet.count {
                let end = min(offset + maxWrite, packet.count)
                if !p.canSendWriteWithoutResponse {
                    await withCheckedContinuation { readyContinuation = $0 }
                }
                p.writeValue(Data(packet[offset..<end]), for: c, type: .withoutResponse)
                offset = end
            }
            if expectAck {
                let acked = await waitForAck(timeout: .seconds(2))
                if !acked { lastError = "Sign didn't acknowledge chunk \(i + 1) of \(packets.count)" }
            } else {
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func waitForAck(timeout: Duration) async -> Bool {
        ackToken &+= 1
        let token = ackToken
        return await withCheckedContinuation { cont in
            ackContinuation = cont
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                // Only time out the wait we started, not a later one.
                if self?.ackToken == token { self?.resolveAck(false) }
            }
        }
    }

    private func resolveAck(_ value: Bool) {
        ackContinuation?.resume(returning: value)
        ackContinuation = nil
    }
}

extension SignConnection: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: startScan()
        case .unauthorized:
            state = .bluetoothUnavailable("Bluetooth permission denied — allow LEDSign in System Settings › Privacy & Security › Bluetooth")
        case .poweredOff: state = .bluetoothUnavailable("Bluetooth is off")
        default: state = .bluetoothUnavailable("Bluetooth unavailable")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard name.hasPrefix("CoolLED"), self.peripheral == nil else { return }
        if let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           let parsed = SignInfo(manufacturerData: data) {
            info = parsed
            let id = data.prefix(2).reversed().map { String(format: "%02X", $0) }.joined()
            deviceName = "\(name)-\(id)"
        } else {
            deviceName = name
        }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        state = .connecting(deviceName)
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lastError = error?.localizedDescription
        self.peripheral = nil
        startScan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        writeChar = nil
        resolveAck(false)
        state = .disconnected
        // Reconnect automatically (e.g. sign power-cycled or walked out of range).
        startScan()
    }
}

extension SignConnection: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let s = peripheral.services?.first(where: { $0.uuid == Self.service }) else { return }
        peripheral.discoverCharacteristics([Self.characteristic], for: s)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let c = service.characteristics?.first(where: { $0.uuid == Self.characteristic }) else { return }
        writeChar = c
        peripheral.setNotifyValue(true, for: c)
        state = .ready
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        resolveAck(true)
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        readyContinuation?.resume()
        readyContinuation = nil
    }
}
