/*======================================================================
  CẤP LẠI TOÀN BỘ QUYỀN EXECUTE CHO 4 NHÓM
  Chạy trên: SERVER, SERVER1, SERVER2   ·   sqlcmd -f 65001
  ----------------------------------------------------------------------
  ⚠️ PHẢI CHẠY LẠI SAU MỖI LẦN NHÂN BẢN ĐẨY THỦ TỤC XUỐNG PHÂN MẢNH

  VÌ SAO
  Quyền GRANT KHÔNG nằm trong định nghĩa của stored procedure. Khi merge
  replication đẩy thủ tục từ máy chủ xuống, nó DROP thủ tục cũ rồi CREATE
  lại - và mọi GRANT trên thủ tục đó BIẾN MẤT.

  Sự cố thật đã xảy ra: sau một lần đồng bộ thủ tục, nhóm Sinhvien chỉ
  còn 3 quyền EXECUTE (đáng lẽ 11), mất luôn sp_DangNhap_SV. Hậu quả là
  sinh viên đăng nhập vào ứng dụng bị báo "sai mật khẩu" - trong khi
  tài khoản SQL vẫn hoàn toàn bình thường. Rất khó đoán ra nếu không
  biết cơ chế này.

  => Quy trình đúng:  sửa SP ở máy chủ -> nhân bản đẩy xuống
                      -> CHẠY LẠI SCRIPT NÀY  -> kiểm tra
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;

/*----------------------------------------------------------------------
  Bảng ánh xạ: thủ tục nào cấp cho nhóm nào
----------------------------------------------------------------------*/
DECLARE @map TABLE (sp sysname, nhom sysname);

INSERT INTO @map (sp, nhom) VALUES
    /*--- Câu 1: đăng nhập, tài khoản, mật khẩu ---*/
    ('SP_LayThongTinNguoiDung','Truong'),   ('SP_LayThongTinNguoiDung','CoSo'),
    ('SP_LayThongTinNguoiDung','Giangvien'),('SP_LayThongTinNguoiDung','Sinhvien'),
    ('SP_LayThongTinNhanVien','Truong'),    ('SP_LayThongTinNhanVien','CoSo'),
    ('SP_LayThongTinNhanVien','Giangvien'), ('SP_LayThongTinNhanVien','Sinhvien'),
    ('sp_DangNhap_SV','Sinhvien'),
    ('sp_DoiMatKhau_SV','Truong'),   ('sp_DoiMatKhau_SV','CoSo'),
    ('sp_DoiMatKhau_SV','Giangvien'),('sp_DoiMatKhau_SV','Sinhvien'),
    ('SP_DOIMATKHAU','Truong'), ('SP_DOIMATKHAU','CoSo'), ('SP_DOIMATKHAU','Giangvien'),
    ('SP_TAOLOGIN','Truong'),   ('SP_TAOLOGIN','CoSo'),
    ('sp_DS_TaiKhoan','Truong'),('sp_DS_TaiKhoan','CoSo'),
    ('sp_DS_GV_ChuaCoTaiKhoan','Truong'), ('sp_DS_GV_ChuaCoTaiKhoan','CoSo'),

    /*--- Câu 6: bộ đề ---*/
    ('sp_Bode_DS','Giangvien'),  ('sp_Bode_DS','CoSo'),  ('sp_Bode_DS','Truong'),
    ('sp_Bode_Them','Giangvien'),('sp_Bode_Them','CoSo'),
    ('sp_Bode_Sua','Giangvien'), ('sp_Bode_Sua','CoSo'),
    ('sp_Bode_Xoa','Giangvien'), ('sp_Bode_Xoa','CoSo'),

    /*--- Câu 7: chuẩn bị thi ---*/
    ('sp_ChuanBiThi','Giangvien'), ('sp_ChuanBiThi','CoSo'),
    ('sp_LichThi','Sinhvien'), ('sp_LichThi','Giangvien'),
    ('sp_LichThi','CoSo'),     ('sp_LichThi','Truong'),

    /*--- Câu 8: thi (giảng viên được THI THỬ) ---*/
    ('sp_LayDeThi','Sinhvien'), ('sp_LayDeThi','Giangvien'), ('sp_LayDeThi','CoSo'),
    ('sp_NopBai','Sinhvien'),   ('sp_NopBai','Giangvien'),
    ('sp_ThongTinThiSinh','Sinhvien'), ('sp_ThongTinThiSinh','Giangvien'),
    ('sp_ThongTinThiSinh','CoSo'),
    ('sp_ThoiGianConLai','Sinhvien'),  ('sp_ThoiGianConLai','Giangvien'),
    ('sp_MoLaiBaiThi','Sinhvien'),     ('sp_MoLaiBaiThi','Giangvien'),
    ('sp_MoLaiBaiThi','CoSo'),

    /*--- Câu 9, 10, 11: ba báo cáo. Đề: Trưởng chạy được TẤT CẢ ---*/
    ('sp_XemKetQua','Sinhvien'), ('sp_XemKetQua','Giangvien'),
    ('sp_XemKetQua','CoSo'),     ('sp_XemKetQua','Truong'),

    /*--- Câu 9: danh sách bài thi. Sinh viên xem bài CỦA MÌNH ---*/
    ('sp_DS_BaiThi_SV','Sinhvien'), ('sp_DS_BaiThi_SV','Giangvien'),
    ('sp_DS_BaiThi_SV','CoSo'),     ('sp_DS_BaiThi_SV','Truong'),

    /*--- Câu 9 - PHÚC KHẢO: giảng viên chọn lớp rồi chọn sinh viên.
          CỐ Ý không cấp cho Sinhvien: các em chỉ xem bài của chính mình,
          không được liệt kê bạn cùng lớp. ---*/
    ('sp_DS_Lop_CoBaiThi','Giangvien'),      ('sp_DS_Lop_CoBaiThi','CoSo'),
    ('sp_DS_Lop_CoBaiThi','Truong'),
    ('sp_DS_SinhVien_CoBaiThi','Giangvien'), ('sp_DS_SinhVien_CoBaiThi','CoSo'),
    ('sp_DS_SinhVien_CoBaiThi','Truong'),
    ('sp_BangDiemMonHoc','Giangvien'), ('sp_BangDiemMonHoc','CoSo'),
    ('sp_BangDiemMonHoc','Truong'),
    ('sp_BaoCao_DangKy','CoSo'), ('sp_BaoCao_DangKy','Truong'),

    /*--- Quản trị: sao lưu / phục hồi ---*/
    ('SP_SAOLUU','Truong'),    ('SP_SAOLUU','CoSo'),
    ('SP_DS_SAOLUU','Truong'), ('SP_DS_SAOLUU','CoSo'),
    ('SP_PHUCHOI_CSDL','Truong');

/*----------------------------------------------------------------------
  Cấp quyền
----------------------------------------------------------------------*/
DECLARE @sp sysname, @nhom sysname, @sql nvarchar(400), @cap int = 0, @bo int = 0;
DECLARE c CURSOR FOR SELECT sp, nhom FROM @map;
OPEN c; FETCH NEXT FROM c INTO @sp, @nhom;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID('dbo.' + @sp) IS NULL OR DATABASE_PRINCIPAL_ID(@nhom) IS NULL
        SET @bo = @bo + 1;                    /* server này không có SP hoặc nhóm đó */
    ELSE
    BEGIN
        SET @sql = N'GRANT EXECUTE ON dbo.' + QUOTENAME(@sp) + N' TO ' + QUOTENAME(@nhom) + N';';
        EXEC (@sql);
        SET @cap = @cap + 1;
    END
    FETCH NEXT FROM c INTO @sp, @nhom;
END
CLOSE c; DEALLOCATE c;

PRINT N'Đã cấp ' + CAST(@cap AS nvarchar(5)) + N' quyền EXECUTE, bỏ qua '
    + CAST(@bo AS nvarchar(5)) + N' (không có SP/nhóm trên server này).';
GO

PRINT N'== Đã cấp lại quyền ==';
GO

/*----------------------------------------------------------------------
  Kiểm tra: mỗi nhóm có bao nhiêu quyền
----------------------------------------------------------------------*/
SELECT nhom = r.name, so_thu_tuc = COUNT(*)
FROM sys.database_permissions p
JOIN sys.database_principals r ON p.grantee_principal_id = r.principal_id
WHERE r.type = 'R' AND p.permission_name = 'EXECUTE' AND p.state_desc = 'GRANT'
  AND r.name IN ('Truong','CoSo','Giangvien','Sinhvien')
GROUP BY r.name
ORDER BY r.name;
GO
