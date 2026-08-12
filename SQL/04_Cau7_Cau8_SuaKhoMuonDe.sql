/*======================================================================
  CÂU 7 + 8 - SỬA LOGIC "KHO ĐỀ MƯỢN"
  Chạy trên: SERVER1, SERVER2   (sqlcmd -f 65001)
  ----------------------------------------------------------------------
  LÝ DO SỬA
  Trước đây bảng Bode_Muon được replication lọc sẵn bằng row filter
  MACS <> '<cơ sở này>', nên bản thân nó đã là "kho của cơ sở còn lại".
  Nay row filter đó đã được gỡ (để cây dẫn xuất khớp đúng cây mẫu của
  Thầy), Bode_Muon chứa câu hỏi của CẢ HAI cơ sở.

  Hệ quả nếu không sửa:
    * sp_ChuanBiThi ĐẾM TRÙNG kho đề (local bị cộng hai lần) -> tưởng đủ
      đề trong khi thực tế thiếu.
    * sp_LayDeThi "mượn" nhầm chính câu hỏi của cơ sở mình và gắn nhãn
      NGUON='MUON' -> sai ngữ nghĩa, mất minh chứng phân tán khi demo.

  CÁCH SỬA: lọc MACS ngay trong thủ tục (m.MACS <> @MACS) thay vì dựa
  vào bộ lọc của replication. Logic tự nó đúng, không phụ thuộc cấu hình
  nhân bản -> an toàn hơn và đọc là hiểu ngay.
======================================================================*/
USE TN_CSDLPT;
GO

/*======================================================================
  CÂU 7 - CHUẨN BỊ THI (đăng ký + kiểm tra đủ đề)
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

    /* Giáo viên phải cùng cơ sở với lớp */
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

    /*------------------------------------------------------------------
      KIỂM TRA ĐỦ ĐỀ (đề câu 7: "phải kiểm tra xem đã đủ đề chưa,
      nếu chưa đủ thì báo lỗi rõ ràng là thiếu bao nhiêu câu")

      Cần tối thiểu 70% số câu ở ĐÚNG trình độ (phần còn lại tối đa 30%
      được hạ 1 bậc). Kho tính gồm: đề của chính cơ sở lớp đang học
      (dbo.Bode) + đề MƯỢN được của cơ sở còn lại (Bode_Muon, MACS khác).
    ------------------------------------------------------------------*/
    DECLARE @MACS nchar(3) =
        (SELECT k.MACS FROM dbo.Lop l JOIN dbo.Khoa k ON l.MAKH=k.MAKH WHERE l.MALOP=@MALOP);

    DECLARE @canToiThieu int = @SOCAUTHI - FLOOR(@SOCAUTHI * 0.30);

    DECLARE @coLocal int =
        (SELECT COUNT(*) FROM dbo.Bode WHERE MAMH=@MAMH AND TRINHDO=@TRINHDO);
    DECLARE @coMuon int =
        (SELECT COUNT(*) FROM dbo.Bode_Muon
         WHERE MAMH=@MAMH AND TRINHDO=@TRINHDO
           AND MACS <> @MACS);          /* <== CHỈ tính đề của CƠ SỞ CÒN LẠI */
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

/*======================================================================
  CÂU 8 - PHÁT ĐỀ  (chỉ sửa 2 chỗ đọc Bode_Muon: thêm MACS <> @MACS)
======================================================================*/
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

    /*--- 1. Xác định LỚP + CƠ SỞ CỦA LỚP.
            Đề: ưu tiên lấy đề theo CƠ SỞ MÀ LỚP ĐANG HỌC (không phải
            theo giảng viên dạy).                                       ---*/
    IF @ThiThu = 1
    BEGIN
        IF @MALOP_ThiThu IS NULL
        BEGIN RAISERROR(N'Thi thử phải chọn lớp.',16,1); RETURN; END
        SELECT @MALOP = l.MALOP, @MACS = k.MACS
        FROM dbo.Lop l JOIN dbo.Khoa k ON l.MAKH = k.MAKH
        WHERE l.MALOP = @MALOP_ThiThu;
        IF @MALOP IS NULL BEGIN RAISERROR(N'Lớp không tồn tại tại cơ sở này.',16,1); RETURN; END
        IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE MAGV = @MASV)
        BEGIN RAISERROR(N'Chỉ giáo viên mới được thi thử.',16,1); RETURN; END
    END
    ELSE
    BEGIN
        SELECT @MALOP = sv.MALOP, @MACS = k.MACS
        FROM dbo.Sinhvien sv JOIN dbo.Lop l ON sv.MALOP = l.MALOP
                             JOIN dbo.Khoa k ON l.MAKH  = k.MAKH
        WHERE sv.MASV = @MASV;
        IF @MALOP IS NULL BEGIN RAISERROR(N'Không tìm thấy sinh viên tại cơ sở này.',16,1); RETURN; END
    END

    /*--- 2. Thông số kỳ thi giáo viên đã đăng ký ---*/
    SELECT @TD = TRINHDO, @SOCAU = SOCAUTHI, @TG = THOIGIAN, @NGAYTHI = NGAYTHI
    FROM dbo.Giaovien_Dangky WHERE MALOP=@MALOP AND MAMH=@MAMH AND LAN=@LAN;
    IF @TD IS NULL BEGIN RAISERROR(N'Lớp chưa được đăng ký thi môn/lần này.',16,1); RETURN; END

    /*--- 3. Ràng buộc chỉ áp cho thi THẬT ---*/
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

    /*--- 3b. Dùng lại đề lần trước ---*/
    IF @DungLaiDeLanTruoc = 1
    BEGIN
        IF @LAN <= 1
        BEGIN RAISERROR(N'Chỉ chọn lại được bộ đề khi thi từ lần 2 trở đi.',16,1); RETURN; END
        IF NOT EXISTS (SELECT 1 FROM dbo.ChiTiet_BaiThi
                       WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN-1)
        BEGIN RAISERROR(N'Không tìm thấy bài thi lần trước để lấy lại bộ đề.',16,1); RETURN; END
    END

    /*--- 4. Phiếu cũ quá hạn chưa nộp -> kết thúc bằng điểm 0 ---*/
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
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
        END CATCH
        RAISERROR(N'Bài thi trước của bạn đã hết giờ và bị kết thúc (0 điểm). Liên hệ giám thị nếu cần mở lại.',16,1);
        RETURN;
    END

    /*--- 5. Phiếu còn hiệu lực -> trả lại đúng phiếu cũ ---*/
    SELECT TOP 1 @MAPHIEU = MAPHIEU
    FROM dbo.PhieuThi
    WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN AND DANOP=0
      AND THITHU=@ThiThu AND HANNOP > GETDATE()
    ORDER BY BATDAU DESC;

    IF @MAPHIEU IS NULL
    BEGIN
        /*=============== 6. CHỌN CÂU HỎI ===============*/
        DECLARE @TDthap char(1) = CASE @TD WHEN 'A' THEN 'B' WHEN 'B' THEN 'C' ELSE NULL END;
        DECLARE @tranThap int = FLOOR(@SOCAU * 0.30);
        DECLARE @thieu int;

        CREATE TABLE #De(CAUHOI int PRIMARY KEY, NGUON varchar(5), TD char(1),
                         NOIDUNG nvarchar(max), A nvarchar(max), B nvarchar(max),
                         C nvarchar(max), D nvarchar(max), DAP_AN char(1));

        IF @DungLaiDeLanTruoc = 1
        BEGIN
            INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
            SELECT CAUHOI, 'CU', @TD, NOIDUNG, A, B, C, D, DAP_AN
            FROM dbo.ChiTiet_BaiThi
            WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN-1;
        END
        ELSE
        BEGIN
        /* (6a) ĐÚNG trình độ - kho của CƠ SỞ LỚP ĐANG HỌC (ưu tiên 1) */
        INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
        SELECT TOP (@SOCAU) CAUHOI, 'LOCAL', TRINHDO,
               CAST(NOIDUNG AS nvarchar(max)), CAST(A AS nvarchar(max)),
               CAST(B AS nvarchar(max)), CAST(C AS nvarchar(max)),
               CAST(D AS nvarchar(max)), DAP_AN
        FROM dbo.Bode WHERE MAMH=@MAMH AND TRINHDO=@TD
        ORDER BY NEWID();

        /* (6b) Thiếu -> MƯỢN cùng trình độ ở CƠ SỞ CÒN LẠI (ưu tiên 2).
           Lọc MACS <> @MACS ngay tại đây, KHÔNG dựa vào row filter của
           replication (row filter đó đã được gỡ để cây dẫn xuất khớp
           cây mẫu). Đọc bảng cục bộ nên sinh viên chạy được, không cần
           linked server. */
        SET @thieu = @SOCAU - (SELECT COUNT(*) FROM #De);
        IF @thieu > 0
            INSERT INTO #De(CAUHOI,NGUON,TD,NOIDUNG,A,B,C,D,DAP_AN)
            SELECT TOP (@thieu) m.CAUHOI, 'MUON', m.TRINHDO,
                   m.NOIDUNG, m.A, m.B, m.C, m.D, m.DAP_AN
            FROM dbo.Bode_Muon m
            WHERE m.MAMH = @MAMH AND m.TRINHDO = @TD
              AND m.MACS <> @MACS                      /* <== SỬA */
              AND m.CAUHOI NOT IN (SELECT CAUHOI FROM #De)
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
                WHERE MAMH=@MAMH AND TRINHDO=@TDthap AND CAUHOI NOT IN (SELECT CAUHOI FROM #De)
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
                  AND m.MACS <> @MACS                  /* <== SỬA */
                  AND m.CAUHOI NOT IN (SELECT CAUHOI FROM #De)
                ORDER BY NEWID();
        END
        END

        IF @DungLaiDeLanTruoc = 1 SET @SOCAU = (SELECT COUNT(*) FROM #De);

        /* (6d) Không đủ câu -> báo lỗi, tuyệt đối không phát đề thiếu */
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

        /*=============== 7. GHI PHIẾU THI ===============*/
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
            DROP TABLE #De;
            THROW;
        END CATCH
        DROP TABLE #De;
    END

    /*=============== 8. TRẢ VỀ CHO ỨNG DỤNG ===============*/
    SELECT MAPHIEU  AS maphieu,  SOCAU AS socau, THOIGIAN AS thoigian,
           BATDAU   AS batdau,   HANNOP AS hannop,
           DATEDIFF(SECOND, GETDATE(), HANNOP) AS sogiayconlai
    FROM dbo.PhieuThi WHERE MAPHIEU = @MAPHIEU;

    SELECT STT AS stt, CAUHOI AS cauhoi, NGUON AS nguon,
           NOIDUNG AS noidung, A AS a, B AS b, C AS c, D AS d
    FROM dbo.PhieuThi_CauHoi WHERE MAPHIEU = @MAPHIEU ORDER BY STT;
    /*      ^^^ CỐ Ý KHÔNG TRẢ DAP_AN - đáp án chỉ tồn tại phía server */
END
GO

/* Cấp lại quyền (CREATE OR ALTER giữ quyền, nhưng chạy cho chắc) */
DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN ('CoSo','Giangvien','Sinhvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS=0
BEGIN
    IF @r <> 'Sinhvien'
    BEGIN
        SET @sql = N'GRANT EXECUTE ON dbo.sp_ChuanBiThi TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    END
    SET @sql = N'GRANT EXECUTE ON dbo.sp_LayDeThi TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Câu 7 + 8: đã sửa logic kho đề mượn (lọc MACS trong SP) ==';
GO
