# Đồ án CSDL Phân Tán — Đề 4: Thi trắc nghiệm

> Báo cáo tổng hợp — cập nhật 06/08/2026
> CSDL: `TN_CSDLPT` · Ứng dụng: `De4_WinForm` (C# WinForms, .NET 9)

---

## 1. KIẾN TRÚC PHÂN TÁN

### 1.1 Ba mảnh

| Mảnh | Server | Kiểu | Nội dung |
|---|---|---|---|
| 1 | `…\SERVER1` | Ngang | Toàn bộ dữ liệu **Cơ sở 1** |
| 2 | `…\SERVER2` | Ngang | Toàn bộ dữ liệu **Cơ sở 2** |
| 3 | `…\SERVER3` | **Dọc** | Lớp + Sinh viên **cả hai cơ sở**, chỉ vài cột |

Publisher `…\SERVER` giữ đầy đủ dữ liệu, đóng vai trò máy chủ nhân bản.

### 1.2 Cây dẫn xuất (bộ lọc Merge Replication)

Mảnh 1 và 2 giống hệt nhau, chỉ khác điều kiện lọc ở gốc:

```
COSO                        ← NGUYÊN THUỶ · row filter: MACS = 'CS1'   (mảnh 2: 'CS2')
└─ KHOA                     KHOA.MACS = COSO.MACS
   └─ LOP                   LOP.MAKH = KHOA.MAKH
      ├─ GIAOVIEN_DANGKY    GIAOVIEN_DANGKY.MALOP = LOP.MALOP
      └─ SINHVIEN           SINHVIEN.MALOP = LOP.MALOP
         └─ BANGDIEM        BANGDIEM.MASV = SINHVIEN.MASV
```

**Nguyên tắc:** chỉ `COSO` bị lọc dòng; mọi bảng khác kéo theo bằng **join filter** dọc theo khóa ngoại. Bảng nào không có cột `MACS` (LOP, SINHVIEN, BANGDIEM…) thì bắt buộc đi vòng qua bảng cha gần nhất.

Kết quả kiểm chứng thực tế:

| Server | Số sinh viên | Lớp |
|---|---|---|
| SERVER (chủ) | 18 | TH04, TH05, TH06, VT04 |
| SERVER1 (CS1) | 10 | TH04, TH05, TH06 |
| SERVER2 (CS2) | 8 | VT04 |
| SERVER3 (tra cứu) | 18 | cả hai cơ sở |

### 1.3 Mảnh 3 — phân mảnh dọc

Không lọc dòng (lấy cả hai cơ sở), chỉ **trích các cột cần thiết**:

| Bảng | Cột giữ lại | Cột đã cắt |
|---|---|---|
| `SINHVIEN` | MASV, HO, TEN, MALOP | NGAYSINH, DIACHI, **PASSWORD** |
| `LOP` | MALOP, TENLOP | MAKH |

Theo đúng yêu cầu đề, mảnh này **không cho người dùng đăng nhập** — nó không xuất hiện trong ComboBox chọn phân mảnh. Ứng dụng truy cập bằng tài khoản dịch vụ chỉ-đọc `tracuu` (đã `DENY INSERT/UPDATE/DELETE`), dùng để **tra cứu mã sinh viên / mã lớp đã tồn tại chưa** khi nhập liệu.

---

## 2. PHÂN QUYỀN (tĩnh — 4 nhóm)

| Nhóm | Quyền |
|---|---|
| **Truong** | Đăng nhập mọi phân mảnh, **chỉ xem**, chạy được cả 3 báo cáo, chỉ tạo được tài khoản nhóm `Truong` |
| **CoSo** | Toàn quyền **trên cơ sở của mình**, tạo được tài khoản `CoSo` và `Giangvien` |
| **Giangvien** | **Không** nhập khoa/lớp/sinh viên. Chỉ cập nhật **đề thi do chính mình soạn**. Được **thi thử không ghi điểm** |
| **Sinhvien** | Chỉ được **thi**. Không truy cập bảng trực tiếp — mọi thao tác qua stored procedure |

Ràng buộc được ép ở **tầng CSDL**, không phụ thuộc giao diện:

- `sp_Bode_Sua/Xoa` xác định giảng viên bằng `SUSER_SNAME()` (login = mã GV) → không giả mạo được từ ứng dụng.
- `Giangvien` bị `DENY INSERT/UPDATE/DELETE` trên `KHOA`, `LOP`, `SINHVIEN`, `BODE`.
- `sp_NopBai` lấy cờ `THITHU` **từ phiếu thi ở server**, không lấy từ tham số client.

---

## 3. ĐĂNG NHẬP (Câu 1)

Hai đối tượng, hai cách khác nhau:

| Đối tượng | Cơ chế |
|---|---|
| Giảng viên / Cơ sở / Trưởng | Mỗi người **một SQL login riêng** + mật khẩu |
| Sinh viên | **Một SQL login dùng chung**, danh tính xác thực bằng `MASV` + `PASSWORD` trong bảng `SINHVIEN` |

Lý do dùng tài khoản chung cho sinh viên: tránh tạo hàng chục ngàn login trên SQL Server (tốn tài nguyên, khó quản lý).

Form đăng nhập có **ComboBox chọn phân mảnh**, dữ liệu lấy từ view `V_DS_PHANMANH`:

```sql
CREATE VIEW dbo.V_DS_PHANMANH AS
SELECT TENCN = PUBS.description, TENSERVER = SUBS.subscriber_server
FROM dbo.sysmergepublications PUBS, dbo.sysmergesubscriptions SUBS
WHERE PUBS.pubid = SUBS.pubid AND PUBS.publisher <> SUBS.subscriber_server;
```

---

## 4. CÁC CHỨC NĂNG

| Câu | Chức năng | Màn hình | Điểm bám đề |
|---|---|---|---|
| 1 | Đăng nhập, tạo tài khoản, đổi mật khẩu | `frmDangNhap`, `frmTaiKhoan` | 2 cách đăng nhập; Trưởng chỉ tạo Trưởng |
| 2 | Danh mục môn học | `frmMonHoc` | Chỉ mã + tên (không tín chỉ) |
| 3 | Khoa và Lớp | `frmKhoaLop` | **Chung một form** (master-detail) |
| 4 | Sinh viên | `frmSinhVien` | Lớp chỉ để **chọn**; có ô mật khẩu; **kiểm trùng mã qua mảnh 3** |
| 5 | Giảng viên | `frmGiaoVien` | **Chọn khoa** rồi nhập GV vào khoa đó |
| 6 | Bộ đề | `frmBoDe` | Tự lọc theo GV đăng nhập; trình độ A/B/C; đáp án A/B/C/D |
| 7 | Chuẩn bị thi | `frmChuanBiThi` | **Kiểm đủ đề, báo rõ còn thiếu bao nhiêu câu** |
| 8 | Thi trắc nghiệm | `frmThi` | Xem mục 5 |
| 9 | Xem lại bài thi | `frmXemKetQua` | Có đáp án đúng + câu đã chọn (phúc khảo) |
| 10 | Bảng điểm môn học | `frmBangDiem` | **Làm tròn 0.5** + điểm chữ |
| 11 | Đăng ký thi 2 cơ sở | `frmBaoCaoDangKy` | **UNION 2 phân mảnh**, không qua máy chủ |
| — | Sao lưu / phục hồi | `frmSaoLuu` | Phần quản trị |

### Bộ nút chuẩn cho mọi form nhập liệu

**Thêm — Xóa — Ghi — Phục hồi — Nạp lại**

- **Ghi** tự nhận biết đang Thêm (`INSERT`) hay đang Sửa (`UPDATE`).
- **Phục hồi** hai mức:
  1. Còn thay đổi chưa ghi → hủy phần chưa ghi.
  2. Hết phần chưa ghi → **lùi từng bước đã ghi**, lấy từ **ngăn xếp (Stack)** lưu ảnh chụp bảng trước mỗi lần Ghi. Bấm nhiều lần để lùi nhiều cấp. Nút hiện số bước còn lùi được, ví dụ `Phục hồi (3)`.

---

## 5. CÂU 8 — THI TRẮC NGHIỆM (trọng tâm)

### 5.1 Luật chọn câu hỏi

Thực hiện hoàn toàn trong stored procedure `sp_LayDeThi`:

1. **Ưu tiên theo CƠ SỞ CỦA LỚP** (không phải theo giảng viên dạy) — lấy hết kho `BODE` của cơ sở lớp đang học.
2. **Thiếu thì mượn cơ sở còn lại** từ `Bode_Muon` (lọc `MACS <> cơ sở của lớp`), đánh dấu `NGUON = 'MUON'`.
3. **Vẫn thiếu** → hạ **đúng 1 bậc** trình độ (A→B, B→C), tổng phần hạ bậc **không quá 30%** tổng số câu.
4. Không đủ → **báo lỗi**, tuyệt đối không phát đề thiếu.

Kiểm chứng thực tế (đề 100 câu trình độ A, lớp TH05 thuộc CS1):

```
Kho CS1 trình độ A : 94 câu
Kho mượn CS2       : 16 câu
Đề phát ra         : 94 LOCAL + 6 MUON = 100 câu   ✅
```

### 5.2 Các ràng buộc khác

| Yêu cầu | Cách làm |
|---|---|
| Chỉ hiện môn **đã đăng ký & chưa thi** | ComboBox lọc từ `sp_LichThi`, bỏ môn có `dathi = 1` |
| Xáo trộn câu hỏi | `ORDER BY NEWID()` |
| Thời gian tính **sau khi tải xong đề** | Đồng hồ đếm ngược lấy mốc `sogiayconlai` **do server trả về**, không tin đồng hồ máy trạm |
| Hết giờ **tự động** kết thúc | `Timer` 1 giây; về 0 thì tự gọi nộp bài, không đợi người dùng bấm |
| Mọi câu điểm bằng nhau, thang 10 | `DIEM = SoCauDung * 10 / SoCau` |
| Chấm điểm **an toàn** | Đáp án **không bao giờ** gửi về máy trạm; chấm bằng cách JOIN với `PhieuThi_CauHoi` phía server |
| Chống nộp trùng | Giao tác `SERIALIZABLE` + `UPDLOCK, HOLDLOCK` |
| F5 / mở lại không đổi đề | Phiếu còn hiệu lực thì trả lại đúng phiếu cũ |
| Giảng viên **thi thử** | `@ThiThu = 1` → không ghi `BANGDIEM` |
| Chọn lại đề lần trước | `@DungLaiDeLanTruoc = 1` |

---

## 6. CÂU 11 — BÁO CÁO HAI CƠ SỞ

Đề yêu cầu rõ: báo cáo này **không được lấy dữ liệu từ máy chủ**, phải chạy trên hai phân mảnh và ghép bằng **UNION**.

Cách làm:

1. `sp_BaoCao_DangKy` được cài trên **SERVER1 và SERVER2** (đã **gỡ khỏi** máy chủ).
2. Mỗi phân mảnh chỉ chứa dữ liệu cơ sở mình — bản thân phân mảnh **đã là bộ lọc**, không cần điều kiện `MACS`.
3. Ứng dụng gọi thủ tục trên **cả hai** phân mảnh rồi **UNION** kết quả.
4. Màn hình in rõ nguồn dữ liệu để chứng minh:
   `Nguồn dữ liệu (UNION từ các PHÂN MẢNH, không qua server chủ): Co so 1 (…\SERVER1): 3 dòng | Co so 2 (…\SERVER2): 2 dòng`

Cột báo cáo: cơ sở, lớp, môn học, giảng viên, trình độ, số câu, thời gian, ngày thi, lần, **ĐÃ THI (X)**, ghi chú (*Đã thi xong / Đang thi dở (2/8) / Quá hạn chưa thi / Chưa tới ngày thi*).

---

## 7. NHỮNG LỖI ĐÃ PHÁT HIỆN VÀ SỬA

| # | Lỗi | Hậu quả nếu không sửa |
|---|---|---|
| 1 | **Trùng mã câu hỏi giữa 2 cơ sở** — cùng dải 1..259. Bảng tạm `#De` khóa `PRIMARY KEY(CAUHOI)` nên mọi câu mượn bị loại | **Chức năng mượn đề chưa bao giờ chạy** — đề luôn ra 100% câu của cơ sở mình, mất hẳn phần minh chứng phân tán. Sửa: `#De` khóa `(CAUHOI, NGUON)`; `ChiTiet_BaiThi` đổi khóa chính sang `STT` |
| 2 | **Phân quyền trống** — nhóm `Giangvien` không `SELECT` được `MONHOC`, không `EXECUTE` được `sp_Bode_DS` | Màn hình bộ đề chết hoàn toàn khi đăng nhập bằng tài khoản giảng viên |
| 3 | **Câu 11 chạy trên máy chủ** | Vi phạm trực tiếp yêu cầu của đề |
| 4 | **Câu 10 không làm tròn 0.5** | Ra điểm kiểu 2.25, sai mẫu của trường |
| 5 | **Mảnh 3 lộ cột PASSWORD** | Máy tra cứu giữ mật khẩu sinh viên — sai bảo mật |
| 6 | **`Bode_Muon` chứa cả đề của chính cơ sở mình** (sau khi gỡ row filter để khớp cây dẫn xuất chuẩn) | `sp_ChuanBiThi` đếm trùng kho đề → tưởng đủ trong khi thiếu. Sửa: lọc `MACS` ngay trong thủ tục, không phụ thuộc cấu hình nhân bản |
| 7 | **Thông báo tiếng Việt lỗi font** trong `sp_DoiMatKhau_SV` | Người dùng thấy `Máº­t kháº©u` |
| 8 | **Snapshot replication chết** — share `\\…\ReplData` không còn tồn tại | Không tạo lại được snapshot, mọi thay đổi cấu hình nhân bản đều vô hiệu |

---

## 8. DANH SÁCH TỆP

### Script SQL (`SQL/`)

| Tệp | Nội dung | Chạy trên |
|---|---|---|
| `01_Cau1_DangNhap_TaiKhoan.sql` | SP đăng nhập, đổi mật khẩu, thông tin người dùng | S1, S2, chủ |
| `02_Cau1_TaiKhoanTraCuu_SERVER3.sql` | Tài khoản dịch vụ `tracuu` chỉ-đọc | SERVER3 |
| `03_PhanQuyen.sql` | Phân quyền tĩnh 4 nhóm | S1, S2, chủ |
| `04_Cau7_Cau8_SuaKhoMuonDe.sql` | Lọc `MACS` trong SP thay vì dựa vào nhân bản | S1, S2 |
| `05_Cau8_SuaTrungMaCauHoi.sql` | Sửa lỗi trùng mã làm hỏng chức năng mượn đề | S1, S2 |
| `06_Cau10_Cau11_BaoCao.sql` | Làm tròn 0.5; câu 11 chuyển xuống phân mảnh | S1, S2 |
| `07_SaoLuu_PhucHoi.sql` | Sao lưu / phục hồi dữ liệu | S1, S2, chủ |

> Chạy bằng `sqlcmd -f 65001` (tệp lưu UTF-8) để không lỗi phông tiếng Việt.

### Ứng dụng (`De4_WinForm/QuanLyThi/`)

| Tệp | Vai trò |
|---|---|
| `DataProvider.cs` | Kết nối theo phân mảnh, phiên làm việc, tra cứu mảnh 3, UNION câu 11 |
| `BangCrud.cs` | Nạp/ghi dữ liệu + **ngăn xếp undo nhiều cấp** |
| `frmCrudBase.cs` | Form nhập liệu chuẩn (Thêm/Xóa/Ghi/Phục hồi/Nạp lại) |
| `frmDangNhap.cs` | Đăng nhập + ComboBox phân mảnh |
| `frmTaiKhoan.cs` | Tạo tài khoản, đổi mật khẩu |
| `frmMonHoc / frmKhoaLop / frmSinhVien / frmGiaoVien / frmBoDe` | Câu 2–6 |
| `frmChuanBiThi / frmThi / frmXemKetQua` | Câu 7–9 |
| `frmBangDiem / frmBaoCaoDangKy` | Câu 10–11 |
| `frmTraCuu.cs` | Tra cứu qua mảnh 3 |
| `frmSaoLuu.cs` | Sao lưu / phục hồi |

---

## 9. CHẠY CHƯƠNG TRÌNH

```
dotnet run --project D:\LEARN\PITT\CSDLPT\De4_WinForm\QuanLyThi
```

### Tài khoản thử nghiệm

| Tài khoản | Mật khẩu | Nhóm | Phân mảnh |
|---|---|---|---|
| `truong01` | `Truong@123` | Trưởng | cả hai |
| `coso1` | `Coso@123` | Cơ sở | Cơ sở 1 |
| `TH101`, `TH123` | `Gv@123` | Giảng viên | Cơ sở 1 |
| `coso2` | `Coso@123` | Cơ sở | Cơ sở 2 |
| `TH657` | `Gv@123` | Giảng viên | Cơ sở 2 |
| Mã sinh viên (vd `005`) | mật khẩu trong bảng | Sinh viên | theo lớp |

---

## 10. ĐIỂM CẦN LƯU Ý KHI BẢO VỆ

**Bảng `PhieuThi_CauHoi` lưu lại nội dung câu hỏi** (`NOIDUNG, A, B, C, D, DAP_AN`) — thoạt nhìn giống dư thừa. Lý do thiết kế:

1. Đó là **ảnh chụp đề tại thời điểm thi**. Giảng viên có thể sửa hoặc xóa câu hỏi sau kỳ thi; nếu chỉ lưu khóa thì in lại bài cũ sẽ ra nội dung đã bị đổi, không phúc khảo được.
2. Với **câu mượn của cơ sở khác** (cột `NGUON = 'MUON'`), câu hỏi gốc **không tồn tại** trong bảng `BODE` của phân mảnh này nên không join ngược về được.

Khóa chính `(MAPHIEU, STT)` — `STT` định danh vị trí câu trong phiếu thi, `CAUHOI` chỉ là thuộc tính tham chiếu. Cách đặt khóa này cũng chính là thứ cho phép một phiếu chứa đồng thời câu số 5 của cơ sở mình và câu số 5 mượn được.
