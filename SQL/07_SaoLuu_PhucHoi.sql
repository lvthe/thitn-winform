/*======================================================================
  PHẦN QUẢN TRỊ - SAO LƯU / PHỤC HỒI DỮ LIỆU
  Chạy trên: SERVER1, SERVER2, SERVER   (sqlcmd -f 65001)
  ----------------------------------------------------------------------
  Đề (phần quản trị): "tạo ra bản sao lưu trên DB, về sau người dùng có
  thể phục hồi lại được nếu có sự cố xảy ra trong tương lai".

  ⚠️ LƯU Ý QUAN TRỌNG VỀ NHÂN BẢN
  TN_CSDLPT đang tham gia merge replication. RESTORE đè lên một CSDL
  đang được nhân bản sẽ LÀM HỎNG cấu hình replication (phải gỡ và tạo
  lại publication/subscription). Vì vậy:
     * SAO LƯU  : an toàn, dùng thoải mái.
     * PHỤC HỒI : chỉ dùng khi thực sự có sự cố, và phải chấp nhận
                  thiết lập lại nhân bản sau đó.
  Thủ tục phục hồi bên dưới CỐ Ý bắt người gọi truyền @XacNhan = 'TOI DONG Y'
  để không ai bấm nhầm.
======================================================================*/
USE master;
GO

/*----------------------------------------------------------------------
  1. Bảng nhật ký sao lưu (để ứng dụng liệt kê các bản đã tạo)
----------------------------------------------------------------------*/
USE TN_CSDLPT;
GO

IF OBJECT_ID('dbo.NhatKy_SaoLuu') IS NULL
BEGIN
    CREATE TABLE dbo.NhatKy_SaoLuu(
        ID          int IDENTITY(1,1) PRIMARY KEY,
        TENFILE     nvarchar(400) NOT NULL,
        THOIDIEM    datetime      NOT NULL DEFAULT(GETDATE()),
        NGUOITAO    sysname       NOT NULL DEFAULT(ORIGINAL_LOGIN()),
        GHICHU      nvarchar(200) NULL
    );
    PRINT N'  Đã tạo bảng NhatKy_SaoLuu';
END
GO

/*----------------------------------------------------------------------
  2. SAO LƯU CSDL
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.SP_SAOLUU
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

/*----------------------------------------------------------------------
  3. Danh sách bản sao lưu
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.SP_DS_SAOLUU
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID, TENFILE, THOIDIEM, NGUOITAO, GHICHU
    FROM dbo.NhatKy_SaoLuu ORDER BY THOIDIEM DESC;
END
GO

/*----------------------------------------------------------------------
  4. PHỤC HỒI CSDL - có rào chắn
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.SP_PHUCHOI_CSDL
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

/*----------------------------------------------------------------------
  5. Cấp quyền
----------------------------------------------------------------------*/
DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN (N'Truong', N'CoSo');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.SP_SAOLUU TO '   + QUOTENAME(@r) + N';'; EXEC(@sql);
    SET @sql = N'GRANT EXECUTE ON dbo.SP_DS_SAOLUU TO '+ QUOTENAME(@r) + N';'; EXEC(@sql);
    SET @sql = N'GRANT SELECT ON dbo.NhatKy_SaoLuu TO '+ QUOTENAME(@r) + N';'; EXEC(@sql);
    IF @r = N'Truong'
    BEGIN
        SET @sql = N'GRANT EXECUTE ON dbo.SP_PHUCHOI_CSDL TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    END
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Đã cài đặt sao lưu / phục hồi dữ liệu ==';
GO
