/*======================================================================
  CÂU 8 - SỬA "ƯU TIÊN LẤY ĐỀ THEO CƠ SỞ CỦA LỚP"
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Sau khi chạy xong PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  TRIỆU CHỨNG
  Đề (Thầy nhấn mạnh): "các câu hỏi thi sẽ ưu tiên lấy ở CƠ SỞ MÀ LỚP ĐÃ
  HỌC... chừng nào không đủ nữa thì mới lấy thêm cơ sở còn lại".
  Thực tế phát đề gần như luôn ra 100% NGUON='LOCAL', chức năng mượn đề
  hầu như không bao giờ kích hoạt.

  NGUYÊN NHÂN
  Bảng BODE KHÔNG nằm trong cây dẫn xuất (nhân bản toàn bộ), nên mỗi phân
  mảnh đều có ĐỦ câu hỏi của CẢ HAI cơ sở. Kiểm tra thực tế trên CS2:

        BODE môn MMTCB trên CS2:
             TH123 (giáo viên CS1) : 158 câu   <-- không phải đề của CS2
             TH657 (giáo viên CS2) :  40 câu

  Bước (6a) lấy "LOCAL" đọc thẳng dbo.Bode nên vơ luôn cả 158 câu của CS1
  rồi gắn nhãn LOCAL. Ưu tiên theo cơ sở coi như không có hiệu lực.

  CÁCH SỬA
  Xác định "đề của cơ sở này" bằng cách nối BODE -> GIAOVIEN -> KHOA.
  Bảng KHOA CÓ nằm trong cây dẫn xuất (lọc theo MACS), nên phép nối này
  tự động chỉ giữ lại câu hỏi do giáo viên THUỘC CƠ SỞ NÀY soạn -
  không cần thêm điều kiện MACS nào.

  Đây cũng là cách làm nhất quán với phần đã sửa trước đó: cho logic tự
  đúng dựa trên cấu trúc phân mảnh, thay vì phụ thuộc cấu hình nhân bản.
======================================================================*/
USE TN_CSDLPT;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_LayDeThi]
    @MASV char(8), @MAMH char(5), @LAN smallint,
    @DungLaiDeLanTruoc bit = 0,
    @ThiThu bit = 0,
    @MALOP_ThiThu nchar(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MALOP nchar(15), @MACS nchar(3), @TD char(1),
            @SOCAU int, @TG int, @MAPHIEU uniqueidentifier, @con int,
            @NGAYTHI datetime;

    /*--- 1. LỚP + CƠ SỞ CỦA LỚP (đề: ưu tiên theo LỚP, không theo GV) ---*/
    IF @ThiThu = 1
    BEGIN
        IF @MALOP_ThiThu IS NULL BEGIN RAISERROR(N'Thi thử phải chọn lớp.',16,1); RETURN; END
        SELECT @MALOP = l.MALOP, @MACS = k.MACS
        FROM dbo.Lop l JOIN dbo.Khoa k ON l.MAKH = k.MAKH WHERE l.MALOP = @MALOP_ThiThu;
        IF @MALOP IS NULL BEGIN RAISERROR(N'Lớp không tồn tại tại cơ sở này.',16,1); RETURN; END
        IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE MAGV = @MASV)
        BEGIN RAISERROR(N'Chỉ giáo viên mới được thi thử.',16,1); RETURN; END
    END
    ELSE
    BEGIN
        SELECT @MALOP = sv.MALOP, @MACS = k.MACS
        FROM dbo.Sinhvien sv JOIN dbo.Lop l ON sv.MALOP = l.MALOP
                             JOIN dbo.Khoa k ON l.MAKH = k.MAKH
        WHERE sv.MASV = @MASV;
        IF @MALOP IS NULL BEGIN RAISERROR(N'Không tìm thấy sinh viên tại cơ sở này.',16,1); RETURN; END
    END

    SELECT @TD = TRINHDO, @SOCAU = SOCAUTHI, @TG = THOIGIAN, @NGAYTHI = NGAYTHI
    FROM dbo.Giaovien_Dangky WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=@LAN;
    IF @TD IS NULL BEGIN RAISERROR(N'Lớp chưa được đăng ký thi môn/lần này.',16,1); RETURN; END

    IF @ThiThu = 0
    BEGIN
        IF CAST(@NGAYTHI AS date) <> CAST(GETDATE() AS date)
        BEGIN
            DECLARE @m5 nvarchar(200) = N'Chưa tới ngày thi. Kỳ thi này được đăng ký vào ngày '
                + CONVERT(nvarchar(10), @NGAYTHI, 103) + N'.';
            RAISERROR(@m5,16,1); RETURN;
        END
        IF EXISTS (SELECT 1 FROM dbo.BangDiem WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN)
        BEGIN RAISERROR(N'Bạn đã thi và có điểm cho môn/lần thi này - không được thi lại.',16,1); RETURN; END
    END

    IF @DungLaiDeLanTruoc = 1
    BEGIN
        IF @LAN <= 1 BEGIN RAISERROR(N'Chỉ chọn lại được bộ đề khi thi từ lần 2 trở đi.',16,1); RETURN; END
        IF NOT EXISTS (SELECT 1 FROM dbo.ChiTiet_BaiThi WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN-1)
        BEGIN RAISERROR(N'Không tìm thấy bài thi lần trước để lấy lại bộ đề.',16,1); RETURN; END
    END

    IF @ThiThu = 0
       AND EXISTS (SELECT 1 FROM dbo.PhieuThi
                   WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN
                     AND DANOP=0 AND THITHU=0 AND HANNOP <= GETDATE())
    BEGIN
        BEGIN TRY
            BEGIN TRAN;
                UPDATE dbo.PhieuThi SET DANOP = 1
                WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN AND DANOP=0 AND HANNOP <= GETDATE();
                IF NOT EXISTS (SELECT 1 FROM dbo.BangDiem WITH (UPDLOCK, HOLDLOCK)
                               WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN)
                    INSERT INTO dbo.BangDiem(MASV,MAMH,LAN,NGAYTHI,DIEM)
                    VALUES(@MASV,@MAMH,@LAN,GETDATE(),0);
            COMMIT;
        END TRY
        BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; END CATCH
        RAISERROR(N'Bài thi trước của bạn đã hết giờ và bị kết thúc (0 điểm). Liên hệ giám thị nếu cần mở lại.',16,1);
        RETURN;
    END

    SELECT TOP 1 @MAPHIEU = MAPHIEU FROM dbo.PhieuThi
    WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN AND DANOP=0
      AND THITHU=@ThiThu AND HANNOP > GETDATE()
    ORDER BY BATDAU DESC;

    IF @MAPHIEU IS NULL
    BEGIN
        DECLARE @TDthap char(1) = CASE @TD WHEN 'A' THEN 'B' WHEN 'B' THEN 'C' ELSE NULL END;
        DECLARE @tranThap int = FLOOR(@SOCAU * 0.30);
        DECLARE @thieu int;

        CREATE TABLE #De(CAUHOI int, NGUON varchar(5), TD char(1),
                         NOIDUNG nvarchar(max), A nvarchar(max), B nvarchar(max),
                         C nvarchar(max), D nvarchar(max), DAP_AN char(1),
                         PRIMARY KEY (CAUHOI, NGUON));

        IF @DungLaiDeLanTruoc = 1
        BEGIN
            INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
            SELECT CAUHOI, 'CU', @TD, NOIDUNG, A, B, C, D, DAP_AN
            FROM dbo.ChiTiet_BaiThi WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN-1;
        END
        ELSE
        BEGIN
        /*===== (6a) ĐÚNG trình độ - kho CỦA CƠ SỞ LỚP ĐANG HỌC (ưu tiên 1)
          ★ SỬA: nối GIAOVIEN -> KHOA để chỉ lấy câu do giáo viên THUỘC
            CƠ SỞ NÀY soạn. KHOA nằm trong cây dẫn xuất (lọc theo MACS)
            nên phép nối tự giới hạn đúng cơ sở. Trước đây đọc thẳng
            dbo.Bode nên vơ luôn đề của cơ sở kia rồi gắn nhãn LOCAL. =====*/
        INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
        SELECT TOP (@SOCAU) b.CAUHOI, 'LOCAL', b.TRINHDO,
               CAST(b.NOIDUNG AS nvarchar(max)), CAST(b.A AS nvarchar(max)),
               CAST(b.B AS nvarchar(max)), CAST(b.C AS nvarchar(max)),
               CAST(b.D AS nvarchar(max)), b.DAP_AN
        FROM dbo.Bode b
          JOIN dbo.Giaovien g ON b.MAGV = g.MAGV
          JOIN dbo.Khoa     k ON g.MAKH = k.MAKH        /* <-- tự lọc theo cơ sở */
        WHERE b.MAMH=@MAMH AND b.TRINHDO=@TD
        ORDER BY NEWID();

        /*===== (6b) Thiếu -> MƯỢN cùng trình độ ở CƠ SỞ CÒN LẠI =====*/
        SET @thieu = @SOCAU - (SELECT COUNT(*) FROM #De);
        IF @thieu > 0
            INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
            SELECT TOP (@thieu) m.CAUHOI, 'MUON', m.TRINHDO,
                   m.NOIDUNG, m.A, m.B, m.C, m.D, m.DAP_AN
            FROM dbo.Bode_Muon m
            WHERE m.MAMH = @MAMH AND m.TRINHDO = @TD
              AND m.MACS <> @MACS
              AND NOT EXISTS (SELECT 1 FROM #De d WHERE d.CAUHOI=m.CAUHOI AND d.NGUON='MUON')
            ORDER BY NEWID();

        /*===== (6c) Vẫn thiếu -> hạ 1 bậc, tổng phần hạ ≤ 30% =====*/
        SET @thieu = @SOCAU - (SELECT COUNT(*) FROM #De);
        IF @thieu > 0 AND @TDthap IS NOT NULL
        BEGIN
            DECLARE @conLayThap int = @tranThap;
            DECLARE @lay int = CASE WHEN @thieu < @conLayThap THEN @thieu ELSE @conLayThap END;

            IF @lay > 0
            BEGIN
                INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
                SELECT TOP (@lay) b.CAUHOI, 'LOCAL', b.TRINHDO,
                       CAST(b.NOIDUNG AS nvarchar(max)), CAST(b.A AS nvarchar(max)),
                       CAST(b.B AS nvarchar(max)), CAST(b.C AS nvarchar(max)),
                       CAST(b.D AS nvarchar(max)), b.DAP_AN
                FROM dbo.Bode b
                  JOIN dbo.Giaovien g ON b.MAGV = g.MAGV
                  JOIN dbo.Khoa     k ON g.MAKH = k.MAKH      /* <-- tự lọc theo cơ sở */
                WHERE b.MAMH=@MAMH AND b.TRINHDO=@TDthap
                  AND NOT EXISTS (SELECT 1 FROM #De d WHERE d.CAUHOI=b.CAUHOI AND d.NGUON='LOCAL')
                ORDER BY NEWID();
                SET @conLayThap = @conLayThap - @@ROWCOUNT;
            END

            SET @thieu = @SOCAU - (SELECT COUNT(*) FROM #De);
            SET @lay = CASE WHEN @thieu < @conLayThap THEN @thieu ELSE @conLayThap END;
            IF @lay > 0
                INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
                SELECT TOP (@lay) m.CAUHOI, 'MUON', m.TRINHDO,
                       m.NOIDUNG, m.A, m.B, m.C, m.D, m.DAP_AN
                FROM dbo.Bode_Muon m
                WHERE m.MAMH = @MAMH AND m.TRINHDO = @TDthap
                  AND m.MACS <> @MACS
                  AND NOT EXISTS (SELECT 1 FROM #De d WHERE d.CAUHOI=m.CAUHOI AND d.NGUON='MUON')
                ORDER BY NEWID();
        END
        END

        IF @DungLaiDeLanTruoc = 1 SET @SOCAU = (SELECT COUNT(*) FROM #De);

        SET @con = (SELECT COUNT(*) FROM #De);
        IF @con < @SOCAU
        BEGIN
            DECLARE @msg nvarchar(300) = N'Không đủ câu hỏi để phát đề: cần '
                + CAST(@SOCAU AS nvarchar(10)) + N' câu, chỉ gom được '
                + CAST(@con AS nvarchar(10)) + N' câu (đã tính cả mượn cơ sở còn lại). '
                + N'Đề nghị giáo viên bổ sung kho đề môn ' + RTRIM(@MAMH) + N'.';
            DROP TABLE #De;
            RAISERROR(@msg,16,1); RETURN;
        END

        SET @MAPHIEU = NEWID();
        BEGIN TRY
            BEGIN TRAN;
                INSERT INTO dbo.PhieuThi(MAPHIEU,MASV,MAMH,LAN,MALOP,TRINHDO,SOCAU,THOIGIAN,BATDAU,HANNOP,THITHU)
                VALUES(@MAPHIEU,@MASV,@MAMH,@LAN,@MALOP,@TD,@SOCAU,@TG,
                       GETDATE(), DATEADD(MINUTE,@TG,GETDATE()), @ThiThu);
                INSERT INTO dbo.PhieuThi_CauHoi(MAPHIEU,STT,CAUHOI,NGUON,NOIDUNG,A,B,C,D,DAP_AN)
                SELECT @MAPHIEU, ROW_NUMBER() OVER (ORDER BY NEWID()),
                       CAUHOI, NGUON, NOIDUNG, A, B, C, D, DAP_AN
                FROM #De;
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            DROP TABLE #De; THROW;
        END CATCH
        DROP TABLE #De;
    END

    SELECT MAPHIEU AS maphieu, SOCAU AS socau, THOIGIAN AS thoigian,
           BATDAU AS batdau, HANNOP AS hannop,
           DATEDIFF(SECOND, GETDATE(), HANNOP) AS sogiayconlai
    FROM dbo.PhieuThi WHERE MAPHIEU = @MAPHIEU;

    SELECT STT AS stt, CAUHOI AS cauhoi, NGUON AS nguon,
           NOIDUNG AS noidung, A AS a, B AS b, C AS c, D AS d
    FROM dbo.PhieuThi_CauHoi WHERE MAPHIEU = @MAPHIEU ORDER BY STT;
END
GO

/*----------------------------------------------------------------------
  sp_ChuanBiThi: đếm kho đề LOCAL cũng phải theo đúng cơ sở
----------------------------------------------------------------------*/
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

    IF EXISTS (SELECT 1 FROM dbo.Giaovien_Dangky WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=@LAN)
        BEGIN RAISERROR(N'Lớp này đã đăng ký môn học + lần thi này rồi.',16,1); RETURN; END

    IF @LAN = 2 AND NOT EXISTS (SELECT 1 FROM dbo.Giaovien_Dangky
                                WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=1)
        BEGIN RAISERROR(N'Chưa có đăng ký lần 1 cho lớp/môn này.',16,1); RETURN; END

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

    INSERT INTO dbo.Giaovien_Dangky(MAGV,MALOP,MAMH,TRINHDO,NGAYTHI,LAN,SOCAUTHI,THOIGIAN)
    VALUES(@MAGV,@MALOP,@MAMH,@TRINHDO,ISNULL(@NGAYTHI, GETDATE()),@LAN,@SOCAUTHI,@THOIGIAN);

    SELECT N'Đăng ký thi thành công.' AS Message;
END
GO

PRINT N'== Câu 8: đã sửa ưu tiên lấy đề đúng theo cơ sở của lớp ==';
GO
