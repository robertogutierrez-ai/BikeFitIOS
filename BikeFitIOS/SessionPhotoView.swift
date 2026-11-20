import PhotosUI
import SwiftUI
import UIKit

struct SessionPhotoView: View {
    let session: SavedSession
    let onChange: () -> Void
    @State private var selection: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
                    .accessibilityLabel("Imagen guardada para la sesión")
                Button("Eliminar imagen", role: .destructive) { delete() }.disabled(busy)
            }
            PhotosPicker(selection: $selection, matching: .images) {
                Text(image == nil ? "Añadir imagen para comparar" : "Cambiar imagen")
            }
            .disabled(busy)
            if busy { ProgressView("Guardando imagen…") }
        }
        .onAppear(perform: load)
        .onChange(of: selection) { item in
            guard let item = item else { return }
            busy = true
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else {
                        throw PhotoError.invalidImage
                    }
                    let scale = min(1, 1280 / max(source.size.width, source.size.height))
                    let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                        source.draw(in: CGRect(origin: .zero, size: size))
                    }
                    guard let jpeg = normalized.jpegData(compressionQuality: 0.85) else {
                        throw PhotoError.invalidImage
                    }
                    try SessionHistoryStore.standard().savePhoto(jpeg, for: session)
                    image = normalized
                    onChange()
                } catch {
                    self.error = "No se pudo guardar la imagen: \(error.localizedDescription)"
                }
                selection = nil
                busy = false
            }
        }
        .alert("Imagen de sesión", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func load() {
        do {
            if let data = try SessionHistoryStore.standard().photo(for: session) {
                guard let decoded = UIImage(data: data) else { throw PhotoError.invalidImage }
                image = decoded
            } else {
                image = nil
            }
        } catch {
            self.error = "No se pudo leer la imagen: \(error.localizedDescription)"
        }
    }

    private func delete() {
        do {
            try SessionHistoryStore.standard().deletePhoto(session)
            image = nil
            onChange()
        } catch {
            self.error = "No se pudo eliminar la imagen: \(error.localizedDescription)"
        }
    }

    private enum PhotoError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "La imagen seleccionada no tiene un formato válido." }
    }
}
