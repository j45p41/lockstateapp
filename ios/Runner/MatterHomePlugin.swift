import Flutter
import UIKit
import HomeKit
import MatterSupport
import Matter
import CoreBluetooth

/// Flutter plugin for Matter device commissioning and state monitoring.
///
/// Uses MatterSupport framework (iOS 16.4+) for in-app device commissioning,
/// and HomeKit for ongoing state monitoring (Matter devices appear as HomeKit
/// accessories after commissioning via Apple's fabric).
///
/// MethodChannel: com.locksure.lockstate/matter_home
///   - requestAccess         → triggers HMHomeManager authorization
///   - commissionDevice      → commission a Matter device via system dialog
///   - discoverDevices       → returns Locksure accessories from all homes
///   - subscribeToDevice     → starts lock state notifications for a device
///   - unsubscribeFromDevice → stops notifications
///   - getDeviceState        → reads current lock/door state
///   - getDiagnostics        → reads device diagnostics (reboot count, uptime, etc.)
///
/// EventChannel: com.locksure.lockstate/matter_home_events
///   - streams state change events from subscribed devices
class MatterHomePlugin: NSObject, FlutterPlugin {

    private var homeManager: HMHomeManager?
    private var eventSink: FlutterEventSink?
    private var subscribedAccessories: [String: HMAccessory] = [:]
    private var isHomeManagerReady = false
    private var pendingDiscoverResult: FlutterResult?

    // BLE scanning for commissionable Matter devices
    private var centralManager: CBCentralManager?
    private var bleScanDelegate: MatterBleScanDelegate?
    private var discoveredCommissionable: [String: [String: Any]] = [:]
    private var bleScanTimer: Timer?
    private var pendingBleScanResult: FlutterResult?

    // Commissioning discriminator override (set by scanForCommissionableDevices)
    private var overrideDiscriminator: UInt16 = 3840

    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.locksure.lockstate/matter_home",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.locksure.lockstate/matter_home_events",
            binaryMessenger: registrar.messenger()
        )

        let instance = MatterHomePlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - MethodChannel Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAccess":
            requestAccess(result: result)
        case "commissionDevice":
            let args = call.arguments as? [String: Any]
            commissionDevice(args: args, result: result)
        case "discoverDevices":
            discoverDevices(result: result)
        case "subscribeToDevice":
            guard let args = call.arguments as? [String: Any],
                  let uniqueId = args["uniqueId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "uniqueId required", details: nil))
                return
            }
            subscribeToDevice(uniqueId: uniqueId, result: result)
        case "unsubscribeFromDevice":
            guard let args = call.arguments as? [String: Any],
                  let uniqueId = args["uniqueId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "uniqueId required", details: nil))
                return
            }
            unsubscribeFromDevice(uniqueId: uniqueId, result: result)
        case "getDeviceState":
            guard let args = call.arguments as? [String: Any],
                  let uniqueId = args["uniqueId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "uniqueId required", details: nil))
                return
            }
            getDeviceState(uniqueId: uniqueId, result: result)
        case "getDiagnostics":
            guard let args = call.arguments as? [String: Any],
                  let uniqueId = args["uniqueId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "uniqueId required", details: nil))
                return
            }
            getDiagnostics(uniqueId: uniqueId, result: result)
        case "triggerDfuMode":
            guard let args = call.arguments as? [String: Any],
                  let uniqueId = args["uniqueId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "uniqueId required", details: nil))
                return
            }
            triggerDfuMode(uniqueId: uniqueId, result: result)
        case "isMatterSupported":
            if #available(iOS 16.4, *) {
                result(true)
            } else {
                result(false)
            }
        case "removeAccessory":
            guard let args = call.arguments as? [String: Any],
                  let uniqueId = args["uniqueId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "uniqueId required", details: nil))
                return
            }
            removeAccessory(uniqueId: uniqueId, result: result)
        case "discoverRooms":
            discoverRooms(result: result)
        case "scanForCommissionableDevices":
            let duration = (call.arguments as? [String: Any])?["durationSec"] as? Int ?? 5
            scanForCommissionableDevices(durationSec: duration, result: result)
        case "setCommissioningDiscriminator":
            if let args = call.arguments as? [String: Any],
               let disc = args["discriminator"] as? Int {
                overrideDiscriminator = UInt16(disc)
                print("[MatterHome] Commissioning discriminator set to \(disc) (0x\(String(disc, radix: 16)))")
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARG", message: "discriminator required", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - HomeKit Access

    private func requestAccess(result: @escaping FlutterResult) {
        if homeManager == nil {
            homeManager = HMHomeManager()
            homeManager?.delegate = self
        }
        result(true)
    }

    // MARK: - Matter Commissioning (via HomeKit → Apple Home fabric)

    /// Commission a new Locksure Matter device DIRECTLY into Apple Home.
    ///
    /// Uses `HMAccessorySetupManager.performAccessorySetup(using:)` with a
    /// Matter setup payload — this is the Apple-recommended API (DTS thread 766028)
    /// for apps that want to add a device to the user's Apple Home without
    /// running their own Matter fabric. The device ends up in Apple's fabric,
    /// so HomeKit discovery will find it afterwards.
    ///
    /// For test-VID devices (0xFFF1..0xFFF4), Apple shows an "Uncertified
    /// Accessory — Add Anyway" prompt; user accepts once and commissioning
    /// completes.
    private func commissionDevice(args: [String: Any]?, result: @escaping FlutterResult) {
        guard #available(iOS 16.4, *) else {
            result(FlutterError(code: "UNSUPPORTED",
                message: "Matter commissioning requires iOS 16.4+", details: nil))
            return
        }

        guard let manager = homeManager, isHomeManagerReady else {
            result(FlutterError(code: "NOT_READY",
                message: "HomeKit not initialized. Call requestAccess first.", details: nil))
            return
        }

        guard manager.homes.first != nil else {
            result(FlutterError(code: "NO_HOME",
                message: "No Home found. Create a Home in the Apple Home app first.", details: nil))
            return
        }

        Task {
            let startTime = Date()
            print("[MatterHome] ================================================")
            print("[MatterHome] Commissioning via HMAccessorySetupManager")
            print("[MatterHome] discriminator=\(self.overrideDiscriminator) (0x\(String(self.overrideDiscriminator, radix: 16))) passcode=20202021")

            let setupMgr = HMAccessorySetupManager()
            let request = HMAccessorySetupRequest()

            if #available(iOS 16.4, *) {
                let payload = MTRSetupPayload(setupPasscode: NSNumber(value: 20202021),
                                               discriminator: NSNumber(value: self.overrideDiscriminator))
                // HMAccessorySetupRequest.matterPayload was added in iOS 16.4
                request.matterPayload = payload

                if let manualCode = payload.manualEntryCode() {
                    print("[MatterHome]   manualEntryCode: \(manualCode)")
                }
                if #available(iOS 17.6, *) {
                    if let qrCode = try? payload.qrCodeString() {
                        print("[MatterHome]   qrCodeString: \(qrCode)")
                    }
                }
            }

            print("[MatterHome] Calling performAccessorySetup — Apple's pairing sheet should appear")

            do {
                let setupResult = try await setupMgr.performAccessorySetup(using: request)
                let elapsed = Date().timeIntervalSince(startTime)
                print("[MatterHome] ✓ performAccessorySetup SUCCESS after \(String(format: "%.1f", elapsed))s")
                print("[MatterHome]   homeUUID: \(setupResult.homeUniqueIdentifier.uuidString)")
                print("[MatterHome]   accessoryUUIDs: \(setupResult.accessoryUniqueIdentifiers.map { $0.uuidString })")

                // Wait briefly for HomeKit to register the new accessory
                try? await Task.sleep(nanoseconds: 1_500_000_000)

                // Look up the resulting home to log its accessories
                let resultHome = manager.homes.first(where: {
                    $0.uniqueIdentifier == setupResult.homeUniqueIdentifier
                })
                if let h = resultHome {
                    print("[MatterHome] Accessories in '\(h.name)' AFTER commission: \(h.accessories.count)")
                    for acc in h.accessories {
                        print("[MatterHome]   • \(acc.name) | \(acc.manufacturer ?? "?") / \(acc.model ?? "?") | reachable=\(acc.isReachable)")
                    }
                }

                let devices = self.findLocksureAccessories(in: manager)
                result(["success": true, "devices": devices])
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                let nsErr = error as NSError
                print("[MatterHome] ✗ performAccessorySetup FAILED after \(String(format: "%.1f", elapsed))s")
                print("[MatterHome]   error: \(error)")
                print("[MatterHome]   domain: \(nsErr.domain) code: \(nsErr.code)")
                print("[MatterHome]   localizedDescription: \(error.localizedDescription)")

                let desc = error.localizedDescription
                if desc.contains("cancel") || nsErr.code == -999 {
                    result(["success": false, "error": "Commissioning was cancelled."])
                } else {
                    result(["success": false, "error": desc])
                }
            }
        }
    }

    // MARK: - Remove Accessory (unpair from Apple Home)

    /// Remove a Matter accessory from Apple Home. This un-commissions the
    /// device from Apple's Matter fabric (device reverts to factory-unpaired
    /// on Apple's side, though still in other fabrics if multi-admin).
    ///
    /// Called when the user deletes the corresponding door in Locksure — avoids
    /// leaving orphaned accessories in Apple Home.
    private func removeAccessory(uniqueId: String, result: @escaping FlutterResult) {
        guard let manager = homeManager, isHomeManagerReady else {
            result(FlutterError(code: "NOT_READY", message: "HomeKit not initialized", details: nil))
            return
        }
        guard let accessory = findAccessory(uniqueId: uniqueId, in: manager) else {
            print("[MatterHome] removeAccessory: not found in any home (already removed?) \(uniqueId)")
            result(["success": true, "message": "Accessory not found — already removed"])
            return
        }
        guard let home = manager.homes.first(where: { $0.accessories.contains(accessory) }) else {
            result(FlutterError(code: "NO_HOME", message: "Home not found for accessory", details: nil))
            return
        }

        var nodeIdStr = "nil"
        if #available(iOS 16.1, *) {
            nodeIdStr = accessory.matterNodeID?.description ?? "nil"
        }
        print("[MatterHome] removeAccessory: removing '\(accessory.name)' (uuid=\(accessory.uniqueIdentifier.uuidString), matterNodeID=\(nodeIdStr)) from home '\(home.name)'")
        print("[MatterHome]   home.isPrimary=\(home.isPrimary)")
        print("[MatterHome]   accessories before: \(home.accessories.count)")

        home.removeAccessory(accessory) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                let nsErr = error as NSError
                print("[MatterHome] removeAccessory FAILED: \(error)")
                print("[MatterHome]   domain: \(nsErr.domain) code: \(nsErr.code)")
                print("[MatterHome]   userInfo: \(nsErr.userInfo)")
                result(FlutterError(code: "REMOVE_FAILED",
                    message: error.localizedDescription, details: nil))
                return
            }
            // Verify the accessory is actually gone — HMHome.removeAccessory
            // sometimes returns success without actually unpairing Matter devices.
            print("[MatterHome] removeAccessory returned success, verifying…")
            // Wait briefly for HomeKit to propagate the removal
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let stillPresent = self.homeManager?.homes
                    .flatMap { $0.accessories }
                    .contains(where: { $0.uniqueIdentifier.uuidString == uniqueId }) ?? false
                print("[MatterHome]   accessories after: \(home.accessories.count), still present: \(stillPresent)")
                if stillPresent {
                    print("[MatterHome] WARNING: removeAccessory reported success but device is still in Apple Home.")
                    print("[MatterHome] This can happen if:")
                    print("[MatterHome]   • You are not the Home admin/owner")
                    print("[MatterHome]   • Apple TV/HomePod Mini isn't online to propagate unpair")
                    print("[MatterHome]   • iOS deferred the removal")
                    result(["success": false, "stillPresent": true,
                        "error": "removeAccessory reported success but device still in Apple Home"])
                } else {
                    print("[MatterHome] removeAccessory confirmed — device gone")
                    self.subscribedAccessories.removeValue(forKey: uniqueId)
                    result(["success": true])
                }
            }
        }
    }


    // NOTE: Vendor-cluster historical event retrieval was removed after
    // verifying that Apple Home's XPC-bridged Matter controller does not
    // support attribute reads or subscriptions on custom/vendor clusters
    // (confirmed via DTS + diagnostic probes returning MTRErrorDomain Code=6
    // "Invalid object state" on both vendor and standard Descriptor
    // cluster reads). History is now real-time only via HMCharacteristic.


    // MARK: - BLE Scan for Commissionable Matter Devices

    /// Scan for Matter-commissionable BLE advertisements. Returns devices that
    /// advertise the Matter commissioning service UUID (0xFFF6). For each device
    /// we parse the 8-byte service data to extract:
    ///   - 2 bytes: opcode + version (discriminator low nibble in bits 0-11)
    ///   - 2 bytes: vendor ID (little-endian)
    ///   - 2 bytes: product ID (little-endian)
    ///   - 1 byte: flags
    ///   - 1 byte: additional data
    private func scanForCommissionableDevices(durationSec: Int, result: @escaping FlutterResult) {
        print("[MatterHome] BLE scan starting for \(durationSec)s …")

        // Cancel any prior scan
        bleScanTimer?.invalidate()
        bleScanTimer = nil

        discoveredCommissionable.removeAll()
        pendingBleScanResult = result

        if bleScanDelegate == nil {
            bleScanDelegate = MatterBleScanDelegate(plugin: self)
        }
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: bleScanDelegate, queue: .main)
        } else if centralManager?.state == .poweredOn {
            startBleScanNow()
        }

        // Stop scan after duration and return results
        bleScanTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(durationSec), repeats: false) { [weak self] _ in
            self?.stopBleScanAndReturn()
        }
    }

    fileprivate func startBleScanNow() {
        // Matter commissioning service UUID
        let matterUUID = CBUUID(string: "FFF6")
        centralManager?.scanForPeripherals(
            withServices: [matterUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        print("[MatterHome] BLE scan active — looking for service UUID FFF6")
    }

    fileprivate func onBlePeripheralDiscovered(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let matterUUID = CBUUID(string: "FFF6")
        guard let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
              let data = serviceData[matterUUID] else {
            return
        }

        // Parse Matter commissionable data advertisement (spec 5.4.2.5.6)
        guard data.count >= 8 else {
            print("[MatterHome] BLE: service data too short (\(data.count) bytes) — ignored")
            return
        }
        let bytes = Array(data)
        // Byte 0 lower nibble = op code (0=commissionable), upper nibble = version
        // Bytes 1-2 = discriminator (little-endian, 12-bit)
        let discriminator = (UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)) & 0x0FFF
        let vendorID = UInt16(bytes[3]) | (UInt16(bytes[4]) << 8)
        let productID = UInt16(bytes[5]) | (UInt16(bytes[6]) << 8)
        let flags = bytes[7]

        // Only report Locksure devices (vendor 65521 = 0xFFF1)
        guard vendorID == 65521 else { return }

        let id = peripheral.identifier.uuidString
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Locksure"

        let info: [String: Any] = [
            "id": id,
            "name": name,
            "discriminator": Int(discriminator),
            "vendorID": Int(vendorID),
            "productID": Int(productID),
            "rssi": rssi.intValue,
            "flags": Int(flags),
        ]

        // Dedup by peripheral id (keep latest RSSI)
        discoveredCommissionable[id] = info
        print("[MatterHome] BLE found: \(name) disc=\(discriminator) (0x\(String(discriminator, radix: 16))) vendor=\(vendorID) product=\(productID) rssi=\(rssi)")
    }

    private func stopBleScanAndReturn() {
        centralManager?.stopScan()
        bleScanTimer?.invalidate()
        bleScanTimer = nil

        // Sort by RSSI descending (closest first)
        let sorted = Array(discoveredCommissionable.values).sorted {
            (($0["rssi"] as? Int) ?? -200) > (($1["rssi"] as? Int) ?? -200)
        }
        print("[MatterHome] BLE scan complete — \(sorted.count) Locksure device(s) found")
        pendingBleScanResult?(sorted)
        pendingBleScanResult = nil
    }

    // MARK: - Room Discovery

    /// Returns rooms (HMRoom) from all HomeKit homes.
    /// Each room includes the home name so the app can group them.
    private func discoverRooms(result: @escaping FlutterResult) {
        guard let manager = homeManager, isHomeManagerReady else {
            if homeManager == nil {
                homeManager = HMHomeManager()
                homeManager?.delegate = self
            }
            // Return empty for now — will be ready after delegate fires
            result([])
            return
        }

        var rooms: [[String: Any]] = []
        for home in manager.homes {
            for room in home.rooms {
                rooms.append([
                    "roomName": room.name,
                    "homeName": home.name,
                    "homeId": home.uniqueIdentifier.uuidString,
                ])
            }
        }
        result(rooms)
    }

    // MARK: - Device Discovery

    private func discoverDevices(result: @escaping FlutterResult) {
        guard let manager = homeManager else {
            homeManager = HMHomeManager()
            homeManager?.delegate = self
            pendingDiscoverResult = result
            return
        }

        if !isHomeManagerReady {
            pendingDiscoverResult = result
            return
        }

        let devices = findLocksureAccessories(in: manager)
        result(devices)
    }

    /// Iterates all homes and accessories, filtering for Locksure devices.
    /// Captures both manufacturer and model for identification.
    private func findLocksureAccessories(in manager: HMHomeManager) -> [[String: Any]] {
        var results: [[String: Any]] = []

        for home in manager.homes {
            for accessory in home.accessories {
                let manufacturer = accessory.manufacturer ?? ""
                let model = accessory.model ?? ""
                let name = accessory.name

                var isLocksure = manufacturer.localizedCaseInsensitiveContains("locksure")
                    || model.localizedCaseInsensitiveContains("locksure")
                    || name.localizedCaseInsensitiveContains("locksure")

                // Also match by Matter vendor ID (iOS 17+) — catches devices
                // freshly commissioned that don't yet have manufacturer populated
                if !isLocksure, #available(iOS 17.0, *) {
                    // Check if it's a Matter accessory with Locksure vendor
                    if accessory.services.contains(where: { svc in
                        svc.serviceType == HMServiceTypeLockMechanism
                    }) && model.lowercased().contains("lseu") {
                        isLocksure = true
                    }
                }

                if !isLocksure {
                    print("[MatterHome] Skipping non-Locksure accessory: name=\(name) mfg=\(manufacturer) model=\(model)")
                    continue
                }

                var deviceMap: [String: Any] = [
                    "uniqueId": accessory.uniqueIdentifier.uuidString,
                    "name": name,
                    "manufacturer": manufacturer,
                    "model": model,
                    "isReachable": accessory.isReachable,
                    "isBlocked": accessory.isBlocked,
                ]

                if let fw = accessory.firmwareVersion {
                    deviceMap["firmwareVersion"] = fw
                }

                // Read current lock state
                if let lockService = accessory.services.first(where: {
                    $0.serviceType == HMServiceTypeLockMechanism
                }) {
                    if let lockChar = lockService.characteristics.first(where: {
                        $0.characteristicType == HMCharacteristicTypeCurrentLockMechanismState
                    }) {
                        if let value = lockChar.value as? Int {
                            deviceMap["lockState"] = mapHomeKitLockState(value)
                        }
                    }
                }

                // Read door state — check LockMechanism service first (Matter
                // DoorLock puts DoorState on the lock service), then standalone
                var foundDoor = false
                if let lockSvc = accessory.services.first(where: { $0.serviceType == HMServiceTypeLockMechanism }) {
                    if let c = lockSvc.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeCurrentDoorState }),
                       let v = c.value as? Int {
                        deviceMap["doorState"] = mapHomeKitDoorState(v)
                        foundDoor = true
                    } else if let c = lockSvc.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeContactState }),
                              let v = c.value as? Int {
                        deviceMap["doorState"] = mapHomeKitContactState(v)
                        foundDoor = true
                    }
                }
                if !foundDoor,
                   let doorService = accessory.services.first(where: {
                    $0.serviceType == HMServiceTypeDoor
                }) ?? accessory.services.first(where: {
                    $0.serviceType == HMServiceTypeContactSensor
                }) {
                    if let doorChar = doorService.characteristics.first(where: {
                        $0.characteristicType == HMCharacteristicTypeCurrentDoorState
                    }) {
                        if let value = doorChar.value as? Int {
                            deviceMap["doorState"] = mapHomeKitDoorState(value)
                        }
                    } else if let contactChar = doorService.characteristics.first(where: {
                        $0.characteristicType == HMCharacteristicTypeContactState
                    }) {
                        if let value = contactChar.value as? Int {
                            deviceMap["doorState"] = mapHomeKitContactState(value)
                        }
                    }
                }

                // Read battery from PowerSource cluster (mapped to HMServiceTypeBattery)
                if let batteryService = accessory.services.first(where: {
                    $0.serviceType == HMServiceTypeBattery
                }) {
                    if let levelChar = batteryService.characteristics.first(where: {
                        $0.characteristicType == HMCharacteristicTypeBatteryLevel
                    }) {
                        if let value = levelChar.value as? Int {
                            deviceMap["batteryPercent"] = value
                        }
                    }
                    if let lowChar = batteryService.characteristics.first(where: {
                        $0.characteristicType == HMCharacteristicTypeStatusLowBattery
                    }) {
                        if let value = lowChar.value as? Int {
                            deviceMap["batteryLow"] = value == 1
                        }
                    }
                }

                // Matter node info (iOS 17+)
                if #available(iOS 17.0, *) {
                    deviceMap["matterNodeID"] = accessory.matterNodeID
                }

                results.append(deviceMap)
            }
        }

        return results
    }

    // MARK: - Device Subscription

    private func subscribeToDevice(uniqueId: String, result: @escaping FlutterResult) {
        guard let manager = homeManager, isHomeManagerReady else {
            result(FlutterError(code: "NOT_READY", message: "HomeKit not initialized", details: nil))
            return
        }

        guard let accessory = findAccessory(uniqueId: uniqueId, in: manager) else {
            result(FlutterError(code: "NOT_FOUND", message: "Accessory not found: \(uniqueId)", details: nil))
            return
        }

        accessory.delegate = self
        subscribedAccessories[uniqueId] = accessory

        // Enable notifications + kick an initial read so Firestore populates
        // immediately after subscription (without waiting for the next change).
        // Reads flow through the HMAccessoryDelegate same as notifications.
        func enableAndRead(_ c: HMCharacteristic, label: String) {
            c.enableNotification(true) { error in
                if let error = error {
                    print("[MatterHome] \(label) notification error: \(error.localizedDescription)")
                } else {
                    print("[MatterHome] \(label) notifications enabled for \(uniqueId)")
                }
            }
            c.readValue { error in
                if let error = error {
                    print("[MatterHome] \(label) initial read error: \(error.localizedDescription)")
                }
            }
        }

        // Diagnostic dump of what HomeKit has exposed for this accessory.
        // Helps diagnose "battery not showing" — if no HMServiceTypeBattery
        // appears, the Matter firmware's PowerSource cluster wasn't mapped.
        print("[MatterHome] subscribeToDevice \(uniqueId): services=\(accessory.services.map { $0.serviceType })")
        var sawBatteryService = false

        for service in accessory.services {
            switch service.serviceType {
            case HMServiceTypeLockMechanism:
                for c in service.characteristics
                    where c.characteristicType == HMCharacteristicTypeCurrentLockMechanismState
                        || c.characteristicType == HMCharacteristicTypeLockMechanismLastKnownAction {
                    enableAndRead(c, label: "Lock")
                }
                // DoorLock cluster's DoorState lives on the lock service itself
                for c in service.characteristics
                    where c.characteristicType == HMCharacteristicTypeCurrentDoorState
                        || c.characteristicType == HMCharacteristicTypeContactState {
                    enableAndRead(c, label: "Door (on LockMechanism)")
                }
            case HMServiceTypeDoor, HMServiceTypeContactSensor:
                for c in service.characteristics
                    where c.characteristicType == HMCharacteristicTypeCurrentDoorState
                        || c.characteristicType == HMCharacteristicTypeContactState {
                    enableAndRead(c, label: "Door")
                }
            case HMServiceTypeBattery:
                sawBatteryService = true
                print("[MatterHome] Battery service found for \(uniqueId), characteristics=\(service.characteristics.map { $0.characteristicType })")
                for c in service.characteristics
                    where c.characteristicType == HMCharacteristicTypeBatteryLevel {
                    enableAndRead(c, label: "Battery")
                }
            default:
                break
            }
        }

        if !sawBatteryService {
            print("[MatterHome] WARNING: No battery service on \(uniqueId) — HomeKit has not surfaced a PowerSource cluster for this Matter device")
        }

        result(true)
    }

    private func unsubscribeFromDevice(uniqueId: String, result: @escaping FlutterResult) {
        if let accessory = subscribedAccessories.removeValue(forKey: uniqueId) {
            if let lockService = accessory.services.first(where: {
                $0.serviceType == HMServiceTypeLockMechanism
            }) {
                for characteristic in lockService.characteristics {
                    if characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                        characteristic.enableNotification(false, completionHandler: { _ in })
                    }
                }
            }
            accessory.delegate = nil
        }
        result(true)
    }

    // MARK: - Read Current State

    private func getDeviceState(uniqueId: String, result: @escaping FlutterResult) {
        guard let manager = homeManager, isHomeManagerReady else {
            result(FlutterError(code: "NOT_READY", message: "HomeKit not initialized", details: nil))
            return
        }

        guard let accessory = findAccessory(uniqueId: uniqueId, in: manager) else {
            result(FlutterError(code: "NOT_FOUND", message: "Accessory not found", details: nil))
            return
        }

        var stateMap: [String: Any] = [
            "deviceUniqueId": uniqueId,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "isReachable": accessory.isReachable,
        ]

        // Read lock state
        if let lockService = accessory.services.first(where: {
            $0.serviceType == HMServiceTypeLockMechanism
        }) {
            let lockChar = lockService.characteristics.first(where: {
                $0.characteristicType == HMCharacteristicTypeCurrentLockMechanismState
            })

            if let value = lockChar?.value as? Int {
                stateMap["lockState"] = mapHomeKitLockState(value)
            } else {
                stateMap["lockState"] = 0
            }

            // Force a fresh read
            lockChar?.readValue { [weak self] error in
                if error == nil, let value = lockChar?.value as? Int {
                    let mapped = self?.mapHomeKitLockState(value) ?? 0
                    if mapped != stateMap["lockState"] as? Int {
                        var event = stateMap
                        event["lockState"] = mapped
                        self?.eventSink?(event)
                    }
                }
            }
        }

        // Read door state — check LockMechanism service first (Matter DoorLock
        // puts DoorState on the lock service), then standalone Door/ContactSensor
        var foundDoorState = false
        if let lockService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLockMechanism }) {
            if let doorChar = lockService.characteristics.first(where: {
                $0.characteristicType == HMCharacteristicTypeCurrentDoorState
            }), let value = doorChar.value as? Int {
                stateMap["doorState"] = mapHomeKitDoorState(value)
                foundDoorState = true
            } else if let contactChar = lockService.characteristics.first(where: {
                $0.characteristicType == HMCharacteristicTypeContactState
            }), let value = contactChar.value as? Int {
                stateMap["doorState"] = mapHomeKitContactState(value)
                foundDoorState = true
            }
        }
        if !foundDoorState {
        for service in accessory.services {
            if service.serviceType == HMServiceTypeDoor || service.serviceType == HMServiceTypeContactSensor {
                if let doorChar = service.characteristics.first(where: {
                    $0.characteristicType == HMCharacteristicTypeCurrentDoorState
                }), let value = doorChar.value as? Int {
                    stateMap["doorState"] = mapHomeKitDoorState(value)
                } else if let contactChar = service.characteristics.first(where: {
                    $0.characteristicType == HMCharacteristicTypeContactState
                }), let value = contactChar.value as? Int {
                    stateMap["doorState"] = mapHomeKitContactState(value)
                }
                break
            }
        }
        }

        result(stateMap)
    }

    // MARK: - Diagnostics

    /// Reads diagnostic information from the accessory.
    /// BasicInformation (firmware, manufacturer) comes from HomeKit.
    /// Thread/General diagnostics would require direct MTR cluster reads
    /// which need controller setup — returned as placeholder for now.
    private func getDiagnostics(uniqueId: String, result: @escaping FlutterResult) {
        guard let manager = homeManager, isHomeManagerReady else {
            result(FlutterError(code: "NOT_READY", message: "HomeKit not initialized", details: nil))
            return
        }

        guard let accessory = findAccessory(uniqueId: uniqueId, in: manager) else {
            result(FlutterError(code: "NOT_FOUND", message: "Accessory not found", details: nil))
            return
        }

        var diag: [String: Any] = [
            "uniqueId": uniqueId,
            "name": accessory.name,
            "manufacturer": accessory.manufacturer ?? "Unknown",
            "model": accessory.model ?? "Unknown",
            "firmwareVersion": accessory.firmwareVersion ?? "Unknown",
            "isReachable": accessory.isReachable,
            "isBlocked": accessory.isBlocked,
            "isBridged": accessory.isBridged,
            "supportsIdentify": accessory.supportsIdentify,
            "category": accessory.category.categoryType,
            "services": accessory.services.map { svc in
                [
                    "name": svc.name,
                    "type": svc.serviceType,
                    "isPrimary": svc.isPrimaryService,
                    "characteristics": svc.characteristics.map { chr in
                        [
                            "type": chr.characteristicType,
                            "value": "\(chr.value ?? "nil")",
                            "properties": chr.properties,
                        ] as [String: Any]
                    },
                ] as [String: Any]
            },
        ]

        // Matter node info (iOS 17+)
        if #available(iOS 17.0, *) {
            diag["matterNodeID"] = accessory.matterNodeID
        }

        result(diag)
    }

    // MARK: - DFU Trigger

    /// Trigger BLE DFU mode on a Matter device.
    ///
    /// IMPORTANT: HomeKit's Matter bridge does not expose any writable
    /// characteristic we can safely use as a DFU trigger. The earlier
    /// implementation wrote `99` to the first writable characteristic on the
    /// LockMechanism service — which is TargetLockMechanismState, a 0/1 value
    /// that HomeKit rightly rejected (and if accepted would have unlocked the
    /// door). DoorLock SoundVolume and custom vendor clusters are not surfaced
    /// to third-party apps by the bridge.
    ///
    /// So this method now just reports that DFU mode needs a manual trigger,
    /// and the app UI guides the user through whatever mechanism the firmware
    /// defines (button hold, etc.). Once the device advertises mcuboot on
    /// `0xFE59` the existing BLE DFU flow takes over.
    private func triggerDfuMode(uniqueId: String, result: @escaping FlutterResult) {
        guard let manager = homeManager else {
            result(["success": false, "fallbackToBle": true, "error": "HomeKit not initialised"])
            return
        }
        guard let accessory = findAccessory(uniqueId: uniqueId, in: manager) else {
            result(["success": false, "fallbackToBle": true, "error": "Accessory not found"])
            return
        }

        // Find the Identify cluster's IdentifyTime characteristic.
        // Matter Identify cluster ID = 0x0003, IdentifyTime attr = 0x0000.
        // HomeKit maps unknown services with raw UUIDs. Walk all services
        // looking for a writable characteristic that matches.
        var identifyTimeChar: HMCharacteristic?
        for service in accessory.services {
            for c in service.characteristics {
                let uuid = c.characteristicType.lowercased()
                // HomeKit maps Matter attribute IDs into characteristic UUIDs.
                // The Identify cluster IdentifyTime shows up as a writable int.
                // Check for the raw UUID pattern or try Apple's mapped version.
                if uuid.contains("0003") && c.properties.contains(.writable) {
                    identifyTimeChar = c
                    break
                }
            }
            if identifyTimeChar != nil { break }
        }

        if let char = identifyTimeChar {
            // Write magic value 0xDFDF (57311) — firmware reboots into loader
            print("[MatterHome] triggerDfuMode: writing 0xDFDF to IdentifyTime for \(uniqueId)")
            char.writeValue(NSNumber(value: 0xDFDF)) { error in
                if let error = error {
                    print("[MatterHome] triggerDfuMode: write failed: \(error)")
                    result(["success": false, "fallbackToBle": true, "error": error.localizedDescription])
                } else {
                    print("[MatterHome] triggerDfuMode: 0xDFDF written — device should reboot to DFU")
                    result(["success": true, "fallbackToBle": false])
                }
            }
        } else {
            // Fallback: use accessory.identify() — sends IdentifyTime=15.
            // Firmware will blink LED (not trigger DFU) since value != 0xDFDF.
            print("[MatterHome] triggerDfuMode: IdentifyTime characteristic not found, falling back to manual")
            result([
                "success": false,
                "fallbackToBle": true,
                "error": "IdentifyTime not accessible via HomeKit — put device in DFU mode manually (long-press button)"
            ])
        }
    }

    // MARK: - Helpers

    private func findAccessory(uniqueId: String, in manager: HMHomeManager) -> HMAccessory? {
        let uuid = UUID(uuidString: uniqueId)
        for home in manager.homes {
            if let accessory = home.accessories.first(where: {
                $0.uniqueIdentifier == uuid
            }) {
                return accessory
            }
        }
        return nil
    }

    /// Maps HomeKit lock state to app lock state.
    /// HomeKit: 0=unsecured, 1=secured, 2=jammed, 3=unknown
    /// App:     0=unknown, 1=locked, 2=unlocked, 3=error
    private func mapHomeKitLockState(_ homeKitState: Int) -> Int {
        switch homeKitState {
        case 0: return 2  // unsecured → unlocked
        case 1: return 1  // secured → locked
        case 2: return 3  // jammed → error
        default: return 0 // unknown
        }
    }

    /// Maps HomeKit CurrentDoorState → app state.
    /// HomeKit: 0=open, 1=closed, 2=opening, 3=closing, 4=stopped
    /// App:     3=open, 4=closed, 0=unknown
    private func mapHomeKitDoorState(_ homeKitState: Int) -> Int {
        switch homeKitState {
        case 0: return 3  // open
        case 1: return 4  // closed
        default: return 0 // unknown
        }
    }

    /// Maps HomeKit ContactState → app state.
    /// ContactState semantics are INVERTED from CurrentDoorState:
    ///   HomeKit: 0=contact detected (door CLOSED), 1=no contact (door OPEN)
    ///   App:     3=open, 4=closed, 0=unknown
    private func mapHomeKitContactState(_ homeKitState: Int) -> Int {
        switch homeKitState {
        case 0: return 4  // contact detected → closed
        case 1: return 3  // no contact → open
        default: return 0 // unknown
        }
    }
}

// MARK: - HMHomeManagerDelegate

extension MatterHomePlugin: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        isHomeManagerReady = true
        print("[MatterHome] HomeKit ready — \(manager.homes.count) home(s)")

        if let pending = pendingDiscoverResult {
            let devices = findLocksureAccessories(in: manager)
            pending(devices)
            pendingDiscoverResult = nil
        }
    }
}

// MARK: - HMAccessoryDelegate (state change notifications)

extension MatterHomePlugin: HMAccessoryDelegate {
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        let uniqueId = accessory.uniqueIdentifier.uuidString

        guard subscribedAccessories[uniqueId] != nil else { return }

        var event: [String: Any] = [
            "deviceUniqueId": uniqueId,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let fw = accessory.firmwareVersion, !fw.isEmpty {
            event["firmwareVersion"] = fw
        }

        if characteristic.characteristicType == HMCharacteristicTypeCurrentLockMechanismState
            || characteristic.characteristicType == HMCharacteristicTypeLockMechanismLastKnownAction {
            if let value = characteristic.value as? Int {
                event["lockState"] = mapHomeKitLockState(value)
                print("[MatterHome] Lock state changed: \(uniqueId) → \(event["lockState"]!)")
                eventSink?(event)
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeCurrentDoorState {
            if let value = characteristic.value as? Int {
                event["doorState"] = mapHomeKitDoorState(value)
                print("[MatterHome] Door state changed (CurrentDoorState raw=\(value)): \(uniqueId) → \(event["doorState"]!)")
                eventSink?(event)
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeContactState {
            if let value = characteristic.value as? Int {
                event["doorState"] = mapHomeKitContactState(value)
                print("[MatterHome] Door state changed (ContactState raw=\(value)): \(uniqueId) → \(event["doorState"]!)")
                eventSink?(event)
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeBatteryLevel {
            if let value = characteristic.value as? Int {
                event["batteryPercent"] = value
                print("[MatterHome] Battery changed: \(uniqueId) → \(value)%")
                eventSink?(event)
            }
        }
    }
}

// MARK: - EventChannel StreamHandler

extension MatterHomePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - BLE scan delegate for Matter commissionable devices

class MatterBleScanDelegate: NSObject, CBCentralManagerDelegate {
    weak var plugin: MatterHomePlugin?

    init(plugin: MatterHomePlugin) {
        self.plugin = plugin
        super.init()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[MatterHome] BLE state: \(central.state.rawValue)")
        if central.state == .poweredOn {
            plugin?.startBleScanNow()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        plugin?.onBlePeripheralDiscovered(peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
}

