/*======================================================================
  TÁCH "PHÂN CÔNG GIẢNG DẠY" RA KHỎI "ĐĂNG KÝ KỲ THI"
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Chạy bằng: sqlcmd -f 65001
  Sau đó PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  VẤN ĐỀ
  Bảng GIAOVIEN_DANGKY đang gánh HAI việc khác nhau:
      (a) phân công dạy : giáo viên X dạy môn M cho lớp L
      (b) đăng ký kỳ thi: ngày thi, trình độ, số câu, thời gian
  Nhưng chỉ có MỘT thủ tục ghi vào nó là sp_ChuanBiThi, và thủ tục đó lại
  từ chối khi kho đề chưa đủ 70% số câu thi. Hệ quả: với một môn HOÀN TOÀN
  MỚI chưa ai soạn đề, Cơ sở KHÔNG phân công được, mà giảng viên cũng
  không soạn được đề vì chưa được phân công -> khoá chết.

  CÁCH TÁCH - KHÔNG ĐỔI SCHEMA CỦA THẦY
  Dùng chính các cột đã có làm dấu hiệu, không thêm cột nào:

      SOCAUTHI IS NULL   ->  dòng PHÂN CÔNG   (chưa đăng ký thi)
      SOCAUTHI IS NOT NULL -> dòng ĐĂNG KÝ THI (đã đủ thông tin kỳ thi)

  Dòng phân công để trống cả TRINHDO, SOCAUTHI, THOIGIAN. Việc để TRINHDO
  NULL còn có tác dụng phụ rất tốt: sp_LayDeThi vốn đã có sẵn câu
        IF @TD IS NULL RAISERROR(N'Lớp chưa được đăng ký thi môn/lần này.')
  nên sinh viên KHÔNG thể vào thi một dòng mới chỉ phân công. Không phải
  sửa gì thêm ở đó.

  QUY TRÌNH MỚI
      1. Cơ sở  -> màn "Phân công giảng dạy"  -> sp_PhanCong_Them
                   (KHÔNG kiểm tra kho đề - đây mới là chỗ gỡ khoá chết)
      2. Giảng viên thấy môn đó trong màn Soạn bộ đề -> soạn đề
      3. Giảng viên/Cơ sở -> màn Chuẩn bị thi -> sp_ChuanBiThi
                   (kiểm tra kho đề như cũ, rồi ĐIỀN TIẾP vào dòng đã có)

  BA THỦ TỤC PHẢI SỬA THEO
      sp_ChuanBiThi    - UPDATE dòng phân công thay vì INSERT dòng mới
      sp_LichThi       - sinh viên không được thấy dòng mới phân công
      sp_BaoCao_DangKy - câu 11 chỉ đếm kỳ thi thật, không đếm phân công
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;
GO

/*======================================================================
  1. sp_PhanCong_DS - danh sách cho màn Phân công giảng dạy
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_PhanCong_DS]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  MAGV     = RTRIM(dk.MAGV),
            GIANGVIEN= RTRIM(gv.HO) + N' ' + RTRIM(gv.TEN),
            MAMH     = RTRIM(dk.MAMH),
            TENMH    = RTRIM(mh.TENMH),
            MALOP    = RTRIM(dk.MALOP),
            TENLOP   = RTRIM(l.TENLOP),
            LAN      = dk.LAN,
            TRANGTHAI= CASE WHEN dk.SOCAUTHI IS NULL
                            THEN N'Mới phân công'
                            ELSE N'Đã đăng ký thi ' + CONVERT(nvarchar(10), dk.NGAYTHI, 103)
                       END,
            /* Bỏ phân công được hay không - để ứng dụng khoá nút cho đúng */
            XOADUOC  = CAST(CASE WHEN dk.SOCAUTHI IS NULL THEN 1 ELSE 0 END AS bit)
    FROM dbo.Giaovien_Dangky dk
      JOIN dbo.Giaovien gv ON dk.MAGV  = gv.MAGV
      JOIN dbo.Monhoc   mh ON dk.MAMH  = mh.MAMH
      JOIN dbo.Lop      l  ON dk.MALOP = l.MALOP
    ORDER BY dk.SOCAUTHI, gv.HO, gv.TEN, mh.TENMH, l.TENLOP, dk.LAN;
END
GO
PRINT N'  + sp_PhanCong_DS';
GO

/*======================================================================
  2. sp_PhanCong_Them - Cơ sở phân công giáo viên dạy môn cho lớp

  CỐ Ý KHÔNG kiểm tra kho đề: đây chính là bước gỡ khoá chết. Đề thi chưa
  có là chuyện bình thường ở thời điểm phân công đầu học kỳ.

  Luôn tạo LAN = 1. Lần 2 là kỳ thi lại của cùng phân công đó, do
  sp_ChuanBiThi tự tạo, không cần phân công riêng.
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_PhanCong_Them]
    @MAGV char(8), @MAMH char(5), @MALOP nchar(15)
AS
BEGIN
    SET NOCOUNT ON;

    /* Chỉ Cơ sở mới được phân công. Giảng viên không tự phân công cho mình
       (nếu không thì việc lọc môn ở màn Soạn bộ đề thành vô nghĩa). */
    IF ISNULL(IS_MEMBER('CoSo'),0) = 0 AND ISNULL(IS_MEMBER('db_owner'),0) = 0
        BEGIN RAISERROR(N'Chỉ nhóm Cơ sở mới được phân công giảng dạy.',16,1); RETURN; END

    IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE MAGV = @MAGV)
        BEGIN RAISERROR(N'Mã giáo viên không tồn tại tại cơ sở này.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Monhoc WHERE MAMH = @MAMH)
        BEGIN RAISERROR(N'Môn học không tồn tại.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Lop WHERE MALOP = @MALOP)
        BEGIN RAISERROR(N'Lớp không tồn tại tại cơ sở này.',16,1); RETURN; END

    /* Giáo viên và lớp phải CÙNG MỘT CƠ SỞ - cùng luật với sp_ChuanBiThi */
    IF NOT EXISTS (SELECT 1
                   FROM dbo.Lop l JOIN dbo.Khoa kl ON l.MAKH = kl.MAKH
                        JOIN dbo.Giaovien g ON g.MAGV = @MAGV
                        JOIN dbo.Khoa kg ON g.MAKH = kg.MAKH AND kg.MACS = kl.MACS
                   WHERE l.MALOP = @MALOP)
        BEGIN RAISERROR(N'Giáo viên và lớp không thuộc cùng một cơ sở.',16,1); RETURN; END

    /* Khoá chính là (MAMH, MALOP, LAN) -> mỗi lớp chỉ một giáo viên phụ trách
       một môn. Nếu đã có thì nói rõ đang là ai, đừng để lỗi khoá chính thô. */
    DECLARE @gvCu char(8), @soCau smallint;
    SELECT @gvCu = MAGV, @soCau = SOCAUTHI
    FROM dbo.Giaovien_Dangky WHERE MAMH = @MAMH AND MALOP = @MALOP AND LAN = 1;

    IF @gvCu IS NOT NULL
    BEGIN
        DECLARE @ten nvarchar(70) =
            (SELECT RTRIM(HO) + N' ' + RTRIM(TEN) FROM dbo.Giaovien WHERE MAGV = @gvCu);
        DECLARE @m nvarchar(300) =
            CASE WHEN RTRIM(@gvCu) = RTRIM(@MAGV)
                 THEN N'Giáo viên này đã được phân công dạy môn đó cho lớp đó rồi.'
                 ELSE N'Lớp/môn này đang do ' + @ten + N' phụ trách.'
                      + CASE WHEN @soCau IS NULL
                             THEN N' Bỏ phân công cũ trước nếu muốn đổi người.'
                             ELSE N' Đã đăng ký kỳ thi nên không đổi người được nữa.' END
            END;
        RAISERROR(@m,16,1); RETURN;
    END

    /* TRINHDO / SOCAUTHI / THOIGIAN để NULL = dấu hiệu "mới phân công".
       NGAYTHI NOT NULL nên buộc phải có giá trị - dùng mặc định GETDATE(),
       nhưng dòng này bị loại khỏi mọi báo cáo/lịch thi nhờ SOCAUTHI IS NULL. */
    INSERT INTO dbo.Giaovien_Dangky(MAGV, MAMH, MALOP, TRINHDO, NGAYTHI, LAN, SOCAUTHI, THOIGIAN)
    VALUES(@MAGV, @MAMH, @MALOP, NULL, GETDATE(), 1, NULL, NULL);

    SELECT N'Đã phân công giảng dạy. Giảng viên có thể soạn đề cho môn này.' AS ThongBao;
END
GO
PRINT N'  + sp_PhanCong_Them';
GO

/*======================================================================
  3. sp_PhanCong_Xoa - bỏ phân công (chỉ khi CHƯA đăng ký kỳ thi)
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_PhanCong_Xoa]
    @MAMH char(5), @MALOP nchar(15)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISNULL(IS_MEMBER('CoSo'),0) = 0 AND ISNULL(IS_MEMBER('db_owner'),0) = 0
        BEGIN RAISERROR(N'Chỉ nhóm Cơ sở mới được bỏ phân công.',16,1); RETURN; END

    IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien_Dangky
                   WHERE MAMH=@MAMH AND MALOP=@MALOP AND LAN=1)
        BEGIN RAISERROR(N'Không có phân công nào cho lớp/môn này.',16,1); RETURN; END

    /* Đã điền thông tin kỳ thi rồi thì đây không còn là phân công thuần,
       xoá đi là mất luôn kỳ thi -> chặn. */
    IF EXISTS (SELECT 1 FROM dbo.Giaovien_Dangky
               WHERE MAMH=@MAMH AND MALOP=@MALOP AND SOCAUTHI IS NOT NULL)
        BEGIN RAISERROR(N'Lớp/môn này đã đăng ký kỳ thi - không bỏ phân công được.',16,1); RETURN; END

    DELETE FROM dbo.Giaovien_Dangky WHERE MAMH=@MAMH AND MALOP=@MALOP AND LAN=1;
    SELECT N'Đã bỏ phân công.' AS ThongBao;
END
GO
PRINT N'  + sp_PhanCong_Xoa';
GO

/*======================================================================
  4. sp_ChuanBiThi - ĐIỀN TIẾP vào dòng phân công thay vì tạo dòng mới

  Giữ nguyên toàn bộ luật cũ (trình độ, lần, số câu, thời gian, cùng cơ sở,
  kiểm tra kho đề 70%, ưu tiên đề đúng cơ sở). Chỉ đổi phần cuối:

      LAN = 1 -> BẮT BUỘC đã có phân công của Cơ sở, và UPDATE dòng đó
      LAN = 2 -> INSERT dòng mới, thừa hưởng giáo viên từ lần 1
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ChuanBiThi]
    @MAGV char(8), @MALOP nchar(15), @MAMH char(5), @TRINHDO char(1),
    @LAN smallint, @SOCAUTHI smallint, @NGAYTHI datetime, @THOIGIAN smallint
AS
BEGIN
    SET NOCOUNT ON;

    IF @TRINHDO NOT IN ('A','B','C')    BEGIN RAISERROR(N'Trình độ phải là A, B hoặc C.',16,1); RETURN; END
    IF @LAN NOT BETWEEN 1 AND 2         BEGIN RAISERROR(N'Lần thi phải từ 1 đến 2.',16,1); RETURN; END
    IF @SOCAUTHI NOT BETWEEN 10 AND 100 BEGIN RAISERROR(N'Số câu thi phải từ 10 đến 100.',16,1); RETURN; END
    IF @THOIGIAN NOT BETWEEN 2 AND 60   BEGIN RAISERROR(N'Thời gian thi phải từ 2 đến 60 phút.',16,1); RETURN; END

    IF NOT EXISTS (SELECT 1 FROM dbo.Lop      WHERE MALOP = @MALOP)
        BEGIN RAISERROR(N'Lớp không tồn tại tại cơ sở này.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Monhoc   WHERE MAMH = @MAMH)
        BEGIN RAISERROR(N'Môn học không tồn tại.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE MAGV = @MAGV)
        BEGIN RAISERROR(N'Mã giáo viên không tồn tại tại cơ sở này.',16,1); RETURN; END

    IF NOT EXISTS (SELECT 1
                   FROM dbo.Lop l JOIN dbo.Khoa kl ON l.MAKH = kl.MAKH
                        JOIN dbo.Giaovien g ON g.MAGV = @MAGV
                        JOIN dbo.Khoa kg ON g.MAKH = kg.MAKH AND kg.MACS = kl.MACS
                   WHERE l.MALOP = @MALOP)
        BEGIN RAISERROR(N'Giáo viên và lớp không thuộc cùng một cơ sở.',16,1); RETURN; END

    /*--- Trạng thái hiện tại của (lớp, môn, lần) này ---*/
    DECLARE @gvPhanCong char(8), @daDangKy bit = 0, @coDong bit = 0;
    SELECT @gvPhanCong = MAGV,
           @daDangKy   = CASE WHEN SOCAUTHI IS NULL THEN 0 ELSE 1 END,
           @coDong     = 1
    FROM dbo.Giaovien_Dangky WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=@LAN;

    IF @coDong = 1 AND @daDangKy = 1
        BEGIN RAISERROR(N'Lớp này đã đăng ký môn học + lần thi này rồi.',16,1); RETURN; END

    IF @LAN = 1 AND @coDong = 0
        BEGIN RAISERROR(N'Lớp/môn này chưa được Cơ sở phân công giảng dạy. Vào màn "Phân công giảng dạy" để phân công trước.',16,1); RETURN; END

    IF @LAN = 2
    BEGIN
        DECLARE @gvLan1 char(8);
        SELECT @gvLan1 = MAGV FROM dbo.Giaovien_Dangky
        WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=1 AND SOCAUTHI IS NOT NULL;
        IF @gvLan1 IS NULL
            BEGIN RAISERROR(N'Chưa có đăng ký lần 1 cho lớp/môn này.',16,1); RETURN; END
        SET @gvPhanCong = @gvLan1;      /* lần 2 thừa hưởng giáo viên của lần 1 */
    END

    /* Người đăng ký phải đúng là người được phân công. Chặn cả trường hợp
       nhóm Cơ sở chọn nhầm giáo viên trong ô chọn. */
    IF RTRIM(@gvPhanCong) <> RTRIM(@MAGV)
    BEGIN
        DECLARE @tenPC nvarchar(70) =
            (SELECT RTRIM(HO) + N' ' + RTRIM(TEN) FROM dbo.Giaovien WHERE MAGV = @gvPhanCong);
        DECLARE @mPC nvarchar(300) =
            N'Lớp/môn này được phân công cho ' + ISNULL(@tenPC, RTRIM(@gvPhanCong))
            + N'. Chỉ giáo viên được phân công mới đăng ký kỳ thi được.';
        RAISERROR(@mPC,16,1); RETURN;
    END

    DECLARE @MACS nchar(3) =
        (SELECT k.MACS FROM dbo.Lop l JOIN dbo.Khoa k ON l.MAKH=k.MAKH WHERE l.MALOP=@MALOP);

    DECLARE @canToiThieu int = @SOCAUTHI - FLOOR(@SOCAUTHI * 0.30);

    /* Đề của CHÍNH cơ sở này: nối qua KHOA (đã lọc theo MACS) */
    DECLARE @coLocal int =
        (SELECT COUNT(*)
         FROM dbo.Bode b
           JOIN dbo.Giaovien g ON b.MAGV = g.MAGV
           JOIN dbo.Khoa     k ON g.MAKH = k.MAKH
         WHERE b.MAMH=@MAMH AND b.TRINHDO=@TRINHDO);

    /* Đề mượn được của cơ sở còn lại */
    DECLARE @coMuon int =
        (SELECT COUNT(*) FROM dbo.Bode_Muon
         WHERE MAMH=@MAMH AND TRINHDO=@TRINHDO AND MACS <> @MACS);

    DECLARE @coChinh int = @coLocal + @coMuon;

    IF @coChinh < @canToiThieu
    BEGIN
        DECLARE @thieu int = @canToiThieu - @coChinh;
        DECLARE @m nvarchar(400) =
              N'Kho đề chưa đủ để đăng ký thi ' + CAST(@SOCAUTHI AS nvarchar(10))
            + N' câu trình độ ' + @TRINHDO + N'.' + CHAR(13) + CHAR(10)
            + N'Cần tối thiểu ' + CAST(@canToiThieu AS nvarchar(10)) + N' câu, '
            + N'hiện có ' + CAST(@coChinh AS nvarchar(10)) + N' câu '
            + N'(' + CAST(@coLocal AS nvarchar(10)) + N' câu tại cơ sở, '
            + CAST(@coMuon AS nvarchar(10)) + N' câu mượn được).' + CHAR(13) + CHAR(10)
            + N'=> CÒN THIẾU ' + CAST(@thieu AS nvarchar(10)) + N' CÂU. '
            + N'Đề nghị giáo viên soạn bổ sung trước khi đăng ký.';
        RAISERROR(@m,16,1); RETURN;
    END

    IF @coDong = 1
        /* Dòng phân công đã có -> ĐIỀN TIẾP thông tin kỳ thi vào đó */
        UPDATE dbo.Giaovien_Dangky
        SET TRINHDO = @TRINHDO, NGAYTHI = ISNULL(@NGAYTHI, GETDATE()),
            SOCAUTHI = @SOCAUTHI, THOIGIAN = @THOIGIAN
        WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=@LAN;
    ELSE
        /* Chỉ xảy ra với LAN = 2 - kỳ thi lại của cùng phân công */
        INSERT INTO dbo.Giaovien_Dangky(MAGV,MALOP,MAMH,TRINHDO,NGAYTHI,LAN,SOCAUTHI,THOIGIAN)
        VALUES(@MAGV,@MALOP,@MAMH,@TRINHDO,ISNULL(@NGAYTHI, GETDATE()),@LAN,@SOCAUTHI,@THOIGIAN);

    SELECT N'Đăng ký kỳ thi thành công. Kho đề có ' + CAST(@coLocal AS nvarchar(10))
         + N' câu tại cơ sở, ' + CAST(@coMuon AS nvarchar(10)) + N' câu mượn được.' AS ThongBao;
END
GO
PRINT N'  + sp_ChuanBiThi (điền tiếp vào dòng phân công)';
GO

/*======================================================================
  5. sp_LichThi - sinh viên không được thấy dòng MỚI PHÂN CÔNG
     (chưa có ngày thi thật, chưa có số câu, chưa có thời gian)
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_LichThi]
    @MASV char(8)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RTRIM(dk.MAMH) AS mamh, mh.TENMH AS tenmh, dk.LAN AS lan,
           RTRIM(dk.TRINHDO) AS trinhdo, dk.SOCAUTHI AS socauthi,
           dk.THOIGIAN AS thoigian, dk.NGAYTHI AS ngaythi,
           CAST(CASE WHEN bd.MASV IS NULL THEN 0 ELSE 1 END AS bit) AS dathi,
           bd.DIEM AS diem
    FROM dbo.Giaovien_Dangky dk
      JOIN dbo.Sinhvien sv ON sv.MALOP = dk.MALOP
      JOIN dbo.Monhoc   mh ON dk.MAMH  = mh.MAMH
      LEFT JOIN dbo.BangDiem bd
             ON bd.MASV = sv.MASV AND bd.MAMH = dk.MAMH AND bd.LAN = dk.LAN
    WHERE sv.MASV = @MASV
      AND dk.SOCAUTHI IS NOT NULL          /* bỏ dòng mới phân công */
    ORDER BY dk.NGAYTHI, dk.MAMH, dk.LAN;
END
GO
PRINT N'  + sp_LichThi (bỏ dòng mới phân công)';
GO

/*======================================================================
  6. sp_BaoCao_DangKy - câu 11 chỉ đếm KỲ THI THẬT
     Không có bộ lọc này thì mỗi lần Cơ sở phân công sẽ đẻ ra một dòng
     "đăng ký" giả trong báo cáo, kèm ngày thi bịa theo GETDATE().
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_BaoCao_DangKy]
    @tungay date, @denngay date
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  MACS      = RTRIM(cs.MACS),
            COSO      = cs.TENCS,
            TENLOP    = lop.TENLOP,
            TENMH     = mh.TENMH,
            GIANGVIEN = RTRIM(gv.HO) + N' ' + RTRIM(gv.TEN),
            TRINHDO   = RTRIM(dk.TRINHDO),
            SOCAUTHI  = dk.SOCAUTHI,
            THOIGIAN  = dk.THOIGIAN,
            NGAYTHI   = dk.NGAYTHI,
            LAN       = dk.LAN,
            /* Đề: "đã thi thì đánh dấu X, chưa thì để trống" */
            DATHI     = CASE WHEN x.SoDaThi > 0 THEN N'X' ELSE N'' END,
            GHICHU    = CASE
                          WHEN x.SiSo > 0 AND x.SoDaThi >= x.SiSo THEN N'Đã thi xong'
                          WHEN x.SoDaThi > 0 THEN N'Đang thi dở ('
                               + CAST(x.SoDaThi AS nvarchar(5)) + N'/'
                               + CAST(x.SiSo AS nvarchar(5)) + N')'
                          WHEN CAST(dk.NGAYTHI AS date) > CAST(GETDATE() AS date) THEN N'Chưa tới ngày thi'
                          WHEN CAST(dk.NGAYTHI AS date) < CAST(GETDATE() AS date) THEN N'Quá hạn chưa thi'
                          ELSE N'Thi hôm nay'
                        END
    FROM dbo.Giaovien_Dangky dk
      JOIN dbo.Lop      lop ON dk.MALOP = lop.MALOP
      JOIN dbo.Khoa     k   ON lop.MAKH = k.MAKH
      JOIN dbo.CoSo     cs  ON k.MACS   = cs.MACS
      JOIN dbo.Monhoc   mh  ON dk.MAMH  = mh.MAMH
      JOIN dbo.Giaovien gv  ON dk.MAGV  = gv.MAGV
      CROSS APPLY (
          SELECT SiSo    = (SELECT COUNT(*) FROM dbo.Sinhvien s WHERE s.MALOP = dk.MALOP),
                 SoDaThi = (SELECT COUNT(*) FROM dbo.BangDiem bd
                            JOIN dbo.Sinhvien s2 ON bd.MASV = s2.MASV
                            WHERE s2.MALOP = dk.MALOP AND bd.MAMH = dk.MAMH AND bd.LAN = dk.LAN)
      ) x
    WHERE dk.SOCAUTHI IS NOT NULL          /* chỉ kỳ thi thật */
      AND dk.NGAYTHI >= @tungay
      AND dk.NGAYTHI <  DATEADD(DAY, 1, @denngay)
    ORDER BY dk.NGAYTHI, lop.TENLOP;
END
GO
PRINT N'  + sp_BaoCao_DangKy (chỉ kỳ thi thật)';
GO

/*======================================================================
  7. Cấp quyền - phân công là việc của Cơ sở; Trưởng chỉ xem
======================================================================*/
IF DATABASE_PRINCIPAL_ID('CoSo') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.sp_PhanCong_DS   TO [CoSo];
    GRANT EXECUTE ON dbo.sp_PhanCong_Them TO [CoSo];
    GRANT EXECUTE ON dbo.sp_PhanCong_Xoa  TO [CoSo];
END
IF DATABASE_PRINCIPAL_ID('Truong') IS NOT NULL
    GRANT EXECUTE ON dbo.sp_PhanCong_DS TO [Truong];      /* chỉ xem */
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
    GRANT EXECUTE ON dbo.sp_PhanCong_DS TO [Giangvien];   /* xem mình dạy gì */
GO

PRINT N'== Xong. Nhớ chạy lại 12_CapLaiQuyen.sql ==';
GO

/*----------------------------------------------------------------------
  Kiểm tra: dữ liệu cũ phải KHÔNG bị coi là phân công dở
  (mọi dòng seed đều có SOCAUTHI nên vẫn là kỳ thi thật)
----------------------------------------------------------------------*/
SELECT loai = CASE WHEN SOCAUTHI IS NULL THEN N'Mới phân công'
                   ELSE N'Đã đăng ký thi' END,
       so_dong = COUNT(*)
FROM dbo.Giaovien_Dangky
GROUP BY CASE WHEN SOCAUTHI IS NULL THEN N'Mới phân công' ELSE N'Đã đăng ký thi' END;
GO
