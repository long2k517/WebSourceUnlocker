import SwiftUI

@main
struct WebSourceUnlockerApp: App {
    var body: some Scene {
        WindowGroup {
            // Scan chạy một lần duy nhất, cache tĩnh
            if DeviceGuard.scan.isIOS {
                ContentView()
            } else {
                BlockedView(reason: DeviceGuard.scan.reason)
            }
        }
    }
}

struct BlockedView: View {
    let reason: String

    var body: some View {
        VStack(spacing: 16) {
            Text("TIẾN TRÌNH ĐÃ DỪNG")
                .font(.system(.headline, design: .monospaced))
                .fontWeight(.bold)
            Text(reason)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
            Text("YÊU CẦU THIẾT BỊ: IOS")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
