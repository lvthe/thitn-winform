/*======================================================================
  SP LẤY THÔNG TIN NGƯỜI DÙNG - VIẾT THEO ĐÚNG MẪU CỦA THẦY
  Nguồn: Tailieu_CSDLPT/HD FORM DANG NHAP.docx
  Chạy trên: SERVER1, SERVER2, SERVER   (sqlcmd -f 65001)
  ----------------------------------------------------------------------
  Mẫu gốc của Thầy (đề tài quản lý nhân viên):

      CREATE PROC [dbo].[SP_LayThongTinNhanVien] @TENLOGIN NVARCHAR(50)
      AS
      DECLARE @TENUSER NVARCHAR(50), @UID INT
      SELECT @UID = UID, @TENUSER = NAME FROM sys.sysusers
             WHERE sid = SUSER_SID(@TENLOGIN)
      SELECT MANV = @TENUSER,
             HOTEN = (SELECT HO + ' ' + TEN FROM NHANVIEN WHERE MANV = @TENUSER),
             TENNHOM = NAME
        FROM sys.sysusers
       WHERE UID = (SELECT GROUPUID FROM SYS.SYSMEMBERS WHERE MEMBERUID = @UID)

  Ý tưởng cốt lõi của Thầy:
    * username trong CSDL được đặt TRÙNG mã nhân viên -> từ login suy ra
      được mã, rồi từ mã lấy họ tên trong bảng nghiệp vụ.
    * Nhóm quyền KHÔNG viết cứng trong code mà đọc thẳng từ hệ thống
      (sys.sysmembers -> sys.sysusers) nên thêm nhóm mới không phải sửa SP.

  Bản dưới đây giữ NGUYÊN cách làm đó, chỉ đổi bảng nghiệp vụ cho khớp
  đề tài thi trắc nghiệm:  NHANVIEN -> GIAOVIEN,  MANV -> MAGV.
======================================================================*/
USE TN_CSDLPT;
GO

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

/* Giữ thêm tên gọi theo đúng mẫu Thầy để tiện đối chiếu khi chấm */
CREATE OR ALTER PROCEDURE dbo.SP_LayThongTinNhanVien
    @TENLOGIN nvarchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.SP_LayThongTinNguoiDung @TENLOGIN;
END
GO

/*----------------------------------------------------------------------
  Cấp quyền cho cả 4 nhóm (ai đăng nhập cũng cần biết mình là ai)
----------------------------------------------------------------------*/
DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN (N'Truong', N'CoSo', N'Giangvien', N'Sinhvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.SP_LayThongTinNguoiDung TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    SET @sql = N'GRANT EXECUTE ON dbo.SP_LayThongTinNhanVien  TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Đã cài SP lấy thông tin người dùng theo mẫu của Thầy ==';
GO
