using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 6 - Soạn BỘ ĐỀ (ngân hàng câu hỏi).
/// Đề: giảng viên đăng nhập thì TỰ ĐỘNG chỉ thấy câu hỏi do chính mình
/// soạn, và chỉ được sửa / xóa câu của mình. Ràng buộc này được ép ở
/// TẦNG CSDL (các SP dùng SUSER_SNAME()), nên không thể lách từ ứng dụng.
/// Mã câu hỏi do sp_Bode_Them tự cấp theo dải riêng của từng cơ sở.
/// </summary>
public class frmBoDe : Form
{
    private readonly ComboBox _cboMon = new();
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly BindingSource _bs = new();

    // Panel soạn thảo
    private readonly TextBox _txtNoiDung = new() { Multiline = true, ScrollBars = ScrollBars.Vertical };
    private readonly TextBox _txtA = new(), _txtB = new(), _txtC = new(), _txtD = new();
    private readonly ComboBox _cboTrinhDo = new(), _cboDapAn = new();
    private readonly Label _lblCauHoi = new();

    private readonly ToolStrip _nut = new();
    private readonly ToolStripButton _btnThem = new("Thêm");
    private readonly ToolStripButton _btnSua = new("Sửa");
    private readonly ToolStripButton _btnXoa = new("Xóa");
    private readonly ToolStripButton _btnPhucHoi = new("Phục hồi");
    private readonly ToolStripButton _btnNapLai = new("Nạp lại");
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();
    private readonly Button _btnGhiCau = new() { Text = "Ghi câu hỏi", Dock = DockStyle.Fill };

    private bool _dangThem;

    public frmBoDe()
    {
        Text = "Câu 6 - Soạn bộ đề";
        ClientSize = new Size(1000, 620);
        StartPosition = FormStartPosition.CenterParent;
        DungGiaoDien();

        _btnThem.Click += (_, _) => BatDauThem();
        _btnSua.Click += (_, _) => Ghi(sua: true);
        _btnXoa.Click += (_, _) => Xoa();
        _btnPhucHoi.Click += (_, _) => { _dangThem = false; HienChiTiet(); Bao("Đã phục hồi.", false); };
        _btnNapLai.Click += (_, _) => NapMonHoc();
        _cboMon.SelectedIndexChanged += MonThayDoi;
        _bs.PositionChanged += (_, _) => { if (!_dangThem) HienChiTiet(); };

        // Nhóm Trưởng: chỉ xem đề thi, không soạn / sửa / xóa (đề).
        if (Phien.ChiXem)
        {
            foreach (var b in new[] { _btnThem, _btnSua, _btnXoa, _btnPhucHoi })
                b.Enabled = false;
            foreach (var t in new[] { _txtNoiDung, _txtA, _txtB, _txtC, _txtD })
                t.ReadOnly = true;                 // vẫn đọc được nội dung, chỉ không sửa
            _cboTrinhDo.Enabled = _cboDapAn.Enabled = false;
            _btnGhiCau.Enabled = false;
            Text += " — chỉ xem";
        }

        Load += (_, _) => KhoiTao();
    }

    private void DungGiaoDien()
    {
        _btnThem.Text = "➕  Thêm";
        _btnSua.Text = "✏  Sửa";
        _btnXoa.Text = "🗑  Xóa";
        _btnPhucHoi.Text = "↩  Phục hồi";
        _btnNapLai.Text = "🔄  Nạp lại";
        _btnXoa.ForeColor = GiaoDien.DoCanhBao;
        _nut.Items.AddRange(new ToolStripItem[]
        { _btnThem, _btnSua, _btnXoa, new ToolStripSeparator(), _btnPhucHoi, _btnNapLai });
        GiaoDien.TrangTriThanhNut(_nut);       // nút tự co giãn theo DPI
        _tt.Items.Add(_lbl);

        var loc = new Panel { Dock = DockStyle.Top, Height = 42 };
        loc.Controls.Add(new Label { Text = "Môn học:", Location = new Point(10, 12), Size = new Size(70, 23) });
        _cboMon.Location = new Point(84, 9); _cboMon.Size = new Size(300, 25);
        _cboMon.DropDownStyle = ComboBoxStyle.DropDownList;
        loc.Controls.Add(_cboMon);
        loc.Controls.Add(_lblCauHoi);
        _lblCauHoi.Location = new Point(400, 12);
        _lblCauHoi.AutoSize = true;                 // không cắt chữ khi màn hình phóng to
        _lblCauHoi.ForeColor = SystemColors.GrayText;

        _luoi.AllowUserToAddRows = false;
        _luoi.AllowUserToDeleteRows = false;
        _luoi.ReadOnly = true;
        _luoi.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);

        // Panel soạn thảo bên dưới
        var soan = new TableLayoutPanel
        {
            Dock = DockStyle.Bottom,
            Height = 250,
            ColumnCount = 4,
            Padding = new Padding(8)
        };
        soan.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 90));
        soan.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 60));
        soan.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 90));
        soan.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40));

        _txtNoiDung.Dock = DockStyle.Fill;
        foreach (var t in new[] { _txtA, _txtB, _txtC, _txtD }) t.Dock = DockStyle.Fill;
        _cboTrinhDo.DropDownStyle = ComboBoxStyle.DropDownList;
        _cboTrinhDo.Items.AddRange(new object[] { "A", "B", "C" });
        _cboDapAn.DropDownStyle = ComboBoxStyle.DropDownList;
        _cboDapAn.Items.AddRange(new object[] { "A", "B", "C", "D" });

        soan.Controls.Add(new Label { Text = "Nội dung:", Dock = DockStyle.Fill }, 0, 0);
        soan.Controls.Add(_txtNoiDung, 1, 0);
        soan.SetRowSpan(_txtNoiDung, 2);
        soan.Controls.Add(new Label { Text = "Trình độ:", Dock = DockStyle.Fill }, 2, 0);
        soan.Controls.Add(_cboTrinhDo, 3, 0);
        soan.Controls.Add(new Label { Text = "Đáp án đúng:", Dock = DockStyle.Fill }, 2, 1);
        soan.Controls.Add(_cboDapAn, 3, 1);

        soan.Controls.Add(new Label { Text = "A.", Dock = DockStyle.Fill }, 0, 2);
        soan.Controls.Add(_txtA, 1, 2);
        soan.Controls.Add(new Label { Text = "B.", Dock = DockStyle.Fill }, 2, 2);
        soan.Controls.Add(_txtB, 3, 2);
        soan.Controls.Add(new Label { Text = "C.", Dock = DockStyle.Fill }, 0, 3);
        soan.Controls.Add(_txtC, 1, 3);
        soan.Controls.Add(new Label { Text = "D.", Dock = DockStyle.Fill }, 2, 3);
        soan.Controls.Add(_txtD, 3, 3);

        _btnGhiCau.Height = LogicalToDeviceUnits(34);
        _btnGhiCau.Click += (_, _) => Ghi(sua: !_dangThem);
        soan.Controls.Add(_btnGhiCau, 3, 4);

        Controls.Add(_luoi);
        Controls.Add(soan);
        Controls.Add(loc);
        Controls.Add(_nut);
        Controls.Add(_tt);
    }

    private void KhoiTao()
    {
        _lblCauHoi.Text = Phien.VaiTro switch
        {
            "Giangvien" => $"Chỉ hiện câu hỏi do {Phien.Ma} soạn (ràng buộc ở tầng CSDL).",
            "Truong"    => "Nhóm Trưởng: xem toàn bộ câu hỏi của phân mảnh, không sửa.",
            _           => "Nhóm Cơ sở: xem được toàn bộ câu hỏi của phân mảnh."
        };
        NapMonHoc();
    }

    /// <summary>
    /// Đổ ô chọn môn học. Với GIẢNG VIÊN, sp_DS_MonHoc_SoanDe chỉ trả về môn
    /// người đó DẠY - lấy từ GIAOVIEN_DANGKY (bảng duy nhất trong schema ghi
    /// cặp giáo viên–môn học), cộng thêm môn giảng viên ĐÃ CÓ đề trong BODE.
    /// Việc phân công là của nhóm CoSo, nên thủ tục KHÔNG có tham số nào để
    /// ứng dụng nới danh sách ra - giảng viên không tự mở rộng được.
    /// Cơ sở / Trưởng vẫn thấy đủ môn của phân mảnh.
    /// </summary>
    private void NapMonHoc()
    {
        try
        {
            var mon = DataProvider.GoiSP("dbo.sp_DS_MonHoc_SoanDe");

            // Gán DataSource TRƯỚC rồi mới đặt Display/ValueMember, và tháo
            // handler trong lúc gán - nếu không, SelectedIndexChanged nổ giữa
            // chừng lúc ValueMember chưa có, gọi Nap() với mã môn rỗng.
            _cboMon.SelectedIndexChanged -= MonThayDoi;
            _cboMon.DataSource = mon;
            _cboMon.DisplayMember = "TENMH";
            _cboMon.ValueMember = "MAMH";
            _cboMon.SelectedIndexChanged += MonThayDoi;

            if (mon.Rows.Count == 0)
            {
                Bao(Phien.VaiTro == "Giangvien"
                        ? $"Giảng viên {Phien.Ma} chưa được phân công dạy môn nào tại phân mảnh này. "
                          + "Liên hệ Cơ sở để được phân công trước khi soạn đề."
                        : "Phân mảnh này chưa có môn học nào.",
                    true);
                _luoi.DataSource = null;
                XoaTrangPanel();
                return;
            }
        }
        catch (Exception ex)
        {
            // Ô chọn môn học trống là triệu chứng, không phải nguyên nhân. Hay gặp
            // nhất là mất quyền sau khi nhân bản tạo lại bảng / thủ tục
            // -> phải nói thẳng ra, đừng chỉ ghi lặng lẽ ở thanh trạng thái.
            Bao("Không nạp được môn học: " + ex.Message, true);
            MessageBox.Show(
                "Không đọc được danh mục môn học nên không soạn được đề.\r\n\r\n" +
                ex.Message +
                "\r\n\r\nNếu là lỗi quyền: chạy lại SQL\\12_CapLaiQuyen.sql trên phân mảnh này " +
                "(nhân bản tạo lại bảng và thủ tục thì mọi quyền trên đó bị mất).",
                "Câu 6 - Soạn bộ đề", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        Nap();
    }

    private void MonThayDoi(object? sender, EventArgs e) => Nap();

    private string MaMon() => _cboMon.SelectedValue?.ToString()?.Trim() ?? "";

    private void Nap()
    {
        try
        {
            var dt = DataProvider.GoiSP("dbo.sp_Bode_DS",
                new SqlParameter("@MAMH", SqlDbType.Char, 5) { Value = MaMon() });
            _bs.DataSource = dt;
            _luoi.DataSource = _bs;

            foreach (var c in new[] { "a", "b", "c", "d" })
                if (_luoi.Columns.Contains(c)) _luoi.Columns[c]!.Visible = false;
            frmCrudBase.DatCot(_luoi, "cauhoi", "Mã câu", 14);
            frmCrudBase.DatCot(_luoi, "mamh", "Môn", 12);
            frmCrudBase.DatCot(_luoi, "trinhdo", "Trình độ", 12);
            frmCrudBase.DatCot(_luoi, "noidung", "Nội dung", 46);
            frmCrudBase.DatCot(_luoi, "dap_an", "Đáp án", 10);
            frmCrudBase.DatCot(_luoi, "magv", "GV soạn", 14);

            _dangThem = false;
            HienChiTiet();
            Bao($"{dt.Rows.Count} câu hỏi.", false);
        }
        catch (SqlException ex) { Bao(ex.Message, true); }
    }

    private void HienChiTiet()
    {
        if (_bs.Current is not DataRowView r) { XoaTrangPanel(); return; }
        _txtNoiDung.Text = r["noidung"]?.ToString() ?? "";
        _txtA.Text = r["a"]?.ToString() ?? "";
        _txtB.Text = r["b"]?.ToString() ?? "";
        _txtC.Text = r["c"]?.ToString() ?? "";
        _txtD.Text = r["d"]?.ToString() ?? "";
        _cboTrinhDo.SelectedItem = r["trinhdo"]?.ToString()?.Trim();
        _cboDapAn.SelectedItem = r["dap_an"]?.ToString()?.Trim();
    }

    private void XoaTrangPanel()
    {
        _txtNoiDung.Clear(); _txtA.Clear(); _txtB.Clear(); _txtC.Clear(); _txtD.Clear();
        _cboTrinhDo.SelectedIndex = -1; _cboDapAn.SelectedIndex = -1;
    }

    private void BatDauThem()
    {
        _dangThem = true;
        XoaTrangPanel();
        _cboTrinhDo.SelectedItem = "A";
        _cboDapAn.SelectedItem = "A";
        _txtNoiDung.Focus();
        Bao("Đang soạn câu hỏi mới - nhập xong bấm Ghi câu hỏi. Mã câu do hệ thống tự cấp.", false);
    }

    private void Ghi(bool sua)
    {
        if (_cboTrinhDo.SelectedItem == null || _cboDapAn.SelectedItem == null)
        { Bao("Chọn trình độ và đáp án đúng.", true); return; }
        if (_txtNoiDung.Text.Trim().Length == 0)
        { Bao("Nội dung câu hỏi không được để trống.", true); return; }

        var thamSo = new List<SqlParameter>
        {
            new("@MAMH",    SqlDbType.Char, 5)      { Value = MaMon() },
            new("@TRINHDO", SqlDbType.Char, 1)      { Value = _cboTrinhDo.SelectedItem!.ToString() },
            new("@NOIDUNG", SqlDbType.NVarChar, -1) { Value = _txtNoiDung.Text },
            new("@A", SqlDbType.NVarChar, -1) { Value = _txtA.Text },
            new("@B", SqlDbType.NVarChar, -1) { Value = _txtB.Text },
            new("@C", SqlDbType.NVarChar, -1) { Value = _txtC.Text },
            new("@D", SqlDbType.NVarChar, -1) { Value = _txtD.Text },
            new("@DAP_AN", SqlDbType.Char, 1) { Value = _cboDapAn.SelectedItem!.ToString() },
        };

        try
        {
            if (_dangThem || !sua)
            {
                var dt = DataProvider.GoiSP("dbo.sp_Bode_Them", thamSo.ToArray());
                var ma = dt.Rows.Count > 0 ? dt.Rows[0][0]?.ToString() : "?";
                Bao($"Đã thêm câu hỏi mã {ma}.", false);
            }
            else
            {
                if (_bs.Current is not DataRowView r) { Bao("Chưa chọn câu hỏi để sửa.", true); return; }
                thamSo.Insert(0, new SqlParameter("@CAUHOI", SqlDbType.Int) { Value = r["cauhoi"] });
                DataProvider.GoiSP("dbo.sp_Bode_Sua", thamSo.ToArray());
                Bao("Đã sửa câu hỏi.", false);
            }
            Nap();
        }
        catch (SqlException ex) { Bao(ex.Message, true); }
    }

    private void Xoa()
    {
        if (_bs.Current is not DataRowView r) { Bao("Chưa chọn câu hỏi.", true); return; }
        if (MessageBox.Show($"Xóa câu hỏi mã {r["cauhoi"]}?", "Xác nhận",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        try
        {
            DataProvider.GoiSP("dbo.sp_Bode_Xoa",
                new SqlParameter("@CAUHOI", SqlDbType.Int) { Value = r["cauhoi"] });
            Bao("Đã xóa câu hỏi.", false);
            Nap();
        }
        catch (SqlException ex) { Bao(ex.Message, true); }
    }

    private void Bao(string s, bool loi)
    {
        _lbl.ForeColor = loi ? Color.Firebrick : SystemColors.ControlText;
        _lbl.Text = s;
    }
}
