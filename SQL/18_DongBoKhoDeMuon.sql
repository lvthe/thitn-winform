/*======================================================================
  KHO ĐỀ MƯỢN (Bode_Muon): ĐƯA CƠ CHẾ LÀM MỚI VÀO REPO
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Chạy bằng: sqlcmd -f 65001
  Sau đó PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  CƠ CHẾ ĐANG CÓ (và nó CHẠY ĐÚNG)
  Trên MÁY CHỦ có thủ tục dbo.sp_LamMoi_BodeMuon: dựng lại toàn bộ
  Bode_Muon bằng một câu MERGE lấy từ BODE nối GIAOVIEN nối KHOA. Một SQL
  Agent job tên "TN_CSDLPT - Lam moi kho de muon" gọi nó MỖI 5 PHÚT, rồi
  nhân bản đẩy kết quả xuống hai phân mảnh.

  Phải chạy ở MÁY CHỦ vì chỉ ở đó bảng KHOA mới có đủ cả hai cơ sở. Chạy
  trên phân mảnh thì KHOA đã bị cây dẫn xuất lọc, MERGE sẽ tưởng đề của cơ
  sở kia là "không còn nguồn" rồi XOÁ SẠCH chúng khỏi kho mượn.

  VẤN ĐỀ THẬT SỰ: THỦ TỤC VÀ JOB KHÔNG CÓ TRONG REPO
  Cả hai chỉ tồn tại trong database. Dựng lại hệ thống ở máy khác bằng bộ
  script này thì mất hẳn - kho đề mượn đứng im vĩnh viễn mà không báo lỗi
  gì, nên câu 8 "thiếu thì mượn cơ sở còn lại" sẽ không bao giờ kích hoạt.
  Script này đưa cả hai vào repo (phần 1).

  ----------------------------------------------------------------------
  ★ GHI LẠI MỘT HƯỚNG ĐI SAI - ĐỪNG LẶP LẠI

  Bản đầu của script này cho sp_Bode_Them/Sua/Xoa ghi thẳng vào Bode_Muon
  ngay lúc giảng viên soạn đề, với ý định "mượn được ngay, khỏi chờ 5 phút".
  Ý tưởng đó HỎNG, vì hai publication KHÔNG đối xứng:

      TN_CSDLPT_CS1 . Bode_Muon : (không lọc)      -> nhận đủ mọi dòng
      TN_CSDLPT_CS2 . Bode_Muon : [MACS] <> 'CS2'  -> CHỈ nhận dòng của CS1

  Nên khi ghi một dòng MACS='CS2' vào Bode_Muon trên SERVER2, dòng đó vi
  phạm bộ lọc. Nhân bản đẩy nó ra bảng xung đột:

      MSmerge_conflict_TN_CSDLPT_CS2_Bode_Muon : 40 dòng
      kèm cảnh báo "The merge process is retrying a failed operation
      made to article 'Bode_Muon'"

  Mà lợi ích thì bằng KHÔNG: mỗi phân mảnh chỉ đọc Bode_Muon với điều kiện
  MACS <> cơ sở của mình, nên dòng CS2 nằm trong Bode_Muon của CS2 không ai
  đọc tới. Muốn CS1 mượn được đề CS2 thì dòng đó phải đi qua MÁY CHỦ -
  tức vẫn đúng đường mà job 5 phút đang làm.

  => Ba thủ tục bộ đề GIỮ NGUYÊN hành vi gốc: chỉ đụng dbo.Bode.
     Bode_Muon để job trên máy chủ lo. Phần 2 khôi phục lại chúng.
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;
GO

/*======================================================================
  1. sp_LamMoi_BodeMuon + job 5 phút - CHỈ TRÊN MÁY CHỦ

  Nhận diện máy chủ: KHÔNG dùng sysmergepublications, vì bảng hệ thống đó
  CÓ TRÊN CẢ SUBSCRIBER và cũng có dòng mô tả publication mà nó đăng ký.
  Đã dính đúng bẫy này một lần: job bị tạo nhầm lên cả hai phân mảnh, nơi
  mệnh đề WHEN NOT MATCHED BY SOURCE THEN DELETE sẽ quét sạch đề mượn của
  cơ sở kia. Chỉ IsMergePublished mới phân biệt được.
======================================================================*/
DECLARE @laMayChu bit =
    CASE WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsMergePublished') = 1 THEN 1 ELSE 0 END;

IF @laMayChu = 1
BEGIN
    EXEC(N'
CREATE OR ALTER PROCEDURE dbo.sp_LamMoi_BodeMuon
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    ;WITH src AS (
        SELECT b.CAUHOI, k.MACS, b.MAMH, b.TRINHDO,
               CAST(b.NOIDUNG AS nvarchar(max)) AS NOIDUNG,
               CAST(b.A AS nvarchar(max)) AS A, CAST(b.B AS nvarchar(max)) AS B,
               CAST(b.C AS nvarchar(max)) AS C, CAST(b.D AS nvarchar(max)) AS D,
               b.DAP_AN, b.MAGV
        FROM dbo.BODE b
        JOIN dbo.GIAOVIEN g ON b.MAGV = g.MAGV
        JOIN dbo.KHOA     k ON g.MAKH = k.MAKH
        WHERE b.DAP_AN IS NOT NULL AND b.MAGV IS NOT NULL
    )
    MERGE dbo.Bode_Muon AS t
    USING src AS s ON t.CAUHOI = s.CAUHOI
    WHEN MATCHED AND (t.MACS <> s.MACS OR t.MAMH <> s.MAMH OR t.TRINHDO <> s.TRINHDO
                   OR t.DAP_AN <> s.DAP_AN OR t.MAGV <> s.MAGV
                   OR ISNULL(t.NOIDUNG,N'''') <> ISNULL(s.NOIDUNG,N'''')
                   OR ISNULL(t.A,N'''') <> ISNULL(s.A,N'''') OR ISNULL(t.B,N'''') <> ISNULL(s.B,N'''')
                   OR ISNULL(t.C,N'''') <> ISNULL(s.C,N'''') OR ISNULL(t.D,N'''') <> ISNULL(s.D,N''''))
        THEN UPDATE SET t.MACS=s.MACS, t.MAMH=s.MAMH, t.TRINHDO=s.TRINHDO,
                        t.NOIDUNG=s.NOIDUNG, t.A=s.A, t.B=s.B, t.C=s.C, t.D=s.D,
                        t.DAP_AN=s.DAP_AN, t.MAGV=s.MAGV
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (CAUHOI,MACS,MAMH,TRINHDO,NOIDUNG,A,B,C,D,DAP_AN,MAGV)
             VALUES (s.CAUHOI,s.MACS,s.MAMH,s.TRINHDO,s.NOIDUNG,s.A,s.B,s.C,s.D,s.DAP_AN,s.MAGV)
    WHEN NOT MATCHED BY SOURCE
        THEN DELETE;
    SELECT @@ROWCOUNT AS SoDongThayDoi;
END');
    PRINT N'  + sp_LamMoi_BodeMuon (máy chủ)';

    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'TN_CSDLPT - Lam moi kho de muon')
    BEGIN
        DECLARE @db sysname = DB_NAME();
        EXEC msdb.dbo.sp_add_job     @job_name = N'TN_CSDLPT - Lam moi kho de muon';
        EXEC msdb.dbo.sp_add_jobstep @job_name = N'TN_CSDLPT - Lam moi kho de muon',
             @step_name = N'Lam moi', @subsystem = N'TSQL',
             @command = N'EXEC dbo.sp_LamMoi_BodeMuon;', @database_name = @db;
        EXEC msdb.dbo.sp_add_jobschedule @job_name = N'TN_CSDLPT - Lam moi kho de muon',
             @name = N'Moi 5 phut', @freq_type = 4, @freq_interval = 1,
             @freq_subday_type = 4, @freq_subday_interval = 5;
        EXEC msdb.dbo.sp_add_jobserver @job_name = N'TN_CSDLPT - Lam moi kho de muon';
        PRINT N'  + job "TN_CSDLPT - Lam moi kho de muon" (5 phút/lần)';
    END
    ELSE PRINT N'  (job làm mới kho đề mượn đã có sẵn)';

    EXEC dbo.sp_LamMoi_BodeMuon;      /* chạy ngay một lần cho khỏi chờ */
END
ELSE
    PRINT N'  (phân mảnh - bỏ qua sp_LamMoi_BodeMuon, đúng thiết kế)';
GO

/*======================================================================
  2. KHÔI PHỤC ba thủ tục bộ đề về hành vi gốc: CHỈ đụng dbo.Bode
     (xem phần "hướng đi sai" ở đầu file)
======================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[sp_Bode_Them]
    @MAMH char(5), @TRINHDO char(1),
    @NOIDUNG nvarchar(max), @A nvarchar(max), @B nvarchar(max),
    @C nvarchar(max), @D nvarchar(max), @DAP_AN char(1),
    @MAGV char(8) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @gvHienTai char(8) = NULL;
    IF ISNULL(IS_MEMBER('Giangvien'),0) = 1 AND ISNULL(IS_MEMBER('CoSo'),0) = 0
        SET @gvHienTai = CAST(SUSER_SNAME() AS char(8));
    IF @gvHienTai IS NOT NULL SET @MAGV = @gvHienTai;      /* GV luôn ghi đề cho chính mình */

    IF @MAGV IS NULL BEGIN RAISERROR(N'Thiếu mã giáo viên cho câu hỏi.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE MAGV=@MAGV)
        BEGIN RAISERROR(N'Mã giáo viên không tồn tại tại cơ sở này.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Monhoc WHERE MAMH=@MAMH)
        BEGIN RAISERROR(N'Môn học không tồn tại.',16,1); RETURN; END
    IF @TRINHDO NOT IN ('A','B','C')     BEGIN RAISERROR(N'Trình độ phải là A, B hoặc C.',16,1); RETURN; END
    IF @DAP_AN NOT IN ('A','B','C','D')  BEGIN RAISERROR(N'Đáp án phải là A, B, C hoặc D.',16,1); RETURN; END
    IF LEN(LTRIM(RTRIM(ISNULL(@NOIDUNG,N'')))) = 0
        BEGIN RAISERROR(N'Nội dung câu hỏi không được để trống.',16,1); RETURN; END

    /* Dải mã suy từ CƠ SỞ CỦA GIÁO VIÊN: CS1 -> 1.000.000, CS2 -> 1.500.000 */
    DECLARE @macs nchar(3) =
        (SELECT k.MACS FROM dbo.Giaovien g JOIN dbo.Khoa k ON g.MAKH = k.MAKH WHERE g.MAGV = @MAGV);
    DECLARE @base int =
        CASE RIGHT(RTRIM(ISNULL(@macs,N'')),1) WHEN '1' THEN 1000000 WHEN '2' THEN 1500000 END;
    IF @base IS NULL
        BEGIN RAISERROR(N'Không xác định được cơ sở của giáo viên để cấp mã câu hỏi.',16,1); RETURN; END
    DECLARE @tran int = @base + 499999;

    DECLARE @cauhoi int;
    BEGIN TRY
        BEGIN TRAN;
            /* Khoá dải khoá trong cùng giao tác -> hai giảng viên bấm Ghi
               cùng lúc không thể lấy trùng số. */
            SELECT @cauhoi = ISNULL(MAX(CAUHOI), @base - 1) + 1
            FROM dbo.Bode WITH (UPDLOCK, HOLDLOCK)
            WHERE CAUHOI BETWEEN @base AND @tran;

            IF @cauhoi > @tran
            BEGIN
                RAISERROR(N'Đã hết dải mã câu hỏi dành cho cơ sở này.',16,1);
                ROLLBACK; RETURN;
            END

            INSERT INTO dbo.Bode(CAUHOI,MAMH,TRINHDO,NOIDUNG,A,B,C,D,DAP_AN,MAGV)
            VALUES(@cauhoi,@MAMH,@TRINHDO,@NOIDUNG,@A,@B,@C,@D,@DAP_AN,@MAGV);
            /* KHÔNG ghi Bode_Muon ở đây - job trên máy chủ lo, tối đa 5 phút */
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT @cauhoi AS cauhoi;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_Bode_Sua]
    @CAUHOI int, @MAMH char(5), @TRINHDO char(1),
    @NOIDUNG nvarchar(max), @A nvarchar(max), @B nvarchar(max),
    @C nvarchar(max), @D nvarchar(max), @DAP_AN char(1),
    @MAGV char(8) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @gvHienTai char(8) = NULL;
    IF ISNULL(IS_MEMBER('Giangvien'),0) = 1 AND ISNULL(IS_MEMBER('CoSo'),0) = 0
        SET @gvHienTai = CAST(SUSER_SNAME() AS char(8));
    IF @TRINHDO NOT IN ('A','B','C')     BEGIN RAISERROR(N'Trình độ phải là A, B hoặc C.',16,1); RETURN; END
    IF @DAP_AN NOT IN ('A','B','C','D')  BEGIN RAISERROR(N'Đáp án phải là A, B, C hoặc D.',16,1); RETURN; END

    UPDATE dbo.Bode
    SET MAMH=@MAMH, TRINHDO=@TRINHDO, NOIDUNG=@NOIDUNG,
        A=@A, B=@B, C=@C, D=@D, DAP_AN=@DAP_AN,
        MAGV = CASE WHEN @gvHienTai IS NOT NULL THEN MAGV     /* GV không đổi chủ sở hữu */
                    ELSE ISNULL(@MAGV, MAGV) END
    WHERE CAUHOI = @CAUHOI
      AND (@gvHienTai IS NULL OR MAGV = @gvHienTai);

    IF @@ROWCOUNT = 0
        RAISERROR(N'Không sửa được: câu hỏi không tồn tại hoặc không do bạn soạn.',16,1);
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_Bode_Xoa]
    @CAUHOI int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @gvHienTai char(8) = NULL;
    IF ISNULL(IS_MEMBER('Giangvien'),0) = 1 AND ISNULL(IS_MEMBER('CoSo'),0) = 0
        SET @gvHienTai = CAST(SUSER_SNAME() AS char(8));

    DELETE FROM dbo.Bode
    WHERE CAUHOI = @CAUHOI
      AND (@gvHienTai IS NULL OR MAGV = @gvHienTai);

    IF @@ROWCOUNT = 0
        RAISERROR(N'Không xóa được: câu hỏi không tồn tại hoặc không do bạn soạn.',16,1);
END
GO
PRINT N'  + sp_Bode_Them / Sua / Xoa (khôi phục hành vi gốc: chỉ đụng dbo.Bode)';
GO

/*======================================================================
  3. Quyền trên Bode_Muon - không ai được sửa trực tiếp
======================================================================*/
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
    DENY INSERT, UPDATE, DELETE ON dbo.Bode_Muon TO [Giangvien];
IF DATABASE_PRINCIPAL_ID('Sinhvien') IS NOT NULL
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Bode_Muon TO [Sinhvien];
GO

PRINT N'== Xong. Nhớ chạy lại 12_CapLaiQuyen.sql ==';
GO

/*----------------------------------------------------------------------
  Kiểm tra.
  LƯU Ý: trên SERVER2, Bode_Muon ÍT HƠN Bode là ĐÚNG, vì publication CS2
  lọc [MACS] <> 'CS2' - phần chênh chính là số câu do giáo viên CS2 soạn.
  Trên máy chủ và SERVER1 thì hai số phải bằng nhau.
----------------------------------------------------------------------*/
SELECT may            = @@SERVERNAME,
       bode           = (SELECT COUNT(*) FROM dbo.Bode),
       bode_muon      = (SELECT COUNT(*) FROM dbo.Bode_Muon),
       muon_theo_MACS = (SELECT STRING_AGG(CONCAT(RTRIM(MACS),'=',n), ' ')
                         FROM (SELECT MACS, n = COUNT(*) FROM dbo.Bode_Muon GROUP BY MACS) x);
GO
