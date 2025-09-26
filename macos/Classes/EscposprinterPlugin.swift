import Cocoa
import FlutterMacOS
import IOKit
import IOKit.usb

public class EscposprinterPlugin: NSObject, FlutterPlugin {
    private var usbPrinterAdapter: USBPrinterAdapter

    public override init() {
        self.usbPrinterAdapter = USBPrinterAdapter()
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "escposprinter", binaryMessenger: registrar.messenger)
        let instance = EscposprinterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("🔧 EscposprinterPlugin: Received method call: \(call.method)")
        NSLog("🔧 EscposprinterPlugin: Arguments: \(String(describing: call.arguments))")

        switch call.method {
        case "getUSBDeviceList":
            NSLog("📋 EscposprinterPlugin: Getting USB device list...")
            getUSBDeviceList(result: result)
        case "connectPrinter":
            guard let args = call.arguments as? [String: Any],
                let vendor = args["vendor"] as? Int,
                let product = args["product"] as? Int
            else {
                NSLog("❌ EscposprinterPlugin: Invalid arguments for connectPrinter")
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Missing vendor or product ID",
                        details: nil))
                return
            }
            NSLog(
                "🔌 EscposprinterPlugin: Connecting to printer vendor: \(vendor), product: \(product)"
            )
            connectPrinter(vendorId: vendor, productId: product, result: result)
        case "closeConn":
            NSLog("🔌 EscposprinterPlugin: Closing connection...")
            closeConnection(result: result)
        case "printText":
            guard let args = call.arguments as? [String: Any],
                let text = args["text"] as? String
            else {
                NSLog("❌ EscposprinterPlugin: Invalid arguments for printText")
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Missing text argument", details: nil))
                return
            }
            NSLog("🖨️ EscposprinterPlugin: Printing text: \(text)")
            printText(text: text, result: result)
        case "printRawData":
            guard let args = call.arguments as? [String: Any],
                let rawData = args["raw"] as? String
            else {
                NSLog("❌ EscposprinterPlugin: Invalid arguments for printRawData")
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Missing raw data argument",
                        details: nil))
                return
            }
            NSLog("🖨️ EscposprinterPlugin: Printing raw data (length: \(rawData.count))")
            printRawData(rawData: rawData, result: result)
        case "write":
            guard let args = call.arguments as? [String: Any],
                let data = args["data"] as? FlutterStandardTypedData
            else {
                NSLog("❌ EscposprinterPlugin: Invalid arguments for write")
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENTS", message: "Missing data argument", details: nil))
                return
            }
            NSLog("🖨️ EscposprinterPlugin: Writing data (bytes: \(data.data.count))")
            write(data: data.data, result: result)
        default:
            NSLog("❌ EscposprinterPlugin: Method not implemented: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }

    private func getUSBDeviceList(result: @escaping FlutterResult) {
        NSLog("📋 EscposprinterPlugin: Calling USBPrinterAdapter.getUSBDeviceList()")
        let devices = usbPrinterAdapter.getUSBDeviceList()
        NSLog("📋 EscposprinterPlugin: Found \(devices.count) devices")
        for (index, device) in devices.enumerated() {
            NSLog("📋 Device \(index): \(device)")
        }
        result(devices)
    }

    private func connectPrinter(vendorId: Int, productId: Int, result: @escaping FlutterResult) {
        NSLog(
            "🔌 EscposprinterPlugin: Calling USBPrinterAdapter.selectDevice(vendorId: \(vendorId), productId: \(productId))"
        )
        let success = usbPrinterAdapter.selectDevice(vendorId: vendorId, productId: productId)
        NSLog("🔌 EscposprinterPlugin: Connection result: \(success)")
        if success {
            NSLog("✅ EscposprinterPlugin: Successfully connected to printer")
        } else {
            NSLog("❌ EscposprinterPlugin: Failed to connect to printer")
        }
        result(success)
    }

    private func closeConnection(result: @escaping FlutterResult) {
        NSLog("🔌 EscposprinterPlugin: Calling USBPrinterAdapter.closeConnection()")
        usbPrinterAdapter.closeConnection()
        NSLog("🔌 EscposprinterPlugin: Connection closed")
        result(true)
    }

    private func printText(text: String, result: @escaping FlutterResult) {
        NSLog("🖨️ EscposprinterPlugin: Calling USBPrinterAdapter.printText() with text: '\(text)'")
        let success = usbPrinterAdapter.printText(text: text)
        NSLog("🖨️ EscposprinterPlugin: Print text result: \(success)")
        if success {
            NSLog("✅ EscposprinterPlugin: Successfully printed text")
        } else {
            NSLog("❌ EscposprinterPlugin: Failed to print text")
        }
        result(success)
    }

    private func printRawData(rawData: String, result: @escaping FlutterResult) {
        NSLog(
            "🖨️ EscposprinterPlugin: Calling USBPrinterAdapter.printRawData() with data length: \(rawData.count)"
        )
        let success = usbPrinterAdapter.printRawData(rawData: rawData)
        NSLog("🖨️ EscposprinterPlugin: Print raw data result: \(success)")
        if success {
            NSLog("✅ EscposprinterPlugin: Successfully printed raw data")
        } else {
            NSLog("❌ EscposprinterPlugin: Failed to print raw data")
        }
        result(success)
    }

    private func write(data: Data, result: @escaping FlutterResult) {
        NSLog("🖨️ EscposprinterPlugin: Calling USBPrinterAdapter.write() with \(data.count) bytes")
        NSLog(
            "🖨️ EscposprinterPlugin: Data content: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))"
        )
        let success = usbPrinterAdapter.write(data: data)
        NSLog("🖨️ EscposprinterPlugin: Write result: \(success)")
        if success {
            NSLog("✅ EscposprinterPlugin: Successfully wrote data")
        } else {
            NSLog("❌ EscposprinterPlugin: Failed to write data")
        }
        result(success)
    }
}
