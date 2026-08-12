/*======================================================================
  CÂU 8 - SỬA LỖI TRÙNG MÃ CÂU HỎI GIỮA HAI CƠ SỞ
  Chạy trên: SERVER1, SERVER2   (sqlcmd -f 65001)
  ----------------------------------------------------------------------
  TRIỆU CHỨNG
  Phát đề 100 câu ra 100 câu LOCAL, KHÔNG có câu nào NGUON='MUON',
  dù kho CS2 còn thừa câu cùng trình độ.

  NGUYÊN NHÂN
  Câu hỏi cũ của hai cơ sở dùng chung dải mã 1..259 nên TRÙNG NHAU hoàn
  toàn (kiểm tra thực tế: cả 40 câu MMTCB của CS2 đều trùng mã với CS1).
  Bảng tạm #De trong sp_LayDeThi đặt PRIMARY KEY(CAUHOI) và lọc
  "CAUHOI NOT IN (SELECT CAUHOI FROM #De)" -> mọi câu mượn đều bị loại.
  => Chức năng "mượn đề cơ sở khác" của câu 8 thực tế CHƯA BAO GIỜ chạy.

  CÁCH SỬA
  1) #De định danh bằng (CAUHOI, NGUON): câu số 5 của cơ sở mình và câu
     số 5 mượn của cơ sở bạn là HAI câu khác nhau.
  2) ChiTiet_BaiThi: khóa chính đổi từ (MASV,MAMH,LAN,CAUHOI) sang
     (MASV,MAMH,LAN,STT). STT là số thứ tự câu trong bài thi - luôn duy
     nhất, và về dạng chuẩn thì STT mới đúng là thứ định danh vị trí câu
     trong bài, CAUHOI chỉ là thuộc tính tham chiếu.
  (Câu hỏi soạn MỚI đã được sp_Bode_Them cấp mã theo dải riêng từng cơ
   sở nên không còn trùng; bản vá này xử lý phần dữ liệu cũ.)
======================================================================*/
USE TN_CSDLPT;
GO

/*----------------------------------------------------------------------
  1. Đổi khóa chính ChiTiet_BaiThi (bảng CỤC BỘ, không nhân bản)
----------------------------------------------------------------------*/
IF EXISTS (SELECT 1 FROM sys.indexes i
           JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id
           JOIN sys.columns c ON c.object_id=i.object_id AND c.column_id=ic.column_id
           WHERE i.is_primary_key=1 AND i.object_id=OBJECT_ID('dbo.ChiTiet_BaiThi')
             AND c.name='CAUHOI')
BEGIN
    DECLARE @pk sysname = (SELECT name FROM sys.indexes
                           WHERE object_id=OBJECT_ID('dbo.ChiTiet_BaiThi') AND is_primary_key=1);
    EXEC('ALTER TABLE dbo.ChiTiet_BaiThi DROP CONSTRAINT ' + @pk);
    ALTER TABLE dbo.ChiTiet_BaiThi
        ADD CONSTRAINT PK_ChiTiet PRIMARY KEY CLUSTERED (MASV, MAMH, LAN, STT);
    PRINT N'  ChiTiet_BaiThi: khóa chính đổi sang (MASV, MAMH, LAN, STT)';
END
ELSE PRINT N'  ChiTiet_BaiThi: khóa chính đã đúng, bỏ qua';
GO

/*----------------------------------------------------------------------
  2. sp_LayDeThi - #De định danh bằng (CAUHOI, NGUON)
----------------------------------------------------------------------*/
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

        /* (CAUHOI, NGUON) - câu số 5 của mình KHÁC câu số 5 mượn được */
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
        /* (6a) Đúng trình độ - kho CƠ SỞ CỦA LỚP (ưu tiên 1) */
        INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
        SELECT TOP (@SOCAU) CAUHOI, 'LOCAL', TRINHDO,
               CAST(NOIDUNG AS nvarchar(max)), CAST(A AS nvarchar(max)),
               CAST(B AS nvarchar(max)), CAST(C AS nvarchar(max)),
               CAST(D AS nvarchar(max)), DAP_AN
        FROM dbo.Bode WHERE MAMH=@MAMH AND TRINHDO=@TD ORDER BY NEWID();

        /* (6b) Thiếu -> MƯỢN cùng trình độ ở CƠ SỞ CÒN LẠI (ưu tiên 2) */
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

        /* (6c) Vẫn thiếu -> hạ 1 bậc, tổng phần hạ bậc KHÔNG QUÁ 30% */
        SET @thieu = @SOCAU - (SELECT COUNT(*) FROM #De);
        IF @thieu > 0 AND @TDthap IS NOT NULL
        BEGIN
            DECLARE @conLayThap int = @tranThap;
            DECLARE @lay int = CASE WHEN @thieu < @conLayThap THEN @thieu ELSE @conLayThap END;

            IF @lay > 0
            BEGIN
                INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
                SELECT TOP (@lay) CAUHOI, 'LOCAL', TRINHDO,
                       CAST(NOIDUNG AS nvarchar(max)), CAST(A AS nvarchar(max)),
                       CAST(B AS nvarchar(max)), CAST(C AS nvarchar(max)),
                       CAST(D AS nvarchar(max)), DAP_AN
                FROM dbo.Bode
                WHERE MAMH=@MAMH AND TRINHDO=@TDthap
                  AND NOT EXISTS (SELECT 1 FROM #De d WHERE d.CAUHOI=Bode.CAUHOI AND d.NGUON='LOCAL')
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
    /* CỐ Ý KHÔNG TRẢ DAP_AN */
END
GO

DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN ('CoSo','Giangvien','Sinhvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.sp_LayDeThi TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Câu 8: đã sửa lỗi trùng mã câu hỏi, chức năng mượn đề hoạt động ==';
GO
