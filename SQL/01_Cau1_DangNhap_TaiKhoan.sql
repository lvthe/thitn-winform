/*======================================================================
  CÂU 1 - ĐĂNG NHẬP & QUẢN TRỊ TÀI KHOẢN
  Chạy trên: SERVER1, SERVER2, SERVER (publisher)
  LƯU Ý: chạy bằng  sqlcmd -f 65001  (file lưu UTF-8) để không lỗi font.
======================================================================*/
USE TN_CSDLPT;
GO

/*----------------------------------------------------------------------
  1. Đổi mật khẩu SINH VIÊN (mật khẩu nằm trong bảng SINHVIEN vì
     toàn bộ sinh viên dùng chung 1 SQL login).
     Bản cũ bị lỗi font ở các thông báo -> tạo lại.
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.sp_DoiMatKhau_SV
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

/*----------------------------------------------------------------------
  2. Đổi mật khẩu CÁN BỘ (Giảng viên / Cơ sở / Trưởng).
     Mỗi người một SQL login riêng nên đổi bằng ALTER LOGIN.
     KHÔNG dùng EXECUTE AS: một login luôn được phép tự đổi mật khẩu
     của chính mình khi cung cấp OLD_PASSWORD, không cần quyền đặc biệt.
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.SP_DOIMATKHAU
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

/*----------------------------------------------------------------------
  3. Thông tin người đăng nhập: trả về MÃ - HỌ TÊN - NHÓM QUYỀN.
     Theo mẫu SP_LayThongTinNhanVien của Thầy (username = mã nhân viên).
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.SP_LayThongTinNguoiDung
    @TENLOGIN sysname = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @TENLOGIN IS NULL SET @TENLOGIN = ORIGINAL_LOGIN();

    SELECT  MA      = @TENLOGIN,
            HOTEN   = (SELECT RTRIM(HO) + N' ' + RTRIM(TEN)
                       FROM dbo.Giaovien WHERE RTRIM(MAGV) = RTRIM(@TENLOGIN)),
            TENNHOM = CASE
                        WHEN IS_MEMBER('Truong')    = 1 THEN N'Truong'
                        WHEN IS_MEMBER('CoSo')      = 1 THEN N'CoSo'
                        WHEN IS_MEMBER('Giangvien') = 1 THEN N'Giangvien'
                        WHEN IS_MEMBER('Sinhvien')  = 1 THEN N'Sinhvien'
                        ELSE N'' END;
END
GO

/*----------------------------------------------------------------------
  4. Cấp quyền thực thi
----------------------------------------------------------------------*/
DECLARE @r sysname, @sql nvarchar(max);
DECLARE c CURSOR FOR
    SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN (N'Truong', N'CoSo', N'Giangvien', N'Sinhvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.SP_LayThongTinNguoiDung TO ' + QUOTENAME(@r) + N';';
    EXEC (@sql);
    IF @r <> N'Sinhvien'
    BEGIN
        SET @sql = N'GRANT EXECUTE ON dbo.SP_DOIMATKHAU TO ' + QUOTENAME(@r) + N';';
        EXEC (@sql);
    END
    SET @sql = N'GRANT EXECUTE ON dbo.sp_DoiMatKhau_SV TO ' + QUOTENAME(@r) + N';';
    EXEC (@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Câu 1: đã cài đặt xong SP đăng nhập / đổi mật khẩu / thông tin người dùng ==';
GO
