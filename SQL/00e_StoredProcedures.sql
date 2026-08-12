/*======================================================================
  TOAN BO STORED PROCEDURE NGHIEP VU
  Chay tren: SERVER1, SERVER2 va SERVER (publisher)
  Chay bang: sqlcmd -f 65001 (tep luu UTF-8) de khong loi font tieng Viet
======================================================================*/
USE TN_CSDLPT;
GO

/*---------- SP_TAOLOGIN ----------*/

/*=====================================================================
  1. SP_TAOLOGIN - thêm ràng buộc cho nhóm Giangvien
=====================================================================*/
CREATE   PROCEDURE dbo.SP_TAOLOGIN
    @username sysname, @password nvarchar(128), @role sysname
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    /* Quyền xét theo NGƯỜI GỌI thật, không theo owner đang mượn ngữ cảnh */
    DECLARE @caller sysname = ORIGINAL_LOGIN();
    DECLARE @isCoSo bit = 0, @isTruong bit = 0;
    SELECT @isCoSo = 1 FROM sys.database_role_members m
      JOIN sys.database_principals r ON m.role_principal_id = r.principal_id
      JOIN sys.database_principals u ON m.member_principal_id = u.principal_id
      WHERE r.name = 'CoSo' AND u.name = @caller;
    SELECT @isTruong = 1 FROM sys.database_role_members m
      JOIN sys.database_principals r ON m.role_principal_id = r.principal_id
      JOIN sys.database_principals u ON m.member_principal_id = u.principal_id
      WHERE r.name = 'Truong' AND u.name = @caller;

    IF @isTruong = 1
    BEGIN
        IF @role <> N'Truong' BEGIN RAISERROR(N'Trưởng chỉ tạo được tài khoản nhóm Truong.',16,1); RETURN; END
    END
    ELSE IF @isCoSo = 1
    BEGIN
        IF @role NOT IN (N'CoSo', N'Giangvien') BEGIN RAISERROR(N'Cơ sở chỉ tạo được CoSo / Giangvien.',16,1); RETURN; END
    END
    ELSE
    BEGIN RAISERROR(N'Bạn không có quyền tạo tài khoản.',16,1); RETURN; END

    IF @username IS NULL OR LTRIM(@username)=N'' OR @password IS NULL OR LEN(@password)<3
        BEGIN RAISERROR(N'Thiếu tên đăng nhập hoặc mật khẩu (>=3 ký tự).',16,1); RETURN; END
    IF @username = @role
        BEGIN RAISERROR(N'Tên đăng nhập không được trùng tên nhóm (SQL không phân biệt hoa/thường).',16,1); RETURN; END
    IF DATABASE_PRINCIPAL_ID(@role) IS NULL
        BEGIN RAISERROR(N'Nhóm quyền không tồn tại trên server này.',16,1); RETURN; END
    IF SUSER_ID(@username) IS NOT NULL
        BEGIN RAISERROR(N'Tài khoản đã tồn tại.',16,1); RETURN; END

    /*--- MỚI: giảng viên phải được ĐĂNG KÝ TRƯỚC ở màn Giáo viên ---
      Đề câu 1: "Trước khi sinh viên/giáo viên sử dụng chương trình thì phải
      đăng ký trước". Với giảng viên, đăng ký = có dòng trong bảng Giaovien.
      Tên đăng nhập PHẢI trùng MAGV để các thủ tục lọc đề theo SUSER_SNAME()
      biết câu hỏi nào là của giảng viên nào.                              */
    IF @role = N'Giangvien'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE RTRIM(MAGV) = RTRIM(@username))
        BEGIN
            DECLARE @m nvarchar(300) = N'Chưa có giáo viên mã "' + @username
                + N'" tại cơ sở này. Vào màn Giáo viên khai báo giáo viên trước, '
                + N'rồi mới tạo tài khoản với tên đăng nhập ĐÚNG BẰNG mã giáo viên.';
            RAISERROR(@m,16,1); RETURN;
        END
    END

    DECLARE @sql nvarchar(max);
    SET @sql = N'CREATE LOGIN ' + QUOTENAME(@username) +
               N' WITH PASSWORD = ' + QUOTENAME(@password, '''') + N', CHECK_POLICY = OFF;';
    EXEC (@sql);
    SET @sql = N'CREATE USER ' + QUOTENAME(@username) + N' FOR LOGIN ' + QUOTENAME(@username) + N';';
    EXEC (@sql);
    SET @sql = N'ALTER ROLE ' + QUOTENAME(@role) + N' ADD MEMBER ' + QUOTENAME(@username) + N';';
    EXEC (@sql);

    SELECT N'Đã tạo tài khoản ' + @username + N' thuộc nhóm ' + @role AS Message;
END
GO

/*---------- sp_BangDiemMonHoc ----------*/

/*======================================================================
  CÂU 10 - BẢNG ĐIỂM MÔN HỌC CỦA MỘT LỚP
  ----------------------------------------------------------------------
  Đề: giảng viên chọn LỚP + MÔN + LẦN THI (đúng khóa chính của bảng
  đăng ký) -> in bảng điểm thi hết môn của lớp đó.

  Yêu cầu riêng của Thầy về ĐIỂM:
     "lấy một số lẻ ... làm tròn đến 0.5"
     -> chỉ được phép ra 5 / 5.5 / 6 / 6.5 ..., KHÔNG có 2.25
     Công thức: ROUND(DIEM * 2, 0) / 2
     Điểm chữ quy đổi TỪ ĐIỂM ĐÃ LÀM TRÒN (để điểm số và điểm chữ
     không mâu thuẫn nhau trên cùng một dòng).
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_BangDiemMonHoc]
    @MALOP nchar(15), @MAMH char(5), @LAN smallint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  TENLOP  = l.TENLOP,
            TENMH   = mh.TENMH,
            LAN     = bd.LAN,
            MASV    = RTRIM(sv.MASV),
            HOTEN   = RTRIM(sv.HO) + N' ' + RTRIM(sv.TEN),
            DIEM    = CAST(ROUND(bd.DIEM * 2, 0) / 2 AS decimal(4,1)),
            DIEMCHU = CASE
                        WHEN ROUND(bd.DIEM * 2, 0) / 2 >= 8.5 THEN N'A'
                        WHEN ROUND(bd.DIEM * 2, 0) / 2 >= 7.0 THEN N'B'
                        WHEN ROUND(bd.DIEM * 2, 0) / 2 >= 5.5 THEN N'C'
                        WHEN ROUND(bd.DIEM * 2, 0) / 2 >= 4.0 THEN N'D'
                        ELSE N'F' END,
            NGAYTHI = bd.NGAYTHI
    FROM dbo.BangDiem bd
      JOIN dbo.Sinhvien sv ON bd.MASV  = sv.MASV
      JOIN dbo.Lop      l  ON sv.MALOP = l.MALOP
      JOIN dbo.Monhoc   mh ON bd.MAMH  = mh.MAMH
    WHERE sv.MALOP = @MALOP AND bd.MAMH = @MAMH AND bd.LAN = @LAN
    ORDER BY sv.MASV;
END
GO

/*---------- sp_BaoCao_DangKy ----------*/

/*======================================================================
  CÂU 11 - DANH SÁCH ĐĂNG KÝ THI CỦA CẢ HAI CƠ SỞ
  ----------------------------------------------------------------------
  RÀNG BUỘC CỦA THẦY (nhắc lại 2 lần trong bài giảng):
     "Riêng câu 11 này KHÔNG được về server chủ, bắt buộc phải chạy
      trên 2 phân mảnh. Ý tưởng của tôi là dùng phép UNION."

  => Thủ tục này được cài trên TỪNG PHÂN MẢNH (SERVER1, SERVER2).
     Mỗi phân mảnh chỉ chứa dữ liệu cơ sở mình (nhờ cây dẫn xuất),
     nên KHÔNG cần điều kiện lọc MACS - bản thân phân mảnh ĐÃ LÀ bộ lọc.
     Ứng dụng gọi thủ tục này trên CẢ HAI phân mảnh rồi UNION hai kết
     quả lại thành một báo cáo. Tuyệt đối không đụng tới server chủ.

  Cột theo yêu cầu đề: lớp, môn học, giảng viên đăng ký, ngày thi,
  và cột ĐÃ THI (đánh 'X' nếu đã thi, để trống nếu chưa).
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_BaoCao_DangKy]
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
    WHERE dk.NGAYTHI >= @tungay
      AND dk.NGAYTHI <  DATEADD(DAY, 1, @denngay)
    ORDER BY dk.NGAYTHI, lop.TENLOP;
END
GO

/*---------- sp_Bode_DS ----------*/
/*======================================================================
  BỘ ĐỀ (đề mục 6) - 4 SP thay cho SQL trực tiếp từ ứng dụng.

  "GV đang đăng nhập là ai" được xác định từ CHÍNH SQL LOGIN
  (SUSER_SNAME(), vì login của giảng viên đặt trùng MAGV), KHÔNG lấy từ
  tham số do ứng dụng gửi lên => không thể giả mạo bằng cách gọi thẳng API.
  Với nhóm CoSo (toàn quyền trên phân mảnh) thì @magv = NULL -> thấy tất cả.
======================================================================*/

/*--- Danh sách câu hỏi ---*/
CREATE   PROCEDURE [dbo].[sp_Bode_DS]
    @MAMH char(5) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @magv char(8) = NULL;
    IF ISNULL(IS_MEMBER('Giangvien'),0) = 1 AND ISNULL(IS_MEMBER('CoSo'),0) = 0
        SET @magv = CAST(SUSER_SNAME() AS char(8));

    SELECT CAUHOI AS cauhoi, RTRIM(MAMH) AS mamh, RTRIM(TRINHDO) AS trinhdo,
           CAST(NOIDUNG AS nvarchar(max)) AS noidung,
           CAST(A AS nvarchar(max)) AS a, CAST(B AS nvarchar(max)) AS b,
           CAST(C AS nvarchar(max)) AS c, CAST(D AS nvarchar(max)) AS d,
           RTRIM(DAP_AN) AS dap_an, RTRIM(MAGV) AS magv
    FROM dbo.Bode
    WHERE (@magv IS NULL OR MAGV = @magv)                 -- GV: chỉ đề của mình
      AND (@MAMH IS NULL OR MAMH = @MAMH)
    ORDER BY CAUHOI;
END
GO

/*---------- sp_Bode_Sua ----------*/
/*--- Sửa câu hỏi (GV chỉ sửa được câu của mình - ép ở DB) ---*/
CREATE   PROCEDURE [dbo].[sp_Bode_Sua]
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
        MAGV = CASE WHEN @gvHienTai IS NOT NULL THEN MAGV     -- GV không đổi chủ sở hữu
                    ELSE ISNULL(@MAGV, MAGV) END
    WHERE CAUHOI = @CAUHOI
      AND (@gvHienTai IS NULL OR MAGV = @gvHienTai);

    IF @@ROWCOUNT = 0
        RAISERROR(N'Không sửa được: câu hỏi không tồn tại hoặc không do bạn soạn.',16,1);
END
GO

/*---------- sp_Bode_Them ----------*/
/*--- Thêm câu hỏi (P0-6: mã không trùng giữa 2 cơ sở khi merge) ---------
  Dải mã suy từ CƠ SỞ CỦA GIÁO VIÊN soạn đề (KHOA.MACS - dữ liệu đã
  replicate), nên SP này chạy đúng ở bất kỳ server nào mà KHÔNG cần một
  đối tượng cục bộ nào:
        CS1 -> 1.000.000 .. 1.499.999
        CS2 -> 1.500.000 .. 1.999.999
  Dải đặt HẲN TRÊN vùng dữ liệu cũ vì CAUHOI hiện có (1..259) của hai cơ
  sở đang đan xen nhau, không tách được ở vùng thấp.

  Nguyên tử: SELECT MAX(...) WITH (UPDLOCK, HOLDLOCK) trong cùng giao tác
  với INSERT -> khoá dải khoá (key-range lock), hai giảng viên bấm Ghi
  cùng lúc không thể lấy trùng số. Thay cho SEQUENCE (không replicate được)
  và cho MAX+1 trần trụi của bản cũ (không nguyên tử).                    */
CREATE   PROCEDURE [dbo].[sp_Bode_Them]
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
    IF @gvHienTai IS NOT NULL SET @MAGV = @gvHienTai;      -- GV luôn ghi đề cho chính mình

    IF @MAGV IS NULL BEGIN RAISERROR(N'Thiếu mã giáo viên cho câu hỏi.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Giaovien WHERE MAGV=@MAGV)
        BEGIN RAISERROR(N'Mã giáo viên không tồn tại tại cơ sở này.',16,1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.Monhoc WHERE MAMH=@MAMH)
        BEGIN RAISERROR(N'Môn học không tồn tại.',16,1); RETURN; END
    IF @TRINHDO NOT IN ('A','B','C')     BEGIN RAISERROR(N'Trình độ phải là A, B hoặc C.',16,1); RETURN; END
    IF @DAP_AN NOT IN ('A','B','C','D')  BEGIN RAISERROR(N'Đáp án phải là A, B, C hoặc D.',16,1); RETURN; END
    IF LEN(LTRIM(RTRIM(ISNULL(@NOIDUNG,N'')))) = 0
        BEGIN RAISERROR(N'Nội dung câu hỏi không được để trống.',16,1); RETURN; END

    /* Cơ sở của giáo viên -> dải mã */
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
            SELECT @cauhoi = ISNULL(MAX(CAUHOI), @base - 1) + 1
            FROM dbo.Bode WITH (UPDLOCK, HOLDLOCK)
            WHERE CAUHOI BETWEEN @base AND @tran;

            IF @cauhoi > @tran
            BEGIN
                ROLLBACK;
                RAISERROR(N'Đã dùng hết dải mã câu hỏi của cơ sở này.',16,1); RETURN;
            END

            INSERT INTO dbo.Bode(CAUHOI,MAMH,TRINHDO,NOIDUNG,A,B,C,D,DAP_AN,MAGV)
            VALUES(@cauhoi,@MAMH,@TRINHDO,@NOIDUNG,@A,@B,@C,@D,@DAP_AN,@MAGV);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT @cauhoi AS cauhoi;
END
GO

/*---------- sp_Bode_Xoa ----------*/
/*--- Xoá câu hỏi ---*/
CREATE   PROCEDURE [dbo].[sp_Bode_Xoa]
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

/*---------- sp_ChuanBiThi ----------*/

/*======================================================================
  CÂU 7 - CHUẨN BỊ THI (đăng ký + kiểm tra đủ đề)
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_ChuanBiThi]
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

/*---------- sp_DangNhap_SV ----------*/
/*======================================================================
  ĐĂNG NHẬP SINH VIÊN  (đề mục 1: "masv xem như là login name" + Password)
  Tất cả sinh viên dùng CHUNG 1 SQL login (đề mục phân quyền), nên danh
  tính cụ thể phải xác thực thêm bằng MASV + PASSWORD ở tầng dữ liệu.
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_DangNhap_SV]
    @MASV char(8), @PASSWORD nvarchar(30)
AS
BEGIN
    SET NOCOUNT ON;
    /* KHÔNG dùng COL_LENGTH để kiểm cột ở đây: các hàm metadata tuân theo
       quyền của NGƯỜI GỌI, mà nhóm Sinhvien đã bị thu hồi sạch quyền bảng
       -> COL_LENGTH trả NULL dù cột vẫn tồn tại, làm SP báo lỗi sai.
       (Ownership chaining chỉ bao phủ truy cập DỮ LIỆU, không bao phủ
        khả năng nhìn thấy metadata.)                                      */
    SELECT RTRIM(sv.MASV) AS masv,
           RTRIM(sv.HO) + N' ' + RTRIM(sv.TEN) AS hoten,
           RTRIM(sv.MALOP) AS malop, l.TENLOP AS tenlop
    FROM dbo.Sinhvien sv JOIN dbo.Lop l ON sv.MALOP = l.MALOP
    WHERE sv.MASV = @MASV
      AND RTRIM(sv.PASSWORD) = RTRIM(ISNULL(@PASSWORD, N''));
END
GO

/*---------- SP_DOIMATKHAU ----------*/

/*----------------------------------------------------------------------
  2. Đổi mật khẩu CÁN BỘ (Giảng viên / Cơ sở / Trưởng).
     Mỗi người một SQL login riêng nên đổi bằng ALTER LOGIN.
     KHÔNG dùng EXECUTE AS: một login luôn được phép tự đổi mật khẩu
     của chính mình khi cung cấp OLD_PASSWORD, không cần quyền đặc biệt.
----------------------------------------------------------------------*/
CREATE   PROCEDURE dbo.SP_DOIMATKHAU
    @MatKhauCu  nvarchar(128),
    @MatKhauMoi nvarchar(128)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @me sysname = ORIGINAL_LOGIN();

    IF @MatKhauMoi IS NULL OR LEN(@MatKhauMoi) < 3
    BEGIN RAISERROR(N'Mật khẩu mới phải có ít nhất 3 ký tự.', 16, 1); RETURN; END
    IF @MatKhauMoi = @MatKhauCu
    BEGIN RAISERROR(N'Mật khẩu mới trùng mật khẩu cũ.', 16, 1); RETURN; END

    DECLARE @sql nvarchar(max) =
        N'ALTER LOGIN ' + QUOTENAME(@me) +
        N' WITH PASSWORD = '     + QUOTENAME(@MatKhauMoi, '''') +
        N' OLD_PASSWORD = '      + QUOTENAME(@MatKhauCu , '''') + N';';

    BEGIN TRY
        EXEC (@sql);
        SELECT N'Đổi mật khẩu thành công.' AS Message;
    END TRY
    BEGIN CATCH
        RAISERROR(N'Mật khẩu hiện tại không đúng hoặc mật khẩu mới không đạt yêu cầu.', 16, 1);
    END CATCH
END
GO

/*---------- sp_DoiMatKhau_SV ----------*/

/*----------------------------------------------------------------------
  1. Đổi mật khẩu SINH VIÊN (mật khẩu nằm trong bảng SINHVIEN vì
     toàn bộ sinh viên dùng chung 1 SQL login).
     Bản cũ bị lỗi font ở các thông báo -> tạo lại.
----------------------------------------------------------------------*/
CREATE   PROCEDURE dbo.sp_DoiMatKhau_SV
    @MASV        nchar(8),
    @MatKhauCu   nvarchar(30),
    @MatKhauMoi  nvarchar(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF @MatKhauMoi IS NULL OR LEN(@MatKhauMoi) < 3
    BEGIN RAISERROR(N'Mật khẩu mới phải có ít nhất 3 ký tự.', 16, 1); RETURN; END

    IF NOT EXISTS (SELECT 1 FROM dbo.Sinhvien
                   WHERE MASV = @MASV AND RTRIM([PASSWORD]) = RTRIM(ISNULL(@MatKhauCu, N'')))
    BEGIN RAISERROR(N'Mật khẩu hiện tại không đúng.', 16, 1); RETURN; END

    IF @MatKhauMoi = @MatKhauCu
    BEGIN RAISERROR(N'Mật khẩu mới trùng mật khẩu cũ.', 16, 1); RETURN; END

    UPDATE dbo.Sinhvien SET [PASSWORD] = @MatKhauMoi WHERE MASV = @MASV;
    SELECT N'Đổi mật khẩu thành công.' AS Message;
END
GO

/*---------- sp_DS_GV_ChuaCoTaiKhoan ----------*/

/*=====================================================================
  3. GIÁO VIÊN ĐÃ KHAI BÁO NHƯNG CHƯA CÓ TÀI KHOẢN
  Dùng cho màn Tạo tài khoản: bấm chọn là điền sẵn đúng mã giáo viên.
=====================================================================*/
CREATE   PROCEDURE dbo.sp_DS_GV_ChuaCoTaiKhoan
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RTRIM(g.MAGV) AS magv,
           RTRIM(g.HO) + N' ' + RTRIM(g.TEN) AS hoten,
           g.HOCVI AS hocvi,
           RTRIM(g.MAKH) AS makh
    FROM dbo.Giaovien g
    WHERE NOT EXISTS (SELECT 1 FROM sys.database_principals u
                      WHERE u.type IN ('S','U') AND u.name = RTRIM(g.MAGV))
    ORDER BY g.MAGV;
END
GO

/*---------- SP_DS_SAOLUU ----------*/

/*----------------------------------------------------------------------
  3. Danh sách bản sao lưu
----------------------------------------------------------------------*/
CREATE   PROCEDURE dbo.SP_DS_SAOLUU
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID, TENFILE, THOIDIEM, NGUOITAO, GHICHU
    FROM dbo.NhatKy_SaoLuu ORDER BY THOIDIEM DESC;
END
GO

/*---------- sp_DS_TaiKhoan ----------*/

/*=====================================================================
  2. DANH SÁCH TÀI KHOẢN TRÊN SERVER NÀY
  Trả lời câu hỏi "tài khoản Trưởng / Cơ sở nằm ở đâu": chúng KHÔNG nằm
  trong bảng dữ liệu nào mà là login + user + role của SQL Server.
=====================================================================*/
CREATE   PROCEDURE dbo.sp_DS_TaiKhoan
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.name                              AS tendangnhap,
        r.name                              AS nhom,
        CAST(@@SERVERNAME AS nvarchar(128)) AS server,
        CASE WHEN sp.is_disabled = 1 THEN N'Khoá' ELSE N'Hoạt động' END AS trangthai,
        CASE r.name
             WHEN N'Giangvien' THEN ISNULL(
                  (SELECT RTRIM(g.HO) + N' ' + RTRIM(g.TEN) FROM dbo.Giaovien g
                    WHERE RTRIM(g.MAGV) = RTRIM(u.name)), N'(chưa khai báo ở màn Giáo viên)')
             WHEN N'Sinhvien'  THEN N'(tài khoản dùng chung — sinh viên đăng nhập bằng mã SV)'
             ELSE N''
        END                                 AS ghichu
    FROM sys.database_role_members m
    JOIN sys.database_principals r  ON m.role_principal_id  = r.principal_id
    JOIN sys.database_principals u  ON m.member_principal_id = u.principal_id
    LEFT JOIN sys.server_principals sp ON sp.name = u.name
    WHERE r.name IN (N'Truong', N'CoSo', N'Giangvien', N'Sinhvien')
    ORDER BY CASE r.name WHEN N'Truong' THEN 1 WHEN N'CoSo' THEN 2
                         WHEN N'Giangvien' THEN 3 ELSE 4 END, u.name;
END
GO

/*---------- sp_LayDeThi ----------*/

/*----------------------------------------------------------------------
  2. sp_LayDeThi - #De định danh bằng (CAUHOI, NGUON)
----------------------------------------------------------------------*/
CREATE   PROCEDURE [dbo].[sp_LayDeThi]
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

/*---------- SP_LayThongTinNguoiDung ----------*/
CREATE OR ALTER PROCEDURE dbo.SP_LayThongTinNguoiDung
    @TENLOGIN nvarchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /* Không truyền tham số -> lấy chính người đang đăng nhập */
    IF @TENLOGIN IS NULL SET @TENLOGIN = ORIGINAL_LOGIN();

    DECLARE @TENUSER nvarchar(50), @UID int;

    SELECT @UID = UID, @TENUSER = NAME
    FROM sys.sysusers
    WHERE sid = SUSER_SID(@TENLOGIN);

    IF @TENUSER IS NULL
    BEGIN
        /* Login chưa được ánh xạ thành user trong CSDL này */
        SELECT MA = @TENLOGIN, HOTEN = CAST(NULL AS nvarchar(100)), TENNHOM = CAST(N'' AS nvarchar(128));
        RETURN;
    END

    SELECT  MA      = @TENUSER,
            HOTEN   = (SELECT RTRIM(HO) + N' ' + RTRIM(TEN)
                       FROM dbo.GIAOVIEN WHERE RTRIM(MAGV) = RTRIM(@TENUSER)),
            TENNHOM = u.NAME
    FROM sys.sysusers u
    WHERE u.UID IN (SELECT GROUPUID FROM sys.sysmembers WHERE MEMBERUID = @UID)
      /* Chỉ lấy nhóm quyền của ứng dụng, bỏ các vai trò hệ thống và
         vai trò nội bộ của replication (MSmerge_...) */
      AND u.NAME IN (N'Truong', N'CoSo', N'Giangvien', N'Sinhvien');
END
GO

/*---------- SP_LayThongTinNhanVien ----------*/

/* Giữ thêm tên gọi theo đúng mẫu Thầy để tiện đối chiếu khi chấm */
CREATE   PROCEDURE dbo.SP_LayThongTinNhanVien
    @TENLOGIN nvarchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.SP_LayThongTinNguoiDung @TENLOGIN;
END
GO

/*---------- sp_LichThi ----------*/
/*======================================================================
  LỊCH THI CỦA LỚP SINH VIÊN  (kèm ngày thi + trạng thái đã thi)
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_LichThi]
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
    ORDER BY dk.NGAYTHI, dk.MAMH, dk.LAN;
END
GO

/*---------- sp_MoLaiBaiThi ----------*/
/*======================================================================
  GIÁM THỊ MỞ LẠI BÀI THI (khi phiếu bị kết thúc vì mất điện / rớt mạng)
  Chỉ CoSo được phép - xoá điểm + phiếu treo để sinh viên thi lại lần đó.
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_MoLaiBaiThi]
    @MASV char(8), @MAMH char(5), @LAN smallint
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            DELETE FROM dbo.ChiTiet_BaiThi WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN;
            DELETE FROM dbo.BangDiem       WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN;
            /* Xoá bảng con TRƯỚC: không dựa vào ON DELETE CASCADE, vì
               replication tạo lại schema ở subscriber và tuỳ chọn FK có
               thể không được giữ nguyên. */
            DELETE ch FROM dbo.PhieuThi_CauHoi ch
              JOIN dbo.PhieuThi p ON ch.MAPHIEU = p.MAPHIEU
             WHERE p.MASV=@MASV AND p.MAMH=@MAMH AND p.LAN=@LAN;
            DELETE FROM dbo.PhieuThi       WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN;
        COMMIT;
        SELECT N'Đã mở lại bài thi cho sinh viên ' + RTRIM(@MASV) AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK; THROW;
    END CATCH
END
GO

/*---------- sp_NopBai ----------*/
/*======================================================================
  CÂU 8b - NỘP BÀI (GIAO TÁC)
  @DapAn là JSON CHỈ gồm lựa chọn của thí sinh: [{"STT":1,"DACHON":"A"}, ...]
  Điểm được chấm bằng cách JOIN với PhieuThi_CauHoi (đáp án phía server)
  => client KHÔNG còn khả năng tác động tới điểm (P0-2).

  Mức cô lập SERIALIZABLE cho khối ghi: chống phantom giữa IF EXISTS và
  INSERT khi 2 phiên cùng nộp (Chương 6 - điều khiển đồng thời phân tán).
  Toàn bộ thao tác GHI đều CỤC BỘ -> giao tác cục bộ, KHÔNG cần MSDTC/2PC.
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_NopBai]
    @MASV char(8), @MAPHIEU uniqueidentifier,
    @DapAn nvarchar(max), @GhiDiem bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MAMH char(5), @LAN smallint, @SOCAU int,
            @HANNOP datetime, @DANOP bit, @TREHAN bit = 0, @THITHU bit = 0;

    SELECT @MAMH=MAMH, @LAN=LAN, @SOCAU=SOCAU, @HANNOP=HANNOP, @DANOP=DANOP, @THITHU=THITHU
    FROM dbo.PhieuThi WHERE MAPHIEU=@MAPHIEU AND MASV=@MASV;

    IF @MAMH IS NULL BEGIN RAISERROR(N'Phiếu thi không tồn tại hoặc không thuộc về bạn.',16,1); RETURN; END
    IF @DANOP = 1    BEGIN RAISERROR(N'Phiếu thi này đã được nộp.',16,1); RETURN; END

    /* #6 - phiếu thi thử thì TUYỆT ĐỐI không ghi điểm. Cờ lấy từ chính
       phiếu ở server, không lấy từ tham số do ứng dụng gửi lên, nên client
       không thể biến bài thi thật thành thi thử hay ngược lại. */
    IF @THITHU = 1 SET @GhiDiem = 0;

    /* Ân hạn 60 giây cho độ trễ mạng; quá đó coi như hết giờ -> 0 điểm (P0-3) */
    IF GETDATE() > DATEADD(SECOND, 60, @HANNOP) SET @TREHAN = 1;

    DECLARE @bl TABLE(STT int PRIMARY KEY, DACHON char(1));
    IF @TREHAN = 0 AND @DapAn IS NOT NULL
        INSERT INTO @bl(STT, DACHON)
        SELECT STT, NULLIF(LTRIM(RTRIM(DACHON)),'')
        FROM OPENJSON(@DapAn) WITH (STT int '$.STT', DACHON char(1) '$.DACHON')
        WHERE STT IS NOT NULL;

    /* CHẤM: đối chiếu với đáp án LƯU Ở SERVER */
    DECLARE @SoCauDung int = (
        SELECT COUNT(*)
        FROM dbo.PhieuThi_CauHoi q JOIN @bl b ON b.STT = q.STT
        WHERE q.MAPHIEU = @MAPHIEU AND b.DACHON = q.DAP_AN);
    DECLARE @DIEM float = ROUND(@SoCauDung * 10.0 / NULLIF(@SOCAU,0), 2);

    /* Giáo viên thi thử: chỉ trả điểm, không ghi BangDiem (đề mục phân quyền) */
    IF @GhiDiem = 0
    BEGIN
        UPDATE dbo.PhieuThi SET DANOP = 1 WHERE MAPHIEU = @MAPHIEU;
        SELECT @DIEM AS DIEM, @SoCauDung AS SoCauDung, @SOCAU AS SoCauThi, @TREHAN AS TreHan;
        RETURN;
    END

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRY
        BEGIN TRAN;
            /* Khoá ngay dòng điểm (nếu có) để 2 tab nộp cùng lúc không đụng PK */
            IF EXISTS (SELECT 1 FROM dbo.BangDiem WITH (UPDLOCK, HOLDLOCK)
                       WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN)
                UPDATE dbo.BangDiem SET DIEM=@DIEM, NGAYTHI=GETDATE()
                WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN;
            ELSE
                INSERT INTO dbo.BangDiem(MASV,MAMH,LAN,NGAYTHI,DIEM)
                VALUES(@MASV,@MAMH,@LAN,GETDATE(),@DIEM);

            /* Bài làm chi tiết cho câu 9 - nội dung lấy từ SNAPSHOT SERVER */
            DELETE FROM dbo.ChiTiet_BaiThi WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN;
            INSERT INTO dbo.ChiTiet_BaiThi(MASV,MAMH,LAN,STT,CAUHOI,NOIDUNG,A,B,C,D,DAP_AN,DACHON)
            SELECT @MASV, @MAMH, @LAN, q.STT, q.CAUHOI,
                   q.NOIDUNG, q.A, q.B, q.C, q.D, q.DAP_AN, b.DACHON
            FROM dbo.PhieuThi_CauHoi q LEFT JOIN @bl b ON b.STT = q.STT
            WHERE q.MAPHIEU = @MAPHIEU;

            UPDATE dbo.PhieuThi SET DANOP = 1 WHERE MAPHIEU = @MAPHIEU;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT @DIEM AS DIEM, @SoCauDung AS SoCauDung, @SOCAU AS SoCauThi, @TREHAN AS TreHan;
END
GO

/*---------- SP_PHUCHOI_CSDL ----------*/

/*----------------------------------------------------------------------
  4. PHỤC HỒI CSDL - có rào chắn
----------------------------------------------------------------------*/
CREATE   PROCEDURE dbo.SP_PHUCHOI_CSDL
    @TenFile  nvarchar(400),
    @XacNhan  nvarchar(50)          -- bắt buộc truyền đúng chuỗi 'TOI DONG Y'
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @caller sysname = ORIGINAL_LOGIN();
    IF NOT EXISTS (SELECT 1
                   FROM sys.database_role_members m
                     JOIN sys.database_principals r ON m.role_principal_id = r.principal_id
                     JOIN sys.database_principals u ON m.member_principal_id = u.principal_id
                   WHERE r.name = N'Truong' AND u.name = @caller)
    BEGIN RAISERROR(N'Chỉ nhóm Trưởng mới được phục hồi cơ sở dữ liệu.',16,1); RETURN; END

    IF @XacNhan <> N'TOI DONG Y'
    BEGIN
        RAISERROR(N'Phục hồi CSDL sẽ GHI ĐÈ toàn bộ dữ liệu hiện tại và LÀM HỎNG cấu hình nhân bản (phải thiết lập lại publication/subscription). Nếu vẫn muốn tiếp tục, hãy truyền @XacNhan = N''TOI DONG Y''.',16,1);
        RETURN;
    END

    /* Không tự chạy RESTORE ở đây: RESTORE đòi CSDL ở chế độ SINGLE_USER,
       mà chính kết nối đang gọi thủ tục lại nằm trong CSDL đó -> luôn thất
       bại. Thủ tục trả về ĐÚNG CÂU LỆNH cần chạy từ master (hoặc SSMS),
       kèm cảnh báo, để người quản trị thực hiện có ý thức. */
    SELECT
        CanhBao = N'Chạy các lệnh sau trong ngữ cảnh CSDL [master], sau đó thiết lập lại nhân bản.',
        Lenh =
            N'USE master;' + CHAR(13) + CHAR(10) +
            N'ALTER DATABASE [TN_CSDLPT] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;' + CHAR(13) + CHAR(10) +
            N'RESTORE DATABASE [TN_CSDLPT] FROM DISK = ' + QUOTENAME(@TenFile, '''') +
            N' WITH REPLACE;' + CHAR(13) + CHAR(10) +
            N'ALTER DATABASE [TN_CSDLPT] SET MULTI_USER;';
END
GO

/*---------- SP_SAOLUU ----------*/

/*----------------------------------------------------------------------
  2. SAO LƯU CSDL
----------------------------------------------------------------------*/
CREATE   PROCEDURE dbo.SP_SAOLUU
    @ThuMuc nvarchar(300) = NULL,     -- NULL -> dùng thư mục backup mặc định
    @GhiChu nvarchar(200) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    /* Chỉ Trưởng hoặc Cơ sở được sao lưu.
       LƯU Ý: thủ tục chạy WITH EXECUTE AS OWNER nên IS_MEMBER() sẽ xét
       theo OWNER (dbo) chứ không phải người gọi -> phải dò nhóm quyền
       theo ORIGINAL_LOGIN(), giống cách SP_TAOLOGIN đang làm. */
    DECLARE @caller sysname = ORIGINAL_LOGIN();
    IF NOT EXISTS (SELECT 1
                   FROM sys.database_role_members m
                     JOIN sys.database_principals r ON m.role_principal_id = r.principal_id
                     JOIN sys.database_principals u ON m.member_principal_id = u.principal_id
                   WHERE r.name IN (N'Truong', N'CoSo') AND u.name = @caller)
    BEGIN RAISERROR(N'Bạn không có quyền sao lưu dữ liệu.',16,1); RETURN; END

    IF @ThuMuc IS NULL
        SELECT @ThuMuc = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(300));
    IF RIGHT(@ThuMuc,1) <> '\' SET @ThuMuc = @ThuMuc + '\';

    DECLARE @ten nvarchar(400) =
        @ThuMuc + N'TN_CSDLPT_' + CONVERT(nvarchar(8), GETDATE(), 112)
        + N'_' + REPLACE(CONVERT(nvarchar(8), GETDATE(), 108), ':', '') + N'.bak';

    DECLARE @sql nvarchar(max) =
        N'BACKUP DATABASE [TN_CSDLPT] TO DISK = ' + QUOTENAME(@ten, '''')
      + N' WITH INIT, COMPRESSION, NAME = ''Sao luu TN_CSDLPT'';';

    BEGIN TRY
        EXEC (@sql);
        INSERT INTO dbo.NhatKy_SaoLuu(TENFILE, GHICHU) VALUES(@ten, @GhiChu);
        SELECT N'Đã sao lưu thành công.' AS Message, @ten AS TenFile;
    END TRY
    BEGIN CATCH
        DECLARE @m nvarchar(400) = N'Sao lưu thất bại: ' + ERROR_MESSAGE();
        RAISERROR(@m,16,1);
    END CATCH
END
GO

/*---------- sp_ThoiGianConLai ----------*/
/*======================================================================
  ĐỒNG HỒ SERVER - client gọi định kỳ để chống chỉnh giờ máy trạm (P0-3)
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_ThoiGianConLai]
    @MASV char(8), @MAPHIEU uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DATEDIFF(SECOND, GETDATE(), HANNOP) AS sogiayconlai, DANOP AS danop
    FROM dbo.PhieuThi WHERE MAPHIEU = @MAPHIEU AND MASV = @MASV;
END
GO

/*---------- sp_ThongTinThiSinh ----------*/
/*======================================================================
  THÔNG TIN THÍ SINH  (đề câu 8: "tự động in ra mã lớp, tên lớp, họ tên")
  Đưa vào SP để nhóm Sinhvien KHÔNG cần quyền SELECT trực tiếp trên bảng.
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_ThongTinThiSinh]
    @MASV char(8)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RTRIM(sv.MASV) AS masv,
           RTRIM(sv.HO) + N' ' + RTRIM(sv.TEN) AS hoten,
           RTRIM(l.MALOP) AS malop, l.TENLOP AS lop
    FROM dbo.Sinhvien sv JOIN dbo.Lop l ON sv.MALOP = l.MALOP
    WHERE sv.MASV = @MASV;
END
GO

/*---------- sp_XemKetQua ----------*/
/*======================================================================
  CÂU 9 - XEM KẾT QUẢ (2 result set: phần đầu + chi tiết bài làm)
======================================================================*/
CREATE   PROCEDURE [dbo].[sp_XemKetQua]
    @MASV char(8), @MAMH char(5), @LAN smallint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT l.TENLOP AS Lop, RTRIM(sv.HO) + N' ' + RTRIM(sv.TEN) AS HoTen,
           mh.TENMH AS MonThi, bd.NGAYTHI AS NgayThi, bd.LAN AS LanThi, bd.DIEM AS Diem
    FROM dbo.Sinhvien sv JOIN dbo.Lop l ON sv.MALOP = l.MALOP
      JOIN dbo.BangDiem bd ON bd.MASV = sv.MASV
      JOIN dbo.Monhoc   mh ON bd.MAMH = mh.MAMH
    WHERE sv.MASV = @MASV AND bd.MAMH = @MAMH AND bd.LAN = @LAN;

    SELECT STT, CAUHOI AS CauSo, NOIDUNG, A, B, C, D,
           DAP_AN AS DapAn, DACHON AS DaChon,
           CASE WHEN DACHON IS NULL THEN N'Bỏ trống'
                WHEN DACHON = DAP_AN THEN N'Đúng' ELSE N'Sai' END AS KetQua
    FROM dbo.ChiTiet_BaiThi
    WHERE MASV=@MASV AND MAMH=@MAMH AND LAN=@LAN ORDER BY STT;
END
GO

