# Hệ thống Thi trắc nghiệm — Cơ sở dữ liệu phân tán

Đồ án môn **Cơ sở dữ liệu phân tán** — Đề 4: Thi trắc nghiệm.
Ứng dụng **C# WinForms (.NET 9)** trên **SQL Server Merge Replication**, phân tán thành 3 mảnh.

---

## 1. Kiến trúc phân tán

| Mảnh | Instance | Kiểu | Nội dung |
|---|---|---|---|
| Máy chủ | `SERVER` | Publisher | Giữ đầy đủ dữ liệu, phát hành 3 publication |
| Mảnh 1 | `SERVER1` | Ngang | Toàn bộ dữ liệu **Cơ sở 1** |
| Mảnh 2 | `SERVER2` | Ngang | Toàn bộ dữ liệu **Cơ sở 2** |
| Mảnh 3 | `SERVER3` | **Dọc** | Lớp + Sinh viên **cả hai cơ sở**, chỉ vài cột — dùng để tra cứu |

### Cây dẫn xuất (bộ lọc Merge Replication)

Mảnh 1 và 2 giống hệt nhau, chỉ khác điều kiện lọc ở gốc:

```
COSO                       ← NGUYÊN THUỶ · row filter: MACS = 'CS1'   (mảnh 2: 'CS2')
└─ KHOA                    KHOA.MACS = COSO.MACS
   └─ LOP                  LOP.MAKH = KHOA.MAKH
      ├─ GIAOVIEN_DANGKY   GIAOVIEN_DANGKY.MALOP = LOP.MALOP
      └─ SINHVIEN          SINHVIEN.MALOP = LOP.MALOP
         └─ BANGDIEM       BANGDIEM.MASV = SINHVIEN.MASV
```

Chỉ `COSO` bị lọc dòng; mọi bảng khác kéo theo bằng **join filter** dọc theo khóa ngoại.

---

## 2. Yêu cầu môi trường

- **SQL Server 2019+** với **4 named instance**: `SERVER`, `SERVER1`, `SERVER2`, `SERVER3`
- **SQL Server Agent** đang chạy trên cả 4 instance (cần cho replication)
- Bật **Mixed Mode Authentication** (đề dùng SQL login)
- **.NET 9 SDK** để build ứng dụng
- Bật **SQL Server Browser** (để kết nối named instance)

---

## 3. Cài đặt trên máy mới

### Bước 0 — Sửa tên máy trong script

Mở `SQL/03_ThietLapNhanBan.sql`, sửa 5 biến ở đầu file cho khớp máy bạn:

```sql
:setvar MayChu          "TEN-MAY-CUA-BAN\SERVER"
:setvar MayCS1          "TEN-MAY-CUA-BAN\SERVER1"
:setvar MayCS2          "TEN-MAY-CUA-BAN\SERVER2"
:setvar MayTraCuu       "TEN-MAY-CUA-BAN\SERVER3"
:setvar ThuMucSnapshot  "D:\duong-dan\ReplData"
```

Lấy tên máy bằng: `SELECT @@SERVERNAME`

### Bước 1 — Chạy tự động (khuyến nghị)

```powershell
cd SQL
.\CaiDat.ps1
```

Script sẽ chạy tuần tự tất cả các bước. Muốn chỉ định tên máy khác:

```powershell
.\CaiDat.ps1 -TenMay "TEN-MAY-CUA-BAN" -ThuMucSnapshot "D:\ReplData"
```

### Bước 1b — Hoặc chạy tay từng bước

> Mọi script đều lưu **UTF-8**, bắt buộc chạy với `-f 65001` nếu không sẽ **lỗi font tiếng Việt**.

| Thứ tự | Script | Chạy trên |
|---|---|---|
| 1 | `00_TaoCSDL_Schema.sql` | **cả 4** instance |
| 2 | `00e_StoredProcedures.sql` | `SERVER`, `SERVER1`, `SERVER2` |
| 3 | `01_DuLieuMau.sql` | chỉ `SERVER` |
| 4 | `02_NhomQuyen_TaiKhoan.sql` | cả 4, kèm `-v MayChu="CHU\|CS1\|CS2\|TRACUU"` |
| 5 | `03_ThietLapNhanBan.sql` | chỉ `SERVER` |
| 6 | `02_Cau1_TaiKhoanTraCuu_SERVER3.sql` | chỉ `SERVER3` |
| 7 | `03_PhanQuyen.sql` | `SERVER`, `SERVER1`, `SERVER2` |
| 8 | `04` … `09` | `SERVER1`, `SERVER2` |

Ví dụ một lệnh:

```powershell
sqlcmd -S localhost\SERVER -E -f 65001 -i 00_TaoCSDL_Schema.sql
```

### Bước 2 — Đợi nhân bản

Sau `03_ThietLapNhanBan.sql`, mở **SSMS → Replication → Replication Monitor**, đợi 3 snapshot chạy xong rồi **Start Synchronizing** từng subscription. Kiểm tra:

```sql
-- Trên SERVER1 phải ra 10, SERVER2 ra 8, SERVER3 ra 18
SELECT COUNT(*) FROM TN_CSDLPT.dbo.SINHVIEN;
```

### Bước 3 — Chạy ứng dụng

```bash
dotnet run --project De4_WinForm/QuanLyThi
```

Nếu tên máy khác `DESKTOP-O6C61JT`, sửa `De4_WinForm/QuanLyThi/DataProvider.cs`:

```csharp
public const string ServerChu   = @"localhost\SERVER";
public const string ServerTraCuu = @"localhost\SERVER3";
```

---

## 4. Tài khoản mặc định

> ⚠️ **Đây là mật khẩu DEMO cho môi trường học tập, đang để trong mã nguồn.**
> Đổi lại trước khi dùng cho việc gì khác. Xem `SQL/02_NhomQuyen_TaiKhoan.sql`
> và `De4_WinForm/QuanLyThi/DataProvider.cs`.

| Tài khoản | Mật khẩu | Nhóm quyền | Có ở |
|---|---|---|---|
| `truong01` | `Truong@123` | Trưởng | cả 4 instance |
| `coso1` | `Coso@123` | Cơ sở | SERVER1 |
| `coso2` | `Coso@123` | Cơ sở | SERVER2 |
| `TH101`, `TH123` | `Gv@123` | Giảng viên | SERVER1 |
| `TH657` | `Gv@123` | Giảng viên | SERVER2 |
| `sv` | `Sv@123` | Sinh viên (dùng chung) | S1, S2, S3 |
| `tracuu` | `TraCuu@123` | dịch vụ chỉ-đọc | SERVER3 |

**Sinh viên đăng nhập bằng mã SV**, không dùng login riêng:
mã `001`–`011` (Cơ sở 1) · `201`–`208` (Cơ sở 2) · mật khẩu = chính mã SV.

---

## 5. Cấu trúc mã nguồn

```
De4_WinForm/QuanLyThi/
├── Program.cs              Điểm vào; vòng lặp đăng nhập → làm việc → đăng xuất
├── DataProvider.cs         Kết nối theo phân mảnh, phiên làm việc, tra cứu mảnh 3,
│                           UNION 2 phân mảnh cho câu 11
├── BangCrud.cs             Nạp/ghi dữ liệu + ngăn xếp Undo nhiều cấp
├── GiaoDien.cs             Bảng màu, phông chữ, định dạng lưới dùng chung
├── frmCrudBase.cs          Form nhập liệu chuẩn: Thêm/Xóa/Ghi/Phục hồi/Nạp lại
├── frmDangNhap.cs          Câu 1 — ComboBox phân mảnh từ V_DS_PHANMANH
├── frmTaiKhoan.cs          Câu 1 — tạo tài khoản, đổi mật khẩu
├── frmMonHoc.cs            Câu 2
├── frmKhoaLop.cs           Câu 3 — Khoa và Lớp CHUNG một form
├── frmSinhVien.cs          Câu 4 — chống trùng mã qua mảnh 3
├── frmGiaoVien.cs          Câu 5
├── frmBoDe.cs              Câu 6
├── frmChuanBiThi.cs        Câu 7 — kiểm đủ đề
├── frmThi.cs               Câu 8 — đồng hồ đếm ngược, tự nộp
├── frmXemKetQua.cs         Câu 9 — phúc khảo
├── frmBangDiem.cs          Câu 10 — làm tròn 0.5
├── frmBaoCaoDangKy.cs      Câu 11 — UNION 2 phân mảnh
├── frmTraCuu.cs            Chức năng dùng mảnh dọc
├── frmSaoLuu.cs            Sao lưu / phục hồi
└── ChupManHinh.cs          Tiện ích phát triển: `QuanLyThi.exe --chup <thư-mục>`
```

---

## 6. Tài liệu kèm theo

| Tệp | Nội dung |
|---|---|
| `BAOCAO_DOAN.md` | Báo cáo tổng hợp: kiến trúc, 11 chức năng, lỗi đã sửa |
| `RASOAT_LUONGXULY.md` | Luồng xử lý từng câu: form → nút → tham số → SP → bảng |
| `PHANTICH_DE_THAY.md` | Phân tích yêu cầu của Thầy + checklist đối chiếu |

---

## 7. Những chỗ dễ vấp khi cài đặt

| Triệu chứng | Nguyên nhân & cách xử lý |
|---|---|
| Tiếng Việt hiện thành `Máº­t kháº©u` | Thiếu `-f 65001` khi chạy `sqlcmd` |
| Snapshot thất bại: *"failed to create the directory"* | Thư mục snapshot trỏ tới UNC share không tồn tại. Đổi `working_directory` sang **đường dẫn cục bộ** (4 instance cùng máy nên không cần share) |
| Merge agent: *"could not connect to Subscriber"* | Agent chạy bằng Windows auth mà tài khoản dịch vụ SQL Agent không có login trên subscriber. Script đã đặt `@subscriber_security_mode=0` dùng SQL auth |
| Thêm dòng mới báo *"does not allow nulls"* | Đã xử lý: ràng buộc phía máy trạm được gỡ trong `BangCrud.Nap()`, để CSDL kiểm |
| Đề thi luôn ra 100% câu của cơ sở mình | Mã câu hỏi cũ của 2 cơ sở trùng nhau. Đã xử lý bằng khóa `(CAUHOI, NGUON)` — xem `SQL/05_...` |
