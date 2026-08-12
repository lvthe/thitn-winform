using System.Data;

namespace QuanLyThi;

/// <summary>
/// CÂU 5 - Nhập GIẢNG VIÊN.
/// Đề: "chọn Khoa rồi nhập giảng viên vào khoa đó" - nên có ô chọn Khoa
/// ở trên, lưới chỉ hiện giảng viên của khoa đang chọn, và giảng viên
/// thêm mới tự gắn vào khoa đó.
/// </summary>
public class frmGiaoVien : frmCrudBase
{
    private readonly ComboBox _cboKhoa = new();
    private readonly Label _lbl = new();

    public frmGiaoVien()
    {
        Text = "Câu 5 - Nhập giảng viên";

        _lbl.Text = "Khoa:";
        _lbl.Location = new Point(10, 12);
        _lbl.Size = new Size(50, 23);
        _lbl.TextAlign = ContentAlignment.MiddleLeft;

        _cboKhoa.Location = new Point(62, 9);
        _cboKhoa.Size = new Size(320, 25);
        _cboKhoa.DropDownStyle = ComboBoxStyle.DropDownList;
        _cboKhoa.SelectedIndexChanged += (_, _) => Nap();

        panelLoc.Height = 46;
        panelLoc.Controls.Add(_lbl);
        panelLoc.Controls.Add(_cboKhoa);

        Load += (_, _) => KhoiTao();
    }

    private void KhoiTao()
    {
        try
        {
            var dsKhoa = DataProvider.TruyVan("SELECT MAKH, TENKH FROM dbo.KHOA ORDER BY MAKH");
            _cboKhoa.DataSource = dsKhoa;
            _cboKhoa.DisplayMember = "TENKH";
            _cboKhoa.ValueMember = "MAKH";
        }
        catch (Exception ex) { BaoTrangThai("Không nạp được danh sách khoa: " + ex.Message, true); }

        CauHinh(new BangCrud("GIAOVIEN",
            "SELECT MAGV, HO, TEN, MAKH, HOCVI FROM dbo.GIAOVIEN WHERE MAKH = @makh ORDER BY MAGV"));

        DatCot(luoi, "MAGV", "Mã GV", 15);
        DatCot(luoi, "HO", "Họ", 30);
        DatCot(luoi, "TEN", "Tên", 15);
        DatCot(luoi, "MAKH", "Mã khoa", 15);
        DatCot(luoi, "HOCVI", "Học vị", 25);
    }

    private string MaKhoa() => _cboKhoa.SelectedValue?.ToString()?.Trim() ?? "";

    protected override Microsoft.Data.SqlClient.SqlParameter[] ThamSoNap() =>
    [
        new Microsoft.Data.SqlClient.SqlParameter("@makh", SqlDbType.NChar, 8) { Value = MaKhoa() }
    ];

    /// <summary>Giảng viên thêm mới tự thuộc khoa đang chọn.</summary>
    protected override void KhiThemDong(DataRow dong) => dong["MAKH"] = MaKhoa();

    protected override bool KiemTraTruocKhiGhi()
    {
        if (!base.KiemTraTruocKhiGhi()) return false;
        if (Bang == null) return false;
        foreach (var dong in Bang.Data.Select(null, null, DataViewRowState.Added))
        {
            if ((dong["MAGV"]?.ToString() ?? "").Trim().Length == 0)
            {
                BaoTrangThai("Chưa nhập mã giảng viên.", true);
                return false;
            }
        }
        return true;
    }
}
