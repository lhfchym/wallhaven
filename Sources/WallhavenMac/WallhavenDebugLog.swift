import Foundation

enum WallhavenDebugLog {
    private static let maximumLogSize = 1_000_000
    private static let maximumArchivedLogs = 3
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
            rotateLogIfNeeded(forIncomingBytes: entry.lengthOfBytes(using: .utf8))

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
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )

            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(
                    atPath: logFileURL.path,
                    contents: nil,
                    attributes: [.posixPermissions: 0o600]
                )
            } else {
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logFileURL.path)
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
            lines.append("\(key): \(redacted(value))")
        }

        if let error {
            let nsError = error as NSError
            lines.append("error_type: \(String(reflecting: type(of: error)))")
            lines.append("error_description: \(redacted(error.localizedDescription))")
            lines.append("ns_error_domain: \(nsError.domain)")
            lines.append("ns_error_code: \(nsError.code)")
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

    private static func rotateLogIfNeeded(forIncomingBytes incomingBytes: Int) {
        let currentSize = (try? FileManager.default.attributesOfItem(atPath: logFileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard currentSize + incomingBytes > maximumLogSize else { return }

        let manager = FileManager.default
        for index in stride(from: maximumArchivedLogs - 1, through: 1, by: -1) {
            let source = logFileURL.appendingPathExtension("\(index)")
            let destination = logFileURL.appendingPathExtension("\(index + 1)")
            try? manager.removeItem(at: destination)
            if manager.fileExists(atPath: source.path) {
                try? manager.moveItem(at: source, to: destination)
            }
        }
        let firstArchive = logFileURL.appendingPathExtension("1")
        try? manager.removeItem(at: firstArchive)
        try? manager.moveItem(at: logFileURL, to: firstArchive)
        manager.createFile(atPath: logFileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
    }

    private static func redacted(_ value: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: "(?i)([?&](?:apikey|api_key|token|access_token)=)[^&#\\s]+",
            options: []
        ) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: "$1<redacted>")
    }
}
