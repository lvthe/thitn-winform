/*======================================================================
  DANH SÁCH BÀI THI ĐÃ CÓ ĐIỂM CỦA MỘT SINH VIÊN
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Sau đó PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  TRIỆU CHỨNG
  Sinh viên thi xong, điểm đã ghi vào BANGDIEM, chi tiết bài làm đã ghi
  vào ChiTiet_BaiThi - nhưng mở màn "Xem lại bài thi" thì danh sách TRỐNG.

  NGUYÊN NHÂN
  Màn hình đó truy vấn THẲNG hai bảng BANGDIEM và MONHOC. Toàn bộ sinh
  viên đăng nhập bằng một tài khoản SQL dùng chung, và theo thiết kế thì
  nhóm Sinhvien KHÔNG được cấp quyền đọc bảng - mọi thao tác phải đi qua
  stored procedure. Nên câu truy vấn bị chặn:

        The SELECT permission was denied on the object 'MONHOC'

  Ứng dụng bắt lỗi rồi chỉ ghi một dòng nhỏ ở thanh trạng thái, nên nhìn
  vào chỉ thấy "không có bài thi nào" chứ không thấy nguyên nhân thật.

  CÁCH SỬA
  Đưa truy vấn vào stored procedure này. Nhờ ownership chaining, sinh
  viên gọi được thủ tục mà vẫn KHÔNG cần quyền đọc bảng - đúng nguyên
  tắc đã đặt ra cho nhóm Sinhvien ngay từ đầu.
======================================================================*/
USE TN_CSDLPT;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DS_BaiThi_SV
    @MASV char(8)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  MAMH   = RTRIM(bd.MAMH),
            LAN    = bd.LAN,
            TENMH  = mh.TENMH,
            DIEM   = CAST(ROUND(bd.DIEM * 2, 0) / 2 AS decimal(4,1)),   /* làm tròn 0.5 */
            NGAYTHI= bd.NGAYTHI,
            /* Chuỗi hiển thị sẵn cho ComboBox - dựng ở server cho gọn */
            MOTA   = RTRIM(mh.TENMH) + N' - lần ' + CAST(bd.LAN AS nvarchar(2))
                   + N'  (điểm ' + CAST(CAST(ROUND(bd.DIEM * 2, 0) / 2 AS decimal(4,1)) AS nvarchar(6)) + N')'
    FROM dbo.BangDiem bd
      JOIN dbo.Monhoc mh ON bd.MAMH = mh.MAMH
    WHERE bd.MASV = @MASV
    ORDER BY bd.NGAYTHI DESC, bd.MAMH, bd.LAN;
END
GO

/* Cấp quyền ngay - cả 4 nhóm đều cần xem lại bài thi */
DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN (N'Truong', N'CoSo', N'Giangvien', N'Sinhvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.sp_DS_BaiThi_SV TO ' + QUOTENAME(@r) + N';';
    EXEC (@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Đã tạo sp_DS_BaiThi_SV và cấp quyền ==';
GO
