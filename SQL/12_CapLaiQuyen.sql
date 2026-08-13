/*======================================================================
  KHÔI PHỤC TOÀN BỘ QUYỀN CHO 4 NHÓM (bảng + stored procedure)
  Chạy trên: SERVER, SERVER1, SERVER2   ·   sqlcmd -f 65001
  ----------------------------------------------------------------------
  ⚠️ PHẢI CHẠY LẠI SAU MỖI LẦN:
        - nhân bản đẩy thủ tục xuống phân mảnh
        - tạo lại snapshot / reinitialize subscription

  VÌ SAO
  Quyền GRANT không nằm trong định nghĩa của đối tượng. Nhân bản đẩy
  thủ tục xuống bằng cách DROP rồi CREATE lại; snapshot/reinit cũng
  DROP rồi tạo lại BẢNG. Cả hai đều làm mọi GRANT/DENY trên đối tượng đó
  BIẾN MẤT.

  Hai sự cố thật đã xảy ra:

   1. Sau một lần đồng bộ thủ tục, nhóm Sinhvien chỉ còn 3 quyền EXECUTE
      (đáng lẽ 11), mất sp_DangNhap_SV. Sinh viên đăng nhập bị báo
      "sai mật khẩu" trong khi tài khoản SQL vẫn bình thường.

   2. Sau khi dựng lại subscription CS2, nhóm Giangvien mất SẠCH quyền
      bảng trên SERVER2. Giảng viên TH657 mở màn Bộ đề thì ComboBox môn
      học TRỐNG nên không soạn được đề - lỗi thật là
      "SELECT permission was denied on MONHOC" nhưng bị nuốt mất.

  => Quy trình đúng:  sửa ở máy chủ -> nhân bản đẩy xuống
                      -> CHẠY LẠI SCRIPT NÀY -> KiemTraDongBoSP.ps1
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;

/*======================================================================
  PHẦN A - QUYỀN TRÊN BẢNG
======================================================================*/

/*--- Trưởng: CHỈ XEM toàn bộ, chặn mọi thao tác ghi ---*/
IF DATABASE_PRINCIPAL_ID('Truong') IS NOT NULL
BEGIN
    GRANT SELECT ON DATABASE::TN_CSDLPT TO [Truong];
    DECLARE @b1 sysname, @s1 nvarchar(300);
    DECLARE cT CURSOR FOR SELECT name FROM sys.tables
        WHERE is_ms_shipped=0 AND name NOT LIKE 'MSmerge%' AND name NOT LIKE 'sys%';
    OPEN cT; FETCH NEXT FROM cT INTO @b1;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @s1 = N'DENY INSERT, UPDATE, DELETE ON dbo.' + QUOTENAME(@b1) + N' TO [Truong];';
        EXEC (@s1);
        FETCH NEXT FROM cT INTO @b1;
    END
    CLOSE cT; DEALLOCATE cT;
    PRINT N'  [Truong]    chỉ xem toàn bộ, chặn ghi';
END

/*--- Cơ sở: toàn quyền trên cơ sở của mình ---*/
IF DATABASE_PRINCIPAL_ID('CoSo') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON DATABASE::TN_CSDLPT TO [CoSo];
    GRANT ALTER ANY USER TO [CoSo];          /* để SP_TAOLOGIN tạo được user */
    PRINT N'  [CoSo]      toàn quyền trên phân mảnh';
END

/*--- Giảng viên: ĐỌC danh mục, KHÔNG nhập khoa/lớp/sinh viên (theo đề) ---*/
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.MONHOC          TO [Giangvien];   /* <-- thiếu cái này là không soạn được đề */
    GRANT SELECT ON dbo.KHOA            TO [Giangvien];
    GRANT SELECT ON dbo.LOP             TO [Giangvien];
    GRANT SELECT ON dbo.GIAOVIEN        TO [Giangvien];
    GRANT SELECT ON dbo.SINHVIEN        TO [Giangvien];
    GRANT SELECT ON dbo.GIAOVIEN_DANGKY TO [Giangvien];
    GRANT SELECT ON dbo.BANGDIEM        TO [Giangvien];
    GRANT SELECT ON dbo.BODE            TO [Giangvien];

    /* Đề: giảng viên KHÔNG được nhập khoa / lớp / sinh viên mới.
       Sửa bộ đề PHẢI qua SP (SP mới ép được "chỉ sửa đề của mình"). */
    DENY INSERT, UPDATE, DELETE ON dbo.KHOA     TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.LOP      TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.SINHVIEN TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.GIAOVIEN TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.MONHOC   TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.BODE     TO [Giangvien];
    PRINT N'  [Giangvien] đọc danh mục, chặn sửa trực tiếp';
END

/*--- Sinh viên: KHÔNG đụng bảng, mọi thao tác qua stored procedure ---*/
IF DATABASE_PRINCIPAL_ID('Sinhvien') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.BODE           TO [Sinhvien];
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.GIAOVIEN       TO [Sinhvien];
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.ChiTiet_BaiThi TO [Sinhvien];
    PRINT N'  [Sinhvien]  chặn truy cập bảng trực tiếp';
END
GO

/*======================================================================
  PHẦN B - QUYỀN EXECUTE TRÊN STORED PROCEDURE
======================================================================*/

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
    ('sp_DS_MonHoc_SoanDe','Giangvien'), ('sp_DS_MonHoc_SoanDe','CoSo'),
    ('sp_DS_MonHoc_SoanDe','Truong'),
    ('sp_Bode_DS','Giangvien'),  ('sp_Bode_DS','CoSo'),  ('sp_Bode_DS','Truong'),
    ('sp_Bode_Them','Giangvien'),('sp_Bode_Them','CoSo'),
    ('sp_Bode_Sua','Giangvien'), ('sp_Bode_Sua','CoSo'),
    ('sp_Bode_Xoa','Giangvien'), ('sp_Bode_Xoa','CoSo'),

    /*--- Câu 7: phân công giảng dạy (Cơ sở làm) rồi mới đăng ký kỳ thi.
          sp_PhanCong_Them/Xoa CỐ Ý chỉ cấp cho CoSo: giảng viên tự phân
          công cho mình thì việc lọc môn ở màn Soạn bộ đề thành vô nghĩa. ---*/
    ('sp_PhanCong_DS','CoSo'), ('sp_PhanCong_DS','Truong'), ('sp_PhanCong_DS','Giangvien'),
    ('sp_PhanCong_Them','CoSo'),
    ('sp_PhanCong_Xoa','CoSo'),
    ('sp_ChuanBiThi','Giangvien'), ('sp_ChuanBiThi','CoSo'),
    ('sp_LichThi','Sinhvien'), ('sp_LichThi','Giangvien'),
    ('sp_LichThi','CoSo'),     ('sp_LichThi','Truong'),

    /*--- Câu 8: thi (giảng viên được THI THỬ) ---*/
    ('sp_LayDeThi','Sinhvien'), ('sp_LayDeThi','Giangvien'), ('sp_LayDeThi','CoSo'),
    ('sp_NopBai','Sinhvien'),   ('sp_NopBai','Giangvien'),
    ('sp_ThongTinThiSinh','Sinhvien'), ('sp_ThongTinThiSinh','Giangvien'),
    ('sp_ThongTinThiSinh','CoSo'),
    ('sp_ThoiGianConLai','Sinhvien'),  ('sp_ThoiGianConLai','Giangvien'),
    /*--- sp_MoLaiBaiThi: CHỈ CoSo. Thủ tục này XOÁ điểm + phiếu thi.
          Trước đây cấp nhầm cho Sinhvien/Giangvien, mà @MASV lại là tham
          số do ứng dụng gửi và mọi sinh viên dùng chung login "sv" -> bất
          kỳ ai cũng xoá được điểm của bất kỳ ai. Xem 19_VaLoHongMoLaiBaiThi.sql
          (thủ tục nay còn tự kiểm quyền bên trong, không chỉ dựa vào GRANT). ---*/
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
  Kiểm tra: mỗi nhóm còn bao nhiêu quyền, tách riêng SP và BẢNG.
  Con số cần thấy (trên SERVER1 / SERVER2):
     Giangvien : sp=... , bang_select=8 , bang_deny=6
     Sinhvien  : sp=11  , bang_deny=3
  Nếu bang_select của Giangvien = 0 -> giảng viên sẽ KHÔNG thấy môn học.
----------------------------------------------------------------------*/
SELECT nhom        = r.name,
       sp_execute  = SUM(CASE WHEN p.permission_name='EXECUTE' AND p.state_desc='GRANT'
                              AND o.type IN ('P','PC') THEN 1 ELSE 0 END),
       bang_select = SUM(CASE WHEN p.permission_name='SELECT' AND p.state_desc='GRANT'
                              AND o.type IN ('U','V') THEN 1 ELSE 0 END),
       bang_deny   = SUM(CASE WHEN p.state_desc='DENY' AND o.type IN ('U','V')
                              AND p.permission_name='INSERT' THEN 1 ELSE 0 END)
FROM sys.database_permissions p
JOIN sys.database_principals r ON p.grantee_principal_id = r.principal_id
LEFT JOIN sys.objects o ON o.object_id = p.major_id AND p.class = 1
WHERE r.type = 'R' AND r.name IN ('Truong','CoSo','Giangvien','Sinhvien')
GROUP BY r.name
ORDER BY r.name;
GO
