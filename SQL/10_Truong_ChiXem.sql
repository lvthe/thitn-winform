/*======================================================================
  NHOM TRUONG - QUYEN CHI XEM TREN TUNG PHAN MANH
  Chay tren: SERVER, SERVER1, SERVER2   (sqlcmd -f 65001)
  ----------------------------------------------------------------------
  De: "nhom truong thi duoc quyen dang nhap vao bat ky phan manh nao de
       co the xem ... xem thoi, khong duoc quyen them xoa sua"
      "khi ma dang nhap mot co so do thi chi duoc xem du lieu cua co so
       do ma thoi"

  Nhom Truong da co GRANT SELECT tren toan CSDL (buoc 02). Script nay
  bo sung phan con thieu: quyen doc BO DE qua stored procedure, va CHAN
  ro rang moi thao tac ghi de y dinh "chi xem" hien ngay trong CSDL.
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;

IF DATABASE_PRINCIPAL_ID('Truong') IS NULL
BEGIN
    PRINT N'  (Server nay khong co nhom Truong - bo qua)';
    RETURN;
END

/*----------------------------------------------------------------------
  1. Cho phep DOC bo de
     sp_Bode_DS chi loc theo giang vien khi nguoi goi thuoc nhom
     Giangvien; voi Truong thi @magv = NULL nen thay TOAN BO cau hoi
     cua phan manh -> dung y "xem du lieu cua co so do".
----------------------------------------------------------------------*/
GRANT EXECUTE ON dbo.sp_Bode_DS TO [Truong];
PRINT N'  + sp_Bode_DS (xem bo de)';

/*----------------------------------------------------------------------
  2. CHAN ghi - viet ro rang thay vi chi "khong cap quyen"
     DENY manh hon GRANT, nen du sau nay co ai lo cap nham quyen ghi
     cho nhom Truong thi van bi chan.
----------------------------------------------------------------------*/
DECLARE @b sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR
    SELECT name FROM sys.tables
    WHERE is_ms_shipped = 0 AND name NOT LIKE 'MSmerge%' AND name NOT LIKE 'sys%';
OPEN c; FETCH NEXT FROM c INTO @b;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'DENY INSERT, UPDATE, DELETE ON dbo.' + QUOTENAME(@b) + N' TO [Truong];';
    EXEC (@sql);
    FETCH NEXT FROM c INTO @b;
END
CLOSE c; DEALLOCATE c;
PRINT N'  + DENY INSERT/UPDATE/DELETE tren moi bang';
GO

PRINT N'== Nhom Truong: da thiet lap che do CHI XEM ==';
GO

/* Kiem tra: Truong doc duoc gi, bi chan gi */
SELECT quyen      = p.permission_name,
       trang_thai = p.state_desc,
       so_doi_tuong = COUNT(*)
FROM sys.database_permissions p
JOIN sys.database_principals r ON p.grantee_principal_id = r.principal_id
WHERE r.name = 'Truong'
GROUP BY p.permission_name, p.state_desc
ORDER BY p.state_desc DESC, p.permission_name;
GO
