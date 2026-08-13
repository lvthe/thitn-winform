/*======================================================================
  CÂU 6 - GIẢNG VIÊN CHỈ SOẠN ĐỀ CHO MÔN MÌNH DẠY
  Chạy trên: SERVER (máy chủ) TRƯỚC, rồi SERVER1, SERVER2
  Chạy bằng: sqlcmd -f 65001
  Sau đó PHẢI chạy lại 12_CapLaiQuyen.sql
  ----------------------------------------------------------------------
  VẤN ĐỀ
  Màn "Soạn bộ đề" đang đổ TOÀN BỘ bảng MONHOC vào ô chọn môn, nên giảng
  viên TH657 (chỉ dạy MMTCB) vẫn chọn được Giải tích, Anh văn... rồi soạn
  đề cho môn mình không dạy.

  "GIẢNG VIÊN DẠY MÔN NÀO" LẤY Ở ĐÂU
  Schema của thầy không có bảng phân công giảng dạy riêng:
      GIAOVIEN(MAGV, HO, TEN, MAKH, HOCVI)   -> chỉ gắn với KHOA
      MONHOC  (MAMH, TENMH)                  -> không gắn với ai
  Nơi duy nhất ghi cặp (giáo viên, môn học) là:
      GIAOVIEN_DANGKY(MAGV, MAMH, MALOP, TRINHDO, NGAYTHI, LAN, ...)
  => Đây chính là nguồn sự thật, đúng như tên bảng: giáo viên đăng ký
     dạy/tổ chức thi môn nào cho lớp nào.

  AI PHÂN CÔNG
  Nhóm CoSo là người ánh xạ giáo viên <-> môn học (qua màn Chuẩn bị thi),
  giảng viên KHÔNG tự mở rộng danh sách môn của mình. Vì vậy thủ tục này
  không có tham số "xem tất cả" và màn Soạn bộ đề cũng không có ô tick nào
  để lách - muốn dạy thêm môn thì phải được Cơ sở phân công.

  VÌ SAO CÒN LẤY THÊM TỪ BODE
  KHÔNG phải để làm cửa hậu, mà vì dữ liệu thật đang có trường hợp này:
  trên CS1, giảng viên TH123 có 158 câu hỏi môn MMTCB nhưng KHÔNG có dòng
  nào trong GIAOVIEN_DANGKY. Nếu lọc thuần theo bảng đăng ký thì TH123 mất
  trắng lối vào 158 câu do chính mình soạn.

  => Danh sách môn của giảng viên = HỢP của hai nguồn:
        (1) môn được Cơ sở phân công  (GIAOVIEN_DANGKY)
        (2) môn mình ĐÃ CÓ đề        (BODE)
     Nguồn (2) không mở thêm môn mới - nó chỉ giữ lại những gì giảng viên
     đã sở hữu, nên vẫn đúng nguyên tắc "chỉ soạn đề cho môn mình dạy".

  Nhóm CoSo / Truong: luôn thấy đủ môn (đúng vai trò quản lý phân mảnh),
  cùng quy ước với sp_Bode_DS.

  LƯU Ý VỀ THỨ TỰ NGHIỆP VỤ
  sp_ChuanBiThi (nơi DUY NHẤT ghi vào GIAOVIEN_DANGKY) từ chối đăng ký khi
  kho đề chưa đủ 70% số câu thi. Nên với một môn HOÀN TOÀN MỚI chưa ai soạn
  đề, Cơ sở chưa phân công được bằng màn Chuẩn bị thi. Dữ liệu hiện tại đã
  có sẵn phân công nên không vướng; nếu về sau cần mở môn mới thì phải tách
  "phân công dạy" khỏi "đăng ký kỳ thi" - xem ghi chú ở RASOAT_LUONGXULY.md.
======================================================================*/
USE TN_CSDLPT;
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_DS_MonHoc_SoanDe]
AS
BEGIN
    SET NOCOUNT ON;

    /* Ai đang đăng nhập - lấy từ CHÍNH SQL login, không nhận từ ứng dụng,
       giống hệt sp_Bode_DS / sp_Bode_Them nên không giả mạo được.
       Không có tham số nào để nới danh sách -> ứng dụng không thể lách. */
    DECLARE @magv char(8) = NULL;
    IF ISNULL(IS_MEMBER('Giangvien'),0) = 1 AND ISNULL(IS_MEMBER('CoSo'),0) = 0
        SET @magv = CAST(SUSER_SNAME() AS char(8));

    SELECT MAMH = RTRIM(m.MAMH), TENMH = RTRIM(m.TENMH)
    FROM dbo.Monhoc m
    WHERE @magv IS NULL                                  /* CoSo, Truong: đủ môn */
       OR EXISTS (SELECT 1 FROM dbo.Giaovien_Dangky d    /* (1) Cơ sở phân công  */
                  WHERE d.MAMH = m.MAMH AND d.MAGV = @magv)
       OR EXISTS (SELECT 1 FROM dbo.Bode b               /* (2) môn đã có đề     */
                  WHERE b.MAMH = m.MAMH AND b.MAGV = @magv)
    ORDER BY MAMH;
END
GO

PRINT N'  + sp_DS_MonHoc_SoanDe';
GO

/* Máy chủ chỉ có nhóm Truong, phân mảnh mới có đủ 4 nhóm -> phải rào lại */
IF DATABASE_PRINCIPAL_ID('Giangvien') IS NOT NULL
    GRANT EXECUTE ON dbo.sp_DS_MonHoc_SoanDe TO [Giangvien];
IF DATABASE_PRINCIPAL_ID('CoSo') IS NOT NULL
    GRANT EXECUTE ON dbo.sp_DS_MonHoc_SoanDe TO [CoSo];
IF DATABASE_PRINCIPAL_ID('Truong') IS NOT NULL
    GRANT EXECUTE ON dbo.sp_DS_MonHoc_SoanDe TO [Truong];
GO

PRINT N'== Xong. Nhớ chạy lại 12_CapLaiQuyen.sql sau khi nhân bản đẩy SP xuống ==';
GO
