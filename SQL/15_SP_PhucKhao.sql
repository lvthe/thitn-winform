/*======================================================================
  CÂU 9 - PHÚC KHẢO: GIẢNG VIÊN CHỌN SINH VIÊN ĐỂ XEM LẠI BÀI
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Sau đó PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  Đề (Thầy giảng câu 9):
     "sinh viên thắc mắc tại sao em làm thấy đúng lắm mà chỉ có 5 điểm...
      giảng viên phải có nhiệm vụ giải thích... giống như phúc khảo vậy đó"

  Vậy người xem lại bài KHÔNG chỉ có sinh viên, mà chính GIẢNG VIÊN mới
  là người cần tra bài của sinh viên để giải thích. Muốn vậy giảng viên
  phải CHỌN được lớp rồi chọn sinh viên.

  Hai thủ tục dưới đây phục vụ hai ComboBox đó.
======================================================================*/
USE TN_CSDLPT;
GO

/*----------------------------------------------------------------------
  1. Danh sách LỚP có sinh viên đã thi (chỉ hiện lớp thực sự có bài)
     Nguyên tắc Thầy nhấn mạnh: "cái gì biết là vô lý thì đừng cho người
     ta chọn" - lớp chưa ai thi thì đưa vào danh sách làm gì.
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.sp_DS_Lop_CoBaiThi
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  MALOP  = RTRIM(l.MALOP),
            TENLOP = l.TENLOP,
            SO_SV_DA_THI = COUNT(DISTINCT bd.MASV),
            MOTA   = RTRIM(l.TENLOP) + N'  (' + CAST(COUNT(DISTINCT bd.MASV) AS nvarchar(5))
                   + N' SV đã thi)'
    FROM dbo.Lop l
      JOIN dbo.Sinhvien sv ON sv.MALOP = l.MALOP
      JOIN dbo.BangDiem bd ON bd.MASV  = sv.MASV
    GROUP BY l.MALOP, l.TENLOP
    ORDER BY l.TENLOP;
END
GO

/*----------------------------------------------------------------------
  2. Danh sách SINH VIÊN đã có bài thi trong một lớp
----------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE dbo.sp_DS_SinhVien_CoBaiThi
    @MALOP nchar(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  MASV   = RTRIM(sv.MASV),
            HOTEN  = RTRIM(sv.HO) + N' ' + RTRIM(sv.TEN),
            SO_BAI = COUNT(*),
            MOTA   = RTRIM(sv.MASV) + N' - ' + RTRIM(sv.HO) + N' ' + RTRIM(sv.TEN)
                   + N'  (' + CAST(COUNT(*) AS nvarchar(5)) + N' bài)'
    FROM dbo.Sinhvien sv
      JOIN dbo.BangDiem bd ON bd.MASV = sv.MASV
    WHERE sv.MALOP = @MALOP
    GROUP BY sv.MASV, sv.HO, sv.TEN
    ORDER BY sv.MASV;
END
GO

/*----------------------------------------------------------------------
  3. Cấp quyền
     Sinh viên KHÔNG được cấp hai thủ tục này: các em chỉ xem bài của
     chính mình, không được liệt kê bạn cùng lớp.
----------------------------------------------------------------------*/
DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN (N'Truong', N'CoSo', N'Giangvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.sp_DS_Lop_CoBaiThi TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    SET @sql = N'GRANT EXECUTE ON dbo.sp_DS_SinhVien_CoBaiThi TO ' + QUOTENAME(@r) + N';'; EXEC(@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Đã tạo 2 thủ tục phục vụ phúc khảo ==';
GO
