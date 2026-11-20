import Combine
import CoreBluetooth
import Foundation

struct DiscoveredSensor: Identifiable {
    let peripheral: CBPeripheral
    let name: String
    var id: UUID { peripheral.identifier }
}

final class BluetoothSensors: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let powerService = CBUUID(string: "1818")
    private let cadenceService = CBUUID(string: "1816")
    private let heartService = CBUUID(string: "180D")
    private let powerCharacteristic = CBUUID(string: "2A63")
    private let cadenceCharacteristic = CBUUID(string: "2A5B")
    private let heartCharacteristic = CBUUID(string: "2A37")
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var cancelling: CBPeripheral?
    private var previousCrank: SensorDecoder.CrankSample?
    private var scanTimeout: DispatchWorkItem?
    private var pendingServices = 0
    private var foundCharacteristic = false
    @Published private(set) var devices: [DiscoveredSensor] = []
    @Published private(set) var status = "Bluetooth no iniciado."
    @Published private(set) var scanning = false
    @Published private(set) var connecting = false
    @Published private(set) var disconnecting = false
    @Published private(set) var connectedName: String?
    @Published private(set) var power: Int?
    @Published private(set) var cadence: Double?
    @Published private(set) var heartRate: Int?
    @Published var errorMessage: String?

    func start() {
        guard central == nil else { return }
        status = "Preparando Bluetooth…"
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func scan() {
        guard let central = central, central.state == .poweredOn else {
            errorMessage = "Bluetooth no está disponible. Comprueba los permisos y la configuración del dispositivo."
            return
        }
        guard peripheral == nil, cancelling == nil else {
            errorMessage = "Espera a que termine la desconexión antes de buscar otro sensor."
            return
        }
        stopScan()
        devices = []
        scanning = true
        status = "Buscando sensores durante 15 segundos…"
        central.scanForPeripherals(withServices: [powerService, cadenceService, heartService])
        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.stopScan()
            self.status = self.devices.isEmpty ? "No se encontraron sensores compatibles." : "Selecciona un sensor."
        }
        scanTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }

    func connect(_ device: DiscoveredSensor) {
        guard let central = central, central.state == .poweredOn, peripheral == nil, cancelling == nil else {
            errorMessage = "No se puede conectar el sensor en el estado actual."
            return
        }
        stopScan()
        resetReadings()
        peripheral = device.peripheral
        connecting = true
        device.peripheral.delegate = self
        status = "Conectando con \(device.name)…"
        central.connect(device.peripheral)
    }

    func disconnect() {
        stopScan()
        if let peripheral = peripheral {
            peripheral.delegate = nil
            if let central = central, central.state == .poweredOn,
               peripheral.state == .connected || peripheral.state == .connecting || peripheral.state == .disconnecting {
                cancelling = peripheral
                disconnecting = true
                central.cancelPeripheralConnection(peripheral)
            }
        }
        peripheral = nil
        connecting = false
        connectedName = nil
        resetReadings()
        status = disconnecting ? "Desconectando sensor…" : "Sensor desconectado."
    }

    func stop() {
        disconnect()
        central?.delegate = nil
        central = nil
        cancelling = nil
        disconnecting = false
        devices = []
        status = "Bluetooth detenido."
    }

    private func stopScan() {
        scanTimeout?.cancel()
        scanTimeout = nil
        central?.stopScan()
        scanning = false
    }

    private func resetReadings() {
        power = nil
        cadence = nil
        heartRate = nil
        previousCrank = nil
        pendingServices = 0
        foundCharacteristic = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === self.central else { return }
        switch central.state {
        case .poweredOn:
            status = "Bluetooth disponible."
            scan()
        case .poweredOff:
            disconnect()
            cancelling = nil
            disconnecting = false
            status = "Bluetooth desactivado."
        case .unauthorized:
            disconnect()
            cancelling = nil
            disconnecting = false
            status = "Permiso Bluetooth denegado. Revisa Ajustes."
        case .unsupported:
            disconnect()
            cancelling = nil
            disconnecting = false
            status = "Este dispositivo no admite Bluetooth compatible."
        case .resetting:
            disconnect()
            cancelling = nil
            disconnecting = false
            status = "Bluetooth se está reiniciando."
        case .unknown:
            status = "Comprobando Bluetooth…"
        @unknown default:
            disconnect()
            status = "Estado Bluetooth desconocido."
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central === self.central, scanning, !devices.contains(where: { $0.id == peripheral.identifier }) else { return }
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        devices.append(DiscoveredSensor(peripheral: peripheral, name: name ?? "Sensor sin nombre"))
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard central === self.central, self.peripheral?.identifier == peripheral.identifier else { return }
        connecting = false
        connectedName = peripheral.name ?? "Sensor sin nombre"
        status = "Buscando servicios del sensor…"
        peripheral.discoverServices([powerService, cadenceService, heartService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if central === self.central, cancelling?.identifier == peripheral.identifier {
            cancelling = nil
            disconnecting = false
            status = "Sensor desconectado."
            return
        }
        guard central === self.central, self.peripheral?.identifier == peripheral.identifier else { return }
        disconnect()
        errorMessage = "No se pudo conectar el sensor: \(error?.localizedDescription ?? "error de conexión")."
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if central === self.central, cancelling?.identifier == peripheral.identifier {
            cancelling = nil
            disconnecting = false
            status = "Sensor desconectado."
            return
        }
        guard central === self.central, self.peripheral?.identifier == peripheral.identifier else { return }
        disconnect()
        if let error = error {
            errorMessage = "El sensor se ha desconectado: \(error.localizedDescription)"
        } else {
            status = "El sensor se ha desconectado."
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.peripheral?.identifier == peripheral.identifier else { return }
        if let error = error {
            errorMessage = "No se pudieron leer los servicios: \(error.localizedDescription)"
            disconnect()
            return
        }
        let services = peripheral.services ?? []
        guard !services.isEmpty else {
            errorMessage = "El sensor no ofrece los servicios de potencia, cadencia o pulso compatibles."
            disconnect()
            return
        }
        pendingServices = services.count
        for service in services {
            peripheral.discoverCharacteristics([powerCharacteristic, cadenceCharacteristic, heartCharacteristic], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard self.peripheral?.identifier == peripheral.identifier else { return }
        if let error = error {
            errorMessage = "No se pudieron leer las características del sensor: \(error.localizedDescription)"
            disconnect()
            return
        }
        for characteristic in service.characteristics ?? [] {
            guard [powerCharacteristic, cadenceCharacteristic, heartCharacteristic].contains(characteristic.uuid),
                  characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else { continue }
            foundCharacteristic = true
            peripheral.setNotifyValue(true, for: characteristic)
        }
        pendingServices -= 1
        if pendingServices == 0 {
            if foundCharacteristic {
                status = "Sensor conectado; esperando mediciones."
            } else {
                errorMessage = "El sensor no ofrece notificaciones compatibles."
                disconnect()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral?.identifier == peripheral.identifier else { return }
        if let error = error {
            errorMessage = "No se pudieron activar las mediciones del sensor: \(error.localizedDescription)"
            disconnect()
        } else if !characteristic.isNotifying {
            errorMessage = "El sensor no ha activado las notificaciones."
            disconnect()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral?.identifier == peripheral.identifier else { return }
        if let error = error {
            errorMessage = "No se pudo leer el sensor: \(error.localizedDescription)"
            return
        }
        guard let data = characteristic.value else {
            errorMessage = "El sensor no ha enviado datos."
            return
        }
        do {
            switch characteristic.uuid {
            case powerCharacteristic:
                power = try SensorDecoder.power(data)
            case cadenceCharacteristic:
                if let sample = try SensorDecoder.crank(data) {
                    if let previous = previousCrank {
                        if previous.revolutions != sample.revolutions || previous.eventTime != sample.eventTime {
                            if let value = SensorDecoder.cadence(previous: previous, current: sample) {
                                cadence = value
                            } else {
                                cadence = nil
                                errorMessage = "El sensor ha enviado una cadencia incoherente; esperando la siguiente medición."
                            }
                        }
                    }
                    previousCrank = sample
                }
            case heartCharacteristic:
                heartRate = try SensorDecoder.heartRate(data)
            default:
                return
            }
            status = "Sensor conectado."
        } catch {
            errorMessage = "No se pudo interpretar la medición: \(error.localizedDescription)"
        }
    }
}
