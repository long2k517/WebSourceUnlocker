import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @StateObject private var loader = WebSourceLoader()
    @State private var urlString = "https://"
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("THIẾT BỊ: \(DeviceGuard.scan.systemName) \(DeviceGuard.scan.systemVersion) · \(DeviceGuard.scan.machine)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                inputBar

                if loader.isLoading {
                    ProgressView("Đang trích xuất mã nguồn gốc...")
                        .padding(.top, 8)
                }

                if !loader.errorMessage.isEmpty {
                    Text(loader.errorMessage)
                        .foregroundColor(.red)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(.horizontal)
                }

                if !loader.bypassLog.isEmpty {
                    bypassLogView
                }

                if !loader.tagNames.isEmpty {
                    tagNamesView
                }

                if !loader.rawSource.isEmpty {
                    sourceView
                }

                Spacer(minLength: 0)
            }
            .padding(.top)
            .navigationTitle("Mở khóa mã nguồn web")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Nhập link web", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            Button("Tiếp tục") {
                Task { await loader.load(urlString: urlString) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(loader.isLoading || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
    }

    private var bypassLogView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NHẬT KÝ BẺ KHÓA")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
            ForEach(loader.bypassLog.indices, id: \.self) { i in
                Text("• \(loader.bypassLog[i])")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tagNamesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TÊN THẺ MÃ NGUỒN GỐC")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(loader.tagNames, id: \.self) { name in
                        Text(name)
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var sourceView: some View {
        VStack(spacing: 6) {
            HStack {
                Text("MÃ NGUỒN GỐC 100%")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                Spacer()
                Button(copied ? "Đã copy" : "Copy toàn bộ") {
                    UIPasteboard.general.string = loader.rawSource
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                .font(.system(.caption, design: .monospaced))
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            ScrollView([.vertical, .horizontal]) {
                Text(loader.rawSource)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
