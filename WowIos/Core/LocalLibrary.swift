import Foundation
import Observation

/// Wallpapers you imported or pulled off the dev server. Files live in the app's
/// Documents directory so they survive relaunches, and the index is mirrored to JSON.
@MainActor
@Observable
final class LocalLibrary {
    struct Entry: Codable, Identifiable, Hashable {
        var id: String
        var title: String
        var kind: String
        var fileName: String
        var added: Date
        var allowDownload: Bool
    }

    var entries: [Entry] = []
    var exports: [ExportRecord] = []
    var lastError: String?

    private let folder: URL
    private let indexURL: URL
    private let exportFolder: URL
    private let exportIndexURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("WowIosLibrary", isDirectory: true)
        indexURL = folder.appendingPathComponent("index.json")
        exportFolder = documents.appendingPathComponent("WowIosExports", isDirectory: true)
        exportIndexURL = exportFolder.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        load()
        loadExports()
    }

    // MARK: CRUD

    func add(fileURL: URL, title: String, kind: WallpaperKind, allowDownload: Bool = true) throws {
        let id = UUID().uuidString
        let ext = fileURL.pathExtension.isEmpty ? "mov" : fileURL.pathExtension
        let destination = folder.appendingPathComponent("\(id).\(ext)")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: fileURL, to: destination)
        entries.insert(Entry(id: id,
                             title: title,
                             kind: kind.rawValue,
                             fileName: destination.lastPathComponent,
                             added: Date(),
                             allowDownload: allowDownload),
                       at: 0)
        save()
    }

    func fileURL(for entry: Entry) -> URL {
        folder.appendingPathComponent(entry.fileName)
    }

    func remove(_ entry: Entry) {
        try? FileManager.default.removeItem(at: fileURL(for: entry))
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func contains(title: String) -> Bool {
        entries.contains { $0.title == title }
    }

    var wallpapers: [Wallpaper] {
        entries.map { entry in
            Wallpaper(id: entry.id,
                      title: entry.title,
                      subtitle: "On device",
                      kind: WallpaperKind(rawValue: entry.kind) ?? .video,
                      origin: .local(fileURL(for: entry)),
                      allowDownload: entry.allowDownload,
                      isHD: true)
        }
    }

    var totalBytes: Int64 {
        entries.reduce(into: Int64(0)) { total, entry in
            let size = (try? fileURL(for: entry).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
    }

    // MARK: Export vault

    /// Keeps a copy of everything the app exported so it can be re-shared later.
    func storeExport(title: String, kind: String, fileURL: URL) throws {
        let id = UUID()
        let ext = fileURL.pathExtension.isEmpty ? "jpg" : fileURL.pathExtension
        let destination = exportFolder.appendingPathComponent("\(id.uuidString).\(ext)")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: fileURL, to: destination)
        let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let record = ExportRecord(id: id,
                                  title: title,
                                  kind: kind,
                                  fileName: destination.lastPathComponent,
                                  bytes: size,
                                  date: Date())
        exports.insert(record, at: 0)
        if exports.count > 40 {
            exports = Array(exports.prefix(40))
        }
        saveExports()
    }

    func exportURL(for record: ExportRecord) -> URL {
        exportFolder.appendingPathComponent(record.fileName)
    }

    func deleteExport(_ record: ExportRecord) {
        try? FileManager.default.removeItem(at: exportURL(for: record))
        exports.removeAll { $0.id == record.id }
        saveExports()
    }

    func clearExports() {
        for record in exports {
            try? FileManager.default.removeItem(at: exportURL(for: record))
        }
        exports = []
        saveExports()
    }

    var exportBytes: Int64 {
        exports.reduce(into: Int64(0)) { $0 += Int64($1.bytes) }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded.filter { FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func loadExports() {
        guard let data = try? Data(contentsOf: exportIndexURL),
              let decoded = try? JSONDecoder().decode([ExportRecord].self, from: data) else { return }
        exports = decoded.filter { FileManager.default.fileExists(atPath: exportURL(for: $0).path) }
    }

    private func saveExports() {
        guard let data = try? JSONEncoder().encode(exports) else { return }
        try? data.write(to: exportIndexURL, options: .atomic)
    }
}
