# Phân tích bài giảng "Tạo báo cáo trên hệ thống phân tán"

> Nguồn: `report.txt` — bản chép lời bài giảng của Thầy
> Đối chiếu và cập nhật cho 3 báo cáo của đồ án · 12/08/2026

---

## PHẦN 1 — THẦY DẠY GÌ

### 1.1 Bốn bước làm một báo cáo

| Bước | Nội dung | Thầy nhấn mạnh |
|---|---|---|
| **1** | **Thiết kế nháp trên giấy** — xác định tiêu đề báo cáo, các cột, tham số, phần lặp lại đầu trang | *"Bước này cực kỳ quan trọng. Nếu không định hình được thì viết SP bị sai. Mà SP viết sai thì cho dù thiết kế đẹp thế nào chẳng nữa thì bản chất nó đã sai rồi. Thà thiết kế nó xấu mà đúng."* |
| **2** | **Viết SP** (nếu có tham số) hoặc **View** (nếu không tham số) | *"Bắt buộc phải viết SP này ở **server chủ**, sau đó **đẩy nó xuống các phân mảnh**, để về sau chạy báo cáo trên bất kỳ phân mảnh nào thì SP đã tồn tại ở đó rồi. Chúng ta **không gọi về server chủ**."* |
| **3** | Dùng công cụ báo cáo liên kết với SP để thiết kế | Thầy dùng XtraReport của DevExpress |
| **4** | **Form trung gian** — cầu nối giữa báo cáo và người dùng, nhận tham số, có nút In | Xuất được ra máy in hoặc tệp (Excel / PDF / XML) |

### 1.2 Cấu trúc BAND của báo cáo

```
┌─ ReportHeader ──── tiêu đề báo cáo, CHỈ in ở đầu TRANG 1
├─ PageHeader ────── tiêu đề CỘT, in lại ở đầu MỖI TRANG
├─ Detail ────────── các dòng dữ liệu
├─ ReportFooter ──── dòng TỔNG, nằm NGAY DƯỚI dòng cuối cùng
└─ PageFooter ────── số trang, ở cuối MỖI TRANG
```

> Thầy cảnh báo: *"Bạn nào mà đặt cái số tổng này nằm ở PageFooter thì nó sẽ nằm ở cuối trang, và như vậy nó rất là kỳ."* → Tổng phải ở **ReportFooter**, không phải PageFooter.

### 1.3 Hai nguyên tắc quan trọng nhất

**(a) Giảm tải đường truyền — cột nào tính được thì tính ở máy trạm**

> *"Nếu mà ta viết truy vấn ở trên server mà những dữ liệu này mà tính toán được trong report thì chúng ta **không nên**, chúng ta nên để nó tính ở trên máy client. Còn cái nào mà **không thể** tính toán được thì mới tính ở trên server SQL."*

Ví dụ của Thầy: cột `TRỊ GIÁ = số lượng × đơn giá` → **không** đưa vào SP, tính trong report.

**(b) Tiêu đề động — dữ liệu đã có trên form thì đừng truy vấn lại**

> *"Nếu những thông tin động này mà đã có sẵn ở trên form bước 4 thì chúng ta **không cần đưa nó vào mệnh đề SELECT** để truy vấn, mà ta sẽ gửi từ form đổ qua report."*

Ví dụ: họ tên nhân viên, loại phiếu, năm — form đã có → truyền thẳng vào report.

Cả hai nguyên tắc đều là **tối ưu hóa truy vấn phân tán** (Chương 4) áp dụng vào báo cáo.

### 1.4 Điểm PHÂN BIỆT đề phân tán với đề tập trung ⭐

> *"Đây là đề tài phân tán, có nghĩa rằng chúng ta đăng nhập vô vai trò công ty thì được quyền xem số liệu của **tất cả chi nhánh** bằng cách **chọn chi nhánh tương ứng**. Và khi ta chọn chi nhánh tương ứng thì nó sẽ **tự động rẽ về server đó**."*
>
> *"Cái đề tài phân tán nó **khác biệt** với đề tài tập trung là ở chỗ này: chúng ta phải làm động tác là tạo ra một **ComboBox chi nhánh** để chúng ta rẽ server về đó."*

Kèm quy tắc phân quyền:

| Vai trò | ComboBox chi nhánh |
|---|---|
| Công ty / **Trưởng** | **Sáng lên** — xem được mọi chi nhánh |
| Chi nhánh / **Cơ sở** | **Mờ đi** — chỉ xem một phân mảnh |

Và: ComboBox phải là `DropDownList` — *"cái này chúng ta không được quyền gõ"*.

### 1.5 Tối ưu hóa truy vấn trong SP báo cáo

> *"Đây chính là cái tính tối ưu đây. Chúng ta sẽ truy vấn vào trong phiếu nhập **trước**… đặt tên cho nó là PS, và ta sẽ **kết** với chi tiết nhập, vật tư."*

→ **Chọn (σ) trước, kết (⋈) sau** — đúng Chương 4.

Và quy tắc đặt tên field: hai bảng khác nhau (phiếu nhập / phiếu xuất) phải **đổi về cùng một tên field chung** để report chỉ dùng một tên duy nhất.

### 1.6 Phân loại báo cáo

- **Standard** (chuẩn): mỗi cột trong báo cáo = một field trong SP
  - không tham số · **có tham số** · **có nhóm số liệu**
- **Cross-tab**: dạng khác

---

## PHẦN 2 — ĐỐI CHIẾU VỚI ĐỒ ÁN

### 2.1 Trước khi cập nhật — những chỗ thiếu

| # | Thiếu | Mức độ |
|---|---|---|
| 1 | **Không có ComboBox chi nhánh** trên form báo cáo | 🔴 Đây là điểm Thầy nói *phân biệt đề phân tán với đề tập trung* |
| 2 | Không có **xem trước / in** đúng nghĩa — chỉ xuất CSV thô | 🔴 Bước 4 của Thầy |
| 3 | Không có cấu trúc **band** (ReportHeader / PageHeader / ReportFooter) | 🔴 |
| 4 | Không có **dòng TỔNG** ở ReportFooter | 🟡 |
| 5 | Không có cột **tính tại máy trạm** — mọi thứ đều query từ server | 🟡 Vi phạm nguyên tắc giảm tải |
| 6 | SP báo cáo **không được đẩy xuống phân mảnh** qua nhân bản | 🟡 Hiện deploy trực tiếp từng server — chạy đúng nhưng khác cách Thầy dạy |

### 2.2 Đã cập nhật

#### `BaoCaoIn.cs` — bộ máy in theo đúng cấu trúc band

Tự viết trên `PrintDocument` có sẵn của .NET thay vì XtraReport (DevExpress là thư viện thương mại, không kèm .NET). Vẫn đủ:

```
ReportHeader  → tiêu đề + tiêu đề phụ + dòng ghi nguồn dữ liệu (chỉ trang 1)
PageHeader    → dải xanh chứa tiêu đề cột (lặp mỗi trang)
Detail        → dòng dữ liệu, tô xen kẽ
ReportFooter  → "TỔNG CỘNG (n dòng)" + tổng các cột đánh dấu CongTong
PageFooter    → "Trang n" + thời điểm in
```

Hỗ trợ **cột tính tại máy trạm** qua `CotTinh`:

```csharp
new BaoCaoIn.Cot { Ten = "XEPLOAI", TieuDe = "Xếp loại",
                   CotTinh = r => XepLoai(r) }   // KHÔNG tải từ server
```

Nút **Xem trước / In** mở `PrintPreviewDialog` — từ đó in ra máy in hoặc lưu tệp. Nút **Xuất Excel** ghi CSV kèm UTF-8 BOM (Excel đọc đúng tiếng Việt), có cả dòng tổng.

#### `ChonChiNhanh.cs` — ComboBox chi nhánh

Đóng gói đúng hành vi Thầy mô tả:

- Nạp danh sách từ `V_DS_PHANMANH` (đã bỏ mảnh tra cứu)
- Nhóm **Trưởng**: thấy mọi chi nhánh, ComboBox **sáng**
- Nhóm **Cơ sở**: chỉ còn cơ sở mình, ComboBox **mờ**
- Đổi chi nhánh → sự kiện `KhiDoiChiNhanh` → form **rẽ kết nối sang server đó** và nạp lại
- `DropDownStyle = DropDownList` — không cho gõ tay

#### Câu 10 — `frmBangDiem`

| Trước | Sau |
|---|---|
| Không chọn được chi nhánh | ✅ ComboBox chi nhánh, rẽ server |
| Chỉ xuất CSV thô | ✅ Xem trước / In + Xuất Excel |
| — | ✅ Cột **Xếp loại** tính tại máy trạm |
| — | ✅ Cột **Đạt** + dòng tổng ở ReportFooter |
| — | ✅ Tiêu đề động: lớp / môn / lần lấy từ dữ liệu đã có, không query lại |

#### Câu 11 — `frmBaoCaoDangKy`

Thoả **cùng lúc** hai yêu cầu tưởng như mâu thuẫn:

| Yêu cầu | Nguồn | Cách làm |
|---|---|---|
| Báo cáo **cả hai cơ sở**, dùng **UNION**, không qua server chủ | `giai_de_4.txt` (câu 11) | Mục **"(Tất cả — gộp 2 cơ sở)"**: gọi SP trên từng phân mảnh rồi UNION |
| Có **ComboBox chi nhánh** để rẽ server | `report.txt` | Chọn một chi nhánh cụ thể → chỉ kết nối đúng server đó |

Nhóm Trưởng chọn được cả 3 mục; nhóm Cơ sở bị khoá vào cơ sở mình.

Thêm: xem trước / in, xuất Excel, cột **Số câu** có tổng ở ReportFooter, dòng ghi rõ nguồn dữ liệu để chứng minh khi bảo vệ.

---

## PHẦN 3 — VÌ SAO PHẢI VIẾT SP Ở MÁY CHỦ (bằng chứng thực tế)

Thầy dặn điều này **hai lần** — trong `HD FORM DANG NHAP.docx` và lại trong bài giảng báo cáo:

> *"Bắt buộc phải viết SP này ở **server chủ**, sau đó **đẩy nó xuống các phân mảnh**."*

Ban đầu tưởng đây chỉ là khác biệt về cách triển khai, vì deploy trực tiếp lên từng phân mảnh thì **cũng chạy được**. Kiểm tra thực tế cho thấy **không phải vậy**.

### Cái bẫy

23 thủ tục trong đồ án **đã được khai báo là Article** (lưu trong `sysmergeschemaarticles`, không phải `sysmergearticles` — nên tra nhầm bảng sẽ tưởng là chưa có). Khi một thủ tục đã là Article thì:

> **Nhân bản sẽ GHI ĐÈ bản sửa trực tiếp trên phân mảnh bằng bản của máy chủ.**

Nghĩa là mọi lần sửa thủ tục trực tiếp trên SERVER1/SERVER2 đều **âm thầm bị mất** ở lần đồng bộ kế tiếp.

### Hậu quả đã đo được

So sánh định nghĩa 27 thủ tục giữa 3 server (đã chuẩn hoá để bỏ qua khác biệt ngoặc vuông / khoảng trắng):

| Thủ tục | SERVER1 | SERVER2 | Hậu quả nếu không phát hiện |
|---|---|---|---|
| `sp_BangDiemMonHoc` | khớp | **LỆCH — bản cũ** | Câu 10 ở CS2 **không làm tròn 0.5** |
| `sp_ChuanBiThi` | khớp | **LỆCH — bản cũ** | Câu 7 ở CS2 đếm kho đề sai (không lọc `MACS`) |
| `sp_LayDeThi` | khớp | **LỆCH — bản cũ** | Câu 8 ở CS2 **mượn đề không chạy** (thiếu bản vá khoá `(CAUHOI, NGUON)`) |
| `sp_ChotBaoCao_DangKy` | thiếu | thiếu | Chưa có ở phân mảnh |
| `sp_LamMoi_BodeMuon` | thiếu | thiếu | Chưa có ở phân mảnh |

Ba bản vá quan trọng nhất của đồ án đã bị nhân bản ghi đè mất trên CS2 — mà giao diện vẫn chạy bình thường nên không hề lộ ra.

### Cách làm đúng từ nay

```
        SỬA THỦ TỤC
             │
             ▼
   ┌──────────────────┐
   │  MÁY CHỦ (SERVER)│   ← chỉ sửa Ở ĐÂY
   └────────┬─────────┘
            │ nhân bản đẩy xuống (schema article)
      ┌─────┴─────┐
      ▼           ▼
   SERVER1     SERVER2      ← KHÔNG bao giờ sửa trực tiếp
```

Script `SQL/11_SP_LamArticle.sql` kiểm tra và bổ sung thủ tục còn thiếu vào publication.

> **Bài học rút ra:** khi thủ tục đã là Article, sửa trực tiếp trên phân mảnh là việc *vô nghĩa và nguy hiểm* — nó tạo cảm giác đã sửa xong trong khi thực tế sẽ bị hoàn tác. Đây chính là lý do Thầy nhắc tới hai lần.

### Đã khắc phục

1. Nạp bản đúng của cả 3 thủ tục lên **máy chủ** (nguồn gốc để nhân bản).
2. Đồng bộ lại xuống hai phân mảnh.
3. Thêm công cụ **`SQL/KiemTraDongBoSP.ps1`** để dò lệch bất cứ lúc nào:

```
.\KiemTraDongBoSP.ps1
```

Kết quả sau khi sửa:

```
THU TUC                          SERVER1      SERVER2
----------------------------------------------------------
TAT CA THU TUC DEU KHOP giua may chu va hai phan manh.
Da doi chieu 21 thu tuc (bo qua 6 tien ich chi o may chu).
```

Công cụ **chuẩn hoá** trước khi so sánh (bỏ qua khác biệt `[dbo].[sp_X]` với `dbo.sp_X` và khoảng trắng) nên không báo động giả — lần dò đầu tiên chưa chuẩn hoá đã báo nhầm 17 thủ tục lệch, trong khi thực tế chỉ 5.

### ⚠️ TÁC DỤNG PHỤ: nhân bản làm MẤT QUYỀN

Ngay sau khi đồng bộ thủ tục thành công thì **đăng nhập vào ứng dụng bị báo "sai mật khẩu"** — trong khi tài khoản SQL vẫn hoàn toàn bình thường.

Nguyên nhân: **quyền GRANT không nằm trong định nghĩa stored procedure.** Khi nhân bản đẩy thủ tục xuống, nó `DROP` thủ tục cũ rồi `CREATE` lại — mọi `GRANT` trên thủ tục đó **biến mất**.

| Nhóm | Quyền EXECUTE sau khi nhân bản | Đáng lẽ |
|---|---|---|
| `Sinhvien` | **3** | 11 |
| `Giangvien` | **7** | 17 |

Mất `sp_DangNhap_SV` → ứng dụng không xác thực được sinh viên. Nhưng vì luồng đăng nhập bắt `SqlException` rồi chuyển sang nhánh sinh viên, lỗi *"EXECUTE permission denied"* bị nuốt và hiện ra thành **"Sai mã số hoặc mật khẩu"** — rất khó đoán ra nếu không biết cơ chế này.

**Cùng cơ chế đó còn làm mất QUYỀN BẢNG.** Lần thứ hai gặp lại: sau khi dựng lại subscription CS2, giảng viên `TH657` đăng nhập bình thường nhưng ComboBox **môn học trống trơn** nên không soạn được đề. Kiểm tra quyền bảng của từng nhóm:

| Server | `Giangvien` có quyền bảng |
|---|---|
| SERVER1 | SELECT trên 8 bảng, DENY trên 6 — **còn nguyên** |
| SERVER2 | **không còn gì cả** |

Lý do: snapshot / reinitialize **`DROP` rồi tạo lại BẢNG**, kéo theo mất mọi `GRANT`/`DENY` trên bảng — y hệt chuyện đã xảy ra với thủ tục. Lỗi thật là `SELECT permission was denied on the object 'MONHOC'`, nhưng người dùng chỉ thấy một ô chọn rỗng.

> Bài học lặp lại lần thứ hai: **nhân bản không mang theo phân quyền.** Bất kỳ thao tác nào khiến nhân bản tạo lại đối tượng — đẩy thủ tục, snapshot, reinitialize — đều xoá sạch quyền trên đối tượng đó.

**Quy trình đúng, đủ ba bước:**

```
1. Sửa thủ tục trên MÁY CHỦ
2. Nhân bản đẩy xuống phân mảnh  (hoặc snapshot / reinitialize)
3. CHẠY LẠI  SQL/12_CapLaiQuyen.sql     ← đừng quên bước này
   rồi        SQL/KiemTraDongBoSP.ps1    để xác nhận
```

`12_CapLaiQuyen.sql` nay khôi phục **cả hai loại quyền** — phần A quyền bảng (gộp từ `02`, `03`, `10`), phần B quyền `EXECUTE` — và in ra bảng đối chiếu để nhìn phát hiện ngay:

```
nhom        sp_execute  bang_select  bang_deny
CoSo                24            1          0
Giangvien           20            8          6      ← bang_select = 0 là hỏng
Sinhvien            12            0          3
Truong              18            1         14
```

### 🔴 Lỗi thứ hai phát hiện khi test lại câu 8 trên CS2

Đề: *"các câu hỏi thi sẽ **ưu tiên lấy ở cơ sở mà lớp đã học**… chừng nào không đủ nữa thì mới lấy thêm cơ sở còn lại."*

Kiểm tra bảng `BODE` trên CS2:

```
TH123 (giáo viên CS1) : 158 câu    ← KHÔNG phải đề của CS2
TH657 (giáo viên CS2) :  40 câu
```

`BODE` **không nằm trong cây dẫn xuất** (nhân bản toàn bộ) nên mỗi phân mảnh đều có đủ câu hỏi của cả hai cơ sở. Bước lấy đề "LOCAL" đọc thẳng `dbo.Bode` nên vơ luôn đề của cơ sở kia rồi gắn nhãn LOCAL → **ưu tiên theo cơ sở coi như không có hiệu lực**, và mượn đề gần như không bao giờ kích hoạt.

**Cách sửa** (`SQL/13_Cau8_UuTienDungCoSo.sql`): xác định "đề của cơ sở này" bằng cách nối `BODE → GIAOVIEN → KHOA`. Bảng `KHOA` **có** trong cây dẫn xuất (lọc theo `MACS`), nên phép nối **tự động** chỉ giữ câu hỏi do giáo viên thuộc cơ sở này soạn — không cần thêm điều kiện `MACS` nào.

Kết quả đo trên CS2, môn MMTCB trình độ A:

| | Trước khi sửa | Sau khi sửa |
|---|---|---|
| Kho "của cơ sở này" | 94 (sai — gộp cả CS1) | **16** (đúng — chỉ TH657) |
| Kho mượn được của CS1 | 78 | 78 |
| Đề 30 câu phát ra | 30 LOCAL, 0 MUON | **16 LOCAL + 14 MUON** ✅ |

Đây đúng là hành vi đề mô tả: dùng hết kho của cơ sở mình rồi mới mượn cơ sở bạn.

### Sáu tiện ích CỐ Ý chỉ giữ ở máy chủ

| Thủ tục | Lý do |
|---|---|
| `sp_LamMoi_BodeMuon` | Gom `BODE` của **cả hai** cơ sở để dựng kho đề mượn. Chạy trên phân mảnh chỉ thấy đề của chính nó → kết quả **sai** |
| `sp_ChotBaoCao_DangKy` | Job chốt số liệu định kỳ |
| `SP_SAOLUU`, `SP_PHUCHOI_CSDL`, `SP_DS_SAOLUU` | Hạ tầng riêng từng instance |
| `SP_TAOLOGIN` | Tạo login cục bộ trên chính server đang chạy |

## PHẦN 3B — CÒN LẠI

| # | Việc | Ghi chú |
|---|---|---|
| 2 | **Báo cáo có NHÓM số liệu** | Thầy có nhắc loại report "nhóm số liệu theo từng nhóm". Câu 11 hiện sắp theo cơ sở nhưng chưa có band nhóm riêng với tổng con từng cơ sở |
| 3 | Câu 9 (`frmXemKetQua`) chưa gắn bộ máy in mới | Hiện chỉ xem trên lưới. Có thể thêm nút Xem trước / In như hai báo cáo kia |

---

## PHẦN 4 — CHUẨN BỊ TRẢ LỜI KHI BẢO VỆ

**Nếu Thầy hỏi "sao không dùng XtraReport?"**

XtraReport thuộc bộ DevExpress — thư viện thương mại, không đi kèm .NET. Em tự viết lớp `BaoCaoIn` trên `PrintDocument` có sẵn, **giữ nguyên cấu trúc band** Thầy dạy: ReportHeader chỉ ở trang 1, PageHeader lặp mỗi trang, ReportFooter chứa tổng nằm ngay dưới dòng cuối, PageFooter có số trang. Xem trước, in, và xuất tệp đều làm được.

**Nếu Thầy hỏi "cột nào tính ở đâu?"**

Cột **Xếp loại** và dòng **Tổng** được tính **tại máy trạm** trong report, không truy vấn từ server — đúng nguyên tắc Thầy dạy là giảm tải đường truyền. Tiêu đề động (lớp, môn, lần thi, khoảng ngày, tên chi nhánh) cũng lấy từ form chứ không đưa vào mệnh đề `SELECT`.

**Nếu Thầy hỏi "chi nhánh rẽ server thế nào?"**

ComboBox chi nhánh đổ từ view `V_DS_PHANMANH`. Khi đổi lựa chọn, sự kiện `SelectedIndexChanged` mở **kết nối mới tới đúng server đó** rồi nạp lại toàn bộ dữ liệu. Nhóm Trưởng thấy mọi chi nhánh nên ComboBox sáng; nhóm Cơ sở chỉ có cơ sở mình nên ComboBox mờ.
