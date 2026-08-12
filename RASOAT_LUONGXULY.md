# Rà soát đồ án — Luồng xử lý từng chức năng

> Đối chiếu với: đề tài Thầy giao + `HD FORM DANG NHAP.docx` + `giai_de_4.txt`
> Cập nhật: 12/08/2026 · CSDL `TN_CSDLPT` · App `De4_WinForm` (C# WinForms .NET 9)

---

## PHẦN A — CÁCH ĐỌC TÀI LIỆU NÀY

Mỗi chức năng được mô tả theo đúng chuỗi:

```
[Form nào]  →  [Nút nào]  →  [Tham số truyền đi]  →  [Stored Procedure]  →  [Bảng nào trong CSDL]  →  [Kết quả trả về]
```

Nguyên tắc kiến trúc xuyên suốt toàn dự án:

| Nguyên tắc | Cụ thể |
|---|---|
| **Ứng dụng không tự quyết quyền** | Mỗi người đăng nhập bằng **SQL login riêng**. SQL Server mới là nơi chặn. Ẩn menu chỉ là cho gọn mắt, không phải bảo mật. |
| **Nghiệp vụ nằm trong Stored Procedure** | App chỉ truyền tham số. Đề yêu cầu rõ ở câu 8: *"SP lấy đề có đáp ứng được hay không, nếu không thì mất phân nửa số điểm"*. |
| **Danh tính lấy từ kết nối, không lấy từ tham số** | `SUSER_SNAME()` / `ORIGINAL_LOGIN()` — client không giả mạo được. |
| **Phân mảnh là bộ lọc** | Mỗi phân mảnh chỉ chứa dữ liệu cơ sở mình nhờ cây dẫn xuất, nên SP hầu như không cần điều kiện `MACS`. |

---

## PHẦN B — LUỒNG XỬ LÝ TỪNG CÂU

### CÂU 1 — ĐĂNG NHẬP

#### B1. Đổ danh sách phân mảnh vào ComboBox (chạy khi mở form)

```
frmDangNhap.Load
   └─ DataProvider.LayDanhSachPhanManh()
        └─ Kết nối:  localhost\SERVER  (PUBLISHER, Integrated Security)
             └─ SELECT TENCN, TENSERVER FROM dbo.V_DS_PHANMANH
                  └─ đọc: sysmergepublications + sysmergesubscriptions
        └─ LOẠI BỎ dòng "Tra cuu"/SERVER3
   └─ cboPhanManh.DataSource   = bảng kết quả
      cboPhanManh.DisplayMember= "TENCN"       (chữ người dùng thấy)
      cboPhanManh.ValueMember  = "TENSERVER"   (giá trị dùng để kết nối)
```

`V_DS_PHANMANH` là **nguyên văn của Thầy**:

```sql
CREATE VIEW dbo.V_DS_PHANMANH AS
SELECT TENCN = PUBS.description, TENSERVER = SUBS.subscriber_server
FROM dbo.sysmergepublications PUBS, dbo.sysmergesubscriptions SUBS
WHERE PUBS.pubid = SUBS.pubid AND PUBS.publisher <> SUBS.subscriber_server;
```

> **Vì sao loại mảnh 3 khỏi ComboBox:** Thầy nói *"chúng ta sẽ không cho người ta đăng nhập vào cái server này… nhưng vẫn dùng nó để tra cứu mã sinh viên có chưa"*.

#### B2. Bấm nút **[Đăng nhập]**

```
btnDangNhap_Click
   ├─ Lấy: server = cboPhanManh.SelectedValue
   │       ma     = txtMa.Text          (VD: TH101 hoặc 005)
   │       matKhau= txtMatKhau.Text
   └─ DataProvider.DangNhap(server, tenPhanManh, ma, matKhau)
```

**Đề yêu cầu 2 cách đăng nhập khác nhau** → SP thử lần lượt:

**Cách 1 — Cán bộ (Giảng viên / Cơ sở / Trưởng):**

```
Mở SqlConnection với User ID = <ma>, Password = <matKhau>
   ├─ Mở được  → là cán bộ, đi tiếp
   └─ Mở không được (SqlException) → chuyển sang Cách 2

EXEC dbo.SP_LayThongTinNguoiDung @TENLOGIN = <ma>
   ├─ SUSER_SID(@TENLOGIN)  →  tìm trong sys.sysusers  →  @TENUSER, @UID
   ├─ sys.sysmembers (MEMBERUID = @UID)  →  GROUPUID  →  tên nhóm quyền
   └─ Trả: MA | HOTEN (join dbo.GIAOVIEN theo MAGV) | TENNHOM

→ Phien.Ma = MA, Phien.HoTen = HOTEN, Phien.VaiTro = TENNHOM
```

> Đây chính là mẫu `SP_LayThongTinNhanVien` của Thầy, chỉ đổi bảng nghiệp vụ `NHANVIEN → GIAOVIEN`, `MANV → MAGV`. **Nhóm quyền đọc thẳng từ hệ thống**, không viết cứng trong code.

**Cách 2 — Sinh viên (tài khoản SQL dùng chung):**

```
Mở SqlConnection với User ID = 'sv', Password = 'Sv@123'   (config AppConfig)
EXEC dbo.sp_DangNhap_SV @MASV = <ma>, @PASSWORD = <matKhau>
   └─ SELECT ... FROM dbo.Sinhvien sv JOIN dbo.Lop l ON sv.MALOP = l.MALOP
      WHERE sv.MASV = @MASV AND RTRIM(sv.PASSWORD) = RTRIM(@PASSWORD)
   └─ Trả: masv | hoten | malop | tenlop      ← đúng yêu cầu đề
                                                "hiện mã lớp, tên lớp, họ tên"
   ├─ Có dòng   → Phien.VaiTro = "Sinhvien"
   └─ Không có  → báo "Sai mã số hoặc mật khẩu"
```

> **Vì sao sinh viên dùng chung 1 tài khoản:** Thầy giải thích tạo hàng chục ngàn login trên SQL Server sẽ chiếm tài nguyên và rất khó quản lý. Mật khẩu riêng của từng SV nằm ở cột `SINHVIEN.PASSWORD`.

#### B3. Các nút của form **Tài khoản & mật khẩu** (`frmTaiKhoan`)

| Nút | Tham số truyền | Stored Procedure | Tác động CSDL |
|---|---|---|---|
| **[Tạo tài khoản]** | `@username`, `@password`, `@role` | `SP_TAOLOGIN` (WITH EXECUTE AS OWNER) | `CREATE LOGIN` + `CREATE USER` + `ALTER ROLE ADD MEMBER` |
| **[Đổi mật khẩu]** (cán bộ) | `@MatKhauCu`, `@MatKhauMoi` | `SP_DOIMATKHAU` | `ALTER LOGIN … OLD_PASSWORD` |
| **[Đổi mật khẩu]** (sinh viên) | `@MASV`, `@MatKhauCu`, `@MatKhauMoi` | `sp_DoiMatKhau_SV` | `UPDATE dbo.Sinhvien SET PASSWORD` |

**Logic chặn quyền trong `SP_TAOLOGIN`** (đúng đề):

```
@caller = ORIGINAL_LOGIN()      ← KHÔNG dùng IS_MEMBER vì SP chạy EXECUTE AS OWNER
   ├─ Là Truong    → chỉ cho @role = 'Truong'
   ├─ Là CoSo      → chỉ cho @role IN ('CoSo','Giangvien')
   └─ Khác         → từ chối
Nếu @role='Giangvien' → bắt buộc đã có dòng trong dbo.Giaovien và username = MAGV
```

---

### CÂU 2 — DANH MỤC MÔN HỌC (`frmMonHoc`)

Kế thừa khung `frmCrudBase`. Không dùng SP — thao tác bảng trực tiếp, quyền do SQL Server chặn.

```
Mở form → BangCrud.Nap()
   └─ SELECT MAMH, TENMH FROM dbo.MONHOC ORDER BY MAMH
   └─ SqlDataAdapter + SqlCommandBuilder (tự sinh INSERT/UPDATE/DELETE)
```

| Nút | Việc làm ở app | Việc làm ở CSDL |
|---|---|---|
| **➕ Thêm** | `dt.NewRow()` + `Rows.Add` → dòng trống trên lưới | *(chưa chạm CSDL)* |
| **🗑 Xóa** | `row.Delete()` → đánh dấu xóa | *(chưa chạm CSDL)* |
| **💾 Ghi** | kiểm khóa chính không rỗng → `adapter.Update()` | `INSERT` / `UPDATE` / `DELETE` thật |
| **↩ Phục hồi** | còn thay đổi chưa ghi → `RejectChanges()`;<br>hết rồi → **lùi 1 bước đã ghi** lấy từ `Stack` | Khi lùi bước đã ghi: sinh lệnh đảo ngược |
| **🔄 Nạp lại** | `Nap()` | `SELECT` lại |

> **Nút Ghi tự biết Thêm hay Sửa** — đúng yêu cầu Thầy: *"lúc thêm bấm Ghi thì nó Insert, lúc sửa bấm Ghi thì nó Update"*. `SqlCommandBuilder` quyết định theo `RowState`.

---

### CÂU 3 — KHOA VÀ LỚP CHUNG MỘT FORM (`frmKhoaLop`)

Đề (nguyên văn): *"cho phép luôn là nhập Khoa và nhập Lớp cùng một lúc, trên một cái form"*.

```
Bố cục master–detail:
   Lưới TRÊN  = KHOA   (SELECT MAKH, TENKH, MACS FROM dbo.KHOA)
   Lưới DƯỚI  = LỚP    (SELECT MALOP, TENLOP, MAKH FROM dbo.LOP)
                        lọc theo khoa đang chọn:  bsLop.Filter = "MAKH = '<makh>'"
```

| Nút | Logic |
|---|---|
| **➕ Thêm khoa** | dòng mới, tự gán `MACS` = mã cơ sở của phân mảnh đang đăng nhập (`SELECT TOP 1 MACS FROM dbo.COSO`) |
| **➕ Thêm lớp** | bắt buộc đang chọn 1 khoa → dòng mới tự gán `MAKH` = khoa đó |
| **💾 Ghi** | ghi **KHOA trước, LỚP sau** (vì lớp tham chiếu khoa) |
| **↩ Phục hồi** | huỷ thay đổi chưa ghi của **cả hai** bảng |

---

### CÂU 4 — SINH VIÊN (`frmSinhVien`)

Đề: form này **chỉ nhập sinh viên**, lớp chỉ để **chọn**.

```
SELECT MASV, HO, TEN, NGAYSINH, DIACHI, MALOP, [PASSWORD] FROM dbo.SINHVIEN
Cột MALOP được thay bằng DataGridViewComboBoxColumn
     DataSource = SELECT MALOP, TENLOP FROM dbo.LOP     ← chỉ chọn, không nhập
```

**Điểm quan trọng — đây là chỗ MẢNH 3 phát huy tác dụng:**

```
Bấm [💾 Ghi]
   └─ KiemTraTruocKhiGhi()
        └─ với MỖI dòng thêm mới:
             DataProvider.MaSinhVienDaTonTai(masv)
                └─ Kết nối localhost\SERVER3  bằng login dịch vụ 'tracuu'
                     └─ SELECT COUNT(*) FROM dbo.SINHVIEN WHERE MASV = @m
             ├─ Đã tồn tại → CHẶN, báo "Mã đã tồn tại ở một trong hai cơ sở"
             └─ Chưa       → cho ghi
```

> Mảnh 3 gom Lớp+Sinh viên của **cả hai cơ sở** nên chỉ cần hỏi **một nơi** là biết mã có trùng với cơ sở bạn không — đúng công dụng Thầy mô tả: *"dùng nó để tra cứu mã sinh viên có chưa, mã lớp có chưa"*.

---

### CÂU 5 — GIẢNG VIÊN (`frmGiaoVien`)

Đề: *"chọn Khoa rồi nhập giảng viên vào khoa đó"*.

```
ComboBox Khoa (trên cùng)  →  đổi khoa thì nạp lại lưới
     SELECT MAGV, HO, TEN, MAKH, HOCVI FROM dbo.GIAOVIEN WHERE MAKH = @makh
Nút [➕ Thêm] → dòng mới tự gán MAKH = khoa đang chọn
```

---

### CÂU 6 — BỘ ĐỀ (`frmBoDe`)

Đề: giảng viên đăng nhập thì **tự động chỉ thấy câu hỏi của mình**, chỉ sửa/xóa câu mình soạn.

| Nút | Tham số | Stored Procedure | Logic bên trong |
|---|---|---|---|
| *(mở form / đổi môn)* | `@MAMH` | `sp_Bode_DS` | Nếu là `Giangvien` (và không phải `CoSo`) → `@magv = SUSER_SNAME()` → chỉ trả câu của chính mình |
| **➕ Thêm** → **Ghi câu hỏi** | `@MAMH,@TRINHDO,@NOIDUNG,@A..@D,@DAP_AN` | `sp_Bode_Them` | Tự cấp `CAUHOI` theo **dải riêng từng cơ sở**: CS1 = 1.000.000+, CS2 = 1.500.000+ |
| **✏ Sửa** | thêm `@CAUHOI` | `sp_Bode_Sua` | `WHERE CAUHOI=@CAUHOI AND (@gvHienTai IS NULL OR MAGV=@gvHienTai)` → sửa câu người khác thì `@@ROWCOUNT=0` → báo lỗi |
| **🗑 Xóa** | `@CAUHOI` | `sp_Bode_Xoa` | tương tự, chặn xóa câu người khác |

**Vì sao cấp mã theo dải riêng:** hai cơ sở cùng thêm câu hỏi rồi merge sẽ **đụng khóa chính** nếu dùng `MAX+1` chung. Cấp dải riêng + `SELECT MAX() WITH (UPDLOCK, HOLDLOCK)` trong cùng giao tác với `INSERT` → hai giảng viên bấm Ghi cùng lúc không lấy trùng số.

**Kiểm chứng thực tế:** `TH123` sửa câu của `TH101` → *"Không sửa được: câu hỏi không tồn tại hoặc không do bạn soạn"*.

---

### CÂU 7 — CHUẨN BỊ THI (`frmChuanBiThi`)

```
Bấm [Đăng ký kỳ thi]
   └─ EXEC dbo.sp_ChuanBiThi
        @MAGV, @MALOP, @MAMH, @TRINHDO, @LAN, @SOCAUTHI, @NGAYTHI, @THOIGIAN
```

**Chuỗi kiểm tra bên trong SP (theo thứ tự):**

```
1. @TRINHDO ∈ {A,B,C}        · @LAN ∈ {1,2}          ← hệ niên chế: tối đa 2 lần
   @SOCAUTHI 10..100          · @THOIGIAN 2..60 phút
2. Lớp / Môn / Giáo viên có tồn tại tại phân mảnh này không
3. Giáo viên và lớp phải CÙNG MỘT CƠ SỞ
      Lop → Khoa(kl) ; Giaovien → Khoa(kg) ; yêu cầu kg.MACS = kl.MACS
4. Chưa đăng ký trùng (MALOP + MAMH + LAN)
5. Lần 2 chỉ đăng ký được khi đã có lần 1
6. ★ KIỂM TRA ĐỦ ĐỀ:
      @canToiThieu = @SOCAUTHI - FLOOR(@SOCAUTHI * 0.30)      (tức 70%)
      @coLocal = COUNT(*) FROM dbo.Bode      WHERE MAMH,TRINHDO
      @coMuon  = COUNT(*) FROM dbo.Bode_Muon WHERE MAMH,TRINHDO AND MACS <> @MACS
      Nếu (@coLocal + @coMuon) < @canToiThieu → BÁO LỖI CÓ SỐ LIỆU
7. INSERT INTO dbo.Giaovien_Dangky
```

**Thông báo lỗi thật khi kho đề thiếu** (đúng yêu cầu Thầy *"báo lỗi rõ ràng là thiếu bao nhiêu câu"*):

```
Kho đề chưa đủ để đăng ký thi 30 câu trình độ A.
Cần tối thiểu 21 câu, hiện có 0 câu (0 câu tại cơ sở, 0 câu mượn được).
=> CÒN THIẾU 21 CÂU. Đề nghị giáo viên soạn bổ sung trước khi đăng ký.
```

---

### CÂU 8 — THI TRẮC NGHIỆM (`frmThi`) ⭐ trọng tâm

#### B1. Mở form — nạp danh sách môn

```
EXEC dbo.sp_ThongTinThiSinh @MASV      → hiện mã SV, họ tên, mã lớp, tên lớp
EXEC dbo.sp_LichThi         @MASV      → lịch thi của LỚP sinh viên đó
     └─ app LỌC BỎ dòng có dathi = 1
```

> Đề nhấn mạnh: *"cái gì mà ta biết là vô lý thì đừng cho người ta chọn"* → ComboBox **chỉ chứa môn đã đăng ký và chưa thi**, không hiện hết rồi báo lỗi.

#### B2. Bấm **[Bắt đầu thi]** → lấy đề

```
EXEC dbo.sp_LayDeThi @MASV, @MAMH, @LAN, @DungLaiDeLanTruoc, @ThiThu, @MALOP_ThiThu
```

**Chuỗi xử lý trong SP:**

```
1. Xác định LỚP và CƠ SỞ CỦA LỚP
      Sinhvien → Lop → Khoa → @MACS        ← ưu tiên theo LỚP, KHÔNG theo giảng viên
2. Đọc thông số kỳ thi từ Giaovien_Dangky  → @TD, @SOCAU, @TG, @NGAYTHI
3. Ràng buộc (chỉ áp cho thi thật):
      · Phải đúng NGÀY THI đã đăng ký
      · Đã có điểm rồi thì không phát đề lại
      · Phiếu cũ quá hạn chưa nộp → tự kết thúc, ghi 0 điểm
4. Phiếu còn hiệu lực → TRẢ LẠI ĐÚNG PHIẾU CŨ (mở lại không đổi bộ đề)
5. ★ CHỌN CÂU HỎI vào bảng tạm #De(CAUHOI, NGUON):
      (6a) Đúng trình độ, kho CƠ SỞ CỦA LỚP     → NGUON='LOCAL'   [ưu tiên 1]
      (6b) Thiếu → mượn CƠ SỞ CÒN LẠI            → NGUON='MUON'    [ưu tiên 2]
             FROM dbo.Bode_Muon WHERE MACS <> @MACS
      (6c) Vẫn thiếu → HẠ ĐÚNG 1 BẬC (A→B, B→C), tổng phần hạ ≤ 30%
      (6d) Không đủ → BÁO LỖI, tuyệt đối không phát đề thiếu
6. Ghi PhieuThi + PhieuThi_CauHoi  (giao tác)
      STT = ROW_NUMBER() OVER (ORDER BY NEWID())    ← xáo trộn câu hỏi
7. Trả về 2 result set:
      [0] maphieu, socau, thoigian, batdau, hannop, sogiayconlai
      [1] stt, cauhoi, nguon, noidung, a, b, c, d
          ↑ CỐ Ý KHÔNG TRẢ DAP_AN — đáp án chỉ tồn tại phía server
```

**Kiểm chứng thực tế** (lớp TH05 của CS1, thi 100 câu trình độ A):

```
Kho CS1 trình độ A : 94 câu   →  94 câu NGUON='LOCAL'
Kho mượn từ CS2    : 16 câu   →   6 câu NGUON='MUON'
                                 ────────────────────
                                 100 câu
```

#### B3. Đồng hồ đếm ngược

```
_giayConLai = phieu["sogiayconlai"]      ← lấy TỪ SERVER, không tin đồng hồ máy trạm
Timer 1 giây → _giayConLai--
     · còn ≤ 60 giây  → đồng hồ chuyển ĐỎ
     · về 0           → TỰ ĐỘNG gọi NopBai(tuDong: true)
```

> Đề: *"thời gian tính cho sinh viên là khi nào đã lấy đủ đề mang về máy rồi thì bắt đầu tính"* và *"hết giờ thì tự động ngắt chương trình, chấm điểm luôn, đừng bắt người dùng phải click"*.

#### B4. Bấm **[NỘP BÀI]** (hoặc tự động khi hết giờ)

```
App gom đáp án thành JSON:  [{"STT":1,"DACHON":"A"},{"STT":2,"DACHON":"C"}, ...]
EXEC dbo.sp_NopBai @MASV, @MAPHIEU, @DapAn, @GhiDiem

Bên trong SP:
   1. Kiểm phiếu thuộc về mình, chưa nộp
   2. @THITHU lấy TỪ PHIẾU Ở SERVER → nếu 1 thì ép @GhiDiem = 0
        ↑ client KHÔNG thể biến bài thật thành thi thử hay ngược lại
   3. Trễ hạn quá 60 giây ân hạn → @TREHAN = 1, không nhận đáp án (0 điểm)
   4. CHẤM: OPENJSON(@DapAn) JOIN PhieuThi_CauHoi ON STT
              WHERE b.DACHON = q.DAP_AN          ← đối chiếu đáp án LƯU Ở SERVER
        DIEM = SoCauDung * 10.0 / SOCAU          ← thang 10, mọi câu điểm bằng nhau
   5. Nếu @GhiDiem = 0 (thi thử) → chỉ trả điểm, KHÔNG ghi BangDiem
   6. Ngược lại, trong giao tác SERIALIZABLE:
        · UPDATE/INSERT dbo.BangDiem
        · Ghi lại toàn bộ bài làm vào dbo.ChiTiet_BaiThi  (phục vụ câu 9)
        · UPDATE dbo.PhieuThi SET DANOP = 1
   7. Trả: DIEM, SoCauDung, SoCauThi, TreHan
```

---

### CÂU 9 — XEM LẠI BÀI THI (`frmXemKetQua`)

```
Bấm [Xem lại bài]
   └─ EXEC dbo.sp_XemKetQua @MASV, @MAMH, @LAN
        Result set [0] — phần đầu báo cáo:
             Lop | HoTen | MonThi | NgayThi | LanThi | Diem
        Result set [1] — chi tiết từng câu:
             STT | CauSo | NOIDUNG | A | B | C | D | DapAn | DaChon | KetQua
                              ↑ mã câu trong bộ đề    ↑ đáp án đúng  ↑ SV đã chọn
```

Lưới tô màu: **xanh = đúng**, **đỏ = sai**, **xám = bỏ trống** → giảng viên nhìn ra ngay khi phúc khảo.

---

### CÂU 10 — BẢNG ĐIỂM MÔN HỌC (`frmBangDiem`)

```
ComboBox chỉ liệt kê các kỳ thi ĐÃ ĐĂNG KÝ (không bắt gõ tay rồi báo lỗi)
Bấm [Xem bảng điểm]
   └─ EXEC dbo.sp_BangDiemMonHoc @MALOP, @MAMH, @LAN   ← đúng khóa chính bảng đăng ký
        SELECT TENLOP, TENMH, LAN, MASV, HOTEN,
               DIEM    = ROUND(bd.DIEM * 2, 0) / 2       ← LÀM TRÒN 0.5
               DIEMCHU = CASE trên ĐIỂM ĐÃ LÀM TRÒN
                           >= 8.5 → A ; >= 7.0 → B ; >= 5.5 → C ; >= 4.0 → D ; còn lại F
Nút [In] → xuất CSV để in
```

> Đề: *"lấy một số lẻ, làm tròn đến 0.5"* — chỉ được ra 5 / 5.5 / 6, **không có 2.25**. Điểm chữ tính **từ điểm đã làm tròn** để hai cột không mâu thuẫn nhau.

---

### CÂU 11 — ĐĂNG KÝ THI CẢ HAI CƠ SỞ (`frmBaoCaoDangKy`)

**Ràng buộc nặng nhất của đề** — Thầy nhắc 2 lần: *"riêng câu 11 này KHÔNG được về server chủ, bắt buộc phải trên 2 phân mảnh… dùng phép UNION"*.

```
Bấm [Xem báo cáo]  (từ ngày → đến ngày)
   └─ DataProvider.BaoCaoDangKy_HaiCoSo(tuNgay, denNgay)
        └─ Duyệt từng phân mảnh trong V_DS_PHANMANH (đã bỏ mảnh tra cứu):
             ├─ Kết nối localhost\SERVER1 → EXEC sp_BaoCao_DangKy @tungay,@denngay
             └─ Kết nối localhost\SERVER2 → EXEC sp_BaoCao_DangKy @tungay,@denngay
        └─ UNION: gộp các dòng vào một DataTable chung
        └─ Sắp xếp theo MACS, NGAYTHI
   ✗ KHÔNG mở bất kỳ kết nối nào tới PUBLISHER
```

Màn hình in rõ nguồn dữ liệu để chứng minh khi bảo vệ:

```
Nguồn dữ liệu (UNION từ các PHÂN MẢNH, không qua server chủ):
    Co so 1 (…\SERVER1): 3 dòng    |    Co so 2 (…\SERVER2): 2 dòng
```

Cột: cơ sở · lớp · môn · giảng viên · trình độ · số câu · phút · ngày thi · lần · **ĐÃ THI (X)** · ghi chú.

Cột ghi chú suy từ trạng thái thật: *Đã thi xong / Đang thi dở (2/8) / Quá hạn chưa thi / Chưa tới ngày thi*.

---

## PHẦN C — KẾT QUẢ RÀ SOÁT

### C1. Lỗ hổng PHÁT HIỆN VÀ ĐÃ VÁ trong lần rà soát này

| # | Lỗ hổng | Đối chiếu đề | Đã xử lý |
|---|---|---|---|
| 1 | **Giảng viên không vào được màn hình thi** — menu chỉ mở cho sinh viên | Đề: *"giảng viên được quyền thi thử nhưng không ghi điểm"*. SP đã có cờ `@ThiThu` nhưng **không có đường vào** | Mở menu cho giảng viên, đổi nhãn thành *"Thi thử (không ghi điểm)"*, truyền `@ThiThu=1` + `@MALOP_ThiThu` |
| 2 | **Trưởng thiếu quyền `sp_XemKetQua`** | Đề: *"3 báo cáo là được quyền chạy hết"* — Trưởng chỉ chạy được 2 | `GRANT EXECUTE` cho `Truong` |
| 3 | **Trưởng không thấy menu Bảng điểm (câu 10)** | như trên | Mở menu `mnuBangDiem` cho Trưởng |
| 4 | **Giảng viên thiếu quyền `sp_ThongTinThiSinh`** | cần cho màn hình thi thử | `GRANT EXECUTE` cho `Giangvien` và `CoSo` |

Script: `SQL/09_VaLoHongPhanQuyen.sql`

### C2. Còn tồn — cần bạn quyết

| # | Vấn đề | Mức độ | Ghi chú |
|---|---|---|---|
| 1 | **`SP_LayThongTinNguoiDung` chưa là Article** | Nhỏ | Thầy dặn *"định nghĩa sp này là 1 Article trên các phân mảnh"*. Hiện deploy trực tiếp lên từng server nên **chạy đúng**, chỉ khác cách triển khai |
| 2 | **`V_DS_PHANMANH` đọc bằng Integrated Security** | Vừa | Chạy tốt trên máy này. Đem sang máy khác mà tài khoản Windows không có quyền trên publisher thì ComboBox rơi về danh sách dự phòng cứng trong `AppConfig` |
| 3 | **`sp_MoLaiBaiThi` / `sp_ThoiGianConLai` chưa được app gọi** | Nhỏ | Phục vụ option *"khôi phục bài thi khi cúp điện"*. SP có sẵn, hạ tầng có sẵn (`PhieuThi.BATDAU/HANNOP/DANOP`), chỉ thiếu nút bấm. **Là option cộng điểm, không bắt buộc** |
| 4 | **Trưởng chưa xem được danh mục của cơ sở** | Vừa | Đề: *"đăng nhập vào bất kỳ phân mảnh nào để có thể xem… xem thôi"*. Hiện Trưởng chỉ có Tra cứu + Báo cáo. Nếu Thầy hỏi "xem dữ liệu cơ sở" thì nên mở các form danh mục ở chế độ **chỉ đọc** cho Trưởng |
| 5 | **Đảo đáp án A/B/C/D khi ra đề** | Option | Thầy gợi ý cộng điểm. Chưa làm |
| 6 | **`PhieuThi_CauHoi` lưu lặp nội dung câu hỏi** | Cần lý lẽ | Xem phần D |

### C3. Đã đạt — không cần sửa

| Yêu cầu của đề | Trạng thái |
|---|---|
| 3 mảnh: 2 ngang giống nhau + 1 mảnh dọc | ✅ |
| Cây dẫn xuất `COSO→KHOA→LOP→{GIAOVIEN_DANGKY, SINHVIEN→BANGDIEM}` | ✅ khớp cây mẫu |
| Mảnh 3 chỉ trích cột cần thiết, không cho đăng nhập | ✅ |
| Có ít nhất 1 chức năng dùng mảnh 3 | ✅ chống trùng mã ở câu 4 + màn Tra cứu |
| 2 cách đăng nhập khác nhau | ✅ |
| Trưởng chỉ tạo tài khoản nhóm Trưởng; Cơ sở tạo CoSo + Giảng viên | ✅ |
| Khoa + Lớp chung một form | ✅ |
| Giảng viên chỉ sửa/xóa câu hỏi của mình | ✅ ép ở tầng CSDL |
| Kiểm đủ đề khi đăng ký + báo thiếu bao nhiêu câu | ✅ |
| Câu 8 dùng Stored Procedure | ✅ |
| Ưu tiên đề theo **cơ sở của LỚP** | ✅ |
| Quy tắc 70/30 trình độ, hạ đúng 1 bậc | ✅ |
| Chỉ hiện môn đã đăng ký & chưa thi | ✅ |
| Hết giờ tự động chấm | ✅ |
| Đáp án không gửi về máy trạm | ✅ |
| Làm tròn 0.5 + điểm chữ | ✅ |
| Câu 11 UNION 2 phân mảnh, không qua máy chủ | ✅ |
| Bộ nút Thêm/Sửa/Xóa/Ghi/Phục hồi | ✅ |
| Undo nhiều cấp bằng Stack | ✅ (option) |
| Sao lưu / phục hồi dữ liệu | ✅ |

---

## PHẦN D — CHUẨN BỊ TRẢ LỜI KHI BẢO VỆ

**Câu hỏi có khả năng bị hỏi nhất:** *"Bảng `PhieuThi_CauHoi` lưu lại cả nội dung câu hỏi, có phải dư thừa / vi phạm dạng chuẩn không?"*

Trả lời theo 2 ý:

1. **Đây là ảnh chụp đề tại thời điểm thi.** Giảng viên có quyền sửa hoặc xóa câu hỏi sau kỳ thi. Nếu chỉ lưu khóa `CAUHOI` thì khi in lại bài cũ (câu 9 — phúc khảo) sẽ ra nội dung **đã bị thay đổi**, không còn phản ánh đúng bài sinh viên đã làm.

2. **Câu mượn của cơ sở khác không join ngược được.** Với dòng có `NGUON = 'MUON'`, câu hỏi gốc nằm ở `BODE` của **cơ sở kia**, không tồn tại trong phân mảnh này. Không lưu nội dung thì mất hẳn dữ liệu.

Khóa chính `(MAPHIEU, STT)` — `STT` định danh vị trí câu trong phiếu, `CAUHOI` chỉ là thuộc tính tham chiếu. Chính cách đặt khóa này cho phép một phiếu chứa đồng thời **câu số 5 của cơ sở mình** và **câu số 5 mượn được** (dữ liệu cũ của hai cơ sở dùng chung dải mã 1..259 nên trùng nhau hoàn toàn).

---

## PHẦN E — BẢNG TRA NHANH: NÚT → SP → BẢNG

| Form | Nút | Stored Procedure | Bảng tác động |
|---|---|---|---|
| Đăng nhập | Đăng nhập | `SP_LayThongTinNguoiDung` / `sp_DangNhap_SV` | `sys.sysusers`, `GIAOVIEN` / `SINHVIEN`, `LOP` |
| Tài khoản | Tạo tài khoản | `SP_TAOLOGIN` | login + user + role |
| Tài khoản | Đổi mật khẩu | `SP_DOIMATKHAU` / `sp_DoiMatKhau_SV` | login / `SINHVIEN` |
| Môn học | Ghi | *(không SP)* | `MONHOC` |
| Khoa & Lớp | Ghi | *(không SP)* | `KHOA`, `LOP` |
| Sinh viên | Ghi | *(không SP)* + tra mảnh 3 | `SINHVIEN` |
| Giáo viên | Ghi | *(không SP)* | `GIAOVIEN` |
| Bộ đề | Thêm/Sửa/Xóa | `sp_Bode_Them/Sua/Xoa/DS` | `BODE` |
| Chuẩn bị thi | Đăng ký kỳ thi | `sp_ChuanBiThi` | `GIAOVIEN_DANGKY` (đọc `BODE`, `Bode_Muon`) |
| Thi | Bắt đầu thi | `sp_LayDeThi` | `PhieuThi`, `PhieuThi_CauHoi` |
| Thi | Nộp bài | `sp_NopBai` | `BANGDIEM`, `ChiTiet_BaiThi`, `PhieuThi` |
| Xem lại bài | Xem lại bài | `sp_XemKetQua` | `ChiTiet_BaiThi`, `BANGDIEM` |
| Bảng điểm | Xem bảng điểm | `sp_BangDiemMonHoc` | `BANGDIEM`, `SINHVIEN`, `LOP`, `MONHOC` |
| Đăng ký 2 cơ sở | Xem báo cáo | `sp_BaoCao_DangKy` × 2 phân mảnh | `GIAOVIEN_DANGKY`, `LOP`, `KHOA`, `COSO` |
| Tra cứu | Tra cứu / Mã đã tồn tại chưa | *(không SP)* | `SINHVIEN`, `LOP` **trên SERVER3** |
| Sao lưu | Sao lưu ngay | `SP_SAOLUU` | `BACKUP DATABASE` + `NhatKy_SaoLuu` |
