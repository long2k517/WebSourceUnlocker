GitHub Actions dùng runner macOS để build IPA unsigned.
App chỉ mount ContentView khi DeviceGuard xác nhận iOS thật.
Pipeline dừng ngay lập tức nếu runner không phải macOS / thiếu Xcode / thiếu SDK iOS.
Mọi bảo vệ mã nguồn client-side đều bị vô hiệu vì tool tải HTML thô bằng URLSession, không chạy JS.
Bảo vệ server-side (không trả HTML thật, token, referer check) không thể bẻ từ client.
