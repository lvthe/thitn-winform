# Phân tích đề 4 — Thi trắc nghiệm (theo lời giảng của Thầy)

> Nguồn: `giai_de_4.txt` (bản chép lời tự động, đã gạn lọc và diễn giải lại).
> Cột **Trạng thái** là đối chiếu với DB `TN_CSDLPT` + app hiện có — bạn tự soát lại lần cuối.

---

## A. YÊU CẦU PHÂN TÁN

Trường có **2 cơ sở**: CS1 và CS2. Phân tán thành **3 mảnh**:

| Mảnh | Server | Nội dung | Kiểu |
|---|---|---|---|
| 1 | SERVER1 | Sinh viên, lớp, thông tin đăng ký thi của **cơ sở 1** | Ngang |
| 2 | SERVER2 | Y hệt mảnh 1, nhưng của **cơ sở 2** | Ngang |
| 3 | SERVER3 | **Lớp + Sinh viên của CẢ HAI cơ sở** | **DỌC** |

### Mảnh 3 — những điều Thầy nhấn mạnh

1. **Là phân mảnh DỌC** — *"chỉ chọn ra những cột cần thiết thôi"*, KHÔNG nhân bản toàn bộ cột.
2. **Chỉ dùng để TRA CỨU** — không thêm/xóa/sửa gì trên mảnh này.
3. **KHÔNG cho đăng nhập vào mảnh này.** Nguyên văn: *"chúng ta sẽ không cho người ta đăng nhập vào cái server này… nhưng mà ta vẫn dùng nó để tra cứu mã sinh viên có chưa"*.
4. **Bắt buộc phải có ít nhất MỘT chức năng trong app dùng tới mảnh này** — nếu không thì làm mảnh 3 ra để làm gì.

> ⚠️ Điểm dễ hiểu sai: mảnh 3 **không xuất hiện trong ComboBox đăng nhập**. Nó là nguồn tra cứu chạy ngầm (vd: khi nhập mã SV thì kiểm tra "mã này có chưa", "mã lớp có chưa").

---

## B. 11 CHỨC NĂNG

### Câu 1 — Form đăng nhập (2 đối tượng, 2 cách khác nhau)

| Đối tượng | Cách đăng nhập |
|---|---|
| **Giảng viên** (và cán bộ) | Mỗi người **một SQL login + mật khẩu riêng** |
| **Sinh viên** | **MỘT tài khoản SQL dùng chung**, rồi kiểm `MASV` + `PASSWORD` trong bảng SINHVIEN |

**Lý do Thầy giải thích cho tài khoản chung:** nếu tạo hàng chục ngàn login trên SQL Server thì chiếm tài nguyên server và rất khó quản lý. Thầy cũng thừa nhận cách này **kém bảo mật hơn**, nhưng chấp nhận trong phạm vi môn học.

**Bắt buộc có ô PASSWORD cho sinh viên** — Thầy nói rõ: *"nếu không có password thì không ổn, vì mã số sinh viên thì sinh viên khác cũng biết"*.

Sau khi đăng nhập đúng → hiện **mã lớp, tên lớp, họ tên**.

---

### Câu 2–6 — Các form nhập liệu

**Quy tắc chung cho MỌI form nhập liệu:** phải đủ **Thêm / Sửa / Xóa** + **Ghi** + **Phục hồi**.

- **Nút Ghi** tự nhận biết: đang Thêm → `INSERT`; đang Sửa → `UPDATE`.
- **Nút Phục hồi (Undo)**: hủy thao tác đang dở **khi CHƯA Ghi**. Đã Ghi rồi thì mức cơ bản không cần undo được.
- *(Cộng điểm)* Undo **nhiều cấp** kể cả sau khi Ghi — Thầy gợi ý dùng **Stack** (ngăn xếp) để lưu lịch sử thao tác.

**Bố cục form theo yêu cầu riêng của Thầy:**

| Form | Yêu cầu |
|---|---|
| **Khoa + Lớp** | Nhập **CẢ HAI trên CÙNG MỘT FORM** |
| **Sinh viên** | Form riêng; **Lớp chỉ để CHỌN** (combobox), không nhập lớp ở đây |
| **Giảng viên** | Chọn Khoa → nhập giảng viên vào khoa đó |
| **Bộ đề** | Không cần chọn gì; GV đăng nhập thì **tự động chỉ hiện câu hỏi do chính mình soạn** |
| **Môn học** | Chỉ 2 cột (mã, tên) — không cần số tín chỉ, vì đề này không tính điểm trung bình |

**Quyền trên bộ đề:** GV **được xem** câu hỏi của GV khác cùng môn, nhưng **chỉ được sửa/xóa câu do mình soạn**.

---

### Câu 7 — Giáo viên đăng ký thi (chuẩn bị thi)

Phòng giáo vụ / GV nhập: **lớp, môn học, trình độ, lần thi, số câu thi, ngày thi, thời gian thi (phút)**.

**Bắt buộc KIỂM TRA ĐỦ ĐỀ khi đăng ký:**
- Nếu bộ đề nguồn không đủ số câu → **báo lỗi RÕ RÀNG, nói thiếu bao nhiêu câu**.
- Ví dụ Thầy đưa: yêu cầu 30 câu, bộ đề chỉ có 18 → phải báo *"còn thiếu 12 câu"*.

> Việc kiểm tra đủ đề **nằm ở đây**, KHÔNG nằm ở chức năng Thi. Chức năng Thi chỉ việc lấy đề về.

**Hệ niên chế: mỗi môn thi tối đa 2 lần** → khóa chính của bảng đăng ký phải có thêm cột **LAN**.

---

### Câu 8 — Thi trắc nghiệm ⭐ QUAN TRỌNG NHẤT

Thầy nói thẳng: đây là **chức năng quan trọng nhất** của đề tài. Các form nhập liệu (môn học, khoa lớp) nếu không kịp thì **có thể bỏ, chỉ bị trừ điểm** — nhưng câu 8 thì không.

#### Luồng
1. SV đăng nhập bằng **MASV + password**.
2. SV chọn **môn học → ngày thi → lần thi**.
3. Bấm **Bắt đầu thi** → chương trình mới lấy đề.
4. Hết giờ → **tự động kết thúc và chấm điểm**.

#### ⚠️ Bốn ràng buộc dễ mất điểm

**(a) Chỉ hiện môn ĐÃ ĐĂNG KÝ và CHƯA THI**
Thầy phê bình rất gắt kiểu lập trình "hiện hết 100 môn rồi báo lỗi":
> *"Cái gì mà ta biết là vô lý thì đừng cho người ta chọn."*

Combobox môn học chỉ được chứa môn mà **lớp đó đã đăng ký thi trắc nghiệm** và **SV đó chưa thi**.

**(b) BẮT BUỘC dùng Stored Procedure để lấy đề**
> *"Tôi sẽ hỏi lên SP lấy đề có đáp ứng được hay không. Nếu không thì coi như mất hết phân nửa số điểm của câu này."*

**(c) Quy tắc TRÌNH ĐỘ 70/30**
- Trình độ: **A, B, C** — trong đó **A là cao nhất**.
- Nếu đăng ký trình độ A: **tối thiểu 70%** số câu phải đúng trình độ A.
- Thiếu thì được lấy bù **tối đa 30%** ở trình độ **thấp hơn ĐÚNG 1 bậc** (B).
- **Phải khống chế** — không được lấy thoải mái.
- Ví dụ Thầy: thi 100 câu, trình độ A chỉ có 80 câu → lấy 80 câu A + 20 câu B.

**(d) Ưu tiên lấy đề theo CƠ SỞ CỦA LỚP — đây là chỗ "đụng tới phân tán"**
> *"Không ưu tiên theo giảng viên dạy, mà ưu tiên theo LỚP."*

Lớp học ở cơ sở nào → **ưu tiên lấy câu hỏi do giảng viên ở cơ sở đó soạn**. **Chỉ khi không đủ** mới lấy thêm từ cơ sở còn lại.

#### Các quy định khác

| Vấn đề | Quy định |
|---|---|
| Lấy ngẫu nhiên | Dùng sẵn của SQL Server (`NEWID()`), **không cần thuật toán** |
| Xáo trộn câu hỏi | **Bắt buộc** |
| Tính thời gian | Bắt đầu tính **khi đã tải xong đề về máy**, không tính lúc đi lấy đề |
| Thang điểm | 10, **mọi câu điểm bằng nhau** |
| Câu đã thi lần trước | **Được phép lấy lại** — không bắt buộc loại trừ |
| Hết giờ | **Tự động** ngắt + chấm, không đợi người dùng bấm |
| Sau khi chấm | Hiện điểm → bấm OK → ghi điểm, kết thúc |

---

### Câu 9 — Báo cáo 1: In lại bài đã thi (phúc khảo)

SV đăng nhập rồi in ra bài thi của mình:

- **Đầu báo cáo:** mã SV, họ tên, môn thi, ngày thi (lấy từ đăng ký), lần thi.
- **Thân báo cáo, mỗi câu:** số thứ tự, **mã câu hỏi trong bộ đề**, nội dung, 4 lựa chọn A/B/C/D, **đáp án đúng**, **và câu SV đã chọn**.

**Mục đích:** để giảng viên giải thích khi SV thắc mắc *"em làm đúng mà sao chỉ 5 điểm"*.

> ⚠️ **Ký hiệu trong mẫu báo cáo của Thầy:** `X` = đại diện một ký tự, `99` = đại diện một con số. **Không phải giá trị thật** — nhiều bạn hiểu nhầm.

#### ⚠️ Cảnh báo dạng chuẩn (dễ mất điểm)

Thầy nói rõ: bảng Thầy phát ban đầu **không đủ** để làm chức năng này, sinh viên phải **tự thêm bảng lưu bài thi**. Và:

> *"Thêm vào một cái bảng nữa sao cho HỢP LÝ. Không được vi phạm dạng chuẩn, không dư thừa thông tin. Nếu thêm vô mà vi phạm dạng chuẩn thì coi như MẤT ĐIỂM câu này."*

---

### Câu 10 — Báo cáo 2: Bảng điểm môn học

Giảng viên chọn **tên lớp + tên môn học + lần thi** (chính là khóa chính của bảng đăng ký) → ra bảng điểm thi hết môn của lớp.

- Cột: mã SV, họ tên, **điểm số**, **điểm chữ**.
- **Làm tròn đến 0.5** theo mẫu của trường: chỉ có 5 / 5.5 / 6… **không có 2.25**.
- Điểm chữ quy đổi tương ứng.

---

### Câu 11 — Báo cáo 3: Danh sách đăng ký thi của **CẢ HAI CƠ SỞ**

Người dùng nhập **từ ngày → đến ngày** (đầu đợt thi đến cuối đợt) → liệt kê: **lớp, môn học, giảng viên đăng ký, ngày thi**, kèm cột **ĐÃ THI hay CHƯA** (đã thi đánh dấu `X`, chưa thì để trống).

#### ⚠️ RÀNG BUỘC ĐẶC BIỆT — Thầy nhắc lại 2 lần

> *"Riêng câu 11 này KHÔNG được về server chủ. Bắt buộc phải chạy trên 2 phân mảnh."*
> *"Ý tưởng của tôi là muốn các bạn sử dụng phép tính gọi là **UNION**."*

Nghĩa là: báo cáo này phải **nối dữ liệu từ SERVER1 và SERVER2 bằng `UNION`**, tuyệt đối không truy vấn thẳng vào Publisher.

> 📌 Đối chiếu: các chức năng nhập liệu khác thì **ĐƯỢC PHÉP** về server chủ để kiểm tra số liệu — Thầy đồng ý. **Chỉ riêng câu 11 là cấm.**

---

## C. PHÂN QUYỀN — 4 NHÓM

Thầy phân biệt **phân quyền tĩnh** (tạo sẵn nhóm quyền trên hệ thống rồi gán tài khoản vào nhóm) và **phân quyền động** (người dùng tự định nghĩa quyền qua giao diện).
👉 **Môn này chỉ làm phân quyền TĨNH.**

### 1. Trưởng (Trưởng phòng đào tạo)
- Đăng nhập được vào **bất kỳ phân mảnh nào**.
- **CHỈ XEM** — không thêm/xóa/sửa.
- Tại một thời điểm **chỉ thấy dữ liệu của một cơ sở**; muốn xem cơ sở khác thì **chọn lại cơ sở**.
- Chạy được **cả 3 báo cáo**.
- Được tạo tài khoản — nhưng **CHỈ tạo tài khoản nhóm Trưởng**, không tạo cho 3 nhóm kia.
- Đặc điểm hay: Trưởng xem được cơ sở khác **dù trên server đó chưa có tài khoản riêng**.

### 2. Cơ sở
- **Toàn quyền** (thêm/xóa/sửa) — nhưng **chỉ trên cơ sở của mình**.
- **Không được đăng nhập cơ sở khác.** Muốn làm việc trên cơ sở nào thì **phải có tài khoản** trên đó.
- Được tạo tài khoản mới cho **2 nhóm: Cơ sở và Giảng viên**.

### 3. Giảng viên
- Bị hạn chế nhiều: **KHÔNG** được nhập Khoa mới, **KHÔNG** nhập Lớp mới, **KHÔNG** nhập Sinh viên mới.
- **Chỉ được cập nhật đề thi**, và chỉ sửa/xóa **câu hỏi do chính mình soạn**.
- **Được THI THỬ nhưng KHÔNG ghi điểm.** ⭐

### 4. Sinh viên
- Nói gọn là "chỉ được thi", nhưng thực tế cần quyền: đọc bộ đề, **ghi BANGDIEM**, **ghi bảng chi tiết bài thi**.

> Thầy lưu ý: phải tự suy ra chức năng nào đụng tới bảng nào để cấp quyền cho đúng.

### Form quản trị
Cần **2 form**: **Đăng nhập** và **Tạo tài khoản** (tạo login, đặt password, **đổi password**, gán nhóm quyền).

---

## D. BA PHẦN CỦA MỘT ỨNG DỤNG QUẢN LÝ

Thầy nhấn mạnh mọi app quản lý CSDL đều có 3 phần:

1. **Nhập liệu** — các form danh mục.
2. **Báo cáo thống kê** — thực tế nhiều gấp 5–10 lần phần nhập liệu.
3. **Quản trị** — tạo tài khoản + phân quyền, **và sao lưu / phục hồi dữ liệu** (*"tạo một bảng sao lưu trên DB để về sau người dùng phục hồi lại được nếu có sự cố"*).

---

## E. CÁC OPTION CỘNG ĐIỂM (không bắt buộc)

| # | Option | Ghi chú của Thầy |
|---|---|---|
| 1 | **Đảo luôn đáp án** A/B/C/D khi ra đề | Phải đảm bảo nội dung câu hỏi không mâu thuẫn sau khi đảo (vd: câu có phương án "tất cả đều đúng") |
| 2 | **Khôi phục bài thi khi sự cố** (cúp điện, treo máy) | SV đăng nhập lại → lấy lại bài cũ, **thời gian còn lại đúng như lúc mất** (mất ở phút 25/30 thì vào tiếp còn 5 phút), các câu đã chọn giữ nguyên |
| 3 | **Undo nhiều cấp** trên form nhập liệu | Dùng **Stack**, undo được cả thao tác đã Ghi |
| 4 | Hiện câu hỏi của GV khác cùng môn | Được, nhưng **phải chặn** không cho sửa/xóa |

---

## F. CHECKLIST ĐỐI CHIẾU VỚI BÀI ĐANG LÀM

### ✅ Đã có / đã đúng

| Mục | Ghi chú |
|---|---|
| 3 mảnh: CS1, CS2 (ngang) + TRACUU (dọc) | Cây lọc đã khớp cây mẫu |
| Mảnh 3 chỉ có `LOP` + `SINHVIEN`, đã cắt cột | `SINHVIEN(MASV,HO,TEN,MALOP)`, `LOP(MALOP,TENLOP)` |
| Đăng nhập 2 kiểu | Login chung `sv` cho SV; login riêng cho GV/CoSo/Trưởng |
| `SINHVIEN.PASSWORD` | Đã có cột |
| `BODE.TRINHDO`, `GIAOVIEN_DANGKY.TRINHDO` | Đã có → làm được quy tắc 70/30 |
| `GIAOVIEN_DANGKY(SOCAUTHI, THOIGIAN, LAN)` | Đủ cho câu 7 |
| `PhieuThi.THITHU` (bit) | Đã có sẵn cột cho "GV thi thử không ghi điểm" |
| `PhieuThi.BATDAU / HANNOP / DANOP` | Hạ tầng sẵn cho option khôi phục bài thi |
| `ChiTiet_BaiThi.DACHON` | Lưu được câu SV đã chọn → làm được báo cáo phúc khảo |
| 4 role: Truong / CoSo / Giangvien / Sinhvien | Phân quyền tĩnh, đúng hướng |

### Trạng thái xử lý (cập nhật 06/08/2026)

| # | Vấn đề | Trạng thái |
|---|---|---|
| 1 | Câu 11 chạy ở Publisher | ✅ **ĐÃ SỬA** — `sp_BaoCao_DangKy` chuyển xuống SERVER1+SERVER2, **đã gỡ khỏi server chủ**; app UNION 2 phân mảnh |
| 2 | Mảnh 3 cho đăng nhập | ✅ **ĐÃ SỬA** — bỏ khỏi ComboBox đăng nhập; tạo login dịch vụ `tracuu` chỉ-đọc |
| 3 | `PhieuThi_CauHoi` lưu lặp nội dung | ⚠️ **GIỮ NGUYÊN, có lý lẽ**: là *snapshot đề lúc thi* + phục vụ **đề mượn** (cột `NGUON`) nên không join ngược được. PK đã là `(MAPHIEU, STT)` — hợp lý |
| 4 | Ưu tiên đề theo cơ sở của LỚP | ✅ **ĐÚNG SẴN** — `sp_LayDeThi` lấy `@MACS` từ lớp của SV |
| 5 | Quy tắc 70/30 trình độ | ✅ **ĐÚNG SẴN** — có khống chế trần 30% |
| 6 | Combobox môn thi chỉ hiện môn chưa thi | ✅ **ĐÃ LÀM** trong `frmThi` |
| 7 | GV thi thử không ghi điểm | ✅ **ĐÚNG SẴN** — `sp_NopBai` lấy cờ `THITHU` từ **server**, client không giả mạo được |
| 8 | Làm tròn 0.5 + điểm chữ | ✅ **ĐÃ SỬA** — `ROUND(DIEM*2,0)/2`, điểm chữ tính từ điểm đã làm tròn |
| 9 | Form Khoa + Lớp chung một form | ✅ **ĐÃ LÀM** — `frmKhoaLop` master-detail |
| 10 | Trưởng chỉ tạo tài khoản nhóm Trưởng | ✅ **ĐÚNG SẴN** trong `SP_TAOLOGIN` |
| 11 | Kiểm đủ đề + báo thiếu bao nhiêu câu | ✅ **ĐÃ SỬA** — báo *"CÒN THIẾU 21 CÂU"* |
| 12 | Sao lưu / phục hồi dữ liệu | ⬜ **CHƯA LÀM** |
| 13 | Nút Phục hồi (Undo) | ✅ mức cơ bản (`RejectChanges`). ⬜ Undo nhiều cấp bằng Stack (option cộng điểm) |
| 14 | Đổi password | ✅ **ĐÃ THÊM** — `SP_DOIMATKHAU` (cán bộ) + `sp_DoiMatKhau_SV` (sinh viên) |

### 🔴 Hai lỗi NẶNG phát hiện thêm và đã sửa

| Lỗi | Chi tiết |
|---|---|
| **Mượn đề chưa bao giờ chạy** | Cùng một mã `CAUHOI` có mặt ở **cả hai nguồn gom đề** — đo trên `SERVER1`: cả 276 mã trong `BODE` đều có trong `Bode_Muon`. Bảng tạm `#De` khoá `PRIMARY KEY(CAUHOI)` nên câu `MUON` đụng khoá với câu `LOCAL` cùng mã → bị loại sạch → đề luôn ra **100% LOCAL**. Sửa: `#De` khoá `(CAUHOI, NGUON)`, `ChiTiet_BaiThi` đổi PK sang `STT`. Sau sửa: **94 LOCAL + 6 MUON** |
| **Phân quyền trống rỗng** | Nhóm `Giangvien` không SELECT được `MONHOC`, không EXECUTE được `sp_Bode_DS` → câu 6 chết hoàn toàn. Đã cấp đủ 31 quyền EXECUTE (`SQL/03_PhanQuyen.sql`) |

### Bộ script SQL đã tạo

| File | Nội dung |
|---|---|
| `SQL/01_Cau1_DangNhap_TaiKhoan.sql` | SP đăng nhập, đổi mật khẩu, thông tin người dùng |
| `SQL/02_Cau1_TaiKhoanTraCuu_SERVER3.sql` | Login dịch vụ `tracuu` chỉ-đọc cho mảnh 3 |
| `SQL/03_PhanQuyen.sql` | Phân quyền tĩnh 4 nhóm |
| `SQL/04_Cau7_Cau8_SuaKhoMuonDe.sql` | Lọc `MACS` trong SP thay vì dựa vào replication |
| `SQL/05_Cau8_SuaTrungMaCauHoi.sql` | Sửa lỗi trùng mã làm hỏng chức năng mượn đề |
| `SQL/06_Cau10_Cau11_BaoCao.sql` | Làm tròn 0.5; câu 11 chuyển xuống phân mảnh |

---

## G. THỨ TỰ ƯU TIÊN NẾU THIẾU THỜI GIAN

Theo đúng lời Thầy:

1. **Câu 8 (Thi)** — quan trọng nhất, **phải dùng SP lấy đề** (không thì mất nửa số điểm).
2. **Câu 7 (Đăng ký + kiểm tra đủ đề)** — điều kiện đầu vào của câu 8.
3. **Câu 9, 10, 11 (3 báo cáo)** — đặc biệt câu 11 phải `UNION` 2 phân mảnh.
4. **Câu 1 + phân quyền** — nền tảng.
5. Các form nhập liệu (môn học, khoa/lớp) — *"không kịp thì có thể bỏ, chỉ bị trừ điểm"*, dữ liệu có thể nhập tay bằng SSMS.
