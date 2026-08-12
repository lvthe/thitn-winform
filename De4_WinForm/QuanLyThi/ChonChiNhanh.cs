using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// ComboBox CHỌN CHI NHÁNH cho các form báo cáo.
///
/// Thầy nói đây chính là điểm PHÂN BIỆT đề phân tán với đề tập trung:
///   "đề tài phân tán khác biệt với đề tài tập trung là ở chỗ này:
///    chúng ta phải tạo ra một ComboBox chi nhánh để rẽ server về đó"
///   "đăng nhập vai trò công ty thì được quyền xem số liệu của TẤT CẢ
///    chi nhánh bằng cách chọn chi nhánh tương ứng. Khi chọn chi nhánh
///    thì nó tự động RẼ VỀ SERVER ĐÓ"
///   "nhóm chi nhánh thì chỉ được xem ở một phân mảnh thôi -> cho nó mờ đi"
///
/// Cách dùng:
///     _chiNhanh = new ChonChiNhanh(cboChiNhanh);
///     _chiNhanh.KhiDoiChiNhanh += () => NapLaiBaoCao();
///     _chiNhanh.Nap();
/// </summary>
public class ChonChiNhanh
{
    private readonly ComboBox _cbo;

    /// <summary>Gọi sau khi đã rẽ kết nối sang chi nhánh mới.</summary>
    public event Action? KhiDoiChiNhanh;

    /// <summary>Server của chi nhánh đang chọn (rỗng nếu chọn "tất cả").</summary>
    public string ServerDangChon { get; private set; } = "";

    /// <summary>True khi người dùng chọn mục "Tất cả (gộp 2 cơ sở)".</summary>
    public bool GopTatCa { get; private set; }

    public ChonChiNhanh(ComboBox cbo, bool choPhepGopTatCa = false)
    {
        _cbo = cbo;
        _cbo.DropDownStyle = ComboBoxStyle.DropDownList;   // Thầy: không cho gõ tay
        _choPhepGop = choPhepGopTatCa;
    }

    private readonly bool _choPhepGop;
    private const string MOC_TAT_CA = "(Tất cả — gộp 2 cơ sở)";

    public void Nap()
    {
        var dt = DataProvider.LayDanhSachPhanManh();     // đã bỏ mảnh tra cứu

        // Nhóm Trưởng xem được mọi chi nhánh; nhóm Cơ sở bị khoá vào cơ sở mình.
        if (!Phien.ChiXem)
        {
            for (int i = dt.Rows.Count - 1; i >= 0; i--)
                if (!string.Equals(dt.Rows[i]["TENSERVER"]?.ToString()?.Trim(),
                                   Phien.Server, StringComparison.OrdinalIgnoreCase))
                    dt.Rows.RemoveAt(i);
        }

        if (_choPhepGop && Phien.ChiXem)
        {
            var d = dt.NewRow();
            d["TENCN"] = MOC_TAT_CA;
            d["TENSERVER"] = "";
            dt.Rows.InsertAt(d, 0);
        }

        _cbo.DataSource = dt;
        _cbo.DisplayMember = "TENCN";
        _cbo.ValueMember = "TENSERVER";

        // Đề: nhóm Cơ sở chỉ xem một phân mảnh -> làm mờ combobox
        _cbo.Enabled = Phien.ChiXem && dt.Rows.Count > 1;

        _cbo.SelectedIndexChanged -= Cbo_Changed;
        _cbo.SelectedIndexChanged += Cbo_Changed;
        Cbo_Changed(null, EventArgs.Empty);
    }

    private void Cbo_Changed(object? sender, EventArgs e)
    {
        ServerDangChon = _cbo.SelectedValue?.ToString()?.Trim() ?? "";
        GopTatCa = ServerDangChon.Length == 0;
        KhiDoiChiNhanh?.Invoke();
    }

    /// <summary>
    /// Mở kết nối tới chi nhánh ĐANG CHỌN.
    /// Nếu là chính phân mảnh đang đăng nhập thì dùng tài khoản của phiên;
    /// nếu là chi nhánh khác thì vẫn dùng tài khoản đó (login truong01 được
    /// tạo trên MỌI phân mảnh nên rẽ sang được) - đúng ý Thầy:
    /// "nếu hai cái này khác nhau thì dùng tài khoản hỗ trợ kết nối,
    ///  còn nếu bằng nhau thì dùng tài khoản đăng nhập".
    /// </summary>
    public SqlConnection MoKetNoi()
    {
        var server = ServerDangChon.Length > 0 ? ServerDangChon : Phien.Server;
        var cn = new SqlConnection(
            DataProvider.TaoChuoiKetNoi(server, Phien.Login, Phien.MatKhau));
        cn.Open();
        return cn;
    }

    /// <summary>Tên chi nhánh đang chọn, để in lên tiêu đề báo cáo.</summary>
    public string TenDangChon =>
        (_cbo.SelectedItem as DataRowView)?["TENCN"]?.ToString()?.Trim() ?? Phien.TenPhanManh;
}
