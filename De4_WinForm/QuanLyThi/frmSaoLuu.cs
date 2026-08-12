using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// PHẦN QUẢN TRỊ - Sao lưu / phục hồi dữ liệu.
/// Đề: "tạo bản sao lưu trên DB, về sau người dùng có thể phục hồi lại
/// được nếu có sự cố xảy ra".
///
/// Phục hồi được tách riêng và có rào chắn vì CSDL đang tham gia nhân
/// bản: RESTORE sẽ làm hỏng cấu hình replication, phải thiết lập lại.
/// </summary>
public class frmSaoLuu : Form
{
    private readonly TextBox _txtGhiChu = new();
    private readonly Button _btnSaoLuu = new() { Text = "Sao lưu ngay" };
    private readonly Button _btnLenhPhucHoi = new() { Text = "Lấy lệnh phục hồi" };
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly Label _lblCanhBao = new() { Dock = DockStyle.Bottom, Height = 54 };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    public frmSaoLuu()
    {
        Text = "Quản trị - Sao lưu / Phục hồi dữ liệu";
        ClientSize = new Size(900, 520);
        StartPosition = FormStartPosition.CenterParent;

        var top = new Panel { Dock = DockStyle.Top, Height = 48 };
        top.Controls.Add(new Label { Text = "Ghi chú:", Location = new Point(12, 14), Size = new Size(62, 23) });
        _txtGhiChu.Location = new Point(78, 11); _txtGhiChu.Size = new Size(360, 25);
        top.Controls.Add(_txtGhiChu);
        _btnSaoLuu.Location = new Point(452, 10); _btnSaoLuu.Size = new Size(130, 28);
        _btnSaoLuu.Click += (_, _) => SaoLuu();
        top.Controls.Add(_btnSaoLuu);
        _btnLenhPhucHoi.Location = new Point(592, 10); _btnLenhPhucHoi.Size = new Size(150, 28);
        _btnLenhPhucHoi.Click += (_, _) => LayLenhPhucHoi();
        top.Controls.Add(_btnLenhPhucHoi);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);

        _lblCanhBao.ForeColor = Color.Firebrick;
        _lblCanhBao.Padding = new Padding(10, 6, 10, 6);
        _lblCanhBao.Text =
            "Lưu ý: CSDL này đang tham gia nhân bản (merge replication). "
          + "Phục hồi sẽ ghi đè toàn bộ dữ liệu và LÀM HỎNG cấu hình nhân bản — "
          + "sau khi phục hồi phải thiết lập lại publication/subscription. "
          + "Vì vậy nút bên trên chỉ SINH RA câu lệnh để người quản trị tự chạy có ý thức.";

        _tt.Items.Add(_lbl);
        Controls.Add(_luoi);
        Controls.Add(_lblCanhBao);
        Controls.Add(top);
        Controls.Add(_tt);

        // Chỉ Trưởng mới được lấy lệnh phục hồi
        _btnLenhPhucHoi.Enabled = Phien.VaiTro == "Truong";

        Load += (_, _) => Nap();
    }

    private void Nap()
    {
        try
        {
            var dt = DataProvider.GoiSP("dbo.SP_DS_SAOLUU");
            _luoi.DataSource = dt;
            frmCrudBase.DatCot(_luoi, "ID", "#", 5);
            frmCrudBase.DatCot(_luoi, "TENFILE", "Tệp sao lưu", 50);
            frmCrudBase.DatCot(_luoi, "THOIDIEM", "Thời điểm", 16);
            frmCrudBase.DatCot(_luoi, "NGUOITAO", "Người tạo", 14);
            frmCrudBase.DatCot(_luoi, "GHICHU", "Ghi chú", 20);
            _lbl.Text = $"{dt.Rows.Count} bản sao lưu.";
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void SaoLuu()
    {
        Cursor = Cursors.WaitCursor;
        try
        {
            var dt = DataProvider.GoiSP("dbo.SP_SAOLUU",
                new SqlParameter("@ThuMuc", SqlDbType.NVarChar, 300) { Value = DBNull.Value },
                new SqlParameter("@GhiChu", SqlDbType.NVarChar, 200)
                { Value = string.IsNullOrWhiteSpace(_txtGhiChu.Text) ? DBNull.Value : _txtGhiChu.Text });

            var tep = dt.Rows.Count > 0 && dt.Columns.Contains("TenFile")
                    ? dt.Rows[0]["TenFile"]?.ToString() : "";
            MessageBox.Show("Đã sao lưu thành công.\r\n\r\n" + tep, "Sao lưu",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            _txtGhiChu.Clear();
            Nap();
        }
        catch (SqlException ex)
        {
            MessageBox.Show(ex.Message, "Sao lưu thất bại",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally { Cursor = Cursors.Default; }
    }

    private void LayLenhPhucHoi()
    {
        if (_luoi.CurrentRow?.DataBoundItem is not DataRowView r)
        { _lbl.Text = "Chọn một bản sao lưu trong danh sách."; return; }

        var tep = r["TENFILE"]?.ToString() ?? "";
        if (MessageBox.Show(
                $"Sinh câu lệnh phục hồi từ:\r\n{tep}\r\n\r\n" +
                "Lệnh sẽ GHI ĐÈ toàn bộ dữ liệu hiện tại và làm hỏng cấu hình nhân bản.\r\n" +
                "Tiếp tục?", "Xác nhận",
                MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;

        try
        {
            var dt = DataProvider.GoiSP("dbo.SP_PHUCHOI_CSDL",
                new SqlParameter("@TenFile", SqlDbType.NVarChar, 400) { Value = tep },
                new SqlParameter("@XacNhan", SqlDbType.NVarChar, 50) { Value = "TOI DONG Y" });

            if (dt.Rows.Count > 0)
            {
                var lenh = dt.Rows[0]["Lenh"]?.ToString() ?? "";
                Clipboard.SetText(lenh);
                MessageBox.Show(
                    dt.Rows[0]["CanhBao"] + "\r\n\r\n" + lenh +
                    "\r\n\r\n(Đã chép vào clipboard.)",
                    "Câu lệnh phục hồi", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
        catch (SqlException ex)
        {
            MessageBox.Show(ex.Message, "Lỗi", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
