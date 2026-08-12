/*======================================================================
  CÂU 1 (bổ sung) - TÀI KHOẢN DỊCH VỤ CHO MẢNH 3 (TRA CỨU)
  Chạy trên: SERVER3
  ----------------------------------------------------------------------
  Đề: "không cho người ta đăng nhập vào server này, nhưng vẫn dùng nó
       để tra cứu mã sinh viên có chưa, mã lớp có chưa".
  => Người dùng KHÔNG có tài khoản trên mảnh 3. Chính ỨNG DỤNG dùng một
     tài khoản dịch vụ CHỈ-ĐỌC để tra cứu ngầm.
  => Tài khoản này KHÔNG được cấp quyền ghi, và mảnh 3 không xuất hiện
     trong ComboBox chọn phân mảnh ở form đăng nhập.
======================================================================*/
USE TN_CSDLPT;
GO

IF SUSER_ID('tracuu') IS NULL
    CREATE LOGIN [tracuu] WITH PASSWORD = 'TraCuu@123', CHECK_POLICY = OFF;
GO

IF DATABASE_PRINCIPAL_ID('tracuu') IS NULL
    CREATE USER [tracuu] FOR LOGIN [tracuu];
GO

/* CHỈ cho đọc đúng 2 bảng của mảnh dọc, không gì khác */
GRANT SELECT ON dbo.SINHVIEN TO [tracuu];
GRANT SELECT ON dbo.LOP      TO [tracuu];

/* Chặn mọi thao tác ghi cho chắc */
DENY INSERT, UPDATE, DELETE ON dbo.SINHVIEN TO [tracuu];
DENY INSERT, UPDATE, DELETE ON dbo.LOP      TO [tracuu];
GO

PRINT N'== Đã tạo tài khoản dịch vụ [tracuu] (chỉ đọc) trên mảnh 3 ==';
GO

/* Kiểm tra lại quyền đã cấp */
SELECT  doi_tuong = OBJECT_NAME(p.major_id),
        quyen     = p.permission_name,
        trang_thai= p.state_desc
FROM sys.database_permissions p
JOIN sys.database_principals u ON p.grantee_principal_id = u.principal_id
WHERE u.name = 'tracuu'
ORDER BY doi_tuong, quyen;
GO
