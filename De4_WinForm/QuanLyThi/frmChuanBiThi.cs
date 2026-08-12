using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 7 - Giáo viên đăng ký kỳ thi (chuẩn bị thi).
/// Nhập: lớp, môn, trình độ, lần thi, số câu, ngày thi, thời gian.
/// sp_ChuanBiThi sẽ KIỂM TRA ĐỦ ĐỀ và báo rõ CÒN THIẾU BAO NHIÊU CÂU
/// nếu kho đề chưa đáp ứng - đúng yêu cầu của đề.
/// </summary>
public class frmChuanBiThi : Form
{
    private readonly ComboBox _cboLop = new(), _cboMon = new(), _cboGV = new();
    private readonly ComboBox _cboTrinhDo = new(), _cboLan = new();
    private readonly NumericUpDown _numSoCau = new(), _numThoiGian = new();
    private readonly DateTimePicker _ngayThi = new() { Format = DateTimePickerFormat.Short };
    private readonly Button _btnDangKy = new() { Text = "Đăng ký kỳ thi" };
    private readonly Label _lblKetQua = new();
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };

    public frmChuanBiThi()
    {
        Text = "Câu 7 - Chuẩn bị thi (đăng ký kỳ thi)";
        ClientSize = new Size(940, 620);
        StartPosition = FormStartPosition.CenterParent;
        DungGiaoDien();
        Load += (_, _) => Nap();
    }

    private void DungGiaoDien()
    {
        var bang = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 250,
            ColumnCount = 4,
            Padding = new Padding(10)
        };
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));

        foreach (var c in new Control[] { _cboLop, _cboMon, _cboGV, _cboTrinhDo, _cboLan,
                                          _numSoCau, _numThoiGian, _ngayThi })
            c.Dock = DockStyle.Fill;

        foreach (var cb in new[] { _cboLop, _cboMon, _cboGV, _cboTrinhDo, _cboLan })
            cb.DropDownStyle = ComboBoxStyle.DropDownList;

        _cboTrinhDo.Items.AddRange(new object[] { "A", "B", "C" });
        _cboLan.Items.AddRange(new object[] { 1, 2 });          // hệ niên chế: tối đa 2 lần
        _numSoCau.Minimum = 10; _numSoCau.Maximum = 100; _numSoCau.Value = 30;
        _numThoiGian.Minimum = 2; _numThoiGian.Maximum = 60; _numThoiGian.Value = 30;
        _ngayThi.Value = DateTime.Today;

        void Dong(int r, string l1, Control c1, string l2, Control c2)
        {
            bang.Controls.Add(new Label { Text = l1, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, r);
            bang.Controls.Add(c1, 1, r);
            bang.Controls.Add(new Label { Text = l2, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 2, r);
            bang.Controls.Add(c2, 3, r);
        }
        Dong(0, "Lớp:", _cboLop, "Môn học:", _cboMon);
        Dong(1, "Giảng viên:", _cboGV, "Trình độ:", _cboTrinhDo);
        Dong(2, "Lần thi:", _cboLan, "Ngày thi:", _ngayThi);
        Dong(3, "Số câu thi:", _numSoCau, "Thời gian (phút):", _numThoiGian);

        _btnDangKy.Size = new Size(150, 34);
        _btnDangKy.Click += (_, _) => DangKy();
        bang.Controls.Add(_btnDangKy, 1, 4);

        _lblKetQua.Dock = DockStyle.Fill;
        _lblKetQua.TextAlign = ContentAlignment.MiddleLeft;
        bang.Controls.Add(_lblKetQua, 2, 4);
        bang.SetColumnSpan(_lblKetQua, 2);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);

        var box = new GroupBox { Text = "Các kỳ thi đã đăng ký", Dock = DockStyle.Fill, Padding = new Padding(6) };
        box.Controls.Add(_luoi);

        Controls.Add(box);
        Controls.Add(bang);
    }

    private void Nap()
    {
        try
        {
            _cboLop.DataSource = DataProvider.TruyVan("SELECT MALOP, TENLOP FROM dbo.LOP ORDER BY MALOP");
            _cboLop.DisplayMember = "TENLOP"; _cboLop.ValueMember = "MALOP";

            _cboMon.DataSource = DataProvider.TruyVan("SELECT MAMH, TENMH FROM dbo.MONHOC ORDER BY MAMH");
            _cboMon.DisplayMember = "TENMH"; _cboMon.ValueMember = "MAMH";

            // Giảng viên chỉ đăng ký cho chính mình; Cơ sở chọn được mọi GV.
            var sqlGv = Phien.VaiTro == "Giangvien"
                ? "SELECT MAGV, HO + ' ' + TEN AS HOTEN FROM dbo.GIAOVIEN WHERE MAGV = @me"
                : "SELECT MAGV, HO + ' ' + TEN AS HOTEN FROM dbo.GIAOVIEN ORDER BY MAGV";
            _cboGV.DataSource = Phien.VaiTro == "Giangvien"
                ? DataProvider.TruyVan(sqlGv, new SqlParameter("@me", SqlDbType.Char, 8) { Value = Phien.Ma })
                : DataProvider.TruyVan(sqlGv);
            _cboGV.DisplayMember = "HOTEN"; _cboGV.ValueMember = "MAGV";

            _cboTrinhDo.SelectedIndex = 0;
            _cboLan.SelectedIndex = 0;
            NapDanhSach();
        }
        catch (SqlException ex) { Bao(ex.Message, true); }
    }

    private void NapDanhSach()
    {
        try
        {
            _luoi.DataSource = DataProvider.TruyVan(@"
                SELECT TENLOP = l.TENLOP, TENMH = mh.TENMH, TRINHDO = dk.TRINHDO,
                       LAN = dk.LAN, SOCAU = dk.SOCAUTHI, PHUT = dk.THOIGIAN,
                       NGAYTHI = dk.NGAYTHI,
                       GIANGVIEN = RTRIM(gv.HO) + ' ' + RTRIM(gv.TEN)
                FROM dbo.Giaovien_Dangky dk
                  JOIN dbo.Lop l       ON dk.MALOP = l.MALOP
                  JOIN dbo.Monhoc mh   ON dk.MAMH  = mh.MAMH
                  JOIN dbo.Giaovien gv ON dk.MAGV  = gv.MAGV
                ORDER BY dk.NGAYTHI DESC");
        }
        catch (SqlException ex) { Bao(ex.Message, true); }
    }

    private void DangKy()
    {
        try
        {
            DataProvider.GoiSP("dbo.sp_ChuanBiThi",
                new SqlParameter("@MAGV", SqlDbType.Char, 8) { Value = _cboGV.SelectedValue },
                new SqlParameter("@MALOP", SqlDbType.NChar, 15) { Value = _cboLop.SelectedValue },
                new SqlParameter("@MAMH", SqlDbType.Char, 5) { Value = _cboMon.SelectedValue },
                new SqlParameter("@TRINHDO", SqlDbType.Char, 1) { Value = _cboTrinhDo.SelectedItem },
                new SqlParameter("@LAN", SqlDbType.SmallInt) { Value = _cboLan.SelectedItem },
                new SqlParameter("@SOCAUTHI", SqlDbType.SmallInt) { Value = (short)_numSoCau.Value },
                new SqlParameter("@NGAYTHI", SqlDbType.DateTime) { Value = _ngayThi.Value.Date },
                new SqlParameter("@THOIGIAN", SqlDbType.SmallInt) { Value = (short)_numThoiGian.Value });

            Bao("Đăng ký kỳ thi thành công.", false);
            NapDanhSach();
        }
        catch (SqlException ex)
        {
            // Thông báo "còn thiếu bao nhiêu câu" nằm trong ex.Message -> hiện nguyên văn.
            Bao(ex.Message, true);
            MessageBox.Show(ex.Message, "Không đăng ký được",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void Bao(string s, bool loi)
    {
        _lblKetQua.ForeColor = loi ? Color.Firebrick : Color.SeaGreen;
        _lblKetQua.Text = s.Length > 120 ? s[..120] + "..." : s;
    }
}
