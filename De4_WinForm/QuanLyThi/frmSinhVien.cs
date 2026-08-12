using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 4 - Nhập SINH VIÊN.
/// Đề: form này CHỈ nhập sinh viên; Lớp chỉ để CHỌN (không nhập lớp ở đây,
/// muốn thêm lớp thì sang form Khoa &amp; Lớp).
/// Có ô PASSWORD vì sinh viên dùng SQL login chung, danh tính xác thực
/// bằng MASV + PASSWORD ở tầng dữ liệu.
/// Khi thêm mới, mã sinh viên được đối chiếu qua MẢNH 3 (tra cứu toàn
/// trường) để không trùng với sinh viên của cơ sở còn lại.
/// </summary>
public class frmSinhVien : frmCrudBase
{
    private DataTable _dsLop = new();

    public frmSinhVien()
    {
        Text = "Câu 4 - Nhập sinh viên";
        Load += (_, _) => KhoiTao();
    }

    private void KhoiTao()
    {
        // Danh sách lớp của chính phân mảnh này -> dùng cho ô chọn Lớp.
        try { _dsLop = DataProvider.TruyVan("SELECT MALOP, TENLOP FROM dbo.LOP ORDER BY MALOP"); }
        catch (Exception ex) { BaoTrangThai("Không nạp được danh sách lớp: " + ex.Message, true); }

        CauHinh(new BangCrud("SINHVIEN",
            @"SELECT MASV, HO, TEN, NGAYSINH, DIACHI, MALOP, [PASSWORD]
              FROM dbo.SINHVIEN ORDER BY MALOP, MASV"));

        DatCot(luoi, "MASV", "Mã SV", 14);
        DatCot(luoi, "HO", "Họ", 22);
        DatCot(luoi, "TEN", "Tên", 12);
        DatCot(luoi, "NGAYSINH", "Ngày sinh", 15);
        DatCot(luoi, "DIACHI", "Địa chỉ", 22);
        DatCot(luoi, "PASSWORD", "Mật khẩu", 15);

        ThayCotLopBangComboBox();
    }

    /// <summary>Đổi cột MALOP thành ô chọn (đề: lớp chỉ để chọn, không nhập).</summary>
    private void ThayCotLopBangComboBox()
    {
        if (!luoi.Columns.Contains("MALOP") || _dsLop.Rows.Count == 0) return;

        var viTri = luoi.Columns["MALOP"]!.DisplayIndex;
        luoi.Columns.Remove("MALOP");

        var cot = new DataGridViewComboBoxColumn
        {
            Name = "MALOP",
            DataPropertyName = "MALOP",
            HeaderText = "Lớp (chọn)",
            DataSource = _dsLop,
            ValueMember = "MALOP",
            DisplayMember = "MALOP",
            FillWeight = 15,
            FlatStyle = FlatStyle.Flat
        };
        luoi.Columns.Add(cot);
        cot.DisplayIndex = viTri;
    }

    /// <summary>
    /// Kiểm tra trước khi ghi - đây là chỗ SỬ DỤNG MẢNH 3:
    /// hỏi mảnh tra cứu xem mã sinh viên đã tồn tại ở cơ sở nào chưa.
    /// </summary>
    protected override bool KiemTraTruocKhiGhi()
    {
        if (!base.KiemTraTruocKhiGhi()) return false;
        if (Bang == null) return false;

        var themMoi = Bang.Data.Select(null, null, DataViewRowState.Added);
        foreach (var dong in themMoi)
        {
            var ma = dong["MASV"]?.ToString()?.Trim() ?? "";
            if (ma.Length == 0)
            {
                BaoTrangThai("Chưa nhập mã sinh viên.", true);
                return false;
            }
            if (dong["MALOP"] == DBNull.Value || dong["MALOP"]?.ToString()?.Trim().Length == 0)
            {
                BaoTrangThai($"Sinh viên {ma}: chưa chọn lớp.", true);
                return false;
            }

            try
            {
                if (DataProvider.MaSinhVienDaTonTai(ma))
                {
                    BaoTrangThai($"Mã sinh viên {ma} ĐÃ TỒN TẠI ở một trong hai cơ sở " +
                                 "(kiểm tra qua mảnh tra cứu). Hãy đổi mã khác.", true);
                    return false;
                }
            }
            catch (SqlException ex)
            {
                // Không tra cứu được thì cảnh báo nhưng vẫn cho ghi, tránh chặn nhập liệu.
                BaoTrangThai("Cảnh báo: không tra cứu được mảnh 3 (" + ex.Message + ")", true);
            }
        }
        return true;
    }

    protected override void KhiThemDong(DataRow dong)
    {
        dong["PASSWORD"] = "123";        // mật khẩu mặc định, sinh viên tự đổi sau
    }
}
