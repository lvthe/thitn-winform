/*======================================================================
  PHÂN QUYỀN TĨNH CHO 4 NHÓM  (đề: Trưởng / Cơ sở / Giảng viên / Sinh viên)
  Chạy trên: SERVER1, SERVER2, SERVER (publisher)
  Chạy bằng: sqlcmd -f 65001
  ----------------------------------------------------------------------
  Tóm tắt quyền theo đề:
    * Trưởng    : CHỈ XEM mọi thứ + chạy được 3 báo cáo. Không thêm/xóa/sửa.
    * Cơ sở     : toàn quyền trên cơ sở của mình.
    * Giảng viên: KHÔNG nhập khoa / lớp / sinh viên mới.
                  CHỈ cập nhật đề thi (và chỉ đề do mình soạn - ép trong SP).
                  Được THI THỬ nhưng không ghi điểm.
    * Sinh viên : chỉ được THI. Không truy cập bảng trực tiếp, mọi thao tác
                  đi qua stored procedure (ownership chaining).
======================================================================*/
USE TN_CSDLPT;
GO

SET NOCOUNT ON;

/*----------------------------------------------------------------------
  1. GIẢNG VIÊN - quyền ĐỌC các danh mục cần cho màn soạn đề & báo cáo
----------------------------------------------------------------------*/
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
BEGIN
    GRANT SELECT ON dbo.MONHOC          TO [Giangvien];
    GRANT SELECT ON dbo.KHOA            TO [Giangvien];
    GRANT SELECT ON dbo.LOP             TO [Giangvien];
    GRANT SELECT ON dbo.GIAOVIEN        TO [Giangvien];
    GRANT SELECT ON dbo.SINHVIEN        TO [Giangvien];
    GRANT SELECT ON dbo.GIAOVIEN_DANGKY TO [Giangvien];
    GRANT SELECT ON dbo.BANGDIEM        TO [Giangvien];
    GRANT SELECT ON dbo.BODE            TO [Giangvien];

    /* Đề nói rõ: giảng viên KHÔNG được nhập khoa / lớp / sinh viên mới.
       DENY để ý định này hiện rõ ngay trong CSDL (và vẫn không cản
       stored procedure, vì ownership chaining bỏ qua bước kiểm quyền). */
    DENY INSERT, UPDATE, DELETE ON dbo.KHOA     TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.LOP      TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.SINHVIEN TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.GIAOVIEN TO [Giangvien];
    DENY INSERT, UPDATE, DELETE ON dbo.MONHOC   TO [Giangvien];

    /* Sửa bộ đề PHẢI qua SP (SP mới ép được "chỉ sửa đề của mình"). */
    DENY INSERT, UPDATE, DELETE ON dbo.BODE     TO [Giangvien];
    PRINT N'  [Giangvien] - đã cấp quyền đọc danh mục, chặn sửa trực tiếp';
END
GO

/*----------------------------------------------------------------------
  2. SINH VIÊN - không đụng bảng, chỉ gọi stored procedure
----------------------------------------------------------------------*/
IF DATABASE_PRINCIPAL_ID('Sinhvien') IS NOT NULL
BEGIN
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.BODE     TO [Sinhvien];
    DENY SELECT, INSERT, UPDATE, DELETE ON dbo.GIAOVIEN TO [Sinhvien];
    PRINT N'  [Sinhvien] - chặn truy cập bảng trực tiếp (đi qua SP)';
END
GO

/*----------------------------------------------------------------------
  3. Cấp EXECUTE trên stored procedure theo từng nhóm
----------------------------------------------------------------------*/
DECLARE @map TABLE (sp sysname, nhom sysname);

INSERT INTO @map (sp, nhom) VALUES
    -- Câu 6: soạn bộ đề
    ('sp_Bode_DS',        'Giangvien'), ('sp_Bode_DS',        'CoSo'),
    ('sp_Bode_Them',      'Giangvien'), ('sp_Bode_Them',      'CoSo'),
    ('sp_Bode_Sua',       'Giangvien'), ('sp_Bode_Sua',       'CoSo'),
    ('sp_Bode_Xoa',       'Giangvien'), ('sp_Bode_Xoa',       'CoSo'),
    -- Câu 7: chuẩn bị thi / đăng ký
    ('sp_ChuanBiThi',     'Giangvien'), ('sp_ChuanBiThi',     'CoSo'),
    ('sp_LichThi',        'Sinhvien'),  ('sp_LichThi',        'Giangvien'), ('sp_LichThi', 'CoSo'),
    -- Câu 8: thi (giảng viên được THI THỬ)
    ('sp_LayDeThi',       'Sinhvien'),  ('sp_LayDeThi',       'Giangvien'), ('sp_LayDeThi', 'CoSo'),
    ('sp_NopBai',         'Sinhvien'),  ('sp_NopBai',         'Giangvien'),
    ('sp_ThongTinThiSinh','Sinhvien'),  ('sp_ThongTinThiSinh','Giangvien'),
    ('sp_ThoiGianConLai', 'Sinhvien'),  ('sp_ThoiGianConLai', 'Giangvien'),
    ('sp_MoLaiBaiThi',    'Sinhvien'),  ('sp_MoLaiBaiThi',    'Giangvien'),
    ('sp_DangNhap_SV',    'Sinhvien'),
    -- Câu 9, 10: xem kết quả / bảng điểm
    ('sp_XemKetQua',      'Sinhvien'),  ('sp_XemKetQua',      'Giangvien'), ('sp_XemKetQua', 'CoSo'),
    ('sp_BangDiemMonHoc', 'Giangvien'), ('sp_BangDiemMonHoc', 'CoSo'),      ('sp_BangDiemMonHoc', 'Truong');

DECLARE @sp sysname, @nhom sysname, @sql nvarchar(400), @cap int = 0, @bo int = 0;
DECLARE c CURSOR FOR SELECT sp, nhom FROM @map;
OPEN c; FETCH NEXT FROM c INTO @sp, @nhom;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID('dbo.' + @sp) IS NULL
        SET @bo = @bo + 1;                                  -- SP chưa tồn tại trên server này
    ELSE IF DATABASE_PRINCIPAL_ID(@nhom) IS NULL
        SET @bo = @bo + 1;                                  -- nhóm chưa tồn tại
    ELSE
    BEGIN
        SET @sql = N'GRANT EXECUTE ON dbo.' + QUOTENAME(@sp) + N' TO ' + QUOTENAME(@nhom) + N';';
        EXEC (@sql);
        SET @cap = @cap + 1;
    END
    FETCH NEXT FROM c INTO @sp, @nhom;
END
CLOSE c; DEALLOCATE c;

PRINT N'  Đã cấp EXECUTE: ' + CAST(@cap AS nvarchar(10))
    + N' mục; bỏ qua (chưa có SP/nhóm): ' + CAST(@bo AS nvarchar(10));
GO

PRINT N'== Phân quyền hoàn tất ==';
GO

/* Kiểm tra lại */
SELECT nhom = r.name,
       doi_tuong = ISNULL(OBJECT_NAME(p.major_id), '(toàn CSDL)'),
       quyen = p.permission_name,
       tt = p.state_desc
FROM sys.database_permissions p
JOIN sys.database_principals r ON p.grantee_principal_id = r.principal_id
WHERE r.type = 'R' AND r.name IN ('Truong','CoSo','Giangvien','Sinhvien')
ORDER BY r.name, doi_tuong, quyen;
GO
