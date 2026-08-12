namespace QuanLyThi;

/// <summary>
/// Định dạng giao diện dùng chung cho toàn ứng dụng: bảng màu, phông chữ,
/// và cách trang trí lưới dữ liệu. Gom về một chỗ để mọi màn hình trông
/// đồng nhất và sửa một lần là đổi hết.
/// </summary>
public static class GiaoDien
{
    /* --- Bảng màu --- */
    public static readonly Color XanhChinh = Color.FromArgb(30, 64, 124);
    public static readonly Color XanhNhat = Color.FromArgb(238, 243, 250);
    public static readonly Color XamVien = Color.FromArgb(214, 220, 229);
    public static readonly Color DoCanhBao = Color.FromArgb(153, 27, 27);
    public static readonly Color XanhOK = Color.FromArgb(21, 101, 52);

    public static readonly Font ChuThuong = new("Segoe UI", 9.75F);
    public static readonly Font ChuDam = new("Segoe UI", 9.75F, FontStyle.Bold);
    public static readonly Font ChuTieuDe = new("Segoe UI", 12F, FontStyle.Bold);

    /// <summary>
    /// Trang trí một lưới dữ liệu cho dễ đọc.
    /// LƯU Ý: mọi kích thước đều đi qua LogicalToDeviceUnits() để tự nhân
    /// theo mức phóng DPI của màn hình. Đặt số pixel cứng sẽ làm chữ bị
    /// cắt mất phần dưới trên máy chạy 125% / 150% / 175%.
    /// </summary>
    public static void TrangTriLuoi(DataGridView g, bool chiDoc = false)
    {
        g.BorderStyle = BorderStyle.None;
        g.BackgroundColor = Color.White;
        g.GridColor = XamVien;
        g.EnableHeadersVisualStyles = false;
        g.RowHeadersVisible = false;
        g.Font = ChuThuong;

        g.ColumnHeadersDefaultCellStyle.BackColor = XanhChinh;
        g.ColumnHeadersDefaultCellStyle.ForeColor = Color.White;
        g.ColumnHeadersDefaultCellStyle.Font = ChuDam;
        g.ColumnHeadersDefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleLeft;
        g.ColumnHeadersDefaultCellStyle.Padding = new Padding(g.LogicalToDeviceUnits(6), 0, g.LogicalToDeviceUnits(6), 0);
        // Để tiêu đề tự cao theo cỡ chữ thay vì ép một con số cố định
        g.ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.AutoSize;

        var dem = g.LogicalToDeviceUnits(6);
        g.DefaultCellStyle.Padding = new Padding(dem, g.LogicalToDeviceUnits(4), dem, g.LogicalToDeviceUnits(4));
        g.DefaultCellStyle.SelectionBackColor = Color.FromArgb(198, 219, 245);
        g.DefaultCellStyle.SelectionForeColor = Color.Black;
        g.AlternatingRowsDefaultCellStyle.BackColor = XanhNhat;
        g.RowTemplate.Height = g.LogicalToDeviceUnits(30);
        g.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.DisplayedCells;   // dòng tự vừa nội dung

        g.CellBorderStyle = DataGridViewCellBorderStyle.SingleHorizontal;
        if (chiDoc) g.ReadOnly = true;
    }

    /// <summary>
    /// Trang trí thanh nút: để nút TỰ CO GIÃN theo chữ (AutoSize) thay vì
    /// ép chiều rộng cố định - đây chính là nguyên nhân chữ bị cắt khi
    /// màn hình phóng to.
    /// </summary>
    public static void TrangTriThanhNut(ToolStrip ts)
    {
        ts.Font = ChuThuong;
        ts.AutoSize = true;
        ts.GripStyle = ToolStripGripStyle.Hidden;
        ts.RenderMode = ToolStripRenderMode.System;
        ts.ImageScalingSize = new Size(ts.LogicalToDeviceUnits(16), ts.LogicalToDeviceUnits(16));
        ts.Padding = new Padding(ts.LogicalToDeviceUnits(4), ts.LogicalToDeviceUnits(4),
                                 ts.LogicalToDeviceUnits(4), ts.LogicalToDeviceUnits(4));

        foreach (ToolStripItem it in ts.Items)
        {
            if (it is ToolStripSeparator) continue;
            it.AutoSize = true;                    // <-- mấu chốt
            it.DisplayStyle = ToolStripItemDisplayStyle.Text;
            it.Margin = new Padding(ts.LogicalToDeviceUnits(2), ts.LogicalToDeviceUnits(1),
                                    ts.LogicalToDeviceUnits(2), ts.LogicalToDeviceUnits(1));
            it.Padding = new Padding(ts.LogicalToDeviceUnits(10), ts.LogicalToDeviceUnits(5),
                                     ts.LogicalToDeviceUnits(10), ts.LogicalToDeviceUnits(5));
        }
    }

    /// <summary>Nút nhấn kiểu phẳng, có màu nhấn.</summary>
    public static void TrangTriNut(Button b, bool nhanManh = false)
    {
        b.FlatStyle = FlatStyle.Flat;
        b.Font = nhanManh ? ChuDam : ChuThuong;
        b.FlatAppearance.BorderColor = nhanManh ? XanhChinh : XamVien;
        b.BackColor = nhanManh ? XanhChinh : Color.White;
        b.ForeColor = nhanManh ? Color.White : Color.FromArgb(40, 40, 40);
        b.Cursor = Cursors.Hand;
        b.Height = Math.Max(b.Height, 30);
    }

    /// <summary>Dải tiêu đề màu ở đầu form.</summary>
    public static Panel TaoDaiTieuDe(string tieuDe, string moTa = "")
    {
        var p = new Panel { Dock = DockStyle.Top, Height = moTa.Length > 0 ? 58 : 42, BackColor = XanhChinh };
        p.Controls.Add(new Label
        {
            Text = tieuDe,
            ForeColor = Color.White,
            Font = ChuTieuDe,
            Location = new Point(14, 8),
            AutoSize = true
        });
        if (moTa.Length > 0)
            p.Controls.Add(new Label
            {
                Text = moTa,
                ForeColor = Color.FromArgb(200, 215, 240),
                Font = ChuThuong,
                Location = new Point(16, 33),
                AutoSize = true
            });
        return p;
    }

    /// <summary>Áp định dạng cho mọi lưới và nút bên trong một form.</summary>
    public static void ApDungCho(Control goc)
    {
        foreach (Control c in goc.Controls)
        {
            switch (c)
            {
                case DataGridView g: TrangTriLuoi(g); break;
                case Button b: TrangTriNut(b); break;
                default:
                    if (c.HasChildren) ApDungCho(c);
                    break;
            }
        }
    }
}
