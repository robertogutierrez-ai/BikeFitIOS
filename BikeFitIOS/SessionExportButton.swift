import SwiftUI
import UIKit

struct SessionExportButton: View {
    let result: VideoAnalysisResult
    let date: Date
    @State private var documentURL: URL?
    @State private var showingShare = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Compartir informe PDF") { createDocument() }
                .disabled(documentURL != nil)
            if documentURL != nil && !showingShare {
                Button("Reintentar eliminar el informe temporal") { removeDocument() }
            }
        }
            .sheet(isPresented: $showingShare, onDismiss: removeDocument) {
                if let url = documentURL {
                    ShareDocument(url: url)
                        .ignoresSafeArea()
                }
            }
            .alert("Informe PDF", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
    }

    private func createDocument() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BikeFit-\(UUID().uuidString).pdf")
        do {
            let data = SessionPDF.make(result: result, date: date)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            documentURL = url
            showingShare = true
        } catch {
            self.error = "No se pudo crear el informe: \(error.localizedDescription)"
        }
    }

    private func removeDocument() {
        guard let url = documentURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            documentURL = nil
        } catch {
            self.error = "No se pudo eliminar el informe temporal: \(error.localizedDescription)"
        }
    }
}

private struct ShareDocument: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
