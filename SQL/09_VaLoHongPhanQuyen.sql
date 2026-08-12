/*======================================================================
  VÁ LỖ HỔNG PHÂN QUYỀN PHÁT HIỆN KHI RÀ SOÁT
  Chạy trên: SERVER1, SERVER2   (sqlcmd -f 65001)
  ----------------------------------------------------------------------
  1. Đề: "nhóm Trưởng ... chạy được TẤT CẢ các báo cáo, có 3 báo cáo là
     được quyền chạy hết".
     Thực tế Trưởng chỉ có sp_BangDiemMonHoc + sp_BaoCao_DangKy,
     THIẾU sp_XemKetQua (báo cáo 1 - xem lại bài thi).

  2. Đề: "giảng viên được quyền thi thử nhưng không ghi điểm".
     sp_LayDeThi/sp_NopBai đã hỗ trợ cờ @ThiThu và giảng viên đã có quyền,
     nhưng THIẾU sp_ThongTinThiSinh nên màn hình thi sẽ lỗi khi giảng
     viên vào thi thử.
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;

/* 1. Trưởng chạy đủ 3 báo cáo */
IF DATABASE_PRINCIPAL_ID('Truong') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.sp_XemKetQua      TO [Truong];
    GRANT EXECUTE ON dbo.sp_LichThi        TO [Truong];
    PRINT N'  [Truong]    + sp_XemKetQua, sp_LichThi  (đủ 3 báo cáo)';
END

/* 2. Giảng viên thi thử cần thông tin thí sinh */
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.sp_ThongTinThiSinh TO [Giangvien];
    PRINT N'  [Giangvien] + sp_ThongTinThiSinh  (phục vụ thi thử)';
END

/* 3. Cơ sở cũng cần xem lại bài thi khi sinh viên khiếu nại */
IF DATABASE_PRINCIPAL_ID('CoSo') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.sp_ThongTinThiSinh TO [CoSo];
    GRANT EXECUTE ON dbo.sp_MoLaiBaiThi     TO [CoSo];
    PRINT N'  [CoSo]      + sp_ThongTinThiSinh, sp_MoLaiBaiThi';
END
GO

PRINT N'== Đã vá lỗ hổng phân quyền ==';
GO

/* Kiểm tra lại: mỗi nhóm chạy được những báo cáo nào */
SELECT nhom = r.name, bao_cao = OBJECT_NAME(p.major_id)
FROM sys.database_permissions p
JOIN sys.database_principals r ON p.grantee_principal_id = r.principal_id
WHERE r.type='R' AND p.permission_name='EXECUTE' AND p.state_desc='GRANT'
  AND OBJECT_NAME(p.major_id) IN ('sp_XemKetQua','sp_BangDiemMonHoc','sp_BaoCao_DangKy')
ORDER BY r.name, bao_cao;
GO
