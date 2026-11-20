import AVFoundation
import Combine
import Foundation

final class AnnotatedVideoExport: ObservableObject {
    @Published private(set) var exporting = false
    @Published private(set) var cancelling = false
    @Published private(set) var progress: Float = 0
    @Published private(set) var fileURL: URL?
    @Published private(set) var finished = false
    @Published var errorMessage: String?

    private var session: AVAssetExportSession?
    private var progressTimer: Timer?

    func start(url: URL, sideTitle: String) {
        guard !exporting, fileURL == nil else { return }
        guard let side = VideoAnalyzer.Side.allCases.first(where: { $0.title == sideTitle }) else {
            errorMessage = "El lado seleccionado para el análisis no es válido."
            return
        }
        let asset = AVURLAsset(url: url)
        guard !asset.tracks(withMediaType: .video).isEmpty,
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720),
              session.supportedFileTypes.contains(.mp4) else {
            errorMessage = "No se puede exportar este vídeo anotado en formato MP4."
            return
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("BikeFit-anotado-\(UUID().uuidString).mp4")
        session.outputURL = output
        session.outputFileType = .mp4
        session.videoComposition = AnnotatedVideoRenderer.composition(for: asset, side: side)
        session.shouldOptimizeForNetworkUse = true
        self.session = session
        fileURL = output
        finished = false
        progress = 0
        exporting = true
        cancelling = false
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.session else { return }
            self.progress = session.progress
        }
        session.exportAsynchronously {
            DispatchQueue.main.async {
                self.complete(session)
            }
        }
    }

    func cancel() {
        guard exporting, !cancelling else { return }
        cancelling = true
        session?.cancelExport()
    }

    private func complete(_ session: AVAssetExportSession) {
        progressTimer?.invalidate()
        progressTimer = nil
        self.session = nil
        exporting = false
        let wasCancelled = session.status == .cancelled || (cancelling && session.status == .completed)
        cancelling = false
        if session.status == .completed && !wasCancelled {
            progress = 1
            finished = true
        } else {
            let failure = wasCancelled ? nil : "No se pudo crear el vídeo anotado: \(session.error?.localizedDescription ?? "error de exportación")."
            if removeFile() {
                errorMessage = failure
            } else if let failure = failure {
                errorMessage = "\(failure) \(errorMessage ?? "")"
            }
        }
    }

    @discardableResult
    func removeFile() -> Bool {
        guard !exporting else { return false }
        guard let url = fileURL else { return true }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            fileURL = nil
            finished = false
            return true
        } catch {
            errorMessage = "No se pudo eliminar el vídeo anotado temporal: \(error.localizedDescription)"
            return false
        }
    }
}
