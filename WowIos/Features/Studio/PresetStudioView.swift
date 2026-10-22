import SwiftUI

@MainActor
struct PresetStudioView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LocalLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var editingID: UUID?
    @State private var name = "My gradient"
    @State private var topHex = "#0B0B0F"
    @State private var bottomHex = "#101A2A"
    @State private var accentHex = "#6BF0C7"
    @State private var speed = 0.4
    @State private var busy: String?
    @State private var message: String?

    private var theme: Theme { settings.theme }

    private var draft: CustomPreset {
        CustomPreset(id: editingID ?? UUID(),
                     name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : name,
                     topHex: topHex,
                     bottomHex: bottomHex,
                     accentHex: accentHex,
                     speed: speed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    preview
                    editor
                    actions
                    savedPresets
                    if let message {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.accentSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .chromeSurface()
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle("Preset studio")
            .navigationBarTitleDisplayMode(.inline)
            .chromeBars()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if let busy {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text(busy)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 18).fill(theme.solidChrome))
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            CustomPresetView(preset: draft, animated: !settings.isOn(.noMotion))
            HStack(spacing: 6) {
                Pill(text: "Custom", tint: theme.accent, symbol: "paintpalette.fill")
                Pill(text: String(format: "%.2f×", speed), tint: .white.opacity(0.85))
            }
            .padding(10)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Design", caption: "Three stops, one loop")

            TextField("Name", text: $name)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(theme.solidChrome))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
                }

            colorRow("Top", binding: binding(for: $topHex))
            colorRow("Bottom", binding: binding(for: $bottomHex))
            colorRow("Accent", binding: binding(for: $accentHex))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Motion").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.2f×", speed))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $speed, in: 0.05...1.2).tint(theme.accent)
            }
        }
        .chromeSurface()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                save()
            } label: {
                Label(editingID == nil ? "Save gradient" : "Update gradient", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(WowButtonStyle())

            Button {
                Task { await exportPhoto() }
            } label: {
                Label("Save as photo · 1179×2556", systemImage: "photo")
            }
            .buttonStyle(WowButtonStyle(prominent: false))
            .disabled(busy != nil)

            HStack(spacing: 10) {
                Button {
                    resetDraft()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(WowButtonStyle(prominent: false))

                if editingID != nil {
                    Button {
                        deleteCurrent()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(WowButtonStyle(prominent: false))
                }
            }
        }
    }

    private var savedPresets: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Saved gradients", caption: "Tap one to keep editing")
            if settings.customPresets.isEmpty {
                EmptyHint(symbol: "paintbrush.pointed.fill",
                          title: "Nothing saved yet",
                          message: "Dial in three colours and save your first gradient.")
                    .chromeSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(settings.customPresets.enumerated()), id: \.element.id) { index, preset in
                        Button {
                            load(preset)
                        } label: {
                            HStack(spacing: 10) {
                                CustomPresetView(preset: preset, animated: false)
                                    .frame(width: 34, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name).font(.system(size: 13, weight: .semibold))
                                    Text(String(format: "%.2f× · %@", preset.speed, preset.accentHex))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if editingID == preset.id {
                                    Pill(text: "Editing", tint: theme.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if index < settings.customPresets.count - 1 {
                            Divider().overlay(theme.hairline).padding(.leading, 12)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous).fill(theme.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
                }
            }
        }
    }

    // MARK: Pieces

    private func colorRow(_ title: String, binding: Binding<Color>) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(binding.wrappedValue.hexString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            ColorPicker("", selection: binding, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func binding(for hex: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.hexString })
    }

    // MARK: Actions

    private func save() {
        let preset = draft
        settings.upsertCustomPreset(preset)
        editingID = preset.id
        Haptics.success()
        message = "Saved “\(preset.name)”"
    }

    private func exportPhoto() async {
        busy = "Rendering gradient…"
        defer { busy = nil }
        do {
            let preset = draft
            let url = try StudioRenderer.exportJPEG(preset)
            try library.storeExport(title: preset.name, kind: "Preset", fileURL: url)
            try await LivePhotoBuilder.savePhotoToLibrary(url)
            Haptics.success()
            message = "Saved \(preset.name) to Photos"
        } catch {
            Haptics.warning()
            message = error.localizedDescription
        }
    }

    private func load(_ preset: CustomPreset) {
        editingID = preset.id
        name = preset.name
        topHex = preset.topHex
        bottomHex = preset.bottomHex
        accentHex = preset.accentHex
        speed = preset.speed
        Haptics.select()
    }

    private func resetDraft() {
        editingID = nil
        name = "My gradient"
        topHex = "#0B0B0F"
        bottomHex = "#101A2A"
        accentHex = "#6BF0C7"
        speed = 0.4
        message = nil
        Haptics.tap()
    }

    private func deleteCurrent() {
        guard let editingID else { return }
        settings.deleteCustomPreset(editingID)
        Haptics.warning()
        message = "Deleted"
        resetDraft()
    }
}
