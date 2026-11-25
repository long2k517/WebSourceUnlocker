1. DeviceGuard chạy đúng 1 lần qua static let, không quét lại trong ContentView.
2. Loại bỏ lần quét thứ hai trùng lặp ở ContentView (trước đây quét 2 lần).
3. Toàn bộ NSRegularExpression biên dịch tĩnh 1 lần, dùng lại suốt vòng đời app.
4. Bảng entity map và chữ ký bảo vệ chuyển thành mảng static.
5. ContentView tách thành các view con nhỏ, SwiftUI chỉ redraw phần thay đổi.
6. Loader gom toàn bộ xử lý vào 1 lần publish, không cập nhật rải rác.
7. Truyền log qua mảng cục bộ, chỉ gán 1 lần vào @Published, giảm redraw.
8. Workflow gộp bước quét môi trường, bỏ bước quét trùng, dùng set -euo pipefail.
9. Giữ nguyên 100% chức năng: nhập URL, tải HTML thô, phát hiện bảo vệ, bẻ khóa
   6 lớp, danh sách thẻ, copy, nhật ký, quét thiết bị 2 tầng, xuất IPA unsigned.
