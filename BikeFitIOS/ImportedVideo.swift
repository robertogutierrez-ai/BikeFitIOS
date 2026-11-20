import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ImportedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie, shouldAttemptToOpenInPlace: false) { received in
            ImportedVideo(url: try copyToTemporaryDirectory(received.file))
        }
    }

    static func copyToTemporaryDirectory(_ source: URL, directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let destination = directory
            .appendingPathComponent("bikefit-import-\(UUID().uuidString)")
            .appendingPathExtension(source.pathExtension.isEmpty ? "mov" : source.pathExtension)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}
