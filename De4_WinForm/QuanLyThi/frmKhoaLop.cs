using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 3 - KHOA và LỚP trên CÙNG MỘT FORM.
/// Đề (nguyên văn): "cho phép luôn là nhập Khoa và nhập Lớp cùng một lúc,
/// trên một cái form". Bố cục master - detail: chọn Khoa ở lưới trên,
/// lưới dưới hiện các Lớp thuộc khoa đó.
/// </summary>
public class frmKhoaLop : Form
{
    private readonly SplitContainer _chia = new() { Dock = DockStyle.Fill, Orientation = Orientation.Horizontal };
    private readonly DataGridView _luoiKhoa = new() { Dock = DockStyle.Fill };
    private readonly DataGridView _luoiLop = new() { Dock = DockStyle.Fill };
    private readonly BindingSource _bsKhoa = new(), _bsLop = new();
    private readonly BangCrud _khoa = new("KHOA", "SELECT MAKH, TENKH, MACS FROM dbo.KHOA ORDER BY MAKH");
    private readonly BangCrud _lop = new("LOP", "SELECT MALOP, TENLOP, MAKH FROM dbo.LOP ORDER BY MALOP");

    private readonly ToolStrip _nut = new();
    private readonly ToolStripButton _btnThemKhoa = new("Thêm khoa");
    private readonly ToolStripButton _btnThemLop = new("Thêm lớp");
    private readonly ToolStripButton _btnXoa = new("Xóa");
    private readonly ToolStripButton _btnGhi = new("Ghi");
    private readonly ToolStripButton _btnPhucHoi = new("Phục hồi");
    private readonly ToolStripButton _btnNapLai = new("Nạp lại");
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    public frmKhoaLop()
    {
        Text = "Câu 3 - Nhập Khoa và Lớp (chung một form)";
        ClientSize = new Size(900, 560);
        StartPosition = FormStartPosition.CenterParent;

        _btnThemKhoa.Text = "➕  Thêm khoa";
        _btnThemLop.Text = "➕  Thêm lớp";
        _btnXoa.Text = "🗑  Xóa";
        _btnGhi.Text = "💾  Ghi";
        _btnPhucHoi.Text = "↩  Phục hồi";
        _btnNapLai.Text = "🔄  Nạp lại";
        _btnGhi.ForeColor = GiaoDien.XanhOK;
        _btnXoa.ForeColor = GiaoDien.DoCanhBao;

        _nut.Items.AddRange(new ToolStripItem[]
        {
            _btnThemKhoa, _btnThemLop, _btnXoa, new ToolStripSeparator(),
            _btnGhi, _btnPhucHoi, new ToolStripSeparator(), _btnNapLai
        });
        GiaoDien.TrangTriThanhNut(_nut);       // nút tự co giãn theo DPI
        _tt.Items.Add(_lbl);

        foreach (var g in new[] { _luoiKhoa, _luoiLop })
        {
            g.AllowUserToAddRows = false;
            g.AllowUserToDeleteRows = false;
            g.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
            GiaoDien.TrangTriLuoi(g);
        }

        var boxKhoa = new GroupBox { Text = "KHOA", Dock = DockStyle.Fill, Padding = new Padding(6) };
        boxKhoa.Controls.Add(_luoiKhoa);
        var boxLop = new GroupBox { Text = "LỚP thuộc khoa đang chọn", Dock = DockStyle.Fill, Padding = new Padding(6) };
        boxLop.Controls.Add(_luoiLop);

        _chia.Panel1.Controls.Add(boxKhoa);
        _chia.Panel2.Controls.Add(boxLop);

        Controls.Add(_chia);
        Controls.Add(_nut);
        Controls.Add(_tt);

        _btnThemKhoa.Click += (_, _) => ThemKhoa();
        _btnThemLop.Click += (_, _) => ThemLop();
        _btnXoa.Click += (_, _) => Xoa();
        _btnGhi.Click += (_, _) => Ghi();
        _btnPhucHoi.Click += (_, _) => PhucHoi();
        _btnNapLai.Click += (_, _) => Nap();

        // Nhóm Trưởng: chỉ xem (đề). SQL Server cũng chỉ GRANT SELECT cho role này.
        if (Phien.ChiXem)
        {
            foreach (var b in new[] { _btnThemKhoa, _btnThemLop, _btnXoa, _btnGhi, _btnPhucHoi })
                b.Enabled = false;
            _luoiKhoa.ReadOnly = _luoiLop.ReadOnly = true;
            Controls.Add(new Label
            {
                Dock = DockStyle.Top,
                Height = LogicalToDeviceUnits(30),
                TextAlign = ContentAlignment.MiddleLeft,
                Padding = new Padding(LogicalToDeviceUnits(10), 0, 0, 0),
                BackColor = Color.FromArgb(255, 244, 214),
                ForeColor = Color.FromArgb(124, 84, 0),
                Font = GiaoDien.ChuDam,
                Text = "🔒  Chế độ CHỈ XEM — nhóm Trưởng không được thêm / sửa / xóa dữ liệu."
            });
            Text += " — chỉ xem";
        }

        Load += (_, _) => { Nap(); _chia.SplitterDistance = 230; };
    }

    private void Nap()
    {
        try
        {
            _khoa.Nap();
            _lop.Nap();

            _bsKhoa.DataSource = _khoa.Data;
            _luoiKhoa.DataSource = _bsKhoa;

            // Lọc lớp theo khoa đang chọn (master-detail thủ công vì 2 bảng nạp rời).
            _bsLop.DataSource = _lop.Data;
            _luoiLop.DataSource = _bsLop;
            _bsKhoa.PositionChanged -= LocLop;
            _bsKhoa.PositionChanged += LocLop;
            LocLop(null, EventArgs.Empty);

            DatTieuDeCot();
            Bao($"Khoa: {_khoa.Data.Rows.Count} - Lớp: {_lop.Data.Rows.Count}", false);
        }
        catch (Exception ex) { Bao(ex.Message, true); }
    }

    private void DatTieuDeCot()
    {
        frmCrudBase.DatCot(_luoiKhoa, "MAKH", "Mã khoa", 25);
        frmCrudBase.DatCot(_luoiKhoa, "TENKH", "Tên khoa", 55);
        frmCrudBase.DatCot(_luoiKhoa, "MACS", "Cơ sở", 20);
        frmCrudBase.DatCot(_luoiLop, "MALOP", "Mã lớp", 25);
        frmCrudBase.DatCot(_luoiLop, "TENLOP", "Tên lớp", 55);
        frmCrudBase.DatCot(_luoiLop, "MAKH", "Mã khoa", 20);
    }

    private string? MaKhoaDangChon() =>
        (_bsKhoa.Current as DataRowView)?["MAKH"]?.ToString()?.Trim();

    private void LocLop(object? s, EventArgs e)
    {
        var mk = MaKhoaDangChon();
        _bsLop.Filter = string.IsNullOrEmpty(mk) ? null : $"MAKH = '{mk.Replace("'", "''")}'";
    }

    private void ThemKhoa()
    {
        try
        {
            var d = BangCrud.TaoDongMoi(_khoa.Data);   // điền sẵn cột NOT NULL
            // Khoa mới luôn thuộc chính cơ sở đang đăng nhập (phân mảnh theo MACS).
            d["MACS"] = LayMaCoSo();
            _khoa.Data.Rows.Add(d);
            _bsKhoa.Position = _bsKhoa.Count - 1;
            Bao("Đang thêm khoa - nhập mã, tên rồi bấm Ghi.", false);
        }
        catch (Exception ex) { Bao("Không thêm được khoa: " + ex.Message, true); }
    }

    private void ThemLop()
    {
        var mk = MaKhoaDangChon();
        if (string.IsNullOrEmpty(mk)) { Bao("Chọn một khoa trước khi thêm lớp.", true); return; }
        try
        {
            var d = BangCrud.TaoDongMoi(_lop.Data);
            d["MAKH"] = mk;                       // lớp gắn vào khoa đang chọn
            _lop.Data.Rows.Add(d);
            _bsLop.Position = _bsLop.Count - 1;
            Bao($"Đang thêm lớp cho khoa {mk} - nhập xong bấm Ghi.", false);
        }
        catch (Exception ex) { Bao("Không thêm được lớp: " + ex.Message, true); }
    }

    /// <summary>Mã cơ sở của phân mảnh đang đăng nhập (lấy từ bảng COSO của chính mảnh đó).</summary>
    private string LayMaCoSo()
    {
        try
        {
            using var cn = DataProvider.MoKetNoi();
            using var cmd = new SqlCommand("SELECT TOP 1 MACS FROM dbo.COSO", cn);
            return cmd.ExecuteScalar()?.ToString()?.Trim() ?? "";
        }
        catch { return ""; }
    }

    private void Xoa()
    {
        var luoiDangChon = _luoiLop.Focused ? _luoiLop : _luoiKhoa;
        var bs = ReferenceEquals(luoiDangChon, _luoiLop) ? _bsLop : _bsKhoa;
        if (bs.Current is not DataRowView drv) return;

        var ten = ReferenceEquals(bs, _bsLop) ? "lớp" : "khoa";
        if (MessageBox.Show($"Xóa {ten} đang chọn?", "Xác nhận",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        drv.Row.Delete();
        Bao($"Đã đánh dấu xóa {ten} - bấm Ghi để lưu.", false);
    }

    private void Ghi()
    {
        try
        {
            _bsKhoa.EndEdit(); _bsLop.EndEdit();
            // Ghi KHOA trước vì LỚP tham chiếu tới khoa.
            var n = _khoa.Ghi() + _lop.Ghi();
            Bao($"Đã ghi {n} dòng.", false);
        }
        catch (SqlException ex) { Bao("Không ghi được: " + ex.Message, true); }
    }

    private void PhucHoi()
    {
        _bsKhoa.CancelEdit(); _bsLop.CancelEdit();
        _khoa.PhucHoi(); _lop.PhucHoi();
        Bao("Đã phục hồi - hủy mọi thay đổi chưa ghi.", false);
    }

    private void Bao(string s, bool loi)
    {
        _lbl.ForeColor = loi ? Color.Firebrick : SystemColors.ControlText;
        _lbl.Text = s;
    }
}
