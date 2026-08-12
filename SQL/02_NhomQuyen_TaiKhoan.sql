/*======================================================================
  BUOC 3 - TAO NHOM QUYEN VA TAI KHOAN
  ----------------------------------------------------------------------
  Chay tren TUNG SERVER, moi server mot lenh khac nhau vi tai khoan
  cua tung co so chi ton tai tren co so do (dung yeu cau de:
  "nhom Co so chi duoc lam viec tren co so cua minh").

     sqlcmd -S localhost\SERVER  -E -f 65001 -v MayChu="CHU"  -i 02_NhomQuyen_TaiKhoan.sql
     sqlcmd -S localhost\SERVER1 -E -f 65001 -v MayChu="CS1"  -i 02_NhomQuyen_TaiKhoan.sql
     sqlcmd -S localhost\SERVER2 -E -f 65001 -v MayChu="CS2"  -i 02_NhomQuyen_TaiKhoan.sql
     sqlcmd -S localhost\SERVER3 -E -f 65001 -v MayChu="TRACUU" -i 02_NhomQuyen_TaiKhoan.sql

  MAT KHAU MAC DINH - DOI LAI TRUOC KHI DUNG THAT:
     truong01 / Truong@123      coso1, coso2 / Coso@123
     TH101, TH123, TH657 / Gv@123
     sv / Sv@123                tracuu / TraCuu@123
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;

DECLARE @may sysname = N'$(MayChu)';
PRINT N'>>> Cai dat cho: ' + @may;

/*----------------------------------------------------------------------
  1. NHOM QUYEN (database role) - tao tren MOI server
     Ten nhom KHONG duoc trung ten login: SQL Server khong phan biet
     hoa/thuong ten principal, trung se bao "Cannot make a role a member
     of itself". Vi vay login cua truong dat la 'truong01' chu khong
     phai 'Truong'.
----------------------------------------------------------------------*/
IF DATABASE_PRINCIPAL_ID('Truong')    IS NULL CREATE ROLE [Truong];
IF DATABASE_PRINCIPAL_ID('CoSo')      IS NULL CREATE ROLE [CoSo];
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NULL CREATE ROLE [Giangvien];
IF DATABASE_PRINCIPAL_ID('Sinhvien')  IS NULL CREATE ROLE [Sinhvien];
PRINT N'  Da tao 4 nhom quyen';
GO

/*----------------------------------------------------------------------
  2. QUYEN CO BAN CUA TUNG NHOM
     - Truong    : CHI XEM toan bo (de: "xem thoi, khong duoc them xoa sua")
     - CoSo      : toan quyen tren co so cua minh
     - Giangvien : quyen chi tiet do 03_PhanQuyen.sql cap
     - Sinhvien  : khong dung bang truc tiep, moi thao tac qua SP
----------------------------------------------------------------------*/
GRANT SELECT ON DATABASE::TN_CSDLPT TO [Truong];

GRANT SELECT, INSERT, UPDATE, DELETE ON DATABASE::TN_CSDLPT TO [CoSo];
GRANT ALTER ANY USER TO [CoSo];        /* de SP_TAOLOGIN tao duoc user */
PRINT N'  Da cap quyen co ban cho Truong / CoSo';
GO

/*----------------------------------------------------------------------
  3. TAI KHOAN DANG NHAP
----------------------------------------------------------------------*/
DECLARE @may sysname = N'$(MayChu)';
DECLARE @sql nvarchar(max);

/* Thu tuc phu: tao login + user + gan nhom */
DECLARE @ds TABLE (login_name sysname, mat_khau nvarchar(50), nhom sysname);

/* truong01 co mat o MOI server: de cho phep Truong dang nhap bat ky phan manh nao */
INSERT INTO @ds VALUES (N'truong01', N'Truong@123', N'Truong');

IF @may = N'CS1'
BEGIN
    INSERT INTO @ds VALUES
        (N'coso1', N'Coso@123', N'CoSo'),
        (N'TH101', N'Gv@123',   N'Giangvien'),
        (N'TH123', N'Gv@123',   N'Giangvien'),
        (N'sv',    N'Sv@123',   N'Sinhvien');
END
ELSE IF @may = N'CS2'
BEGIN
    INSERT INTO @ds VALUES
        (N'coso2', N'Coso@123', N'CoSo'),
        (N'TH657', N'Gv@123',   N'Giangvien'),
        (N'sv',    N'Sv@123',   N'Sinhvien');
END
ELSE IF @may = N'TRACUU'
BEGIN
    /* Manh 3: nguoi dung KHONG dang nhap vao day (theo de).
       Chi co tai khoan dich vu chi-doc cho ung dung tra cuu ngam. */
    INSERT INTO @ds VALUES (N'sv', N'Sv@123', N'Sinhvien');
END

DECLARE @ln sysname, @mk nvarchar(50), @nh sysname;
DECLARE c CURSOR FOR SELECT login_name, mat_khau, nhom FROM @ds;
OPEN c; FETCH NEXT FROM c INTO @ln, @mk, @nh;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF SUSER_ID(@ln) IS NULL
    BEGIN
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@ln) + N' WITH PASSWORD = '
                 + QUOTENAME(@mk, '''') + N', CHECK_POLICY = OFF;';
        EXEC (@sql);
    END
    IF DATABASE_PRINCIPAL_ID(@ln) IS NULL
    BEGIN
        SET @sql = N'CREATE USER ' + QUOTENAME(@ln) + N' FOR LOGIN ' + QUOTENAME(@ln) + N';';
        EXEC (@sql);
    END
    SET @sql = N'ALTER ROLE ' + QUOTENAME(@nh) + N' ADD MEMBER ' + QUOTENAME(@ln) + N';';
    EXEC (@sql);
    PRINT N'  + ' + @ln + N'  ->  nhom ' + @nh;
    FETCH NEXT FROM c INTO @ln, @mk, @nh;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Da tao xong nhom quyen va tai khoan ==';
GO

/* Kiem tra */
SELECT tai_khoan = u.name,
       nhom = ISNULL(r.name, N'(chua co nhom)')
FROM sys.database_principals u
LEFT JOIN sys.database_role_members m ON u.principal_id = m.member_principal_id
LEFT JOIN sys.database_principals   r ON m.role_principal_id = r.principal_id
WHERE u.type IN ('S','U') AND u.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')
  AND u.name NOT LIKE 'MSmerge%' AND u.name NOT LIKE 'NT %'
ORDER BY u.name;
GO
