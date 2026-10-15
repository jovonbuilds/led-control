import SwiftUI
import UniformTypeIdentifiers
import LEDSignCore

struct ContentView: View {
    enum Tab: String, CaseIterable { case text = "Text", draw = "Draw" }

    @StateObject private var sign = SignConnection()
    @State private var tab: Tab = .text

    // Text
    @AppStorage("text") private var text = "Hello!"
    @State private var textColor: SignColor = .red
    @AppStorage("fontName") private var fontName = "Helvetica"
    @AppStorage("fontSize") private var fontSize = 15.0
    @AppStorage("bold") private var bold = true

    // Drawing
    @State private var drawing = PixelFrame(width: 96, height: 16)
    @State private var brush: SignColor = .green

    // Sign settings
    @State private var mode: SignMode = .scrollLeft
    @AppStorage("speed") private var speed = 128.0
    @AppStorage("brightness") private var brightness = 200.0
    @AppStorage("loopDelay") private var loopDelay = 150.0
    @State private var powerOn = true
    @State private var openError: String?

    private static let fonts = ["Helvetica", "Arial", "Arial Black", "Impact", "Futura",
                                "Menlo", "Courier New", "Silom", "Chalkboard"]

    private var currentFrame: PixelFrame {
        switch tab {
        case .text:
            TextRenderer.render(text, fontName: fontName, fontSize: fontSize, color: textColor,
                                height: sign.info.height, bold: bold)
        case .draw:
            drawing
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusBar
            HStack {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
                Spacer()
                Button("Open…", action: openDesign).keyboardShortcut("o")
                Button("Save…", action: saveDesign).keyboardShortcut("s")
            }

            ScrollView(.horizontal) {
                LEDPreview(frame: currentFrame, signWidth: sign.info.width,
                           paint: tab == .draw ? { x, y in drawing[x, y] = brush } : nil)
                    .padding(.bottom, 6)
            }
            .frame(height: CGFloat(sign.info.height) * 9 + 20)

            Group {
                switch tab {
                case .text: textControls
                case .draw: drawControls
                }
            }
            .frame(minHeight: 60, alignment: .top)

            Divider()
            signControls
            Divider()
            sendRow
        }
        .padding(20)
        .frame(minWidth: 940)
        .onOpenURL { loadDesign(from: $0) }
        .onChange(of: sign.info) { _, info in
            if drawing.width != info.width || drawing.height != info.height {
                drawing = PixelFrame(width: info.width, height: info.height)
            }
        }
    }

    // MARK: Sections

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusText).font(.headline)
            if sign.isReady {
                Text("\(sign.info.width)×\(sign.info.height) · \(sign.info.colorMode == 1 ? "7-color" : "color mode \(sign.info.colorMode)")")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reconnect") { sign.reconnect() }
        }
    }

    private var textControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Message", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            HStack(spacing: 16) {
                palette(selection: $textColor, includeOff: false)
                Picker("Font", selection: $fontName) {
                    ForEach(Self.fonts, id: \.self) { Text($0).font(.custom($0, size: 13)) }
                }
                .frame(width: 200)
                Stepper("Size \(Int(fontSize))", value: $fontSize, in: 6...24)
                Toggle("Bold", isOn: $bold)
            }
        }
    }

    private var drawControls: some View {
        HStack(spacing: 16) {
            palette(selection: $brush, includeOff: true)
            Text("Click or drag to paint · pick Off to erase").foregroundStyle(.secondary)
            Spacer()
            Button("Fill") { drawing = PixelFrame(width: drawing.width, height: drawing.height, fill: brush) }
            Button("Clear") { drawing = PixelFrame(width: drawing.width, height: drawing.height) }
        }
    }

    private var signControls: some View {
        HStack(spacing: 24) {
            Picker("Mode", selection: $mode) {
                ForEach(SignMode.allCases, id: \.self) { Text($0.name) }
            }
            .frame(width: 200)
            .onChange(of: mode) { _, m in Task { await sign.send(CoolLEDProtocol.mode(m), expectAck: false) } }

            slider("Speed", value: $speed) { CoolLEDProtocol.speed($0) }
            slider("Brightness", value: $brightness) { CoolLEDProtocol.brightness($0) }
            if usesLoop {
                HStack {
                    Text("Loop speed")
                    // Per-frame delay: right = faster. Takes effect on the next Send.
                    Slider(value: Binding(get: { 550 - loopDelay }, set: { loopDelay = 550 - $0 }), in: 50...500)
                        .frame(width: 120)
                }
                .help("Speed of the scroll-over-background animation. Applies on the next Send.")
            }

            Toggle("Display on", isOn: $powerOn)
                .toggleStyle(.switch)
                .onChange(of: powerOn) { _, on in Task { await sign.send(CoolLEDProtocol.power(on: on), expectAck: false) } }
        }
        .disabled(!sign.isReady)
    }

    private var sendRow: some View {
        HStack {
            if let p = sign.sendProgress {
                ProgressView(value: p).frame(width: 200)
                Text(usesLoop ? "Uploading scroll animation…" : "Sending…").foregroundStyle(.secondary)
            } else if let err = openError ?? sign.lastError {
                Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            } else if !sign.isReady {
                Text("Close the CoolLED app on your phone — the sign accepts only one connection.")
                    .foregroundStyle(.secondary)
            } else if usesLoop {
                Label("Scroll over background: the \(currentFrame.backgroundColor.name.lowercased()) background stays still. Upload takes about a minute.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                let frame = currentFrame
                let loop = usesLoop
                Task {
                    await sign.send(CoolLEDProtocol.brightness(UInt8(brightness)), expectAck: false)
                    if loop {
                        let frames = ScrollLoop.frames(of: frame, signWidth: sign.info.width)
                        await sign.send(CoolLEDProtocol.animation(frames, delay: UInt16(loopDelay)), expectAck: true)
                    } else {
                        await sign.send(CoolLEDProtocol.image(frame, signWidth: sign.info.width), expectAck: true)
                        await sign.send(CoolLEDProtocol.mode(mode), expectAck: false)
                        await sign.send(CoolLEDProtocol.speed(UInt8(speed)), expectAck: false)
                    }
                }
            } label: {
                Label("Send to Sign", systemImage: "paperplane.fill").padding(.horizontal, 8)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!sign.isReady || sign.sendProgress != nil)
        }
    }

    // MARK: Designs (.ledsign JSON; PNG import)

    /// Scroll left over a non-black background → send a seamless animation loop so
    /// the background stays still (the sign's own scroll would show black gaps).
    private var usesLoop: Bool {
        mode == .scrollLeft && ScrollLoop.needsLoop(currentFrame)
    }

    static let ledsignType = UTType(exportedAs: "io.jovon.ledsign.design", conformingTo: .json)

    private func openDesign() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.ledsignType, .png]
        panel.directoryURL = Self.designsFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadDesign(from: url)
    }

    private func loadDesign(from url: URL) {
        openError = nil
        do {
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "png" {
                guard let frame = PixelFrame(pngData: data, height: sign.info.height) else { return }
                drawing = frame
            } else {
                let doc = try LEDSignDocument.decode(data)
                drawing = try doc.frame()
                brightness = Double(doc.settings.brightness)
                speed = Double(doc.settings.speed)
                loopDelay = Double(doc.settings.loopDelay)
                mode = doc.settings.signMode
            }
            tab = .draw
        } catch {
            openError = "Couldn't open \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func saveDesign() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.ledsignType]
        panel.directoryURL = Self.designsFolder
        panel.nameFieldStringValue = "Design.\(LEDSignDocument.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openError = nil
        let doc = LEDSignDocument(
            frame: currentFrame,
            settings: .init(brightness: Int(brightness), speed: Int(speed), mode: mode, loopDelay: Int(loopDelay))
        )
        do { try doc.encoded().write(to: url) } catch { openError = error.localizedDescription }
    }

    private static var designsFolder: URL {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Documents/LED Sign Designs")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: Pieces

    private func palette(selection: Binding<SignColor>, includeOff: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(SignColor.allCases.filter { includeOff || $0 != .black }, id: \.self) { c in
                Circle()
                    .fill(c == .black ? Color(white: 0.15) : c.swiftUI)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(selection.wrappedValue == c ? Color.accentColor : .gray.opacity(0.4),
                                             lineWidth: selection.wrappedValue == c ? 3 : 1))
                    .help(c.name)
                    .onTapGesture { selection.wrappedValue = c }
            }
        }
    }

    private func slider(_ label: String, value: Binding<Double>, packet: @escaping (UInt8) -> [[UInt8]]) -> some View {
        HStack {
            Text(label)
            // Send on release, not on every intermediate value.
            Slider(value: value, in: 0...255) { editing in
                if !editing { Task { await sign.send(packet(UInt8(value.wrappedValue)), expectAck: false) } }
            }
            .frame(width: 140)
        }
    }

    private var statusText: String {
        switch sign.state {
        case .bluetoothUnavailable(let why): why
        case .scanning: "Looking for sign…"
        case .connecting(let name): "Connecting to \(name)…"
        case .ready: sign.deviceName
        case .disconnected: "Disconnected"
        }
    }

    private var statusColor: Color {
        switch sign.state {
        case .ready: .green
        case .scanning, .connecting: .yellow
        default: .red
        }
    }
}
