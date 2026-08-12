namespace QuanLyThi;

/// <summary>
/// CÂU 2 - Danh mục MÔN HỌC.
/// Đề: môn học chỉ gồm mã và tên (không cần số tín chỉ, vì đề tài này
/// không tính điểm trung bình tích lũy).
/// </summary>
public class frmMonHoc : frmCrudBase
{
    public frmMonHoc()
    {
        Text = "Câu 2 - Danh mục môn học";
        Load += (_, _) =>
        {
            CauHinh(new BangCrud("MONHOC",
                "SELECT MAMH, TENMH FROM dbo.MONHOC ORDER BY MAMH"));

            DatCot(luoi, "MAMH", "Mã môn học", 30);
            DatCot(luoi, "TENMH", "Tên môn học", 70);
        };
    }
}
