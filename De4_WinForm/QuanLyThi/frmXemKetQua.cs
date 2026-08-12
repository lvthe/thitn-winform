using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 9 - Xem lại bài thi (phục vụ PHÚC KHẢO).
/// Đề: in ra mã SV, họ tên, môn thi, ngày thi, lần thi; và với mỗi câu:
/// số thứ tự, MÃ CÂU HỎI trong bộ đề, nội dung, 4 lựa chọn,
/// ĐÁP ÁN ĐÚNG và CÂU SINH VIÊN ĐÃ CHỌN - để giảng viên giải thích được
/// vì sao sinh viên chỉ được bằng đó điểm.
/// </summary>
public class frmXemKetQua : Form
{
    private readonly ComboBox _cboBai = new();
    private readonly Button _btnXem = new() { Text = "Xem lại bài" };
    private readonly Label _lblDau = new();
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    public frmXemKetQua()
    {
        Text = "Câu 9 - Xem lại bài thi (phúc khảo)";
        ClientSize = new Size(1040, 620);
        StartPosition = FormStartPosition.CenterParent;

        var top = new Panel { Dock = DockStyle.Top, Height = 84 };
        top.Controls.Add(new Label { Text = "Bài thi:", Location = new Point(12, 13), Size = new Size(56, 23) });
        _cboBai.Location = new Point(72, 10); _cboBai.Size = new Size(440, 25);
        _cboBai.DropDownStyle = ComboBoxStyle.DropDownList;
        top.Controls.Add(_cboBai);
        _btnXem.Location = new Point(526, 9); _btnXem.Size = new Size(120, 28);
        _btnXem.Click += (_, _) => Xem();
        top.Controls.Add(_btnXem);

        _lblDau.Location = new Point(12, 46); _lblDau.Size = new Size(1000, 30);
        _lblDau.Font = new Font(Font, FontStyle.Bold);
        top.Controls.Add(_lblDau);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);
        _luoi.RowsDefaultCellStyle.WrapMode = DataGridViewTriState.True;
        _luoi.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCells;
        // Tô màu câu sai để nhìn ra ngay khi phúc khảo
        _luoi.DataBindingComplete += (_, _) => ToMau();

        _tt.Items.Add(_lbl);
        Controls.Add(_luoi);
        Controls.Add(top);
        Controls.Add(_tt);

        Load += (_, _) => NapDanhSachBai();
    }

    private void NapDanhSachBai()
    {
        try
        {
            var dt = DataProvider.TruyVan(@"
                SELECT DISTINCT bd.MAMH, bd.LAN,
                       MOTA = RTRIM(mh.TENMH) + N' - lần ' + CAST(bd.LAN AS nvarchar(2))
                            + N'  (điểm ' + CAST(CAST(bd.DIEM AS decimal(4,1)) AS nvarchar(6)) + N')'
                FROM dbo.BangDiem bd JOIN dbo.Monhoc mh ON bd.MAMH = mh.MAMH
                WHERE bd.MASV = @masv
                ORDER BY bd.MAMH, bd.LAN",
                new SqlParameter("@masv", SqlDbType.Char, 8) { Value = Phien.Ma });

            _cboBai.DataSource = dt;
            _cboBai.DisplayMember = "MOTA";

            if (dt.Rows.Count == 0) _lbl.Text = "Bạn chưa có bài thi nào có điểm.";
            else Xem();
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void Xem()
    {
        if (_cboBai.SelectedItem is not DataRowView r) return;
        try
        {
            var ds = new DataSet();
            using (var cn = DataProvider.MoKetNoi())
            using (var cmd = new SqlCommand("dbo.sp_XemKetQua", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@MASV", SqlDbType.Char, 8).Value = Phien.Ma;
                cmd.Parameters.Add("@MAMH", SqlDbType.Char, 5).Value = r["MAMH"];
                cmd.Parameters.Add("@LAN", SqlDbType.SmallInt).Value = r["LAN"];
                using var da = new SqlDataAdapter(cmd);
                da.Fill(ds);
            }

            if (ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
            {
                var d = ds.Tables[0].Rows[0];
                _lblDau.Text =
                    $"Mã SV: {Phien.Ma}   |   Họ tên: {d["HoTen"]}   |   Lớp: {d["Lop"]}   |   " +
                    $"Môn: {d["MonThi"]}   |   Ngày thi: {Convert.ToDateTime(d["NgayThi"]):dd/MM/yyyy}   |   " +
                    $"Lần {d["LanThi"]}   |   ĐIỂM: {d["Diem"]}";
            }

            if (ds.Tables.Count > 1)
            {
                _luoi.DataSource = ds.Tables[1];
                frmCrudBase.DatCot(_luoi, "STT", "STT", 6);
                frmCrudBase.DatCot(_luoi, "CauSo", "Mã câu", 8);
                frmCrudBase.DatCot(_luoi, "NOIDUNG", "Nội dung câu hỏi", 30);
                frmCrudBase.DatCot(_luoi, "A", "A", 12);
                frmCrudBase.DatCot(_luoi, "B", "B", 12);
                frmCrudBase.DatCot(_luoi, "C", "C", 12);
                frmCrudBase.DatCot(_luoi, "D", "D", 12);
                frmCrudBase.DatCot(_luoi, "DapAn", "Đáp án đúng", 9);
                frmCrudBase.DatCot(_luoi, "DaChon", "Đã chọn", 8);
                frmCrudBase.DatCot(_luoi, "KetQua", "Kết quả", 9);

                var dung = ds.Tables[1].Select("KetQua = N'Đúng'").Length;
                _lbl.Text = $"{ds.Tables[1].Rows.Count} câu - đúng {dung} câu.";
            }
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void ToMau()
    {
        if (!_luoi.Columns.Contains("KetQua")) return;
        foreach (DataGridViewRow row in _luoi.Rows)
        {
            var kq = row.Cells["KetQua"].Value?.ToString();
            row.DefaultCellStyle.BackColor = kq switch
            {
                "Đúng" => Color.FromArgb(232, 245, 233),
                "Sai" => Color.FromArgb(253, 236, 234),
                _ => Color.FromArgb(245, 245, 245)
            };
        }
    }
}
