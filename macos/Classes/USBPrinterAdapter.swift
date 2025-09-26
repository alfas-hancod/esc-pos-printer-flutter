import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib

// USB Constants for macOS
let kIOUSBDeviceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(
    nil, 0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xd4, 0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28,
    0x61)
let kIOUSBInterfaceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(
    nil, 0x2d, 0x97, 0x86, 0xc6, 0x9e, 0xf3, 0x11, 0xd4, 0xad, 0x51, 0x00, 0x0a, 0x27, 0x05, 0x28,
    0x61)
let kIOCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(
    nil, 0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4, 0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42,
    0x6F)
let kIOUSBDeviceInterfaceID = CFUUIDGetConstantUUIDWithBytes(
    nil, 0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xd4, 0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28,
    0x61)
let kIOUSBInterfaceInterfaceID = CFUUIDGetConstantUUIDWithBytes(
    nil, 0x73, 0xc9, 0x7a, 0xe8, 0x9e, 0xf3, 0x11, 0xd4, 0xb1, 0xd0, 0x00, 0x0a, 0x27, 0x05, 0x28,
    0x61)

class USBPrinterAdapter {
    private var currentVendorId: Int = 0
    private var currentProductId: Int = 0
    private var connected = false
    private var currentDeviceService: io_service_t = 0
    private var deviceInterface:
        UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>? = nil
    private var interfaceInterface:
        UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>?>? = nil
    private var bulkOutPipe: UInt8 = 0

    init() {
        NSLog("🔧 USBPrinterAdapter: Initialized")
    }

    deinit {
        closeConnection()
        NSLog("🔧 USBPrinterAdapter: Deinitialized")
    }

    func getUSBDeviceList() -> [[String: String]] {
        NSLog("🔍 USBPrinterAdapter: Starting USB device enumeration...")
        var devices: [[String: String]] = []

        // Create matching dictionary for USB devices
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        guard matchingDict != nil else {
            NSLog("❌ USBPrinterAdapter: Failed to create matching dictionary")
            return devices
        }
        NSLog("✅ USBPrinterAdapter: Created matching dictionary successfully")

        var iter: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iter)

        guard result == KERN_SUCCESS else {
            NSLog("❌ USBPrinterAdapter: Failed to get matching services: \(result)")
            return devices
        }
        NSLog("✅ USBPrinterAdapter: Got matching services iterator")

        defer {
            IOObjectRelease(iter)
        }

        var deviceCount = 0
        var device: io_service_t
        while case let device = IOIteratorNext(iter), device != 0 {
            defer { IOObjectRelease(device) }

            deviceCount += 1
            NSLog("🔍 USBPrinterAdapter: Examining device #\(deviceCount)")

            var deviceDict: [String: String] = [:]

            // Get vendor ID
            if let vendorId = getDeviceProperty(device: device, key: kUSBVendorID) as? NSNumber {
                deviceDict["vendorid"] = String(vendorId.intValue)
                NSLog("📋 USBPrinterAdapter: Device #\(deviceCount) VendorID: \(vendorId.intValue)")
            } else {
                deviceDict["vendorid"] = "0"
                NSLog("⚠️ USBPrinterAdapter: Device #\(deviceCount) VendorID: Not found")
            }

            // Get product ID
            if let productId = getDeviceProperty(device: device, key: kUSBProductID) as? NSNumber {
                deviceDict["productid"] = String(productId.intValue)
                NSLog(
                    "📋 USBPrinterAdapter: Device #\(deviceCount) ProductID: \(productId.intValue)")
            } else {
                deviceDict["productid"] = "0"
                NSLog("⚠️ USBPrinterAdapter: Device #\(deviceCount) ProductID: Not found")
            }

            // Get device ID (using location ID as device ID)
            if let locationId = getDeviceProperty(device: device, key: kUSBDevicePropertyLocationID)
                as? NSNumber
            {
                deviceDict["deviceid"] = String(locationId.intValue)
                NSLog(
                    "📋 USBPrinterAdapter: Device #\(deviceCount) LocationID: \(locationId.intValue)"
                )
            } else {
                deviceDict["deviceid"] = "0"
                NSLog("⚠️ USBPrinterAdapter: Device #\(deviceCount) LocationID: Not found")
            }

            // Get manufacturer name
            if let manufacturer = getDeviceProperty(device: device, key: kUSBVendorString)
                as? String
            {
                deviceDict["manufacturer"] = manufacturer
                NSLog("📋 USBPrinterAdapter: Device #\(deviceCount) Manufacturer: \(manufacturer)")
            } else {
                deviceDict["manufacturer"] = "Unknown"
                NSLog("⚠️ USBPrinterAdapter: Device #\(deviceCount) Manufacturer: Unknown")
            }

            // Get product name
            if let product = getDeviceProperty(device: device, key: kUSBProductString) as? String {
                deviceDict["product"] = product
                NSLog("📋 USBPrinterAdapter: Device #\(deviceCount) Product: \(product)")
            } else {
                deviceDict["product"] = "Unknown"
                NSLog("⚠️ USBPrinterAdapter: Device #\(deviceCount) Product: Unknown")
            }

            // Create device name
            let deviceName =
                "\(deviceDict["manufacturer"] ?? "Unknown") \(deviceDict["product"] ?? "Unknown")"
            deviceDict["name"] = deviceName

            // Only add devices that have both vendor and product IDs
            if deviceDict["vendorid"] != "0" && deviceDict["productid"] != "0" {
                devices.append(deviceDict)
                NSLog("✅ USBPrinterAdapter: Device #\(deviceCount) added to list: \(deviceName)")
            } else {
                NSLog(
                    "⚠️ USBPrinterAdapter: Device #\(deviceCount) skipped (missing vendor/product ID)"
                )
            }
        }

        NSLog(
            "🔍 USBPrinterAdapter: Found \(devices.count) valid USB devices out of \(deviceCount) total devices"
        )
        return devices
    }

    private func getDeviceProperty(device: io_service_t, key: String) -> Any? {
        let property = IORegistryEntryCreateCFProperty(
            device, key as CFString, kCFAllocatorDefault, 0)
        return property?.takeRetainedValue()
    }

    func selectDevice(vendorId: Int, productId: Int) -> Bool {
        NSLog(
            "🔌 USBPrinterAdapter: Attempting to select device with vendor: \(vendorId), product: \(productId)"
        )

        // Close existing connection if any
        closeConnection()

        // Store the device identifiers
        currentVendorId = vendorId
        currentProductId = productId
        NSLog(
            "🔌 USBPrinterAdapter: Stored device identifiers - vendor: \(currentVendorId), product: \(currentProductId)"
        )

        // Find and store the actual device service
        NSLog("🔍 USBPrinterAdapter: Searching for USB device...")
        guard let foundDevice = findUSBDevice(vendorId: vendorId, productId: productId) else {
            NSLog("❌ USBPrinterAdapter: Device not found in device list")
            let devices = getUSBDeviceList()
            NSLog("🔍 USBPrinterAdapter: Available devices:")
            for (index, device) in devices.enumerated() {
                NSLog(
                    "   Device \(index): VID=\(device["vendorid"] ?? "?"), PID=\(device["productid"] ?? "?"), Name=\(device["name"] ?? "?")"
                )
            }
            return false
        }

        currentDeviceService = foundDevice
        NSLog("✅ USBPrinterAdapter: Device found and selected successfully")
        return true
    }

    func openConnection() -> Bool {
        NSLog(
            "🔌 USBPrinterAdapter: Opening connection to device \(currentVendorId):\(currentProductId)"
        )

        if connected {
            NSLog("✅ USBPrinterAdapter: Already connected")
            return true
        }

        if currentVendorId == 0 || currentProductId == 0 {
            NSLog(
                "❌ USBPrinterAdapter: No device selected (vendor: \(currentVendorId), product: \(currentProductId))"
            )
            return false
        }

        if currentDeviceService == 0 {
            NSLog("❌ USBPrinterAdapter: No device service available")
            return false
        }

        // Create device interface
        guard createDeviceInterface() else {
            NSLog("❌ USBPrinterAdapter: Failed to create device interface")
            return false
        }

        // Create interface interface and find bulk endpoint
        guard createInterfaceInterface() else {
            NSLog("❌ USBPrinterAdapter: Failed to create interface interface")
            closeConnection()
            return false
        }

        connected = true
        NSLog("✅ USBPrinterAdapter: Connection established")
        return true
    }

    func closeConnection() {
        if connected {
            NSLog("🔌 USBPrinterAdapter: Closing USB connection")

            // Release interface interface
            if let interface = interfaceInterface {
                let result = interface.pointee?.pointee.USBInterfaceClose(interface)
                if result == kIOReturnSuccess {
                    NSLog("✅ USBPrinterAdapter: USB interface closed successfully")
                } else {
                    NSLog("⚠️ USBPrinterAdapter: Failed to close USB interface: \(result ?? 0)")
                }
                _ = interface.pointee?.pointee.Release(interface)
                interfaceInterface = nil
            }

            // Release device interface
            if let device = deviceInterface {
                let result = device.pointee?.pointee.USBDeviceClose(device)
                if result == kIOReturnSuccess {
                    NSLog("✅ USBPrinterAdapter: USB device closed successfully")
                } else {
                    NSLog("⚠️ USBPrinterAdapter: Failed to close USB device: \(result ?? 0)")
                }
                _ = device.pointee?.pointee.Release(device)
                deviceInterface = nil
            }

            connected = false
            bulkOutPipe = 0
            NSLog("✅ USBPrinterAdapter: Connection closed")
        }

        if currentDeviceService != 0 {
            IOObjectRelease(currentDeviceService)
            currentDeviceService = 0
            NSLog("🔧 USBPrinterAdapter: Device service released")
        } else {
            NSLog("ℹ️ USBPrinterAdapter: Connection already closed")
        }
    }

    func printText(text: String) -> Bool {
        NSLog("🖨️ USBPrinterAdapter: printText called with: '\(text)'")
        guard let data = text.data(using: .utf8) else {
            NSLog("❌ USBPrinterAdapter: Failed to convert text to UTF-8 data")
            return false
        }
        NSLog("🖨️ USBPrinterAdapter: Text converted to \(data.count) bytes, calling write()")
        return write(data: data)
    }

    func printRawData(rawData: String) -> Bool {
        NSLog("🖨️ USBPrinterAdapter: printRawData called with \(rawData.count) characters")
        guard let data = Data(base64Encoded: rawData) else {
            NSLog("❌ USBPrinterAdapter: Failed to decode base64 data")
            return false
        }
        NSLog("🖨️ USBPrinterAdapter: Base64 decoded to \(data.count) bytes, calling write()")
        return write(data: data)
    }

    func write(data: Data) -> Bool {
        NSLog("🖨️ USBPrinterAdapter: write() called with \(data.count) bytes")
        NSLog(
            "🖨️ USBPrinterAdapter: Data hex: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))"
        )

        guard openConnection() else {
            NSLog("❌ USBPrinterAdapter: Failed to open connection for writing")
            return false
        }

        guard currentDeviceService != 0 else {
            NSLog("❌ USBPrinterAdapter: No device service available for writing")
            return false
        }

        // Attempt to write data using IOKit USB communication
        let success = writeDataToUSBDevice(data: data)

        if success {
            NSLog("✅ USBPrinterAdapter: Successfully wrote \(data.count) bytes to printer")
            return true
        } else {
            NSLog("❌ USBPrinterAdapter: Failed to write data to printer")
            return false
        }
    }

    private func writeDataToUSBDevice(data: Data) -> Bool {
        NSLog("🔄 USBPrinterAdapter: Attempting USB bulk transfer...")
        NSLog(
            "🔄 USBPrinterAdapter: Target device - VID:\(currentVendorId), PID:\(currentProductId)")
        NSLog("🔄 USBPrinterAdapter: Data size: \(data.count) bytes")

        guard let interface = interfaceInterface, bulkOutPipe > 0 else {
            NSLog("❌ USBPrinterAdapter: No USB interface or bulk endpoint available")
            return false
        }

        // Convert Data to UnsafeMutableRawPointer
        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                NSLog("❌ USBPrinterAdapter: Failed to get data base address")
                return false
            }

            let mutablePointer = UnsafeMutableRawPointer(mutating: baseAddress)

            NSLog("🔄 USBPrinterAdapter: Performing USB bulk transfer to pipe \(bulkOutPipe)")

            // Perform synchronous bulk write
            let result = interface.pointee?.pointee.WritePipe(
                interface, bulkOutPipe, mutablePointer, UInt32(data.count))

            if result == kIOReturnSuccess {
                NSLog("✅ USBPrinterAdapter: USB bulk transfer completed successfully")
                NSLog(
                    "📊 USBPrinterAdapter: Sent \(data.count) bytes to printer via pipe \(bulkOutPipe)"
                )
                return true
            } else {
                NSLog("❌ USBPrinterAdapter: USB bulk transfer failed with result: \(result ?? 0)")
                return false
            }
        }
    }

    private func createDeviceInterface() -> Bool {
        NSLog("🔧 USBPrinterAdapter: Creating device interface...")

        var plugInInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>? = nil
        var score: Int32 = 0

        // Create plugin interface
        let result = IOCreatePlugInInterfaceForService(
            currentDeviceService,
            kIOUSBDeviceUserClientTypeID,
            kIOCFPlugInInterfaceID,
            &plugInInterface,
            &score
        )

        guard result == kIOReturnSuccess, let plugIn = plugInInterface else {
            NSLog("❌ USBPrinterAdapter: Failed to create plugin interface: \(result)")
            return false
        }

        // Query for device interface
        var deviceInterfacePtr: UnsafeMutableRawPointer? = nil
        let queryResult = plugIn.pointee?.pointee.QueryInterface(
            plugIn,
            CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
            &deviceInterfacePtr
        )

        // Release plugin interface
        _ = plugIn.pointee?.pointee.Release(plugIn)

        guard queryResult == kIOReturnSuccess, let devicePtr = deviceInterfacePtr else {
            NSLog("❌ USBPrinterAdapter: Failed to query device interface: \(queryResult ?? 0)")
            return false
        }

        deviceInterface = devicePtr.assumingMemoryBound(
            to: UnsafeMutablePointer<IOUSBDeviceInterface>?.self)

        // Open device
        let openResult = deviceInterface?.pointee?.pointee.USBDeviceOpen(deviceInterface)
        if openResult != kIOReturnSuccess {
            NSLog("❌ USBPrinterAdapter: Failed to open USB device: \(openResult ?? 0)")
            _ = deviceInterface?.pointee?.pointee.Release(deviceInterface)
            deviceInterface = nil
            return false
        }

        NSLog("✅ USBPrinterAdapter: Device interface created and opened successfully")
        return true
    }

    private func createInterfaceInterface() -> Bool {
        NSLog("🔧 USBPrinterAdapter: Creating interface interface...")

        guard let device = deviceInterface else {
            NSLog("❌ USBPrinterAdapter: No device interface available")
            return false
        }

        // Get interface iterator
        var interfaceIterator: io_iterator_t = 0
        var interfaceRequest = IOUSBFindInterfaceRequest()
        interfaceRequest.bInterfaceClass = UInt16(kIOUSBFindInterfaceDontCare)
        interfaceRequest.bInterfaceSubClass = UInt16(kIOUSBFindInterfaceDontCare)
        interfaceRequest.bInterfaceProtocol = UInt16(kIOUSBFindInterfaceDontCare)
        interfaceRequest.bAlternateSetting = UInt16(kIOUSBFindInterfaceDontCare)

        let result = device.pointee?.pointee.CreateInterfaceIterator(
            device, &interfaceRequest, &interfaceIterator)

        guard result == kIOReturnSuccess else {
            NSLog("❌ USBPrinterAdapter: Failed to create interface iterator: \(result ?? 0)")
            return false
        }

        defer { IOObjectRelease(interfaceIterator) }

        // Get first interface
        let interfaceService = IOIteratorNext(interfaceIterator)
        guard interfaceService != 0 else {
            NSLog("❌ USBPrinterAdapter: No USB interface found")
            return false
        }

        defer { IOObjectRelease(interfaceService) }

        // Create plugin interface for the USB interface
        var plugInInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>? = nil
        var score: Int32 = 0

        let pluginResult = IOCreatePlugInInterfaceForService(
            interfaceService,
            kIOUSBInterfaceUserClientTypeID,
            kIOCFPlugInInterfaceID,
            &plugInInterface,
            &score
        )

        guard pluginResult == kIOReturnSuccess, let plugIn = plugInInterface else {
            NSLog("❌ USBPrinterAdapter: Failed to create interface plugin: \(pluginResult)")
            return false
        }

        // Query for interface interface
        var interfaceInterfacePtr: UnsafeMutableRawPointer? = nil
        let queryResult = plugIn.pointee?.pointee.QueryInterface(
            plugIn,
            CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
            &interfaceInterfacePtr
        )

        // Release plugin interface
        _ = plugIn.pointee?.pointee.Release(plugIn)

        guard queryResult == kIOReturnSuccess, let interfacePtr = interfaceInterfacePtr else {
            NSLog("❌ USBPrinterAdapter: Failed to query interface interface: \(queryResult ?? 0)")
            return false
        }

        interfaceInterface = interfacePtr.assumingMemoryBound(
            to: UnsafeMutablePointer<IOUSBInterfaceInterface>?.self)

        // Open interface
        let openResult = interfaceInterface?.pointee?.pointee.USBInterfaceOpen(interfaceInterface)
        if openResult != kIOReturnSuccess {
            NSLog("❌ USBPrinterAdapter: Failed to open USB interface: \(openResult ?? 0)")
            _ = interfaceInterface?.pointee?.pointee.Release(interfaceInterface)
            interfaceInterface = nil
            return false
        }

        // Find bulk OUT endpoint
        guard findBulkOutEndpoint() else {
            NSLog("❌ USBPrinterAdapter: Failed to find bulk OUT endpoint")
            _ = interfaceInterface?.pointee?.pointee.USBInterfaceClose(interfaceInterface)
            _ = interfaceInterface?.pointee?.pointee.Release(interfaceInterface)
            interfaceInterface = nil
            return false
        }

        NSLog("✅ USBPrinterAdapter: Interface interface created and opened successfully")
        return true
    }

    private func findBulkOutEndpoint() -> Bool {
        NSLog("🔍 USBPrinterAdapter: Searching for bulk OUT endpoint...")

        guard let interface = interfaceInterface else {
            NSLog("❌ USBPrinterAdapter: No interface interface available")
            return false
        }

        // Get number of endpoints
        var numEndpoints: UInt8 = 0
        let result = interface.pointee?.pointee.GetNumEndpoints(interface, &numEndpoints)

        guard result == kIOReturnSuccess else {
            NSLog("❌ USBPrinterAdapter: Failed to get number of endpoints: \(result ?? 0)")
            return false
        }

        NSLog("🔍 USBPrinterAdapter: Found \(numEndpoints) endpoints")

        // Search through endpoints
        for i in 1...numEndpoints {
            var direction: UInt8 = 0
            var number: UInt8 = 0
            var transferType: UInt8 = 0
            var maxPacketSize: UInt16 = 0
            var interval: UInt8 = 0

            let endpointResult = interface.pointee?.pointee.GetPipeProperties(
                interface, i, &direction, &number, &transferType, &maxPacketSize, &interval
            )

            if endpointResult == kIOReturnSuccess {
                NSLog(
                    "🔍 USBPrinterAdapter: Endpoint \(i): direction=\(direction), number=\(number), type=\(transferType), maxPacket=\(maxPacketSize)"
                )

                // Check if this is a bulk OUT endpoint
                // direction: 0 = OUT, 1 = IN
                // transferType: 2 = bulk, 3 = interrupt
                if direction == 0 && transferType == 2 {
                    bulkOutPipe = i
                    NSLog("✅ USBPrinterAdapter: Found bulk OUT endpoint at pipe \(i)")
                    return true
                }
            }
        }

        NSLog("❌ USBPrinterAdapter: No bulk OUT endpoint found")
        return false
    }

    private func findUSBDevice(vendorId: Int, productId: Int) -> io_service_t? {
        NSLog("🔍 USBPrinterAdapter: Searching for USB device VID:\(vendorId) PID:\(productId)")

        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        guard matchingDict != nil else {
            NSLog("❌ USBPrinterAdapter: Failed to create matching dictionary")
            return nil
        }

        var iter: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iter)
        guard result == KERN_SUCCESS else {
            NSLog("❌ USBPrinterAdapter: Failed to get matching services: \(result)")
            return nil
        }

        defer { IOObjectRelease(iter) }

        var deviceCount = 0
        var device: io_service_t
        while case let device = IOIteratorNext(iter), device != 0 {
            defer { IOObjectRelease(device) }

            deviceCount += 1

            guard
                let currentVendorId = getDeviceProperty(device: device, key: kUSBVendorID)
                    as? NSNumber,
                let currentProductId = getDeviceProperty(device: device, key: kUSBProductID)
                    as? NSNumber
            else {
                NSLog("🔍 USBPrinterAdapter: Device \(deviceCount): Could not get VID/PID")
                continue
            }

            NSLog(
                "🔍 USBPrinterAdapter: Device \(deviceCount): VID=\(currentVendorId.intValue), PID=\(currentProductId.intValue)"
            )

            if currentVendorId.intValue == vendorId && currentProductId.intValue == productId {
                NSLog("✅ USBPrinterAdapter: Found matching device!")
                IOObjectRetain(device)
                return device
            }
        }

        NSLog("❌ USBPrinterAdapter: Device not found after checking \(deviceCount) devices")
        return nil
    }
}
