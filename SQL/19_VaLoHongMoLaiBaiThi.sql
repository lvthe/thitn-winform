/*======================================================================
  VÁ LỖ HỔNG: SINH VIÊN TỰ XOÁ ĐƯỢC ĐIỂM CỦA MÌNH VÀ CỦA NGƯỜI KHÁC
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Chạy bằng: sqlcmd -f 65001
  Sau đó PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  LỖ HỔNG
  sp_MoLaiBaiThi(@MASV, @MAMH, @LAN) xoá sạch BangDiem + ChiTiet_BaiThi
  + PhieuThi của một lần thi. Đây là công cụ của GIÁM THỊ, dùng khi phiếu
  thi bị treo vì cúp điện / rớt mạng. Chú thích trong thủ tục ghi rõ
  "Chỉ CoSo được phép", NHƯNG:

      - bên trong KHÔNG có một dòng kiểm quyền nào
      - quyền EXECUTE lại được cấp cho cả Sinhvien và Giangvien

  Vì mọi sinh viên dùng CHUNG một SQL login ("sv"), mà @MASV lại là THAM
  SỐ do ứng dụng gửi lên, nên bất kỳ ai kết nối được bằng login đó đều có
  thể xoá điểm của BẤT KỲ sinh viên nào.

  ĐÃ CHỨNG MINH (chạy trong giao dịch rồi rollback, không mất dữ liệu):

      EXECUTE AS LOGIN = 'sv';
      EXEC dbo.sp_MoLaiBaiThi @MASV='SV999001', @MAMH='KTLT', @LAN=1;
      -> "Đã mở lại bài thi cho sinh viên SV999001"
      -> điểm 7.0 biến mất, thi lại được từ đầu

      EXEC dbo.sp_MoLaiBaiThi @MASV='002', @MAMH='MMTCB', @LAN=1;
      -> xoá luôn điểm của sinh viên KHÁC

  CÁCH VÁ - hai lớp, lớp trong mới là lớp thật
  1. Kiểm quyền NGAY TRONG thủ tục: chỉ nhóm CoSo (giám thị) được gọi.
     Đặt ở đây thì dù sau này ai lỡ GRANT nhầm cho nhóm khác, hoặc nhân
     bản cấp lại quyền sai, thủ tục vẫn tự chặn.
  2. Thu hồi EXECUTE của Sinhvien và Giangvien.

  VÌ SAO BỎ CẢ Giangvien
  Đề giao việc mở lại bài thi cho giám thị. Giảng viên giữ quyền này thì
  cũng xoá được điểm của mọi sinh viên trong phân mảnh. Hiện ứng dụng
  CHƯA có nút nào gọi thủ tục này, nên thu hồi không làm hỏng chức năng
  nào đang chạy.
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_MoLaiBaiThi]
    @MASV char(8), @MAMH char(5), @LAN smallint
AS
BEGIN
    SET NOCOUNT ON;

    /* ★ LỚP CHẶN THẬT - nằm trong thủ tục nên không phụ thuộc vào việc
       ai đã GRANT cái gì. Sinh viên dùng login chung nên tuyệt đối không
       được chạm vào thủ tục phá dữ liệu này. */
    IF ISNULL(IS_MEMBER('CoSo'),0) = 0 AND ISNULL(IS_MEMBER('db_owner'),0) = 0
    BEGIN
        RAISERROR(N'Chỉ nhóm Cơ sở (giám thị) mới được mở lại bài thi.',16,1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Sinhvien WHERE MASV = @MASV)
        BEGIN RAISERROR(N'Sinh viên không tồn tại tại cơ sở này.',16,1); RETURN; END

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
PRINT N'  + sp_MoLaiBaiThi (đã thêm lớp kiểm quyền bên trong)';
GO

/*----------------------------------------------------------------------
  Thu hồi quyền đã cấp nhầm
----------------------------------------------------------------------*/
IF DATABASE_PRINCIPAL_ID('Sinhvien') IS NOT NULL
BEGIN
    REVOKE EXECUTE ON dbo.sp_MoLaiBaiThi FROM [Sinhvien];
    PRINT N'  - thu hồi EXECUTE của Sinhvien';
END
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
BEGIN
    REVOKE EXECUTE ON dbo.sp_MoLaiBaiThi FROM [Giangvien];
    PRINT N'  - thu hồi EXECUTE của Giangvien';
END
IF DATABASE_PRINCIPAL_ID('CoSo') IS NOT NULL
    GRANT EXECUTE ON dbo.sp_MoLaiBaiThi TO [CoSo];
GO

PRINT N'== Xong. Nhớ chạy lại 12_CapLaiQuyen.sql ==';
GO

/*----------------------------------------------------------------------
  Kiểm tra: chỉ còn CoSo
----------------------------------------------------------------------*/
SELECT nhom_con_quyen = ISNULL(STRING_AGG(r.name, ', '), N'(khong con nhom nao)')
FROM sys.database_permissions p
JOIN sys.database_principals r ON r.principal_id = p.grantee_principal_id
WHERE p.major_id = OBJECT_ID('dbo.sp_MoLaiBaiThi')
  AND p.permission_name = 'EXECUTE' AND p.state_desc = 'GRANT' AND r.type = 'R';
GO
