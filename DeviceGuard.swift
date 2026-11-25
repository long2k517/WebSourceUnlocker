import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Quét thiết bị một lần, cache tĩnh để không quét lại
enum DeviceGuard {

    struct ScanResult {
        let isIOS: Bool
        let systemName: String
        let systemVersion: String
        let machine: String
        let reason: String
    }

    static let scan: ScanResult = performScan()

    private static func performScan() -> ScanResult {
        #if os(iOS) && canImport(UIKit)
        let device = UIDevice.current
        let name = device.systemName
        let version = device.systemVersion
        let machine = machineIdentifier()
        let confirmed = name == "iOS" && !version.isEmpty && !machine.isEmpty
        return ScanResult(
            isIOS: confirmed,
            systemName: name,
            systemVersion: version,
            machine: machine,
            reason: confirmed ? "THIẾT BỊ IOS HỢP LỆ" : "SAI NỀN TẢNG"
        )
        #else
        return ScanResult(
            isIOS: false,
            systemName: "unknown",
            systemVersion: "0",
            machine: "unknown",
            reason: "KHÔNG PHẢI IOS - DỪNG TIẾN TRÌNH"
        )
        #endif
    }

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            let bytes = buffer.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }
}
