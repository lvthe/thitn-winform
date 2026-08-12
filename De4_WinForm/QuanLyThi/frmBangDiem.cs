using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 10 - Bảng điểm môn học của một lớp.
/// Đề: giảng viên chọn LỚP + MÔN HỌC + LẦN THI (đúng khóa chính của bảng
/// đăng ký) -> in bảng điểm thi hết môn.
/// Điểm được LÀM TRÒN ĐẾN 0.5 theo mẫu của trường (xử lý trong SP),
/// kèm điểm chữ tương ứng.
/// </summary>
public class frmBangDiem : Form
{
    private readonly ComboBox _cboDangKy = new();
    private readonly Button _btnXem = new() { Text = "Xem bảng điểm" };
    private readonly Button _btnIn = new() { Text = "In" };
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();
    private DataTable _dsDangKy = new();

    public frmBangDiem()
    {
        Text = "Câu 10 - Bảng điểm môn học";
        ClientSize = new Size(900, 560);
        StartPosition = FormStartPosition.CenterParent;

        var loc = new Panel { Dock = DockStyle.Top, Height = 46 };
        loc.Controls.Add(new Label
        { Text = "Lớp / Môn / Lần thi:", Location = new Point(12, 13), Size = new Size(130, 23) });
        _cboDangKy.Location = new Point(146, 10);
        _cboDangKy.Size = new Size(430, 25);
        _cboDangKy.DropDownStyle = ComboBoxStyle.DropDownList;
        loc.Controls.Add(_cboDangKy);
        _btnXem.Location = new Point(590, 9); _btnXem.Size = new Size(120, 28);
        _btnXem.Click += (_, _) => Xem();
        loc.Controls.Add(_btnXem);
        _btnIn.Location = new Point(718, 9); _btnIn.Size = new Size(70, 28);
        _btnIn.Click += (_, _) => InRaFile();
        loc.Controls.Add(_btnIn);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);
        _tt.Items.Add(_lbl);

        Controls.Add(_luoi);
        Controls.Add(loc);
        Controls.Add(_tt);

        Load += (_, _) => NapDanhSachDangKy();
    }

    /// <summary>
    /// Chỉ hiện những kỳ thi ĐÃ ĐĂNG KÝ - không bắt người dùng tự gõ
    /// lớp/môn/lần rồi mới báo lỗi (nguyên tắc Thầy nhấn mạnh:
    /// "cái gì biết là vô lý thì đừng cho người ta chọn").
    /// </summary>
    private void NapDanhSachDangKy()
    {
        try
        {
            _dsDangKy = DataProvider.TruyVan(@"
                SELECT dk.MALOP, dk.MAMH, dk.LAN,
                       MOTA = RTRIM(l.TENLOP) + N' - ' + RTRIM(mh.TENMH)
                            + N' - lần ' + CAST(dk.LAN AS nvarchar(2))
                            + N' (' + CONVERT(nvarchar(10), dk.NGAYTHI, 103) + N')'
                FROM dbo.Giaovien_Dangky dk
                  JOIN dbo.Lop    l  ON dk.MALOP = l.MALOP
                  JOIN dbo.Monhoc mh ON dk.MAMH  = mh.MAMH
                ORDER BY dk.NGAYTHI DESC");

            _cboDangKy.DataSource = _dsDangKy;
            _cboDangKy.DisplayMember = "MOTA";

            if (_dsDangKy.Rows.Count == 0)
                _lbl.Text = "Chưa có kỳ thi nào được đăng ký tại cơ sở này.";
            else
                Xem();
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void Xem()
    {
        if (_cboDangKy.SelectedItem is not DataRowView r) return;
        try
        {
            var dt = DataProvider.GoiSP("dbo.sp_BangDiemMonHoc",
                new SqlParameter("@MALOP", SqlDbType.NChar, 15) { Value = r["MALOP"] },
                new SqlParameter("@MAMH", SqlDbType.Char, 5) { Value = r["MAMH"] },
                new SqlParameter("@LAN", SqlDbType.SmallInt) { Value = r["LAN"] });

            _luoi.DataSource = dt;
            frmCrudBase.DatCot(_luoi, "TENLOP", "Lớp", 14);
            frmCrudBase.DatCot(_luoi, "TENMH", "Môn học", 18);
            frmCrudBase.DatCot(_luoi, "LAN", "Lần", 6);
            frmCrudBase.DatCot(_luoi, "MASV", "Mã SV", 10);
            frmCrudBase.DatCot(_luoi, "HOTEN", "Họ tên", 22);
            frmCrudBase.DatCot(_luoi, "DIEM", "Điểm", 8);
            frmCrudBase.DatCot(_luoi, "DIEMCHU", "Điểm chữ", 10);
            frmCrudBase.DatCot(_luoi, "NGAYTHI", "Ngày thi", 12);

            _lbl.Text = $"{dt.Rows.Count} sinh viên. Điểm đã làm tròn đến 0.5 theo mẫu của trường.";
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    /// <summary>Xuất bảng điểm ra file văn bản để in.</summary>
    private void InRaFile()
    {
        if (_luoi.DataSource is not DataTable dt || dt.Rows.Count == 0)
        { _lbl.Text = "Chưa có dữ liệu để in."; return; }

        using var hop = new SaveFileDialog
        {
            Filter = "Tệp CSV (*.csv)|*.csv",
            FileName = "BangDiem.csv"
        };
        if (hop.ShowDialog(this) != DialogResult.OK) return;

        var sb = new System.Text.StringBuilder();
        sb.AppendLine(string.Join(",", dt.Columns.Cast<DataColumn>().Select(c => c.ColumnName)));
        foreach (DataRow row in dt.Rows)
            sb.AppendLine(string.Join(",", row.ItemArray.Select(v => $"\"{v}\"")));

        File.WriteAllText(hop.FileName, sb.ToString(), System.Text.Encoding.UTF8);
        _lbl.Text = "Đã xuất: " + hop.FileName;
    }
}
