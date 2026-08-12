/*======================================================================
  CÂU 10 + CÂU 11 - BÁO CÁO
  Chạy trên: SERVER1, SERVER2   (sqlcmd -f 65001)
  KHÔNG chạy trên server chủ - xem giải thích ở câu 11 bên dưới.
======================================================================*/
USE TN_CSDLPT;
GO

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
CREATE OR ALTER PROCEDURE [dbo].[sp_BangDiemMonHoc]
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
CREATE OR ALTER PROCEDURE [dbo].[sp_BaoCao_DangKy]
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

/*----------------------------------------------------------------------
  Cấp quyền
    Câu 10: giảng viên + cơ sở + trưởng
    Câu 11: trưởng (theo đề là báo cáo của phòng giáo vụ) + cơ sở
----------------------------------------------------------------------*/
DECLARE @r sysname, @sql nvarchar(300);
DECLARE c CURSOR FOR SELECT name FROM sys.database_principals
    WHERE type='R' AND name IN (N'Truong', N'CoSo', N'Giangvien');
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON dbo.sp_BangDiemMonHoc TO ' + QUOTENAME(@r) + N';';
    EXEC (@sql);
    IF @r IN (N'Truong', N'CoSo')
    BEGIN
        SET @sql = N'GRANT EXECUTE ON dbo.sp_BaoCao_DangKy TO ' + QUOTENAME(@r) + N';';
        EXEC (@sql);
    END
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
GO

PRINT N'== Câu 10 (làm tròn 0.5) + Câu 11 (chạy trên phân mảnh) đã cài đặt ==';
GO
