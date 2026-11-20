import SwiftUI

struct BluetoothSensorsView: View {
    let onClose: () -> Void
    @StateObject private var sensors = BluetoothSensors()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sensores Bluetooth · experimental").font(.title2.bold())
                Text("Busca un sensor Bluetooth LE de potencia ciclista, cadencia CSC o frecuencia cardiaca. Se conecta un sensor cada vez.")
                Text(sensors.status).foregroundStyle(.secondary)
                if sensors.scanning { ProgressView("Buscando sensores…") }
                Button("Buscar sensores") { sensors.scan() }
                    .buttonStyle(.bordered)
                    .disabled(sensors.scanning || sensors.connecting || sensors.disconnecting || sensors.connectedName != nil)
                ForEach(sensors.devices) { device in
                    Button("\(device.name) · \(device.id.uuidString.prefix(8))") {
                        sensors.connect(device)
                    }
                    .disabled(sensors.connecting || sensors.disconnecting || sensors.connectedName != nil)
                }
                if let name = sensors.connectedName {
                    Text("Conectado: \(name)").font(.headline)
                }
                if let power = sensors.power {
                    Text("Última potencia: \(power) W")
                }
                if let cadence = sensors.cadence {
                    Text(String(format: "Última cadencia: %.0f rpm", cadence))
                }
                if let heartRate = sensors.heartRate {
                    Text("Última frecuencia cardiaca: \(heartRate) lpm")
                }
                Text("Se muestra el último valor recibido, que puede quedar desactualizado. No se guardan las mediciones ni se integran todavía en las sesiones.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Desconectar sensor") { sensors.disconnect() }
                Button("Volver", action: onClose)
            }
            .padding()
        }
        .onAppear {
            if scenePhase == .active { sensors.start() }
        }
        .onDisappear { sensors.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { sensors.start() } else { sensors.stop() }
        }
        .alert("Sensores Bluetooth", isPresented: Binding(
            get: { sensors.errorMessage != nil },
            set: { if !$0 { sensors.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(sensors.errorMessage ?? "")
        }
    }
}
