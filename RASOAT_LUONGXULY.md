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
| *(mở form)* — đổ ô **Môn học** | *(không có)* | `sp_DS_MonHoc_SoanDe` | Giảng viên chỉ thấy **môn mình được phân công dạy**; `CoSo`/`Truong` thấy đủ môn |
| *(mở form / đổi môn)* | `@MAMH` | `sp_Bode_DS` | Nếu là `Giangvien` (và không phải `CoSo`) → `@magv = SUSER_SNAME()` → chỉ trả câu của chính mình |
| **➕ Thêm** → **Ghi câu hỏi** | `@MAMH,@TRINHDO,@NOIDUNG,@A..@D,@DAP_AN` | `sp_Bode_Them` | Tự cấp `CAUHOI` theo **dải riêng từng cơ sở**: CS1 = 1.000.000+, CS2 = 1.500.000+ |
| **✏ Sửa** | thêm `@CAUHOI` | `sp_Bode_Sua` | `WHERE CAUHOI=@CAUHOI AND (@gvHienTai IS NULL OR MAGV=@gvHienTai)` → sửa câu người khác thì `@@ROWCOUNT=0` → báo lỗi |
| **🗑 Xóa** | `@CAUHOI` | `sp_Bode_Xoa` | tương tự, chặn xóa câu người khác |

**Vì sao cấp mã theo dải riêng:** hai cơ sở cùng thêm câu hỏi rồi merge sẽ **đụng khóa chính** nếu dùng `MAX+1` chung. Cấp dải riêng + `SELECT MAX() WITH (UPDLOCK, HOLDLOCK)` trong cùng giao tác với `INSERT` → hai giảng viên bấm Ghi cùng lúc không lấy trùng số.

**Kiểm chứng thực tế:** `TH123` sửa câu của `TH101` → *"Không sửa được: câu hỏi không tồn tại hoặc không do bạn soạn"*.

#### Ô chọn môn học: chỉ hiện môn giảng viên dạy

Ban đầu ô này đổ **toàn bộ** `MONHOC`, nên `TH657` (chỉ dạy `MMTCB`) vẫn chọn được Giải tích, Anh văn rồi soạn đề cho môn mình không dạy.

Schema của thầy **không có bảng phân công giảng dạy riêng** — `GIAOVIEN` chỉ gắn với `KHOA`, `MONHOC` không gắn với ai. Nơi duy nhất ghi cặp *(giáo viên, môn học)* là `GIAOVIEN_DANGKY(MAGV, MAMH, MALOP, …)`, đúng như tên bảng.

**Việc phân công là của nhóm `CoSo`**, giảng viên không tự mở rộng danh sách môn của mình. Vì vậy `sp_DS_MonHoc_SoanDe` (`SQL/16_SP_MonGiangDay.sql`) **không có tham số nào** để ứng dụng nới danh sách ra, và màn Soạn bộ đề không có ô tick nào để lách. Danh sách môn lấy từ **hợp của hai nguồn**:

| Nguồn | Ý nghĩa |
|---|---|
| `GIAOVIEN_DANGKY` | môn được Cơ sở phân công |
| `BODE` | môn giảng viên **đã có** đề |

Nguồn thứ hai không phải cửa hậu — nó không mở thêm môn mới, chỉ giữ lại thứ giảng viên đã sở hữu. Cần thiết vì dữ liệu thật đang có trường hợp đó: `TH123` có **158 câu `MMTCB` nhưng không có dòng nào trong `GIAOVIEN_DANGKY`**; lọc thuần theo bảng đăng ký thì thầy ấy mất trắng lối vào 158 câu do chính mình soạn.

**Kiểm chứng thực tế** (`EXECUTE AS LOGIN`, vì SP nhận diện người dùng bằng `SUSER_SNAME()`):

| Login | Dữ liệu | Trước | Sau |
|---|---|---|---|
| `TH657` (CS2) | đăng ký `MMTCB`, có 40 câu | 6 môn | **1 môn** |
| `TH101` (CS1) | đăng ký `AVCB`+`MMTCB`, **chưa soạn đề** | 6 môn | **2 môn** ← nguồn `GIAOVIEN_DANGKY` chạy |
| `TH123` (CS1) | **không đăng ký**, có 158 câu `MMTCB` | 6 môn | **1 môn** ← nguồn `BODE` chạy |
| `coso1` / `coso2` | nhóm `CoSo` | 6 môn | **6 môn** (giữ nguyên) |

Việc phân công được làm ở màn riêng — xem mục ngay dưới đây.

---

### PHÂN CÔNG GIẢNG DẠY (`frmPhanCong`) — làm TRƯỚC câu 7

Bảng `GIAOVIEN_DANGKY` đang gánh **hai việc khác nhau**: *phân công dạy* (giáo viên X dạy môn M cho lớp L) và *đăng ký kỳ thi* (ngày thi, trình độ, số câu, thời gian). Nhưng chỉ có `sp_ChuanBiThi` ghi vào nó, mà thủ tục đó lại từ chối khi kho đề chưa đủ 70% số câu thi. Với một môn **hoàn toàn mới**: Cơ sở không phân công được, giảng viên cũng không soạn được đề vì chưa được phân công → **khoá chết**.

**Cách tách — không đổi schema của thầy.** Dùng chính cột đã có làm dấu hiệu:

| Dấu hiệu | Ý nghĩa |
|---|---|
| `SOCAUTHI IS NULL` | dòng **phân công**, chưa đăng ký thi |
| `SOCAUTHI IS NOT NULL` | dòng **đăng ký kỳ thi** đầy đủ |

Dòng phân công để trống cả `TRINHDO`, `SOCAUTHI`, `THOIGIAN`. Việc `TRINHDO` để `NULL` có tác dụng phụ rất tốt: `sp_LayDeThi` **vốn đã** có sẵn `IF @TD IS NULL RAISERROR(N'Lớp chưa được đăng ký thi môn/lần này.')`, nên sinh viên không thể vào thi một dòng mới phân công — không phải sửa gì thêm ở đó.

**Quy trình mới, ba bước:**

```
1. Cơ sở      → Thi ▸ Phân công giảng dạy  → sp_PhanCong_Them
                (KHÔNG kiểm tra kho đề — đây là chỗ gỡ khoá chết)
2. Giảng viên → Danh mục ▸ Bộ đề           → môn vừa phân công đã hiện ra
3. Giảng viên → Thi ▸ Chuẩn bị thi         → sp_ChuanBiThi
                (kiểm tra kho đề như cũ, rồi ĐIỀN TIẾP vào dòng đã có)
```

| Nút | Tham số | Stored Procedure | Logic |
|---|---|---|---|
| *(mở form)* | — | `sp_PhanCong_DS` | Kèm cột `TRANGTHAI` và `XOADUOC` để ứng dụng khoá nút cho đúng |
| **Phân công** | `@MAGV, @MAMH, @MALOP` | `sp_PhanCong_Them` | `IS_MEMBER('CoSo')`; GV và lớp phải cùng cơ sở; ghi `LAN=1` với `SOCAUTHI=NULL` |
| **Bỏ phân công** | `@MAMH, @MALOP` | `sp_PhanCong_Xoa` | Chỉ xoá được khi **chưa** đăng ký kỳ thi |

**Ba thủ tục phải sửa theo** (`SQL/17_TachPhanCong_DangKyThi.sql`) — nếu quên thì mỗi lần phân công sẽ đẻ ra một "kỳ thi" giả:

| Thủ tục | Sửa gì |
|---|---|
| `sp_ChuanBiThi` | `UPDATE` dòng phân công thay vì `INSERT` dòng mới |
| `sp_LichThi` | thêm `AND dk.SOCAUTHI IS NOT NULL` — sinh viên không thấy dòng mới phân công |
| `sp_BaoCao_DangKy` | thêm `WHERE dk.SOCAUTHI IS NOT NULL` — câu 11 chỉ đếm kỳ thi thật |

**Kiểm chứng thực tế** (chạy trong `BEGIN TRAN … ROLLBACK`, không để lại dữ liệu):

| Tình huống | Kết quả |
|---|---|
| `TH657` đăng ký thi môn `CSDL` chưa được phân công | *"Lớp/môn này chưa được Cơ sở phân công giảng dạy…"* |
| `TH657` tự gọi `sp_PhanCong_Them` | *"EXECUTE permission was denied"* — không cấp cho `Giangvien` |
| `coso2` phân công `TH657` dạy `CSDL`/`VT04` | thành công → `TH657` thấy ngay `CSDL` ở màn Bộ đề |
| dòng phân công đó trong lịch thi của SV / báo cáo câu 11 | **không xuất hiện** ở cả hai |
| đăng ký thi khi kho đề `CSDL` còn trống | *"CÒN THIẾU 7 CÂU…"* — luật cũ vẫn nguyên |
| soạn 8 câu rồi đăng ký lần 1 | thành công, `GIAOVIEN_DANGKY` vẫn **1 dòng duy nhất** (UPDATE, không nhân đôi) |
| bỏ phân công sau khi đã đăng ký thi | *"…đã đăng ký kỳ thi - không bỏ phân công được."* |
| `TH123` đăng ký kỳ thi cho lớp/môn của `TH101` | *"Lớp/môn này được phân công cho KIEU DAC THIEN…"* |
| `TH101` đăng ký **lần 2** (lần 1 đã có) | thành công → thêm dòng `LAN=2`, thừa hưởng giáo viên của lần 1 |
| `truong01` gọi `sp_PhanCong_Xoa` | bị chặn; nhưng `sp_PhanCong_DS` thì xem được |

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
4. Chưa đăng ký trùng — tức đã có dòng và SOCAUTHI IS NOT NULL
5. LAN=1 : BẮT BUỘC đã có dòng phân công của Cơ sở
   LAN=2 : bắt buộc lần 1 đã đăng ký xong, và thừa hưởng giáo viên của lần 1
6. Người đăng ký phải ĐÚNG là người được phân công
7. ★ KIỂM TRA ĐỦ ĐỀ:
      @canToiThieu = @SOCAUTHI - FLOOR(@SOCAUTHI * 0.30)      (tức 70%)
      @coLocal = COUNT(*) FROM dbo.Bode      WHERE MAMH,TRINHDO
      @coMuon  = COUNT(*) FROM dbo.Bode_Muon WHERE MAMH,TRINHDO AND MACS <> @MACS
      Nếu (@coLocal + @coMuon) < @canToiThieu → BÁO LỖI CÓ SỐ LIỆU
8. LAN=1 → UPDATE dòng phân công (điền TRINHDO/NGAYTHI/SOCAUTHI/THOIGIAN)
   LAN=2 → INSERT dòng mới
```

> Bước 4–6 và 8 là phần đã đổi khi **tách phân công khỏi đăng ký thi** — xem mục *Phân công giảng dạy* ở trên.

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
| 3 | **`sp_MoLaiBaiThi` / `sp_ThoiGianConLai` chưa được app gọi** | Nhỏ | Phục vụ option *"khôi phục bài thi khi cúp điện"*. SP có sẵn, hạ tầng có sẵn (`PhieuThi.BATDAU/HANNOP/DANOP`), chỉ thiếu nút bấm. **Là option cộng điểm, không bắt buộc**.<br>⚠️ Riêng `sp_MoLaiBaiThi` từng là **lỗ hổng bảo mật** — đã vá, xem PHẦN G mục G6 |
| 4 | ~~Trưởng chưa xem được danh mục của cơ sở~~ | ✅ **ĐÃ XONG** | Xem mục C4 bên dưới |
| 5 | **Đảo đáp án A/B/C/D khi ra đề** | Option | Thầy gợi ý cộng điểm. Chưa làm |
| 6 | **`PhieuThi_CauHoi` lưu lặp nội dung câu hỏi** | Cần lý lẽ | Xem phần D |

### C4. Nhóm Trưởng — chế độ CHỈ XEM (đã bổ sung)

Đề: *"nhóm trưởng được quyền đăng nhập vào bất kỳ phân mảnh nào để có thể **xem**… xem thôi, không được quyền thêm xóa sửa"* và *"khi đăng nhập một cơ sở đó thì chỉ được xem dữ liệu của cơ sở đó"*.

**Chặn ở hai tầng — tầng CSDL là tầng thật:**

```
1. TẦNG CSDL  (SQL/10_Truong_ChiXem.sql)  ← đây mới là ràng buộc thật
      GRANT SELECT ON DATABASE::TN_CSDLPT TO [Truong]     (đã có từ bước 02)
      GRANT EXECUTE ON dbo.sp_Bode_DS     TO [Truong]     ← bổ sung, để xem bộ đề
      DENY INSERT, UPDATE, DELETE trên MỌI bảng TO [Truong]

   Dùng DENY chứ không chỉ "không GRANT": DENY mạnh hơn GRANT nên
   sau này lỡ ai cấp nhầm quyền ghi cho nhóm Trưởng thì vẫn bị chặn.

2. TẦNG GIAO DIỆN  (Phien.ChiXem)          ← chỉ để khỏi bấm nhầm
      frmCrudBase  : tự khoá Thêm/Xóa/Ghi/Phục hồi + hiện băng vàng nhắc
      frmKhoaLop   : khoá 5 nút, hai lưới chuyển ReadOnly
      frmBoDe      : khoá nút; ô nội dung để ReadOnly (vẫn ĐỌC được chữ,
                     khác với Disabled sẽ làm chữ mờ khó đọc)
      frmMain      : mở menu Danh mục, đổi nhãn "Danh mục (chỉ xem)"
```

**Kiểm chứng bằng chính tài khoản `truong01`:**

| Thao tác | Kết quả |
|---|---|
| `SELECT` MONHOC / KHOA / LOP / SINHVIEN / GIAOVIEN | ✅ đọc được |
| `EXEC sp_Bode_DS` | ✅ thấy toàn bộ câu hỏi của phân mảnh |
| `INSERT INTO MONHOC` | ✅ **bị chặn** — *The INSERT permission was denied* |
| `UPDATE SINHVIEN` | ✅ **bị chặn** — *The UPDATE permission was denied* |

> Ghi chú về `sp_Bode_DS`: bên trong SP, biến `@magv` chỉ được gán khi người gọi thuộc nhóm `Giangvien`. Với Trưởng thì `@magv = NULL` nên trả về **toàn bộ** câu hỏi — đúng ý "xem dữ liệu của cơ sở đó", không bị lọc nhầm thành "đề của chính mình".

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
| Bộ đề | *(mở form)* | `sp_DS_MonHoc_SoanDe` | `MONHOC`, `GIAOVIEN_DANGKY`, `BODE` |
| Bộ đề | Thêm/Sửa/Xóa | `sp_Bode_Them/Sua/Xoa/DS` | `BODE` **và `Bode_Muon`** |
| Phân công giảng dạy | Phân công / Bỏ phân công | `sp_PhanCong_DS/Them/Xoa` | `GIAOVIEN_DANGKY` |
| Chuẩn bị thi | Đăng ký kỳ thi | `sp_ChuanBiThi` | `GIAOVIEN_DANGKY` (đọc `BODE`, `Bode_Muon`) |
| Thi | Bắt đầu thi | `sp_LayDeThi` | `PhieuThi`, `PhieuThi_CauHoi` |
| Thi | Nộp bài | `sp_NopBai` | `BANGDIEM`, `ChiTiet_BaiThi`, `PhieuThi` |
| Xem lại bài | Xem lại bài | `sp_XemKetQua` | `ChiTiet_BaiThi`, `BANGDIEM` |
| Bảng điểm | Xem bảng điểm | `sp_BangDiemMonHoc` | `BANGDIEM`, `SINHVIEN`, `LOP`, `MONHOC` |
| Đăng ký 2 cơ sở | Xem báo cáo | `sp_BaoCao_DangKy` × 2 phân mảnh | `GIAOVIEN_DANGKY`, `LOP`, `KHOA`, `COSO` |
| Tra cứu | Tra cứu / Mã đã tồn tại chưa | *(không SP)* | `SINHVIEN`, `LOP` **trên SERVER3** |
| Sao lưu | Sao lưu ngay | `SP_SAOLUU` | `BACKUP DATABASE` + `NhatKy_SaoLuu` |

---

## PHẦN F — CASE TEST TOÀN TUYẾN

Script: **`SQL/CaseTest_ToanTuyen.ps1`** — chạy thật trên cả 4 instance, không mô phỏng.

```bash
powershell -ExecutionPolicy Bypass -File SQL\CaseTest_ToanTuyen.ps1
```

Script **idempotent**: bước 0 tự dọn dữ liệu test của lần trước rồi làm lại từ đầu, nên chạy bao nhiêu lần cũng được.

### F1. Kịch bản

| Bước | Ai làm | Việc |
|---|---|---|
| 1 | `coso1` | Tạo môn `KTLT`, lớp `TH99`, giáo viên `TH999`, tài khoản `TH999`, **phân công** `TH999` dạy `KTLT` cho `TH99` |
| 2 | `coso1` | Thêm sinh viên `SV999001` vào `TH99` (mật khẩu mặc định `123`) |
| 3 | `TH657` (CS2) | Soạn 4 câu `KTLT` → kho cho CS1 mượn |
| 3 | `TH999` (CS1) | Soạn 13 câu: **8 trình độ A + 3 B + 2 C**, đáp án rải đều **A/B/C/D** |
| 4 | `SV999001` | Vào thi → nộp bài (cố ý đúng 7/10) → nhận điểm |
| 5 | `TH999` | Bảng điểm (câu 10) + phúc khảo (câu 9) |
| 6 | `truong01` | Báo cáo đăng ký (câu 11) + tra cứu mảnh dọc `SERVER3` |

**Hai chi tiết kỹ thuật đáng nhớ khi tự chạy lại bằng tay:**

- `SP_TAOLOGIN` xét quyền bằng `ORIGINAL_LOGIN()` — tức **login mở kết nối**, không phải ngữ cảnh hiện tại. Mượn ngữ cảnh bằng `EXECUTE AS LOGIN='coso1'` sẽ **không qua được**, phải đăng nhập thật (`sqlcmd -U coso1`). Các SP còn lại dùng `SUSER_SNAME()`/`IS_MEMBER()` nên `EXECUTE AS` là đủ.
- Merge agent của hệ thống này chạy **liên tục** (continuous). Không "khởi động rồi chờ chạy xong" được vì `stop_execution_date` vĩnh viễn `NULL` — phải chờ theo **dữ liệu đã tới đích hay chưa**.

### F2. Kết quả — 17/17 bước đạt

| # | Bước | Kết quả |
|---|---|---|
| 4 | Tạo môn/lớp/GV/tài khoản + phân công | ✅ dòng phân công có `SOCAUTHI = NULL` đúng như thiết kế |
| 5 | `TH999` chỉ thấy **1 môn** (`KTLT`) ở màn Bộ đề | ✅ |
| 5 | `TH999` đăng ký thi môn chưa phân công | ✅ **chặn** — *"chưa được Cơ sở phân công giảng dạy"* |
| 6 | Sinh viên mới đăng nhập bằng `MASV` + mật khẩu | ✅ |
| 10 | Đăng ký thi khi kho đề trống | ✅ **chặn** — *"CÒN THIẾU 21 CÂU"* |
| 10 | Soạn 13 câu, đủ `A/B/C`, đáp án `A,B,C,D,A,B,C,D` | ✅ |
| 10 | `TH123` sửa đề của `TH999` | ✅ **chặn** — *"không do bạn soạn"* |
| 10 | Đăng ký 10 câu trình độ A | ✅ `GIAOVIEN_DANGKY` vẫn **1 dòng** — UPDATE chứ không nhân đôi |
| 11 | Phát đề → nộp bài đúng 7/10 | ✅ điểm **7.0** đúng tuyệt đối |
| 11 | Thi lại lần 1 khi đã có điểm | ✅ **chặn** |
| 12 | Bảng điểm câu 10 | ✅ `7.0` → điểm chữ `B` |
| 12 | Phúc khảo: chọn lớp → chọn SV → xem từng câu | ✅ 7 *Đúng* + 3 *Sai*, khớp điểm |
| 12 | Sinh viên xem bài **của mình** | ✅ được |
| 12 | Sinh viên liệt kê **bạn cùng lớp** | ✅ **chặn** — không cấp `sp_DS_SinhVien_CoBaiThi` cho `Sinhvien` |
| 13 | Câu 11: báo cáo đăng ký | ✅ **không có dòng phân công nào lọt vào** |
| 13 | Trưởng `UPDATE SINHVIEN` | ✅ **chặn** |
| 15 | Mảnh dọc chỉ có `MASV, HO, TEN, MALOP` | ✅ không có mật khẩu / địa chỉ |
| 15 | `tracuu` ghi dữ liệu | ✅ **chặn** |
| 13 | **Mượn đề xuyên cơ sở** | ✅ đề 10 câu ra **8 `LOCAL` + 2 `MUON`** |

### F3. Sự cố nhân bản gặp ở lần chạy đầu, và cách đã sửa

Lần chạy đầu **4/15 bước hỏng**, tất cả đều là *"chờ nhân bản"*. Nguyên nhân gốc nằm trong lịch sử merge agent:

```
You must rerun snapshot because current snapshot files are obsolete.
```

```sql
SELECT name, snapshot_ready FROM dbo.sysmergepublications;
--  TN_CSDLPT_CS1     2   ← 2 = snapshot hết hiệu lực, phải tạo lại
--  TN_CSDLPT_CS2     2
--  TN_CSDLPT_TRACUU  1   ← bình thường
```

`TRACUU` báo *"No data needed to be merged"* — **đúng**, vì sinh viên mới chưa bao giờ lên tới máy chủ do publication `CS1` đang tắc. Nên bước tra cứu chỉ là **hệ quả**, không phải lỗi thứ hai.

**Quy trình đã dùng để sửa** (thứ tự này quan trọng):

```sql
-- 0. SAO LƯU TRƯỚC - thao tác này có rủi ro mất thay đổi cục bộ
BACKUP DATABASE TN_CSDLPT TO DISK = N'...\TN_CSDLPT_truoc_reinit.bak' WITH INIT, COMPRESSION;

-- 1. Đánh dấu khởi tạo lại, NHƯNG upload thay đổi của phân mảnh LÊN TRƯỚC
EXEC sp_reinitmergesubscription
     @publication = N'TN_CSDLPT_CS1', @subscriber = N'<MÁY>\SERVER1',
     @subscriber_db = N'TN_CSDLPT',   @upload_first = N'true';
-- ...tương tự cho CS2

-- 2. Tạo lại snapshot, chờ snapshot_ready về 1
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_CS1';
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_CS2';

-- 3. Merge agent tự upload rồi áp snapshot mới
-- 4. BẮT BUỘC: chạy lại SQL/12_CapLaiQuyen.sql (khởi tạo lại DROP bảng -> mất sạch quyền)
```

**Kết quả — `@upload_first = 'true'` giữ được toàn bộ dữ liệu cục bộ:**

| Bảng | Máy chủ trước → sau | Ghi chú |
|---|---|---|
| `BODE` | 258 → **272** | nhận 13 câu test của CS1 + 1 câu của CS2 |
| `MONHOC` | 6 → **7** | môn `KTLT` |
| `GIAOVIEN` | 4 → **5** | `TH999` |
| `LOP` | 8 → **9** | `TH99` |
| `SINHVIEN` | 18 → **19** | `SV999001` |
| `SERVER3` (mảnh dọc) | 18 → **19** | sinh viên mới đã tới nơi tra cứu |

Sau khi sửa, chạy lại script: **17/17 bước đạt**, `KiemTraDongBoSP.ps1` báo *"tất cả thủ tục đều khớp giữa máy chủ và hai phân mảnh"* (28 thủ tục).

> Sau khởi tạo lại, số quyền đúng như mong đợi: `Sinhvien` còn **11** `EXECUTE` (giảm 1 vì đã thu hồi `sp_MoLaiBaiThi` — xem G6) và **4** bảng bị `DENY` (thêm `Bode_Muon`).

### F4. Nghiệp vụ còn thiếu — phát hiện khi dựng case test

**Kho đề mượn `Bode_Muon`.** Ban đầu tôi kết luận *"không có gì ghi vào bảng này"* — **kết luận đó SAI**, do chỉ tìm trong `SQL/*.sql`. Sự thật:

> Trên **máy chủ** có `dbo.sp_LamMoi_BodeMuon` dựng lại toàn bộ `Bode_Muon` bằng một câu `MERGE` từ `BODE ⋈ GIAOVIEN ⋈ KHOA`, do SQL Agent job *"TN_CSDLPT - Lam moi kho de muon"* gọi **mỗi 5 phút**. Cơ chế này **chạy đúng**.

Phải chạy ở máy chủ vì chỉ ở đó `KHOA` mới có đủ hai cơ sở. Chạy trên phân mảnh thì `KHOA` đã bị cây dẫn xuất lọc, mệnh đề `WHEN NOT MATCHED BY SOURCE THEN DELETE` sẽ tưởng đề của cơ sở kia là "không còn nguồn" rồi **xoá sạch** chúng khỏi kho mượn.

**Vấn đề thật sự còn lại chỉ có MỘT**, đã xử lý trong `SQL/18_DongBoKhoDeMuon.sql`:

> Thủ tục + job **chỉ nằm trong DB, không có trong repo**. Dựng lại ở máy khác bằng bộ script này là mất hẳn — kho đề mượn đứng im vĩnh viễn mà không báo lỗi gì, nên câu 8 *"thiếu thì mượn cơ sở còn lại"* sẽ không bao giờ kích hoạt. Script nay tạo lại cả hai, có rào `IsMergePublished` để **chỉ tạo ở máy chủ**.

#### Hai publication KHÔNG đối xứng — và một hướng đi sai của tôi

Ban đầu tôi định cho `sp_Bode_Them/Sua/Xoa` ghi thẳng vào `Bode_Muon` lúc giảng viên soạn đề, để "mượn được ngay, khỏi chờ 5 phút". **Ý tưởng đó hỏng.** Kiểm `sysmergearticles` mới thấy hai publication cấu hình khác nhau:

```
TN_CSDLPT_CS1 . Bode_Muon : (không lọc)      -> nhận đủ mọi dòng
TN_CSDLPT_CS2 . Bode_Muon : [MACS] <> 'CS2'  -> CHỈ nhận dòng của CS1
```

Nên ghi một dòng `MACS='CS2'` vào `Bode_Muon` trên `SERVER2` là **vi phạm bộ lọc**. Nhân bản đẩy nó ra bảng xung đột:

```
MSmerge_conflict_TN_CSDLPT_CS2_Bode_Muon : 40 dòng
"The merge process is retrying a failed operation made to article 'Bode_Muon'"
```

Mà lợi ích thì **bằng không**: mỗi phân mảnh chỉ đọc `Bode_Muon` với điều kiện `MACS <> cơ sở của mình`, nên dòng `CS2` nằm trong `Bode_Muon` của `CS2` **không ai đọc tới**. Muốn `CS1` mượn được đề `CS2` thì dòng đó bắt buộc phải đi qua máy chủ — đúng đường mà job 5 phút vẫn đang làm.

→ Đã **khôi phục** ba thủ tục về hành vi gốc: chỉ đụng `dbo.Bode`, `Bode_Muon` để máy chủ lo.

Cũng vì vậy, con số lệch giữa các server là **đúng, không phải lỗi**:

| Máy | `Bode` | `Bode_Muon` | Vì sao |
|---|---|---|---|
| Máy chủ | 272 | 272 (231 CS1 + 41 CS2) | nguồn đầy đủ |
| `SERVER1` | 272 | 272 | article không lọc |
| `SERVER2` | 272 | **231** | lọc `MACS <> 'CS2'` — thiếu đúng 41 câu do chính CS2 soạn |

> **Cái bẫy thứ hai, đáng ghi lại.** Lần đầu tôi nhận diện máy chủ bằng `EXISTS (SELECT 1 FROM dbo.sysmergepublications)`. Sai: bảng hệ thống đó **có trên cả subscriber** và cũng có dòng mô tả publication mà nó đăng ký — nên `sp_LamMoi_BodeMuon` cùng job 5 phút bị tạo nhầm lên **cả hai phân mảnh**, nơi mệnh đề `WHEN NOT MATCHED BY SOURCE THEN DELETE` sẽ xoá sạch đề mượn của cơ sở kia. Gỡ kịp trước khi job nổ. Dấu hiệu đúng là `DATABASEPROPERTYEX(DB_NAME(), 'IsMergePublished') = 1`.

#### Đường đi của một câu hỏi mượn — ba chặng

```
CS2 soạn đề  ──①──>  dbo.Bode trên SERVER2
                         │ merge LÊN (~60 giây)
                         ▼
                     dbo.Bode trên MÁY CHỦ
                         │ ② sp_LamMoi_BodeMuon  (job 5 phút, hoặc gọi tay)
                         ▼
                     dbo.Bode_Muon trên MÁY CHỦ
                         │ merge XUỐNG (~60 giây)
                         ▼
③ dbo.Bode_Muon trên SERVER1  ──>  sp_LayDeThi đọc với MACS <> 'CS1'
```

Case test đo được từng chặng: lên máy chủ **61 giây**, xuống CS1 **58 giây**. Muốn demo không phải chờ job thì gọi thẳng `EXEC dbo.sp_LamMoi_BodeMuon` trên máy chủ — đúng cách script test đang làm.

### F5. Không phải lỗ hổng — đã kiểm và thấy ổn

| Nghi vấn khi dựng case test | Kết luận |
|---|---|
| Sinh viên mới có mật khẩu không? | ✅ `frmSinhVien.KhiThemDong` đặt sẵn `PASSWORD = "123"` |
| Sinh viên mới có tới được mảnh dọc `SERVER3` không? | ✅ `SINHVIEN` + `LOP` là article của publication `TN_CSDLPT_TRACUU` |
| Dòng "phân công" có lọt vào lịch thi của sinh viên không? | ✅ `sp_LichThi` lọc `SOCAUTHI IS NOT NULL` |
| ...có lọt vào báo cáo câu 11 không? | ✅ `sp_BaoCao_DangKy` lọc tương tự |
| ...sinh viên có vào thi nhầm dòng phân công được không? | ✅ `sp_LayDeThi` **vốn đã** chặn bằng `IF @TD IS NULL` vì dòng phân công để `TRINHDO` trống |

---

## PHẦN G — HƯỚNG TEST BAO QUÁT & TỪ ĐIỂN STORED PROCEDURE

### G1. Ba tầng phải test, và test cái gì ở tầng nào

Sai lầm hay gặp là chỉ bấm thử trên giao diện rồi kết luận "chạy được". Ứng dụng chỉ là tầng ngoài cùng — ràng buộc thật nằm ở CSDL, còn tính phân tán nằm ở nhân bản. Ba tầng phải test riêng:

| Tầng | Công cụ | Trả lời câu hỏi |
|---|---|---|
| **1. CSDL** | `sqlcmd` + `EXECUTE AS LOGIN` | Ràng buộc có thật không, hay chỉ là nút bị khoá trên form? |
| **2. Ứng dụng** | Mở `QuanLyThi.exe` bằng từng tài khoản | Luồng người dùng có đi trọn vẹn không? |
| **3. Phân tán** | Đối chiếu 4 instance | Dữ liệu có lan đúng chỗ, và **không** lan sang chỗ không được phép? |

Tầng 1 quan trọng nhất khi bảo vệ: thầy hỏi *"nếu người ta gọi thẳng vào CSDL thì sao"* thì phải chứng minh được bằng `EXECUTE AS`, không phải bằng ảnh chụp form.

### G2. Bộ tài khoản để test

| Login | Mật khẩu | Nhóm | Có ở | Dùng để test |
|---|---|---|---|---|
| `truong01` | `Truong@123` | `Truong` | mọi phân mảnh | chỉ-xem, chạy đủ 3 báo cáo |
| `coso1` | `Coso@123` | `CoSo` | SERVER1 | toàn quyền CS1, phân công, giám thị |
| `coso2` | `Coso@123` | `CoSo` | SERVER2 | như trên, cho CS2 |
| `TH123` | *(đã tạo)* | `Giangvien` | SERVER1 | soạn đề, thi thử |
| `TH657` | *(đã tạo)* | `Giangvien` | SERVER2 | dùng cho case mượn đề |
| `sv` | `Sv@123` | `Sinhvien` | mọi phân mảnh | **login CHUNG**, danh tính là `MASV` + `PASSWORD` trong bảng |
| `tracuu` | `TraCuu@123` | *(chỉ đọc)* | SERVER3 | mảnh dọc |

### G3. Khuôn mẫu test ở tầng CSDL

```sql
BEGIN TRAN;                          -- luôn bọc giao dịch để không bẩn dữ liệu

/* Trường hợp PHẢI CHẠY ĐƯỢC */
EXECUTE AS LOGIN = 'TH657';
    EXEC dbo.sp_Bode_DS @MAMH = 'MMTCB';
REVERT;

/* Trường hợp PHẢI BỊ CHẶN - bọc TRY/CATCH, in ra lỗi mong đợi */
BEGIN TRY
    EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_MoLaiBaiThi @MASV='002', @MAMH='MMTCB', @LAN=1;
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;   -- lỗi nổ khi đang mượn ngữ cảnh
    PRINT N'CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH

ROLLBACK;
```

**Ba cạm bẫy đã dính thật, ghi lại để khỏi mất thời gian:**

1. `EXECUTE AS LOGIN` đổi `SUSER_SNAME()` và `IS_MEMBER()`, **nhưng KHÔNG đổi `ORIGINAL_LOGIN()`**. Thủ tục nào xét quyền bằng `ORIGINAL_LOGIN()` — `SP_TAOLOGIN`, `SP_SAOLUU` — thì phải đăng nhập thật: `sqlcmd -U coso1 -P Coso@123`.
2. Khi lỗi nổ lúc đang mượn ngữ cảnh, `REVERT` bị nhảy cóc → các câu sau chạy nhầm danh tính. Luôn có dòng `IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;` trong `CATCH`.
3. `sqlcmd` mặc định **trả mã 0 dù có `RAISERROR`**. Thêm `-b` để phân biệt lỗi thật với lỗi cố ý (lỗi trong `TRY/CATCH` không kích hoạt `-b`).

### G4. Từ điển stored procedure theo từng câu

> Cột **Nhóm** lấy trực tiếp từ `sys.database_permissions` trên `SERVER1`, không phải chép từ tài liệu cũ.

#### Câu 1 — Đăng nhập, tài khoản, phân quyền

| SP | Tham số | Nhóm | Làm gì | Điểm cần test |
|---|---|---|---|---|
| `SP_LayThongTinNguoiDung` | `@TENLOGIN` | cả 4 | Đọc `sys.sysusers`/`sys.sysmembers` → trả nhóm quyền của login | Đăng nhập bằng 4 vai trò, xem nhóm trả về có đúng |
| `SP_LayThongTinNhanVien` | `@TENLOGIN` | cả 4 | Ghép thêm họ tên từ `GIAOVIEN` | Login giảng viên phải ra tên thật |
| `sp_DangNhap_SV` | `@MASV, @PASSWORD` | `Sinhvien` | Xác thực sinh viên **trong bảng**, vì SQL login là dùng chung | Sai mật khẩu → 0 dòng, không phải lỗi |
| `SP_TAOLOGIN` | `@username, @password, @role` | `CoSo`/`Truong` | Tạo login + user + gán nhóm. Xét quyền bằng `ORIGINAL_LOGIN()` | Trưởng tạo `Giangvien` → **chặn**; Cơ sở tạo `Truong` → **chặn**; tên login ≠ `MAGV` → **chặn** |
| `SP_DOIMATKHAU` | `@MatKhauCu, @MatKhauMoi` | `CoSo`/`Giangvien`/`Truong` | `ALTER LOGIN` cho cán bộ | Sai mật khẩu cũ → chặn |
| `sp_DoiMatKhau_SV` | `@MASV, @MatKhauCu, @MatKhauMoi` | cả 4 | Đổi cột `PASSWORD` trong `SINHVIEN` | Đổi xong app bắt đăng nhập lại |
| `sp_DS_TaiKhoan` | *(không)* | `CoSo`/`Truong` | Liệt kê login + nhóm | |
| `sp_DS_GV_ChuaCoTaiKhoan` | *(không)* | `CoSo`/`Truong` | Giáo viên đã khai báo nhưng chưa có login | Dùng để đổ ComboBox tạo tài khoản |

#### Câu 2–5 — Danh mục (Môn học · Khoa & Lớp · Sinh viên · Giáo viên)

**Không dùng SP** — thao tác bảng trực tiếp qua `SqlDataAdapter` + `SqlCommandBuilder`. Ràng buộc do SQL Server chặn:

```sql
EXECUTE AS LOGIN = 'TH123';   -- giảng viên
INSERT INTO dbo.LOP(MALOP,TENLOP,MAKH) VALUES(N'X',N'Y',N'Z');
-- The INSERT permission was denied on the object 'LOP'
REVERT;
```

Riêng câu 4 dùng **mảnh dọc**: trước khi ghi, app hỏi `SERVER3` xem `MASV` đã tồn tại ở cơ sở kia chưa.

#### Câu 6 — Bộ đề

| SP | Tham số | Nhóm | Làm gì | Điểm cần test |
|---|---|---|---|---|
| `sp_DS_MonHoc_SoanDe` | *(không)* | `CoSo`/`Giangvien`/`Truong` | Giảng viên chỉ thấy môn **được phân công** (`GIAOVIEN_DANGKY` ∪ `BODE` của mình); `CoSo`/`Truong` thấy đủ | Không có tham số nào để nới danh sách → app không lách được |
| `sp_Bode_DS` | `@MAMH` | `CoSo`/`Giangvien`/`Truong` | Giảng viên chỉ thấy câu của mình (`SUSER_SNAME()`); Trưởng/Cơ sở thấy hết | Đăng nhập 2 giảng viên khác nhau, đếm số câu |
| `sp_Bode_Them` | `@MAMH, @TRINHDO, @NOIDUNG, @A..@D, @DAP_AN, @MAGV` | `CoSo`/`Giangvien` | Cấp mã theo **dải riêng cơ sở** (CS1 `1.000.000+`, CS2 `1.500.000+`), khoá dải bằng `UPDLOCK, HOLDLOCK`; ghi kèm `Bode_Muon` | `@MAGV` giảng viên gửi lên bị **bỏ qua**, luôn ghi cho chính mình |
| `sp_Bode_Sua` | `@CAUHOI` + như trên | `CoSo`/`Giangvien` | Sửa; giảng viên không đổi được chủ sở hữu | Sửa câu người khác → *"không do bạn soạn"* |
| `sp_Bode_Xoa` | `@CAUHOI` | `CoSo`/`Giangvien` | Xoá ở cả `BODE` và `Bode_Muon` | Xoá câu người khác → chặn |

#### Phân công giảng dạy — bước MỚI, đứng giữa câu 6 và câu 7

| SP | Tham số | Nhóm | Làm gì | Điểm cần test |
|---|---|---|---|---|
| `sp_PhanCong_DS` | *(không)* | `CoSo`/`Giangvien`/`Truong` | Danh sách phân công + cột `TRANGTHAI`, `XOADUOC` | |
| `sp_PhanCong_Them` | `@MAGV, @MAMH, @MALOP` | **chỉ `CoSo`** | Ghi dòng `LAN=1` với `SOCAUTHI = NULL`, **không** kiểm kho đề | Giảng viên tự gọi → **chặn**; GV và lớp khác cơ sở → **chặn** |
| `sp_PhanCong_Xoa` | `@MAMH, @MALOP` | **chỉ `CoSo`** | Chỉ xoá được khi chưa đăng ký kỳ thi | Đã đăng ký rồi → **chặn** |

#### Câu 7 — Chuẩn bị thi

| SP | Tham số | Nhóm | Làm gì |
|---|---|---|---|
| `sp_ChuanBiThi` | `@MAGV, @MALOP, @MAMH, @TRINHDO, @LAN, @SOCAUTHI, @NGAYTHI, @THOIGIAN` | `CoSo`/`Giangvien` | 8 lớp kiểm tra rồi **UPDATE** dòng phân công (`LAN=1`) hoặc **INSERT** (`LAN=2`) |
| `sp_LichThi` | `@MASV` | cả 4 | Lịch thi của sinh viên, lọc `SOCAUTHI IS NOT NULL` |

Chuỗi kiểm tra của `sp_ChuanBiThi` — mỗi bước là một case test:

```
1. @TRINHDO ∈ {A,B,C} · @LAN ∈ {1,2} · @SOCAUTHI 10..100 · @THOIGIAN 2..60
2. Lớp / Môn / Giáo viên có tồn tại ở phân mảnh này
3. Giáo viên và lớp CÙNG CƠ SỞ           (Lop→Khoa vs Giaovien→Khoa, so MACS)
4. Chưa đăng ký trùng (đã có dòng VÀ SOCAUTHI IS NOT NULL)
5. LAN=1 phải có phân công sẵn ; LAN=2 phải có lần 1 đã đăng ký
6. Người đăng ký = người được phân công
7. ★ Kho đề ≥ 70% số câu   →  báo CÒN THIẾU BAO NHIÊU CÂU
8. UPDATE (LAN=1) hoặc INSERT (LAN=2)
```

#### Câu 8 — Thi

| SP | Tham số | Nhóm | Làm gì | Điểm cần test |
|---|---|---|---|---|
| `sp_LayDeThi` | `@MASV, @MAMH, @LAN, @DungLaiDeLanTruoc, @ThiThu, @MALOP_ThiThu` | `CoSo`/`Giangvien`/`Sinhvien` | Gom đề vào `#De`, ưu tiên **đề của cơ sở lớp đang học**, thiếu thì mượn `Bode_Muon` (`MACS <> @MACS`); trộn thứ tự bằng `NEWID()` | Đếm `NGUON`: phải thấy `LOCAL` + `MUON`. Chưa tới ngày thi → chặn. Đã có điểm → chặn |
| `sp_ThongTinThiSinh` | `@MASV` | `CoSo`/`Giangvien`/`Sinhvien` | Thông tin hiển thị đầu màn thi | |
| `sp_NopBai` | `@MASV, @MAPHIEU, @DapAn, @GhiDiem` | `Giangvien`/`Sinhvien` | Chấm bằng **đáp án lưu ở server**, ân hạn 60 giây, cờ `THITHU` lấy từ phiếu chứ không từ tham số | Thi thử của giảng viên → **không ghi** `BANGDIEM` |
| `sp_ThoiGianConLai` | `@MASV, @MAPHIEU` | `Giangvien`/`Sinhvien` | Số giây còn lại, tính ở server | *(chưa nối vào giao diện)* |
| `sp_MoLaiBaiThi` | `@MASV, @MAMH, @LAN` | **chỉ `CoSo`** | Giám thị mở lại phiếu treo (cúp điện / rớt mạng) | Xem mục G6 — đây từng là lỗ hổng |

**Quy tắc 70/30**: `@tranThap = FLOOR(@SOCAU * 0.30)` — tối đa 30% số câu được hạ **đúng một bậc** trình độ (A→B, B→C).

#### Câu 9 — Xem lại bài thi / phúc khảo

| SP | Tham số | Nhóm | Làm gì | Điểm cần test |
|---|---|---|---|---|
| `sp_DS_BaiThi_SV` | `@MASV` | cả 4 | Các bài đã thi của một sinh viên | |
| `sp_DS_Lop_CoBaiThi` | *(không)* | `CoSo`/`Giangvien`/`Truong` | Lớp có bài thi → ComboBox 1 | **Cố ý không cấp cho `Sinhvien`** |
| `sp_DS_SinhVien_CoBaiThi` | `@MALOP` | `CoSo`/`Giangvien`/`Truong` | Sinh viên trong lớp đó → ComboBox 2 | Sinh viên gọi → **chặn**, không liệt kê được bạn cùng lớp |
| `sp_XemKetQua` | `@MASV, @MAMH, @LAN` | cả 4 | Từng câu: nội dung, đáp án đúng, SV đã chọn, `Đúng/Sai/Bỏ trống` | Số câu `Đúng` phải khớp điểm |

#### Câu 10 — Bảng điểm môn học

| SP | Tham số | Nhóm | Làm gì |
|---|---|---|---|
| `sp_BangDiemMonHoc` | `@MALOP, @MAMH, @LAN` | `CoSo`/`Giangvien`/`Truong` | `ROUND(DIEM*2,0)/2` → làm tròn 0.5; điểm chữ tính **từ điểm đã làm tròn** |

Case cần test: điểm `7.0` → `B`; điểm lẻ như `6.25` phải ra `6.5`, **không được ra `6.25`**.

#### Câu 11 — Báo cáo đăng ký cả hai cơ sở

| SP | Tham số | Nhóm | Làm gì |
|---|---|---|---|
| `sp_BaoCao_DangKy` | `@tungay, @denngay` | `CoSo`/`Truong` | Cài trên **từng phân mảnh**; app gọi cả hai rồi `UNION`. Lọc `SOCAUTHI IS NOT NULL` |

Ràng buộc nặng nhất của đề: **tuyệt đối không mở kết nối tới máy chủ**. Test bằng cách tắt instance `SERVER` rồi chạy báo cáo — vẫn phải ra kết quả.

#### Quản trị

| SP | Tham số | Nhóm | Ghi chú |
|---|---|---|---|
| `SP_SAOLUU` | `@ThuMuc, @GhiChu` | `CoSo`/`Truong` | Xét quyền bằng `ORIGINAL_LOGIN()` |
| `SP_DS_SAOLUU` | *(không)* | `CoSo`/`Truong` | |
| `SP_PHUCHOI_CSDL` | `@TenFile, @XacNhan` | **chỉ `Truong`** | Cần chuỗi xác nhận |
| `sp_LamMoi_BodeMuon` | *(không)* | *(job gọi)* | **Chỉ máy chủ** — xem PHẦN F mục F4 |

### G5. Checklist bao quát — 11 câu × 4 vai trò

Chạy `SQL/CaseTest_ToanTuyen.ps1` là phủ được phần lớn. Phần còn lại phải bấm tay:

| Hạng mục | Cách kiểm | Đã tự động? |
|---|---|---|
| Đăng nhập 4 vai trò, menu hiện đúng | Mở app 4 lần | ✗ bấm tay |
| Trưởng đăng nhập **từng** phân mảnh, chỉ xem | ComboBox chi nhánh ở màn đăng nhập | ✗ bấm tay |
| Tạo tài khoản đúng/sai vai trò | `SP_TAOLOGIN` với `-U truong01` / `-U coso1` | ✓ một phần |
| Đổi mật khẩu → quay về màn đăng nhập | Mở app | ✗ bấm tay |
| 4 danh mục: Thêm/Sửa/Xóa/Ghi/Phục hồi/Undo nhiều cấp | Mở app | ✗ bấm tay |
| Chống trùng `MASV` qua mảnh dọc | Nhập `MASV` đã có ở cơ sở kia | ✗ bấm tay |
| Lọc môn theo phân công | ✓ | ✓ bước 5 |
| Soạn đề đủ `A/B/C`, đáp án `A/B/C/D` | ✓ | ✓ bước 10 |
| Sửa/xóa đề người khác | ✓ | ✓ bước 10 |
| Đăng ký thi thiếu đề → báo số câu | ✓ | ✓ bước 10 |
| **Mượn đề xuyên cơ sở** | ✓ đề ra `8 LOCAL + 2 MUON` | ✓ bước 8→13 |
| Thi → nộp → điểm chính xác | ✓ | ✓ bước 11 |
| Hết giờ tự chấm | Đăng ký `@THOIGIAN=2` rồi ngồi chờ | ✗ bấm tay |
| Giảng viên **thi thử không ghi điểm** | Menu *Thi thử*, kiểm `BANGDIEM` không đổi | ✗ bấm tay |
| Phúc khảo 3 bước | ✓ | ✓ bước 12 |
| Làm tròn 0.5 + điểm chữ | ✓ | ✓ bước 12 |
| Câu 11 UNION, không qua máy chủ | Tắt instance `SERVER` rồi chạy | ✗ bấm tay |
| Trưởng bị chặn ghi | ✓ | ✓ bước 13 |
| Mảnh dọc chỉ có 4 cột, `tracuu` chỉ đọc | ✓ | ✓ bước 15 |
| Sao lưu / phục hồi | Màn Sao lưu | ✗ bấm tay |
| **Quyền còn đủ sau nhân bản** | `SQL/12_CapLaiQuyen.sql` + `KiemTraDongBoSP.ps1` | ✓ script riêng |

### G6. ⚠️ Lỗ hổng phát hiện khi lập từ điển SP

Khi đối chiếu cột **Nhóm** với chú thích trong từng thủ tục, một dòng lệch hẳn:

> `sp_MoLaiBaiThi` — chú thích ghi *"Chỉ CoSo được phép"*, nhưng quyền `EXECUTE` lại cấp cho cả `Sinhvien` và `Giangvien`, **và bên trong không có một dòng kiểm quyền nào**.

Thủ tục này xoá sạch `BangDiem` + `ChiTiet_BaiThi` + `PhieuThi` của một lần thi. Vì mọi sinh viên dùng **chung** login `sv` và `@MASV` là **tham số do ứng dụng gửi**, ai kết nối được bằng login đó đều xoá được điểm của bất kỳ ai. Đã chứng minh (trong giao dịch rồi rollback):

```
EXECUTE AS LOGIN = 'sv';
EXEC sp_MoLaiBaiThi @MASV='SV999001', @MAMH='KTLT', @LAN=1;
   → "Đã mở lại bài thi cho sinh viên SV999001"   → điểm 7.0 biến mất, thi lại từ đầu
EXEC sp_MoLaiBaiThi @MASV='002', @MAMH='MMTCB', @LAN=1;
   → xoá luôn điểm của sinh viên KHÁC
```

**Đã vá** (`SQL/19_VaLoHongMoLaiBaiThi.sql`) bằng hai lớp:

1. **Kiểm quyền ngay trong thủ tục** — `IS_MEMBER('CoSo')`. Đặt ở đây thì dù sau này ai lỡ `GRANT` nhầm, hoặc nhân bản cấp lại quyền sai, thủ tục vẫn tự chặn.
2. **Thu hồi** `EXECUTE` của `Sinhvien` và `Giangvien`; `12_CapLaiQuyen.sql` cũng đã sửa bảng ánh xạ.

Kiểm chứng sau khi vá: `sv` → *permission denied*; `TH999` → *permission denied*; `coso1` → chạy được; điểm `7.0` còn nguyên.

#### Hệ quả rộng hơn của "login chung" — cần trả lời được khi bảo vệ

Đề yêu cầu **hai cách đăng nhập khác nhau**: cán bộ có SQL login riêng, sinh viên dùng login chung + `MASV`/`PASSWORD` trong bảng. Hệ quả tất yếu: với sinh viên, **CSDL không tự xác định được người gọi là ai** — `SUSER_SNAME()` luôn trả về `sv`. Nên các thủ tục buộc phải nhận `@MASV` từ ứng dụng:

| SP | Rủi ro nếu gọi thẳng bằng login `sv` | Đánh giá |
|---|---|---|
| `sp_MoLaiBaiThi` | **xoá** điểm người khác | 🔴 đã vá — thu hồi quyền |
| `sp_XemKetQua`, `sp_DS_BaiThi_SV`, `sp_LichThi` | **đọc** điểm/bài của người khác | 🟡 lộ thông tin, không phá dữ liệu |
| `sp_LayDeThi` | mở phiếu thi hộ người khác | 🟡 còn bị chặn bởi ngày thi + đã có điểm |
| `sp_NopBai` | phải biết `@MAPHIEU` (GUID) | 🟢 khó khai thác |
| `sp_DoiMatKhau_SV` | phải biết mật khẩu cũ | 🟢 an toàn |

Ranh giới đã chọn: **thủ tục nào PHÁ dữ liệu thì không cấp cho `Sinhvien`**, phải qua giám thị. Nhóm đọc thì chấp nhận, vì siết triệt để đòi bỏ hẳn mô hình login chung — mà đó lại là thứ đề bài yêu cầu.
