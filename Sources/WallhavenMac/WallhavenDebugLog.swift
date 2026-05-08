import Foundation

enum WallhavenDebugLog {
    static let logFileURL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/WallhavenMac/wallhaven.log")

    private static let queue = DispatchQueue(label: "dev.local.wallhavenmac.debug-log")

    static func record(_ event: String, details: [String: String] = [:]) {
        appendEntry(event: event, details: details, error: nil)
    }

    static func recordError(_ event: String, error: Error, details: [String: String] = [:]) {
        appendEntry(event: event, details: details, error: error)
    }

    static func ensureLogFile() -> URL {
        queue.sync {
            createLogFileIfNeeded()
            return logFileURL
        }
    }

    private static func appendEntry(event: String, details: [String: String], error: Error?) {
        let entry = formattedEntry(event: event, details: details, error: error)

        queue.async {
            createLogFileIfNeeded()

            guard let data = entry.data(using: .utf8) else { return }

            do {
                let handle = try FileHandle(forWritingTo: logFileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                assertionFailure("Failed to write WallhavenMac debug log: \(error)")
            }
        }
    }

    private static func createLogFileIfNeeded() {
        let directoryURL = logFileURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
        } catch {
            assertionFailure("Failed to create WallhavenMac debug log: \(error)")
        }
    }

    private static func formattedEntry(event: String, details: [String: String], error: Error?) -> String {
        var lines = [
            "[\(timestamp())] \(event)",
            "version: \(versionSummary())"
        ]

        for (key, value) in details.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key): \(value)")
        }

        if let error {
            let nsError = error as NSError
            lines.append("error_type: \(String(reflecting: type(of: error)))")
            lines.append("error_description: \(error.localizedDescription)")
            lines.append("error_reflection: \(String(reflecting: error))")
            lines.append("ns_error_domain: \(nsError.domain)")
            lines.append("ns_error_code: \(nsError.code)")

            if !nsError.userInfo.isEmpty {
                lines.append("ns_error_user_info: \(nsError.userInfo)")
            }
        }

        return lines.joined(separator: "\n") + "\n\n"
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func versionSummary() -> String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}
