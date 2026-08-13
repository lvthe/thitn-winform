<#
=======================================================================
  CASE TEST TOÀN TUYẾN - từ tạo môn học tới lúc Trưởng tra cứu
  Chạy:  powershell -ExecutionPolicy Bypass -File SQL\CaseTest_ToanTuyen.ps1
  -----------------------------------------------------------------------
  Kịch bản đi đúng quy trình nghiệp vụ sau khi đã tách phân công khỏi
  đăng ký thi (SQL/17) và vá kho đề mượn (SQL/18):

     1. Cơ sở 1 tạo môn học mới + lớp mới + giáo viên mới + phân công dạy
     2. Cơ sở 1 thêm sinh viên mới vào lớp đó
     3. Giáo viên soạn bộ đề (đủ trình độ A/B/C, đáp án rải đều A/B/C/D)
        - kèm case ĐĂNG KÝ KHI KHO ĐỀ CÒN THIẾU -> phải báo lỗi có số liệu
        - kèm case MƯỢN ĐỀ của cơ sở 2 qua nhân bản
     4. Sinh viên vào thi -> nộp bài -> có điểm
     5. Giáo viên xem bảng điểm + phúc khảo bài của sinh viên
     6. Trưởng chạy báo cáo, kiểm tra chỉ-xem, và tra cứu mảnh dọc

  Script IDEMPOTENT: chạy lại bao nhiêu lần cũng được, bước 0 dọn sạch
  dữ liệu test của lần trước.
=======================================================================
#>

$ErrorActionPreference = 'Stop'

$CHU     = 'localhost\SERVER'
$CS1     = 'localhost\SERVER1'
$CS2     = 'localhost\SERVER2'
$TRACUU  = 'localhost\SERVER3'

$tmp = Join-Path $env:TEMP ('casetest_' + [guid]::NewGuid().ToString('N') + '.sql')
$script:soBuoc = 0
$script:loi    = 0

# -b : sqlcmd dừng và trả mã lỗi khi gặp lỗi KHÔNG được bắt.
#      Các case "phải bị chặn" đều nằm trong TRY/CATCH nên không kích hoạt -b,
#      nhờ vậy phân biệt được lỗi thật với lỗi cố ý.
function Chay {
    param([string]$May, [string]$Sql, [string]$TieuDe,
          [string]$TaiKhoan = $null, [string]$MatKhau = $null)
    $script:soBuoc++
    Write-Host ''
    Write-Host ("=" * 72) -ForegroundColor DarkGray
    Write-Host ("[{0}]  {1}" -f $script:soBuoc, $TieuDe) -ForegroundColor Cyan
    $ai = if ($TaiKhoan) { "$May  (đăng nhập: $TaiKhoan)" } else { $May }
    Write-Host ("       {0}" -f $ai) -ForegroundColor DarkGray
    Write-Host ("=" * 72) -ForegroundColor DarkGray

    $Sql | Out-File -Encoding utf8 $tmp
    if ($TaiKhoan) {
        $ra = & sqlcmd -S $May -U $TaiKhoan -P $MatKhau -b -f 65001 -i $tmp -W -s'|' 2>&1
    } else {
        $ra = & sqlcmd -S $May -E -b -f 65001 -i $tmp -W -s'|' 2>&1
    }
    $ra | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        $script:loi++
        Write-Host '   >>> BƯỚC NÀY THẤT BẠI' -ForegroundColor Red
    }
}

# Các merge agent của hệ thống này chạy LIÊN TỤC (continuous), nên không
# "khởi động rồi chờ chạy xong" được - stop_execution_date vĩnh viễn NULL.
# Cách đúng: chờ tới khi DỮ LIỆU cần thiết đã có mặt ở đích.
function ChoDuLieu {
    param([string]$May, [string]$Kiem, [string]$MoTa, [int]$GiayToiDa = 150)
    $script:soBuoc++
    Write-Host ''
    Write-Host ("=" * 72) -ForegroundColor DarkGray
    Write-Host ("[{0}]  Chờ nhân bản: {1}" -f $script:soBuoc, $MoTa) -ForegroundColor Yellow
    Write-Host ("       {0}" -f $May) -ForegroundColor DarkGray
    Write-Host ("=" * 72) -ForegroundColor DarkGray

    $moc = [datetime]::Now
    while (([datetime]::Now - $moc).TotalSeconds -lt $GiayToiDa) {
        $r = & sqlcmd -S $May -E -h -1 -W -f 65001 -Q "USE TN_CSDLPT; SET NOCOUNT ON; $Kiem"
        $r = ($r | Where-Object { $_ -and $_ -notmatch 'rows affected' -and $_ -notmatch 'Changed database' } |
              Select-Object -First 1)
        if ($r -and $r.Trim() -eq '1') {
            Write-Host ("   đã tới nơi sau {0:N0} giây." -f ([datetime]::Now - $moc).TotalSeconds) -ForegroundColor Green
            return
        }
        Start-Sleep -Seconds 3
    }
    $script:loi++
    Write-Host ("   >>> QUÁ {0} GIÂY VẪN CHƯA ĐỒNG BỘ" -f $GiayToiDa) -ForegroundColor Red
}

Write-Host ''
Write-Host '######  CASE TEST TOÀN TUYẾN  ######' -ForegroundColor White

#=======================================================================
# BƯỚC 0 - DỌN DỮ LIỆU TEST CŨ (chạy trên cả 3 server để sạch hẳn)
#=======================================================================
$sqlDon = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

DELETE FROM dbo.ChiTiet_BaiThi   WHERE MASV = 'SV999001' OR MAMH = 'KTLT';
DELETE FROM dbo.PhieuThi_CauHoi  WHERE MAPHIEU IN (SELECT MAPHIEU FROM dbo.PhieuThi
                                                   WHERE MASV='SV999001' OR MAMH='KTLT');
DELETE FROM dbo.PhieuThi         WHERE MASV = 'SV999001' OR MAMH = 'KTLT';
DELETE FROM dbo.BANGDIEM         WHERE MASV = 'SV999001' OR MAMH = 'KTLT';
DELETE FROM dbo.GIAOVIEN_DANGKY  WHERE MAMH = 'KTLT' OR MALOP = N'TH99' OR MAGV = 'TH999';
DELETE FROM dbo.SINHVIEN         WHERE MASV = 'SV999001';
DELETE FROM dbo.Bode_Muon        WHERE MAMH = 'KTLT' OR MAGV = 'TH999';
DELETE FROM dbo.BODE             WHERE MAMH = 'KTLT' OR MAGV = 'TH999';
DELETE FROM dbo.LOP              WHERE MALOP = N'TH99';
DELETE FROM dbo.GIAOVIEN         WHERE MAGV = 'TH999';
DELETE FROM dbo.MONHOC           WHERE MAMH = 'KTLT';

IF DATABASE_PRINCIPAL_ID('TH999') IS NOT NULL DROP USER [TH999];
PRINT N'   đã dọn dữ liệu test cũ.';
'@
Chay $CS1 $sqlDon 'BƯỚC 0 - dọn dữ liệu test cũ (CS1)'
Chay $CS2 $sqlDon 'BƯỚC 0 - dọn dữ liệu test cũ (CS2)'
Chay $CHU $sqlDon 'BƯỚC 0 - dọn dữ liệu test cũ (máy chủ)'
& sqlcmd -S $CS1 -E -Q "IF SUSER_ID('TH999') IS NOT NULL DROP LOGIN [TH999];" | Out-Null

#=======================================================================
# BƯỚC 1 - Cơ sở 1: môn học + lớp + giáo viên + tài khoản + PHÂN CÔNG
#=======================================================================
$sql1 = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

/* Khoa bất kỳ của cơ sở này - phân mảnh đã lọc sẵn nên KHOA ở đây
   chắc chắn thuộc CS1, không cần điều kiện MACS. */
DECLARE @makh nchar(8) = (SELECT TOP 1 MAKH FROM dbo.KHOA ORDER BY MAKH);
PRINT N'   Khoa dùng cho test: ' + RTRIM(@makh);

INSERT INTO dbo.MONHOC(MAMH, TENMH)  VALUES('KTLT', N'Kỹ thuật lập trình');
INSERT INTO dbo.LOP(MALOP, TENLOP, MAKH) VALUES(N'TH99', N'TIN HỌC 2099', @makh);
INSERT INTO dbo.GIAOVIEN(MAGV, HO, TEN, MAKH, HOCVI)
     VALUES('TH999', N'NGUYEN VAN', N'TEST', @makh, N'Thạc sĩ');

/* Tài khoản giảng viên: tên đăng nhập PHẢI trùng MAGV, vì các thủ tục
   nhận diện giảng viên bằng SUSER_SNAME().
   SP_TAOLOGIN xét quyền bằng ORIGINAL_LOGIN() - tức LOGIN MỞ KẾT NỐI,
   nên bước này phải đăng nhập THẬT bằng coso1, mượn ngữ cảnh bằng
   EXECUTE AS sẽ không qua được. */
EXEC dbo.SP_TAOLOGIN @username = N'TH999', @password = N'Gv@12345', @role = N'Giangvien';

/* ★ Phân công giảng dạy - bước MỚI, làm TRƯỚC khi đăng ký kỳ thi */
EXEC dbo.sp_PhanCong_Them @MAGV = 'TH999', @MAMH = 'KTLT', @MALOP = N'TH99';

SELECT kiem_tra = N'Phân công vừa tạo', MAGV, MAMH, MALOP, LAN,
       SOCAUTHI, trang_thai = CASE WHEN SOCAUTHI IS NULL
                                   THEN N'Mới phân công (đúng)'
                                   ELSE N'SAI - đáng lẽ chưa có kỳ thi' END
FROM dbo.GIAOVIEN_DANGKY WHERE MAMH='KTLT';
'@
Chay $CS1 $sql1 'BƯỚC 1 - CS1 tạo môn học, lớp, giáo viên, tài khoản và PHÂN CÔNG dạy' 'coso1' 'Coso@123'

#=======================================================================
# BƯỚC 1b - kiểm chứng: giảng viên mới thấy đúng MỘT môn được phân công
#=======================================================================
$sql1b = @'
USE TN_CSDLPT;
SET NOCOUNT ON;
PRINT N'--- Môn học TH999 thấy ở màn Soạn bộ đề (phải đúng 1 dòng: KTLT) ---';
EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_DS_MonHoc_SoanDe;
REVERT;

PRINT N'--- TH999 đăng ký kỳ thi cho môn KHÁC (chưa phân công) -> phải BỊ CHẶN ---';
BEGIN TRY
    EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_ChuanBiThi @MAGV='TH999', @MALOP=N'TH99', @MAMH='AVCB',
         @TRINHDO='A', @LAN=1, @SOCAUTHI=10, @NGAYTHI=NULL, @THOIGIAN=15;
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH
'@
Chay $CS1 $sql1b 'BƯỚC 1b - kiểm chứng lọc môn theo phân công'

#=======================================================================
# BƯỚC 2 - Cơ sở 1: thêm sinh viên mới vào lớp vừa tạo
#=======================================================================
$sql2 = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

INSERT INTO dbo.SINHVIEN(MASV, HO, TEN, NGAYSINH, DIACHI, MALOP, [PASSWORD])
VALUES('SV999001', N'TRAN THI', N'HOA', '2005-03-15', N'Số 1 Đường Test', N'TH99', N'123');

SELECT kiem_tra = N'Sinh viên mới', MASV, HO, TEN, MALOP, mat_khau = [PASSWORD]
FROM dbo.SINHVIEN WHERE MASV = 'SV999001';

PRINT N'--- Sinh viên đăng nhập bằng MASV + mật khẩu (SQL login chung "sv") ---';
EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_DangNhap_SV @MASV = 'SV999001', @PASSWORD = N'123';
REVERT;
'@
Chay $CS1 $sql2 'BƯỚC 2 - CS1 thêm sinh viên mới + kiểm tra đăng nhập được'

#=======================================================================
# Chờ môn học mới lan sang Cơ sở 2 (MONHOC nhân bản toàn bộ)
#=======================================================================
ChoDuLieu $CS2 "SELECT COUNT(*) FROM dbo.MONHOC WHERE MAMH='KTLT';" `
          'môn KTLT xuất hiện ở CS2'

#=======================================================================
# BƯỚC 3a - Cơ sở 2 cũng dạy môn này và soạn đề -> để CS1 MƯỢN sau
#=======================================================================
$sql3a = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.MONHOC WHERE MAMH='KTLT')
    BEGIN RAISERROR(N'Môn KTLT chưa nhân bản sang CS2 - kiểm tra merge agent.',16,1); RETURN; END

DECLARE @lop nchar(15) = (SELECT TOP 1 MALOP FROM dbo.LOP ORDER BY MALOP);
DECLARE @gv  char(8)   = (SELECT TOP 1 g.MAGV FROM dbo.GIAOVIEN g
                          JOIN dbo.KHOA k ON g.MAKH = k.MAKH ORDER BY g.MAGV);
PRINT N'   CS2 dùng giáo viên ' + RTRIM(@gv) + N' và lớp ' + RTRIM(@lop);

IF NOT EXISTS (SELECT 1 FROM dbo.GIAOVIEN_DANGKY WHERE MAMH='KTLT' AND MALOP=@lop)
    EXEC dbo.sp_PhanCong_Them @MAGV = @gv, @MAMH = 'KTLT', @MALOP = @lop;

/* 4 câu trình độ A của cơ sở 2 - chính là kho mà CS1 sẽ mượn.
   T-SQL không cho ghép chuỗi ngay tại chỗ truyền tham số cho EXEC,
   nên phải dựng sẵn vào biến. */
DECLARE @i int = 1, @nd nvarchar(max);
WHILE @i <= 4
BEGIN
    SET @nd = N'[CS2] Câu hỏi mượn số ' + CAST(@i AS nvarchar(3));
    EXEC dbo.sp_Bode_Them @MAMH='KTLT', @TRINHDO='A', @NOIDUNG = @nd,
         @A=N'Phương án A', @B=N'Phương án B', @C=N'Phương án C', @D=N'Phương án D',
         @DAP_AN='B', @MAGV = @gv;
    SET @i = @i + 1;
END

SELECT kiem_tra = N'Kho đề KTLT tại CS2',
       trong_Bode      = (SELECT COUNT(*) FROM dbo.Bode      WHERE MAMH='KTLT'),
       trong_Bode_Muon = (SELECT COUNT(*) FROM dbo.Bode_Muon WHERE MAMH='KTLT'),
       ghi_chu = N'Hai số phải BẰNG NHAU - đây là lỗ hổng đã vá ở SQL/18';
'@
Chay $CS2 $sql3a 'BƯỚC 3a - CS2 soạn 4 câu KTLT (kho cho CS1 mượn)'

#=======================================================================
# ĐƯỜNG ĐI CỦA "MƯỢN ĐỀ" - ba chặng, phải chờ đúng từng chặng:
#
#   1. CS2 ghi dbo.Bode          -> merge LÊN máy chủ
#   2. Máy chủ dựng lại Bode_Muon bằng sp_LamMoi_BodeMuon
#      (job tự chạy mỗi 5 phút; ở đây gọi thẳng cho khỏi chờ)
#   3. Bode_Muon merge XUỐNG CS1
#
# Chỉ máy chủ mới dựng được Bode_Muon vì chỉ ở đó KHOA mới có đủ hai cơ sở.
#=======================================================================
ChoDuLieu $CHU "SELECT CASE WHEN COUNT(*) >= 4 THEN 1 ELSE 0 END FROM dbo.Bode WHERE MAMH='KTLT' AND CAUHOI >= 1500000;" `
          '4 câu của CS2 lên tới máy chủ'

Chay $CHU 'USE TN_CSDLPT; SET NOCOUNT ON; EXEC dbo.sp_LamMoi_BodeMuon;' `
     'Máy chủ dựng lại kho đề mượn (thay vì chờ job 5 phút)'

ChoDuLieu $CS1 "SELECT CASE WHEN COUNT(*) >= 4 THEN 1 ELSE 0 END FROM dbo.Bode_Muon WHERE MAMH='KTLT' AND RTRIM(MACS)='CS2';" `
          'kho đề mượn của CS1 nhận đủ 4 câu từ CS2'

#=======================================================================
# BƯỚC 3b - Giáo viên CS1 soạn bộ đề: đủ trình độ A/B/C, đáp án A/B/C/D
#=======================================================================
$sql3b = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

/*--- CASE 1: đăng ký khi kho đề CÒN TRỐNG -> phải báo lỗi CÓ SỐ LIỆU ---*/
PRINT N'--- CASE 1: kho đề trống mà đăng ký 30 câu ---';
BEGIN TRY
    EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_ChuanBiThi @MAGV='TH999', @MALOP=N'TH99', @MAMH='KTLT',
         @TRINHDO='A', @LAN=1, @SOCAUTHI=30, @NGAYTHI=NULL, @THOIGIAN=30;
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải báo thiếu đề.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH

/*--- Soạn đề: 8 câu trình độ A, 3 câu B, 2 câu C.
      Đáp án đúng rải đều A/B/C/D để kiểm luôn khâu chấm điểm. ---*/
PRINT N'--- Soạn 13 câu (8A + 3B + 2C), đáp án rải đều A/B/C/D ---';
DECLARE @td char(1), @i int, @n int, @da char(1), @nd nvarchar(max);
DECLARE cur CURSOR FOR SELECT 'A',8 UNION ALL SELECT 'B',3 UNION ALL SELECT 'C',2;
OPEN cur; FETCH NEXT FROM cur INTO @td, @n;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @i = 1;
    WHILE @i <= @n
    BEGIN
        SET @da = CASE (@i % 4) WHEN 1 THEN 'A' WHEN 2 THEN 'B' WHEN 3 THEN 'C' ELSE 'D' END;
        SET @nd = N'[CS1] Câu trình độ ' + @td + N' số ' + CAST(@i AS nvarchar(3))
                + N' - đáp án đúng là ' + @da;
        EXECUTE AS LOGIN = 'TH999';
        EXEC dbo.sp_Bode_Them @MAMH='KTLT', @TRINHDO=@td, @NOIDUNG=@nd,
             @A=N'Đáp án A', @B=N'Đáp án B', @C=N'Đáp án C', @D=N'Đáp án D',
             @DAP_AN=@da;
        REVERT;
        SET @i = @i + 1;
    END
    FETCH NEXT FROM cur INTO @td, @n;
END
CLOSE cur; DEALLOCATE cur;

SELECT kiem_tra = N'Bộ đề KTLT vừa soạn', TRINHDO, so_cau = COUNT(*),
       cac_dap_an = STRING_AGG(RTRIM(DAP_AN), ',') WITHIN GROUP (ORDER BY CAUHOI)
FROM dbo.Bode WHERE MAMH='KTLT' AND MAGV='TH999' GROUP BY TRINHDO;

SELECT kiem_tra = N'Kho đề nhìn từ CS1',
       de_cua_CS1 = (SELECT COUNT(*) FROM dbo.Bode b
                     JOIN dbo.Giaovien g ON b.MAGV=g.MAGV
                     JOIN dbo.Khoa k ON g.MAKH=k.MAKH
                     WHERE b.MAMH='KTLT' AND b.TRINHDO='A'),
       muon_duoc_cua_CS2 = (SELECT COUNT(*) FROM dbo.Bode_Muon
                            WHERE MAMH='KTLT' AND TRINHDO='A' AND MACS <> N'CS1');

/*--- CASE 2: giảng viên KHÁC sửa đề của TH999 -> phải bị chặn ---*/
PRINT N'--- CASE 2: giảng viên khác sửa đề của TH999 ---';
DECLARE @ch int = (SELECT TOP 1 CAUHOI FROM dbo.Bode WHERE MAGV='TH999' ORDER BY CAUHOI);
BEGIN TRY
    EXECUTE AS LOGIN = 'TH123';
    EXEC dbo.sp_Bode_Sua @CAUHOI=@ch, @MAMH='KTLT', @TRINHDO='A',
         @NOIDUNG=N'phá hoại', @A=N'x', @B=N'x', @C=N'x', @D=N'x', @DAP_AN='A';
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH

/*--- CASE 3: đăng ký 10 câu trình độ A -> phải THÀNH CÔNG ---*/
PRINT N'--- CASE 3: đăng ký kỳ thi 10 câu trình độ A, thi HÔM NAY ---';
EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_ChuanBiThi @MAGV='TH999', @MALOP=N'TH99', @MAMH='KTLT',
         @TRINHDO='A', @LAN=1, @SOCAUTHI=10,
         @NGAYTHI = NULL, @THOIGIAN=30;
REVERT;

/* NGAYTHI phải là HÔM NAY thì sp_LayDeThi mới cho vào thi */
UPDATE dbo.GIAOVIEN_DANGKY SET NGAYTHI = CAST(GETDATE() AS date)
WHERE MAMH='KTLT' AND MALOP=N'TH99' AND LAN=1;

SELECT kiem_tra = N'Dòng đăng ký sau khi ĐIỀN TIẾP', MAGV, MAMH, MALOP, LAN,
       TRINHDO, SOCAUTHI, THOIGIAN, NGAYTHI,
       so_dong = (SELECT COUNT(*) FROM dbo.GIAOVIEN_DANGKY WHERE MAMH='KTLT' AND MALOP=N'TH99'),
       ghi_chu = N'so_dong phải = 1 (UPDATE chứ không nhân đôi)'
FROM dbo.GIAOVIEN_DANGKY WHERE MAMH='KTLT' AND MALOP=N'TH99';
'@
Chay $CS1 $sql3b 'BƯỚC 3b - CS1 soạn bộ đề + 3 case ràng buộc + đăng ký kỳ thi'

#=======================================================================
# BƯỚC 4 - Sinh viên vào thi -> nộp bài -> có điểm
#=======================================================================
$sql4 = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

PRINT N'--- Lịch thi sinh viên nhìn thấy ---';
EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_LichThi @MASV = 'SV999001';
REVERT;

PRINT N'--- Phát đề (câu 8): ưu tiên đề CS1, thiếu thì MƯỢN CS2 ---';
EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_LayDeThi @MASV='SV999001', @MAMH='KTLT', @LAN=1;
REVERT;

DECLARE @phieu uniqueidentifier =
    (SELECT TOP 1 MAPHIEU FROM dbo.PhieuThi
     WHERE MASV='SV999001' AND MAMH='KTLT' AND LAN=1 AND DANOP=0 ORDER BY BATDAU DESC);

SELECT kiem_tra = N'Nguồn câu hỏi trong đề', NGUON, so_cau = COUNT(*)
FROM dbo.PhieuThi_CauHoi WHERE MAPHIEU=@phieu GROUP BY NGUON;

/* Làm bài: cố ý làm ĐÚNG 7 câu đầu, SAI 3 câu cuối -> điểm phải là 7.0 */
DECLARE @json nvarchar(max) =
    (SELECT STRING_AGG(
        '{"STT":' + CAST(q.STT AS varchar(5)) + ',"DACHON":"'
        + CASE WHEN q.STT <= 7 THEN RTRIM(q.DAP_AN)
               ELSE CASE WHEN RTRIM(q.DAP_AN) = 'A' THEN 'B' ELSE 'A' END END
        + '"}', ',')
     FROM dbo.PhieuThi_CauHoi q WHERE q.MAPHIEU = @phieu);
SET @json = '[' + @json + ']';

PRINT N'--- Nộp bài: cố ý đúng 7/10 ---';
EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_NopBai @MASV='SV999001', @MAPHIEU=@phieu, @DapAn=@json;
REVERT;

SELECT kiem_tra = N'Điểm đã ghi vào BANGDIEM', MASV, MAMH, LAN, DIEM,
       ghi_chu = CASE WHEN DIEM = 7 THEN N'ĐÚNG (7/10 câu)'
                      ELSE N'SAI - đáng lẽ 7' END
FROM dbo.BANGDIEM WHERE MASV='SV999001' AND MAMH='KTLT';

PRINT N'--- Thi lại lần 1 khi đã có điểm -> phải BỊ CHẶN ---';
BEGIN TRY
    EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_LayDeThi @MASV='SV999001', @MAMH='KTLT', @LAN=1;
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH
'@
Chay $CS1 $sql4 'BƯỚC 4 - sinh viên vào thi, nộp bài, nhận điểm'

#=======================================================================
# BƯỚC 5 - Giáo viên kiểm tra điểm + phúc khảo
#=======================================================================
$sql5 = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

PRINT N'--- Câu 10: bảng điểm môn học (làm tròn 0.5) ---';
EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_BangDiemMonHoc @MALOP=N'TH99', @MAMH='KTLT', @LAN=1;
REVERT;

PRINT N'--- Câu 9 phúc khảo: giáo viên chọn lớp ---';
EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_DS_Lop_CoBaiThi;
REVERT;

PRINT N'--- ...rồi chọn sinh viên trong lớp đó ---';
EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_DS_SinhVien_CoBaiThi @MALOP = N'TH99';
REVERT;

PRINT N'--- ...rồi xem lại từng câu bài làm ---';
EXECUTE AS LOGIN = 'TH999';
    EXEC dbo.sp_XemKetQua @MASV='SV999001', @MAMH='KTLT', @LAN=1;
REVERT;

PRINT N'--- Sinh viên tự xem bài CỦA MÌNH -> phải ĐƯỢC ---';
EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_DS_BaiThi_SV @MASV = 'SV999001';
REVERT;

PRINT N'--- Sinh viên liệt kê bạn cùng lớp -> phải BỊ CHẶN ---';
BEGIN TRY
    EXECUTE AS LOGIN = 'sv';
    EXEC dbo.sp_DS_SinhVien_CoBaiThi @MALOP = N'TH99';
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH
'@
Chay $CS1 $sql5 'BƯỚC 5 - giáo viên xem bảng điểm và phúc khảo'

#=======================================================================
# BƯỚC 6 - Trưởng: báo cáo, chỉ-xem, và tra cứu mảnh dọc
#=======================================================================
$sql6 = @'
USE TN_CSDLPT;
SET NOCOUNT ON;

PRINT N'--- Câu 11: báo cáo đăng ký thi (chỉ kỳ thi THẬT, không có dòng phân công) ---';
EXECUTE AS LOGIN = 'truong01';
    EXEC dbo.sp_BaoCao_DangKy @tungay = '2000-01-01', @denngay = '2099-12-31';
REVERT;

PRINT N'--- Trưởng chạy được báo cáo bảng điểm ---';
EXECUTE AS LOGIN = 'truong01';
    EXEC dbo.sp_BangDiemMonHoc @MALOP=N'TH99', @MAMH='KTLT', @LAN=1;
REVERT;

PRINT N'--- Trưởng SỬA dữ liệu -> phải BỊ CHẶN (chỉ xem) ---';
BEGIN TRY
    EXECUTE AS LOGIN = 'truong01';
    UPDATE dbo.SINHVIEN SET DIACHI = N'thu sua' WHERE MASV='SV999001';
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH
'@
Chay $CS1 $sql6 'BƯỚC 6a - Trưởng chạy báo cáo và bị chặn ghi'

ChoDuLieu $TRACUU "SELECT COUNT(*) FROM dbo.SINHVIEN WHERE MASV='SV999001';" `
          'sinh viên mới xuất hiện trên mảnh dọc SERVER3'

$sql6b = @'
USE TN_CSDLPT;
SET NOCOUNT ON;
PRINT N'--- Mảnh dọc (câu 1): chỉ MASV, HO, TEN, MALOP - KHÔNG có mật khẩu/địa chỉ ---';
SELECT ten_cot = c.name
FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.SINHVIEN') ORDER BY c.column_id;

PRINT N'--- Tra cứu sinh viên vừa tạo trên mảnh 3 ---';
EXECUTE AS LOGIN = 'tracuu';
    SELECT sv.MASV, sv.HO, sv.TEN, sv.MALOP, l.TENLOP
    FROM dbo.SINHVIEN sv LEFT JOIN dbo.LOP l ON sv.MALOP = l.MALOP
    WHERE sv.MASV = 'SV999001';
REVERT;

PRINT N'--- Tài khoản tra cứu GHI dữ liệu -> phải BỊ CHẶN ---';
BEGIN TRY
    EXECUTE AS LOGIN = 'tracuu';
    UPDATE dbo.SINHVIEN SET HO = N'x' WHERE MASV='SV999001';
    REVERT;
    RAISERROR(N'SAI: đáng lẽ phải bị chặn.',16,1);
END TRY
BEGIN CATCH
    IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
    PRINT N'   CHẶN ĐÚNG: ' + ERROR_MESSAGE();
END CATCH
'@
Chay $TRACUU $sql6b 'BƯỚC 6b - Trưởng tra cứu trên mảnh dọc SERVER3'

#=======================================================================
# TỔNG KẾT
#=======================================================================
Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host ''
Write-Host ('#' * 72) -ForegroundColor White
if ($script:loi -eq 0) {
    Write-Host ("  TOÀN BỘ {0} BƯỚC ĐỀU CHẠY XONG, KHÔNG CÓ BƯỚC NÀO LỖI." -f $script:soBuoc) -ForegroundColor Green
} else {
    Write-Host ("  CÓ {0}/{1} BƯỚC LỖI - xem lại phần in màu đỏ ở trên." -f $script:loi, $script:soBuoc) -ForegroundColor Red
}
Write-Host ('#' * 72) -ForegroundColor White
Write-Host ''
Write-Host 'Dữ liệu test còn nguyên để bạn mở app xem lại.' -ForegroundColor DarkGray
Write-Host 'Chạy lại script này sẽ tự dọn rồi làm lại từ đầu.' -ForegroundColor DarkGray
