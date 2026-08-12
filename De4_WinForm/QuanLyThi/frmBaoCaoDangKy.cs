using System.Data;

namespace QuanLyThi;

/// <summary>
/// CÂU 11 - Danh sách đăng ký thi trắc nghiệm của CẢ HAI CƠ SỞ.
/// Người dùng nhập TỪ NGÀY - ĐẾN NGÀY (đầu đợt thi đến cuối đợt).
///
/// RÀNG BUỘC CỦA ĐỀ: báo cáo này KHÔNG được lấy dữ liệu từ server chủ.
/// Ứng dụng gọi sp_BaoCao_DangKy trên TỪNG PHÂN MẢNH rồi UNION lại.
/// Ô "Nguồn dữ liệu" bên dưới in rõ đã đọc từ những phân mảnh nào -
/// để chứng minh điều đó khi bảo vệ.
/// </summary>
public class frmBaoCaoDangKy : Form
{
    private readonly DateTimePicker _tuNgay = new() { Format = DateTimePickerFormat.Short };
    private readonly DateTimePicker _denNgay = new() { Format = DateTimePickerFormat.Short };
    private readonly Button _btnXem = new() { Text = "Xem báo cáo" };
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly Label _lblNguon = new() { Dock = DockStyle.Bottom, Height = 46 };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    public frmBaoCaoDangKy()
    {
        Text = "Câu 11 - Đăng ký thi trắc nghiệm (cả hai cơ sở)";
        ClientSize = new Size(1040, 600);
        StartPosition = FormStartPosition.CenterParent;

        var loc = new Panel { Dock = DockStyle.Top, Height = 46 };
        loc.Controls.Add(new Label { Text = "Từ ngày:", Location = new Point(12, 13), Size = new Size(62, 23) });
        _tuNgay.Location = new Point(78, 10); _tuNgay.Size = new Size(120, 25);
        _tuNgay.Value = DateTime.Today.AddMonths(-3);
        loc.Controls.Add(_tuNgay);
        loc.Controls.Add(new Label { Text = "Đến ngày:", Location = new Point(212, 13), Size = new Size(66, 23) });
        _denNgay.Location = new Point(282, 10); _denNgay.Size = new Size(120, 25);
        _denNgay.Value = DateTime.Today.AddMonths(3);
        loc.Controls.Add(_denNgay);
        _btnXem.Location = new Point(418, 9); _btnXem.Size = new Size(120, 28);
        _btnXem.Click += (_, _) => Xem();
        loc.Controls.Add(_btnXem);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);

        _lblNguon.ForeColor = SystemColors.GrayText;
        _lblNguon.Padding = new Padding(8, 4, 8, 4);
        _tt.Items.Add(_lbl);

        Controls.Add(_luoi);
        Controls.Add(_lblNguon);
        Controls.Add(loc);
        Controls.Add(_tt);

        Load += (_, _) => Xem();
    }

    private void Xem()
    {
        Cursor = Cursors.WaitCursor;
        try
        {
            var kq = DataProvider.BaoCaoDangKy_HaiCoSo(_tuNgay.Value, _denNgay.Value);
            _luoi.DataSource = kq.Data;

            frmCrudBase.DatCot(_luoi, "MACS", "Cơ sở", 8);
            frmCrudBase.DatCot(_luoi, "COSO", "Tên cơ sở", 14);
            frmCrudBase.DatCot(_luoi, "TENLOP", "Lớp", 12);
            frmCrudBase.DatCot(_luoi, "TENMH", "Môn học", 16);
            frmCrudBase.DatCot(_luoi, "GIANGVIEN", "Giảng viên đăng ký", 16);
            frmCrudBase.DatCot(_luoi, "TRINHDO", "TĐ", 6);
            frmCrudBase.DatCot(_luoi, "SOCAUTHI", "Số câu", 8);
            frmCrudBase.DatCot(_luoi, "THOIGIAN", "Phút", 7);
            frmCrudBase.DatCot(_luoi, "NGAYTHI", "Ngày thi", 12);
            frmCrudBase.DatCot(_luoi, "LAN", "Lần", 6);
            frmCrudBase.DatCot(_luoi, "DATHI", "Đã thi", 8);
            frmCrudBase.DatCot(_luoi, "GHICHU", "Ghi chú", 16);

            _lblNguon.Text =
                "Nguồn dữ liệu (UNION từ các PHÂN MẢNH, không qua server chủ):\r\n    "
                + string.Join("    |    ", kq.NhatKy);
            _lbl.Text = $"Tổng cộng {kq.Data.Rows.Count} lượt đăng ký.";
        }
        catch (Exception ex)
        {
            _lbl.Text = "Lỗi: " + ex.Message;
        }
        finally { Cursor = Cursors.Default; }
    }
}
