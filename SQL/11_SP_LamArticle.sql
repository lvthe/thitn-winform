/*======================================================================
  ĐƯA STORED PROCEDURE THÀNH ARTICLE ĐỂ NHÂN BẢN XUỐNG PHÂN MẢNH
  Chạy trên: CHỈ SERVER (publisher)   ·   sqlcmd -f 65001
  ----------------------------------------------------------------------
  Thầy dặn điều này HAI LẦN:

   1) HD FORM DANG NHAP.docx:
      "Tạo lại sp_LayThongTinNhanVien ở CSDL gốc (Server Publisher),
       định nghĩa sp này là 1 Article trên các phân mảnh."

   2) Bài giảng làm báo cáo (report.txt):
      "bắt buộc là chúng ta phải viết SP này ở server chủ và sau đó ta
       sẽ đẩy nó xuống các phân mảnh, để về sau khi chạy báo cáo trên
       bất kỳ phân mảnh nào thì SP này cũng đã tồn tại ở đó rồi."

  ----------------------------------------------------------------------
  GIẢI TỎA MỘT HIỂU NHẦM

  Đề câu 11 nói "KHÔNG được về server chủ". Điều đó nói về nơi CHẠY báo
  cáo và nơi LẤY DỮ LIỆU, chứ không cấm SP tồn tại trên máy chủ.
  Máy chủ giữ BẢN GỐC của thủ tục để nhân bản đẩy xuống hai phân mảnh;
  ứng dụng vẫn chỉ gọi thủ tục đó TRÊN PHÂN MẢNH, không mở kết nối tới
  máy chủ. Hai yêu cầu không hề mâu thuẫn.

  ----------------------------------------------------------------------
  LỢI ÍCH THỰC TẾ
  Trước đây mỗi lần sửa thủ tục phải nhớ chạy lại trên TỪNG server, quên
  một cái là hai cơ sở chạy hai phiên bản khác nhau. Sau khi làm article,
  chỉ sửa ở máy chủ rồi cho nhân bản đẩy xuống - luôn đồng nhất.
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;

/*----------------------------------------------------------------------
  1. Danh sách thủ tục cần nhân bản
     Lấy hết thủ tục nghiệp vụ; bỏ các thủ tục HẠ TẦNG riêng từng máy
     (sao lưu / phục hồi / tạo login) vì chúng thao tác trên chính
     instance đang chạy, không nên đồng nhất qua nhân bản.
----------------------------------------------------------------------*/
IF OBJECT_ID('tempdb..#SP') IS NOT NULL DROP TABLE #SP;
CREATE TABLE #SP (ten sysname PRIMARY KEY);

INSERT INTO #SP (ten)
SELECT name FROM sys.procedures
WHERE is_ms_shipped = 0
  AND name NOT LIKE 'MSmerge%' AND name NOT LIKE 'sp_MS%'
  AND name NOT LIKE 'sp_%diagram%'
  AND name NOT IN (N'SP_SAOLUU', N'SP_PHUCHOI_CSDL', N'SP_DS_SAOLUU',   /* hạ tầng từng máy */
                   N'SP_TAOLOGIN');                                      /* tạo login cục bộ */

SELECT N'Sẽ nhân bản ' + CAST(COUNT(*) AS nvarchar(5)) + N' thủ tục' AS ThongTin FROM #SP;

/*----------------------------------------------------------------------
  2. Thêm vào publication CS1 và CS2
     @type = 'proc schema only' -> nhân bản ĐỊNH NGHĨA thủ tục,
     không nhân bản việc thực thi.
----------------------------------------------------------------------*/
DECLARE @pub sysname, @sp sysname, @them int = 0, @boqua int = 0;
DECLARE cp CURSOR FOR SELECT N'TN_CSDLPT_CS1' UNION ALL SELECT N'TN_CSDLPT_CS2';
OPEN cp; FETCH NEXT FROM cp INTO @pub;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT N'--- ' + @pub + N' ---';
    DECLARE cs CURSOR FOR SELECT ten FROM #SP ORDER BY ten;
    OPEN cs; FETCH NEXT FROM cs INTO @sp;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM sysmergearticles a
                   JOIN sysmergepublications p ON a.pubid = p.pubid
                   WHERE p.name = @pub AND a.name = @sp)
            SET @boqua = @boqua + 1;
        ELSE
        BEGIN
            BEGIN TRY
                EXEC sp_addmergearticle
                     @publication   = @pub,
                     @article       = @sp,
                     @source_object = @sp,
                     @type          = N'proc schema only',
                     @force_invalidate_snapshot   = 1,
                     @force_reinit_subscription   = 1;
                SET @them = @them + 1;
            END TRY
            BEGIN CATCH
                PRINT N'   ! ' + @sp + N': ' + ERROR_MESSAGE();
            END CATCH
        END
        FETCH NEXT FROM cs INTO @sp;
    END
    CLOSE cs; DEALLOCATE cs;
    FETCH NEXT FROM cp INTO @pub;
END
CLOSE cp; DEALLOCATE cp;

PRINT N'';
PRINT N'Đã thêm ' + CAST(@them AS nvarchar(5)) + N' article, bỏ qua '
    + CAST(@boqua AS nvarchar(5)) + N' (đã có sẵn).';
GO

/*----------------------------------------------------------------------
  3. Tạo lại snapshot để đẩy thủ tục xuống phân mảnh
----------------------------------------------------------------------*/
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_CS1';
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_CS2';
PRINT N'Đã khởi động lại snapshot cho CS1 và CS2.';
GO

/*----------------------------------------------------------------------
  4. Kiểm tra
----------------------------------------------------------------------*/
SELECT publication = p.name,
       so_bang     = SUM(CASE WHEN a.type = 10 THEN 1 ELSE 0 END),
       so_thu_tuc  = SUM(CASE WHEN a.type <> 10 THEN 1 ELSE 0 END)
FROM sysmergearticles a
JOIN sysmergepublications p ON a.pubid = p.pubid
WHERE p.name LIKE 'TN_CSDLPT_CS%'
GROUP BY p.name
ORDER BY p.name;
GO

PRINT N'';
PRINT N'== XONG. Đợi snapshot chạy xong rồi chạy Merge Agent để thủ tục ==';
PRINT N'== được đẩy xuống SERVER1 / SERVER2.                            ==';
GO
