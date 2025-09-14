import Foundation

struct AccessEntry: Codable {
    let name: String
    let timestamp: String
}

final class EntryLogger {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "entry.logger.queue")

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Traysar", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("access_log.json")
    }

    func appendEntry(name: String) {
        queue.async {
            var entries: [AccessEntry] = (try? self.load()) ?? []
            let iso = ISO8601DateFormatter().string(from: Date())
            entries.append(AccessEntry(name: name, timestamp: iso))
            do {
                let data = try JSONEncoder().encode(entries)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                print("Failed to write access entry: \(error)")
            }
        }
    }

    private func load() throws -> [AccessEntry] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([AccessEntry].self, from: data)
    }
}


