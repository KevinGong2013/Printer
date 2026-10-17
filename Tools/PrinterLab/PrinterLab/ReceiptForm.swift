import Printer
import SwiftUI
import UniformTypeIdentifiers

struct ReceiptForm: View {
    @EnvironmentObject private var draft: ReceiptDraft

    var body: some View {
        Form {
            profileSection
            textSection
            kvSection
            imageSection
            qrSection
            barcodeSection
            rawSection
            pageSection
        }
        .formStyle(.grouped)
    }

    // MARK: Sections

    private var profileSection: some View {
        Section("Printer profile") {
            Picker("Paper", selection: $draft.paper80) {
                Text("58 mm (384 dots)").tag(false)
                Text("80 mm (576 dots)").tag(true)
            }
            .pickerStyle(.segmented)
            LabeledContent("Custom width (dots)") {
                TextField("0 = default", value: $draft.customWidth, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 110)
            }
            Picker("Text encoding", selection: $draft.encoding) {
                ForEach(EncodingChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Code page (ESC t)", selection: $draft.codePage) {
                Text("Don't send").tag(Command.CharacterCodePage?.none)
                ForEach(Command.CharacterCodePage.allCases, id: \.self) {
                    Text("\(String(describing: $0)) = \($0.rawValue)").tag(Optional($0))
                }
            }
            Picker("International set (ESC R)", selection: $draft.internationalSet) {
                Text("Don't send").tag(Command.InternationalCharacterSet?.none)
                ForEach(Command.InternationalCharacterSet.allCases, id: \.self) {
                    Text(String(describing: $0)).tag(Optional($0))
                }
            }
            Toggle("Start with ESC @ (initialize)", isOn: $draft.initialize)
        }
    }

    private var textSection: some View {
        Section {
            TextEditor(text: $draft.text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 70)
            HStack {
                Toggle("Bold", isOn: $draft.bold)
                Toggle("Italic", isOn: $draft.italics)
                Toggle("Reverse", isOn: $draft.reverse)
                Toggle("Upside down", isOn: $draft.upsideDown)
                Toggle("Rotate 90°", isOn: $draft.rotate90)
            }
            Picker("Underline", selection: $draft.underline) {
                Text("Off").tag(Command.UnderlineMode?.none)
                Text("1 dot").tag(Optional(Command.UnderlineMode.enable1dot))
                Text("2 dots").tag(Optional(Command.UnderlineMode.enable2dot))
            }
            .pickerStyle(.segmented)
            Picker("Alignment", selection: $draft.alignment) {
                ForEach(Command.Alignment.allCases, id: \.self) { Text(String(describing: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Font", selection: $draft.font) {
                ForEach(Command.CharacterFont.allCases, id: \.self) { Text("Font \(String(describing: $0).uppercased())").tag($0) }
            }
            .pickerStyle(.segmented)
            stepper("Width ×", value: $draft.charWidth, range: 1 ... 8)
            stepper("Height ×", value: $draft.charHeight, range: 1 ... 8)
            stepper("Line spacing (0 = default)", value: $draft.lineSpacing, range: 0 ... 255)
        } header: {
            Toggle("Text", isOn: $draft.includeText)
        }
    }

    private var kvSection: some View {
        Section {
            TextEditor(text: $draft.kvText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60)
            LabeledContent("Divider character") {
                TextField("-", text: $draft.dividingChar)
                    .textFieldStyle(.roundedBorder).frame(width: 40)
            }
        } header: {
            Toggle("Key / value lines (key=value per line)", isOn: $draft.includeKV)
        }
    }

    private var imageSection: some View {
        Section {
            HStack {
                if let image = draft.image {
                    Image(decorative: image, scale: 1)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .border(.separator)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(width: 160, height: 90)
                        .overlay(Text("Drop PNG / JPEG").font(.caption).foregroundStyle(.secondary))
                }
                VStack(alignment: .leading) {
                    Button("Choose image…") { chooseImage() }
                    Button("Use sample") { draft.image = SampleImage.make(); draft.imageName = "sample 300×120"; draft.includeImage = true }
                    Text(draft.imageName).font(.caption).foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                providers.first?.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    if let data = data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async { draft.loadImage(from: url) }
                    }
                }
                return true
            }
            Toggle("Floyd–Steinberg dither", isOn: $draft.dither)
            if !draft.dither {
                LabeledContent("Threshold \(Int(draft.threshold))") {
                    Slider(value: $draft.threshold, in: 0 ... 255)
                }
            }
            Picker("Mode", selection: $draft.imageMode) {
                ForEach(ImageItem.Mode.allCases, id: \.self) { Text(String(describing: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Alignment", selection: $draft.imageAlignment) {
                ForEach(Command.Alignment.allCases, id: \.self) { Text(String(describing: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Scale to paper width", isOn: $draft.fitWidth)
            stepper("Rows per band (0 = single command)", value: $draft.rowsPerBand, range: 0 ... 1024, step: 8)
        } header: {
            Toggle("Image (GS v 0)", isOn: $draft.includeImage)
        }
    }

    private var qrSection: some View {
        Section {
            TextField("Content", text: $draft.qrContent)
            stepper("Module size (dots)", value: $draft.qrModuleSize, range: 1 ... 16)
            Picker("Error correction", selection: $draft.qrLevel) {
                ForEach(QRCode.RecoveryLevel.allCases, id: \.self) { Text(String(describing: $0).uppercased()).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Model", selection: $draft.qrModel) {
                ForEach(QRCode.Model.allCases, id: \.self) { Text(String(describing: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Encode content as UTF-8 (recommended for non-ASCII)", isOn: $draft.qrUTF8)
        } header: {
            Toggle("QR code (GS ( k)", isOn: $draft.includeQR)
        }
    }

    private var barcodeSection: some View {
        Section {
            TextField("Content", text: $draft.barcodeContent)
            Picker("Symbology", selection: $draft.symbology) {
                ForEach(Barcode.Symbology.allCases, id: \.self) { Text(String(describing: $0).uppercased()).tag($0) }
            }
            stepper("Height (dots)", value: $draft.barcodeHeight, range: 1 ... 255)
            stepper("Module width", value: $draft.barcodeWidth, range: 2 ... 6)
            Picker("Text", selection: $draft.barcodeText) {
                ForEach(Barcode.TextPosition.allCases, id: \.self) { Text(String(describing: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Toggle("Barcode (GS k)", isOn: $draft.includeBarcode)
        }
    }

    private var rawSection: some View {
        Section {
            TextField("Hex bytes, e.g. 1B 40 1D 56 00", text: $draft.rawHex)
                .font(.system(.body, design: .monospaced))
        } header: {
            Toggle("Raw command", isOn: $draft.includeRaw)
        }
    }

    private var pageSection: some View {
        Section("End of receipt") {
            stepper("Feed lines", value: $draft.feedLines, range: 0 ... 20)
            Picker("Cut", selection: $draft.cut) {
                ForEach(CutChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("Pulse cash drawer", isOn: $draft.cashDrawer)
            if draft.cashDrawer {
                Picker("Drawer pin", selection: $draft.drawerPin) {
                    Text("Pin 2").tag(0)
                    Text("Pin 5").tag(1)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: Helpers

    private func stepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step)
                Text("\(Int(value.wrappedValue))").monospacedDigit().frame(width: 36, alignment: .trailing)
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif, .heic]
        if panel.runModal() == .OK, let url = panel.url {
            draft.loadImage(from: url)
        }
    }
}

enum SampleImage {
    /// A 300×120 test card: text, a gradient and a few shapes, to check scaling, dithering and inversion.
    static func make() -> CGImage? {
        let width = 300, height = 120
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // gradient bar
        let colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors, locations: [0, 1]) {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 10, y: 10, width: 280, height: 24))
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 10, y: 0), end: CGPoint(x: 290, y: 0), options: [])
            ctx.restoreGState()
        }
        // shapes
        ctx.setFillColor(.black)
        ctx.fillEllipse(in: CGRect(x: 20, y: 50, width: 50, height: 50))
        ctx.setLineWidth(3)
        ctx.setStrokeColor(.black)
        ctx.stroke(CGRect(x: 90, y: 50, width: 50, height: 50))
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 160, y: 50, width: 50, height: 50))
        // text
        let text = NSAttributedString(string: "Printer", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 28), .foregroundColor: NSColor.black,
        ])
        let line = CTLineCreateWithAttributedString(text)
        ctx.textPosition = CGPoint(x: 220, y: 62)
        CTLineDraw(line, ctx)
        return ctx.makeImage()
    }
}
