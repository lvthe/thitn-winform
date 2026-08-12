using System.Data;
using System.Text;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 8 - THI TRẮC NGHIỆM (chức năng quan trọng nhất của đề tài).
///
/// Bám sát yêu cầu của đề:
///  * Combobox môn thi CHỈ hiện môn ĐÃ ĐĂNG KÝ và CHƯA THI
///    ("cái gì biết là vô lý thì đừng cho người ta chọn").
///  * Đề được lấy bằng STORED PROCEDURE sp_LayDeThi (bắt buộc).
///  * Thời gian CHỈ bắt đầu đếm khi đã tải xong đề về máy - mốc đếm lấy
///    theo "số giây còn lại" do SERVER trả về, không tin đồng hồ máy trạm.
///  * Hết giờ thì TỰ ĐỘNG kết thúc và chấm điểm, không đợi người dùng bấm.
///  * Đáp án đúng KHÔNG bao giờ được gửi về máy trạm.
/// </summary>
public class frmThi : Form
{
    private readonly ComboBox _cboMon = new();
    private readonly Button _btnBatDau = new() { Text = "Bắt đầu thi" };
    private readonly CheckBox _chkDeLanTruoc = new() { Text = "Dùng lại đề lần trước" };
    private readonly Label _lblDongHo = new();
    private readonly Label _lblThiSinh = new();

    private readonly ListBox _dsCau = new();
    private readonly Label _lblNoiDung = new();
    private readonly RadioButton _rdA = new(), _rdB = new(), _rdC = new(), _rdD = new();
    private readonly Button _btnTruoc = new() { Text = "< Câu trước" };
    private readonly Button _btnSau = new() { Text = "Câu sau >" };
    private readonly Button _btnNop = new() { Text = "NỘP BÀI" };
    private readonly Label _lblTienDo = new();

    private readonly System.Windows.Forms.Timer _dongHo = new() { Interval = 1000 };

    private DataTable _cauHoi = new();
    private readonly Dictionary<int, char> _daChon = new();   // STT -> A/B/C/D
    private Guid _maPhieu;
    private int _giayConLai;
    private int _viTri;
    private bool _dangThi;
    private string _lopThiThu = "";   // giảng viên thi thử phải chọn lớp

    public frmThi()
    {
        Text = "Câu 8 - Thi trắc nghiệm";
        ClientSize = new Size(1000, 640);
        StartPosition = FormStartPosition.CenterParent;
        DungGiaoDien();
        _dongHo.Tick += DongHo_Tick;
        Load += (_, _) => Nap();
        FormClosing += frmThi_FormClosing;
    }

    private void DungGiaoDien()
    {
        var top = new Panel { Dock = DockStyle.Top, Height = 78 };
        _lblThiSinh.Location = new Point(12, 8);
        _lblThiSinh.Size = new Size(600, 22);
        _lblThiSinh.Font = new Font(Font, FontStyle.Bold);
        top.Controls.Add(_lblThiSinh);

        top.Controls.Add(new Label { Text = "Môn thi:", Location = new Point(12, 42), Size = new Size(60, 23) });
        _cboMon.Location = new Point(76, 40); _cboMon.Size = new Size(400, 25);
        _cboMon.DropDownStyle = ComboBoxStyle.DropDownList;
        top.Controls.Add(_cboMon);

        _chkDeLanTruoc.Location = new Point(486, 42); _chkDeLanTruoc.Size = new Size(170, 23);
        top.Controls.Add(_chkDeLanTruoc);

        _btnBatDau.Location = new Point(660, 38); _btnBatDau.Size = new Size(120, 30);
        _btnBatDau.Click += (_, _) => BatDau();
        top.Controls.Add(_btnBatDau);

        _lblDongHo.Location = new Point(800, 34); _lblDongHo.Size = new Size(180, 36);
        _lblDongHo.Font = new Font("Segoe UI", 16F, FontStyle.Bold);
        _lblDongHo.TextAlign = ContentAlignment.MiddleRight;
        _lblDongHo.Text = "--:--";
        top.Controls.Add(_lblDongHo);

        // Danh sách câu bên trái
        _dsCau.Dock = DockStyle.Left;
        _dsCau.Width = 150;
        _dsCau.SelectedIndexChanged += (_, _) =>
        { if (_dsCau.SelectedIndex >= 0 && _dsCau.SelectedIndex != _viTri) { _viTri = _dsCau.SelectedIndex; HienCau(); } };

        // Vùng câu hỏi
        var giua = new Panel { Dock = DockStyle.Fill, Padding = new Padding(14) };
        _lblNoiDung.Dock = DockStyle.Top;
        _lblNoiDung.Height = LogicalToDeviceUnits(110);
        _lblNoiDung.Font = new Font("Segoe UI", 11F);
        _lblNoiDung.AutoEllipsis = true;

        var traLoi = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = LogicalToDeviceUnits(200),
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            AutoScroll = true
        };
        foreach (var rd in new[] { _rdA, _rdB, _rdC, _rdD })
        {
            // AutoSize để chữ dài không bị cắt, và tự co giãn theo mức phóng DPI
            rd.AutoSize = true;
            rd.MaximumSize = new Size(LogicalToDeviceUnits(740), 0);
            rd.Padding = new Padding(0, LogicalToDeviceUnits(4), 0, LogicalToDeviceUnits(4));
            rd.Font = GiaoDien.ChuThuong;
            rd.CheckedChanged += TraLoi_Changed;
            traLoi.Controls.Add(rd);
        }
        giua.Controls.Add(traLoi);
        giua.Controls.Add(_lblNoiDung);

        var duoi = new Panel { Dock = DockStyle.Bottom, Height = 56, Padding = new Padding(10) };
        _btnTruoc.Location = new Point(12, 12); _btnTruoc.Size = new Size(110, 32);
        _btnTruoc.Click += (_, _) => { if (_viTri > 0) { _viTri--; HienCau(); } };
        _btnSau.Location = new Point(130, 12); _btnSau.Size = new Size(110, 32);
        _btnSau.Click += (_, _) => { if (_viTri < _cauHoi.Rows.Count - 1) { _viTri++; HienCau(); } };
        _lblTienDo.Location = new Point(260, 18); _lblTienDo.Size = new Size(400, 23);
        _btnNop.Location = new Point(700, 10); _btnNop.Size = new Size(140, 36);
        _btnNop.Font = new Font(Font, FontStyle.Bold);
        _btnNop.Click += (_, _) => NopBai(tuDong: false);
        duoi.Controls.AddRange(new Control[] { _btnTruoc, _btnSau, _lblTienDo, _btnNop });

        Controls.Add(giua);
        Controls.Add(_dsCau);
        Controls.Add(duoi);
        Controls.Add(top);

        BatTat(false);
    }

    private void BatTat(bool dangThi)
    {
        _dangThi = dangThi;
        _dsCau.Enabled = _rdA.Enabled = _rdB.Enabled = _rdC.Enabled = _rdD.Enabled = dangThi;
        _btnTruoc.Enabled = _btnSau.Enabled = _btnNop.Enabled = dangThi;
        _cboMon.Enabled = _btnBatDau.Enabled = _chkDeLanTruoc.Enabled = !dangThi;
    }

    private void Nap()
    {
        try
        {
            // Thông tin thí sinh (mã lớp, tên lớp, họ tên) - đề yêu cầu hiện ra sau đăng nhập
            if (LaThiThu)
            {
                Text = "Câu 8 - THI THỬ (giảng viên, KHÔNG ghi điểm)";
                _lblThiSinh.Text = $"Giảng viên: {Phien.Ma} - {Phien.HoTen}   |   " +
                                   "Chế độ THI THỬ: bài làm được chấm nhưng KHÔNG ghi vào bảng điểm.";
                _lblThiSinh.ForeColor = GiaoDien.DoCanhBao;
            }
            else
            {
                var tt = DataProvider.GoiSP("dbo.sp_ThongTinThiSinh",
                    new SqlParameter("@MASV", SqlDbType.Char, 8) { Value = Phien.Ma });
                if (tt.Rows.Count > 0)
                {
                    var r = tt.Rows[0];
                    _lblThiSinh.Text = $"Thí sinh: {Phien.Ma}  -  {Doc(r, "hoten")}   |   Lớp: {Doc(r, "malop")} - {Doc(r, "tenlop")}";
                }
                else _lblThiSinh.Text = $"Thí sinh: {Phien.Ma}";
            }

            NapMonThi();
        }
        catch (SqlException ex) { _lblTienDo.Text = "Lỗi: " + ex.Message; }
    }

    private static string Doc(DataRow r, string cot) =>
        r.Table.Columns.Contains(cot) ? r[cot]?.ToString()?.Trim() ?? "" : "";

    /// <summary>Chỉ đưa vào combobox môn ĐÃ ĐĂNG KÝ và CHƯA THI.</summary>
    private void NapMonThi()
    {
        DataTable lich;
        if (LaThiThu)
        {
            // Giảng viên thi thử: chọn trong các kỳ thi ĐÃ ĐĂNG KÝ của phân mảnh,
            // không ràng buộc "chưa thi" vì đây chỉ là thi thử.
            lich = DataProvider.TruyVan(@"
                SELECT mamh = RTRIM(dk.MAMH), tenmh = mh.TENMH, lan = dk.LAN,
                       trinhdo = RTRIM(dk.TRINHDO), socauthi = dk.SOCAUTHI,
                       thoigian = dk.THOIGIAN, ngaythi = dk.NGAYTHI,
                       dathi = CAST(0 AS bit), malop = RTRIM(dk.MALOP)
                FROM dbo.Giaovien_Dangky dk JOIN dbo.Monhoc mh ON dk.MAMH = mh.MAMH
                ORDER BY dk.NGAYTHI DESC");
        }
        else
        {
            lich = DataProvider.GoiSP("dbo.sp_LichThi",
                new SqlParameter("@MASV", SqlDbType.Char, 8) { Value = Phien.Ma });
        }

        var chuaThi = lich.Clone();
        foreach (DataRow r in lich.Rows)
            if (!(r["dathi"] is bool b && b)) chuaThi.ImportRow(r);

        chuaThi.Columns.Add("MOTA", typeof(string),
            "tenmh + ' - lần ' + lan + '  (' + trinhdo + ', ' + socauthi + ' câu, ' + thoigian + ' phút)'");

        _cboMon.DataSource = chuaThi;
        _cboMon.DisplayMember = "MOTA";

        // Thi thử: ghi nhớ lớp của kỳ thi được chọn để truyền cho SP
        if (LaThiThu)
        {
            _cboMon.SelectedIndexChanged -= CboMon_Changed;
            _cboMon.SelectedIndexChanged += CboMon_Changed;
            CboMon_Changed(null, EventArgs.Empty);
        }

        if (chuaThi.Rows.Count == 0)
        {
            _lblTienDo.Text = LaThiThu
                ? "Chưa có kỳ thi nào được đăng ký tại cơ sở này để thi thử."
                : "Không có môn nào để thi (chưa đăng ký, hoặc đã thi hết).";
            _btnBatDau.Enabled = false;
        }
        else _btnBatDau.Enabled = true;
    }

    private void CboMon_Changed(object? sender, EventArgs e)
    {
        if (_cboMon.SelectedItem is DataRowView r && r.Row.Table.Columns.Contains("malop"))
            _lopThiThu = r["malop"]?.ToString()?.Trim() ?? "";
    }

    /// <summary>Giảng viên vào màn hình này là THI THỬ (đề: không ghi điểm).</summary>
    private bool LaThiThu => Phien.VaiTro == "Giangvien";

    private void BatDau()
    {
        if (_cboMon.SelectedItem is not DataRowView r) return;

        try
        {
            var ds = new DataSet();
            using (var cn = DataProvider.MoKetNoi())
            using (var cmd = new SqlCommand("dbo.sp_LayDeThi", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@MASV", SqlDbType.Char, 8).Value = Phien.Ma;
                cmd.Parameters.Add("@MAMH", SqlDbType.Char, 5).Value = r["mamh"];
                cmd.Parameters.Add("@LAN", SqlDbType.SmallInt).Value = r["lan"];
                cmd.Parameters.Add("@DungLaiDeLanTruoc", SqlDbType.Bit).Value = _chkDeLanTruoc.Checked;
                cmd.Parameters.Add("@ThiThu", SqlDbType.Bit).Value = LaThiThu;
                if (LaThiThu)
                    cmd.Parameters.Add("@MALOP_ThiThu", SqlDbType.NChar, 15).Value = _lopThiThu;
                using var da = new SqlDataAdapter(cmd);
                da.Fill(ds);
            }

            if (ds.Tables.Count < 2 || ds.Tables[0].Rows.Count == 0)
            { MessageBox.Show("Không nhận được đề thi.", "Lỗi"); return; }

            var phieu = ds.Tables[0].Rows[0];
            _maPhieu = (Guid)phieu["maphieu"];
            // Mốc thời gian lấy TỪ SERVER (đã trừ thời gian tải đề).
            _giayConLai = Convert.ToInt32(phieu["sogiayconlai"]);
            _cauHoi = ds.Tables[1];

            _daChon.Clear();
            _dsCau.Items.Clear();
            for (int i = 0; i < _cauHoi.Rows.Count; i++)
                _dsCau.Items.Add($"Câu {i + 1}");

            _viTri = 0;
            BatTat(true);
            HienCau();
            _dongHo.Start();
            CapNhatDongHo();
        }
        catch (SqlException ex)
        {
            MessageBox.Show(ex.Message, "Không lấy được đề thi",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void HienCau()
    {
        if (_viTri < 0 || _viTri >= _cauHoi.Rows.Count) return;
        var r = _cauHoi.Rows[_viTri];
        int stt = Convert.ToInt32(r["stt"]);

        _lblNoiDung.Text = $"Câu {_viTri + 1}/{_cauHoi.Rows.Count}:  {r["noidung"]}";
        _rdA.Text = "A.  " + r["a"];
        _rdB.Text = "B.  " + r["b"];
        _rdC.Text = "C.  " + r["c"];
        _rdD.Text = "D.  " + r["d"];

        // Bỏ chọn mà không kích hoạt sự kiện ghi đáp án
        _rdA.CheckedChanged -= TraLoi_Changed; _rdB.CheckedChanged -= TraLoi_Changed;
        _rdC.CheckedChanged -= TraLoi_Changed; _rdD.CheckedChanged -= TraLoi_Changed;
        _rdA.Checked = _rdB.Checked = _rdC.Checked = _rdD.Checked = false;
        if (_daChon.TryGetValue(stt, out var c))
        {
            if (c == 'A') _rdA.Checked = true;
            else if (c == 'B') _rdB.Checked = true;
            else if (c == 'C') _rdC.Checked = true;
            else if (c == 'D') _rdD.Checked = true;
        }
        _rdA.CheckedChanged += TraLoi_Changed; _rdB.CheckedChanged += TraLoi_Changed;
        _rdC.CheckedChanged += TraLoi_Changed; _rdD.CheckedChanged += TraLoi_Changed;

        if (_dsCau.SelectedIndex != _viTri) _dsCau.SelectedIndex = _viTri;
        CapNhatTienDo();
    }

    private void TraLoi_Changed(object? sender, EventArgs e)
    {
        if (!_dangThi || sender is not RadioButton rd || !rd.Checked) return;
        int stt = Convert.ToInt32(_cauHoi.Rows[_viTri]["stt"]);
        char c = ReferenceEquals(rd, _rdA) ? 'A' : ReferenceEquals(rd, _rdB) ? 'B'
               : ReferenceEquals(rd, _rdC) ? 'C' : 'D';
        _daChon[stt] = c;
        _dsCau.Items[_viTri] = $"Câu {_viTri + 1}  [{c}]";
        CapNhatTienDo();
    }

    private void CapNhatTienDo() =>
        _lblTienDo.Text = $"Đã trả lời {_daChon.Count}/{_cauHoi.Rows.Count} câu.";

    private void DongHo_Tick(object? sender, EventArgs e)
    {
        _giayConLai--;
        CapNhatDongHo();
        if (_giayConLai <= 0)
        {
            _dongHo.Stop();
            // Đề: hết giờ thì TỰ ĐỘNG kết thúc, không đợi người dùng bấm.
            NopBai(tuDong: true);
        }
    }

    private void CapNhatDongHo()
    {
        var t = TimeSpan.FromSeconds(Math.Max(_giayConLai, 0));
        _lblDongHo.Text = $"{t.Minutes:00}:{t.Seconds:00}";
        _lblDongHo.ForeColor = _giayConLai <= 60 ? Color.Firebrick : SystemColors.ControlText;
    }

    private void NopBai(bool tuDong)
    {
        if (!_dangThi) return;
        if (!tuDong)
        {
            var chuaLam = _cauHoi.Rows.Count - _daChon.Count;
            var hoi = chuaLam > 0
                ? $"Còn {chuaLam} câu chưa trả lời. Vẫn nộp bài?"
                : "Nộp bài và kết thúc?";
            if (MessageBox.Show(hoi, "Xác nhận nộp bài",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        }

        _dongHo.Stop();
        BatTat(false);

        try
        {
            var json = new StringBuilder("[");
            foreach (var kv in _daChon)
            {
                if (json.Length > 1) json.Append(',');
                json.Append($"{{\"STT\":{kv.Key},\"DACHON\":\"{kv.Value}\"}}");
            }
            json.Append(']');

            var kq = DataProvider.GoiSP("dbo.sp_NopBai",
                new SqlParameter("@MASV", SqlDbType.Char, 8) { Value = Phien.Ma },
                new SqlParameter("@MAPHIEU", SqlDbType.UniqueIdentifier) { Value = _maPhieu },
                new SqlParameter("@DapAn", SqlDbType.NVarChar, -1) { Value = json.ToString() });

            if (kq.Rows.Count > 0)
            {
                var r = kq.Rows[0];
                var treHan = r["TreHan"] is bool b && b;
                var tb = $"ĐIỂM: {r["DIEM"]}\r\n\r\nSố câu đúng: {r["SoCauDung"]}/{r["SoCauThi"]}"
                       + (tuDong ? "\r\n\r\n(Bài thi tự động kết thúc do hết giờ.)" : "")
                       + (treHan ? "\r\n\r\nBài nộp trễ hạn - tính 0 điểm." : "");
                MessageBox.Show(tb, "Kết quả bài thi", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }

            _lblDongHo.Text = "--:--";
            NapMonThi();
        }
        catch (SqlException ex)
        {
            MessageBox.Show(ex.Message, "Lỗi nộp bài", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void frmThi_FormClosing(object? sender, FormClosingEventArgs e)
    {
        if (_dangThi && MessageBox.Show(
                "Bạn đang trong giờ thi. Đóng cửa sổ sẽ KHÔNG nộp bài và bài vẫn tính giờ. Vẫn đóng?",
                "Cảnh báo", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes)
        {
            e.Cancel = true;
            return;
        }
        _dongHo.Stop();
    }
}
