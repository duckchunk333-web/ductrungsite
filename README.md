# StudyRoom — triển khai GitHub + Render + UptimeRobot (miễn phí theo hạn mức)

StudyRoom là website tĩnh dùng Supabase cho tài khoản, database, realtime chat và file storage. Render phục vụ giao diện; Supabase giữ dữ liệu; UptimeRobot chỉ giám sát URL, không phải nơi host và không thể bảo đảm Render free luôn thức.

## 1) Tạo dịch vụ Supabase
1. Tạo project tại https://supabase.com/.
2. Vào **SQL Editor → New query**, dán toàn bộ `supabase.sql` rồi Run.
3. Vào **Project Settings → API** lấy **Project URL** và **anon/public/publishable key**.
4. Mở `config.js`, thay hai giá trị mẫu bằng Project URL và public key.
   - Chỉ dùng anon/public/publishable key ở frontend.
   - KHÔNG đưa `service_role` hoặc secret key vào GitHub.
5. Vào **Authentication → URL Configuration**. Tạm thời để Site URL là URL Render sau khi deploy; thêm Redirect URL `https://TEN-WEBSITE.onrender.com/**`. Trong lúc test local có thể thêm `http://localhost:5500/**`.
6. Kiểm tra Email provider và chính sách xác minh email trong Authentication.

## 2) Đưa mã nguồn lên GitHub
1. Tạo repository mới tại https://github.com/new (ví dụ `studyroom`).
2. Giải nén ZIP này.
3. Upload toàn bộ file và thư mục ở bên trong thư mục dự án lên repository. `index.html`, `config.js`, `app.js`, `style.css`, `supabase.sql`, `render.yaml` phải nằm ở thư mục gốc repository.
4. Commit changes. Không commit bất kỳ secret/service-role key nào.

## 3) Deploy trên Render
1. Vào https://dashboard.render.com/ và đăng nhập bằng GitHub.
2. Chọn **New + → Static Site**, kết nối repository `studyroom`.
3. Render nhận cấu hình từ `render.yaml`. Nếu nhập thủ công:
   - Build command: `echo "StudyRoom static site ready"`
   - Publish directory: `.`
4. Bấm **Create Static Site** và chờ deploy hoàn tất.
5. Mở URL dạng `https://studyroom-xxxx.onrender.com`.
6. Quay lại Supabase → **Authentication → URL Configuration**, đặt Site URL là URL thật đó và thêm redirect URL `https://studyroom-xxxx.onrender.com/**`.
7. Thử đăng ký hai tài khoản ở hai trình duyệt, tạo phòng, tham gia bằng mã, chat và tải file.

> Khi đổi `config.js`, phải commit lên GitHub để Render tự deploy lại. Nếu deploy báo 404, kiểm tra `index.html` có ở đúng thư mục gốc được publish không.

## 4) Thêm UptimeRobot
1. Vào https://uptimerobot.com/ tạo tài khoản miễn phí.
2. Chọn **Add New Monitor**.
3. Monitor Type: **HTTP(s)**.
4. Friendly Name: `StudyRoom`.
5. URL: dán URL Render, ví dụ `https://studyroom-xxxx.onrender.com/`.
6. Chọn khoảng kiểm tra khả dụng có trong gói hiện tại, bật email alert nếu muốn, rồi tạo monitor.

UptimeRobot chỉ kiểm tra website có phản hồi hay không và gửi cảnh báo. Nó không host web, không thay thế Supabase và không bảo đảm Render Free không sleep. Vì đây là Static Site, giao diện thường vẫn được phục vụ; database/auth/storage vẫn phụ thuộc Supabase.

## 5) Chạy thử local
Trong thư mục dự án, chạy:

```bash
python -m http.server 5500
```

Mở http://localhost:5500. Đừng mở trực tiếp `index.html` bằng `file://`.

## Cấu trúc
- `index.html`: giao diện
- `style.css`: dark mode xanh tím, responsive
- `app.js`: đăng nhập, phòng, chat, phản ứng, file
- `config.js`: cấu hình client Supabase
- `supabase.sql`: bảng, RLS, Storage và realtime
- `render.yaml`: cấu hình Render Static Site

## Lưu ý trước khi chia sẻ rộng
- Đây là triển khai miễn phí theo hạn mức của các dịch vụ, không có cam kết uptime/SLA.
- Public anon key được phép xuất hiện ở frontend; an toàn phụ thuộc vào RLS và chính sách Storage trong `supabase.sql`.
- Thông báo trình duyệt chỉ hoạt động khi website còn mở và người dùng cấp quyền.
- Giới hạn upload được đặt ở 25 MB/file trong giao diện/SQL; hạn mức Storage của Supabase có thể thấp hơn tùy gói.
- Không tải tài liệu nhạy cảm lên một dịch vụ chưa được rà soát kỹ. Hãy kiểm tra RLS/policies trước khi dùng cho dữ liệu riêng tư quan trọng.
