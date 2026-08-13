using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// PHÂN CÔNG GIẢNG DẠY - việc của nhóm Cơ sở, làm TRƯỚC câu 7.
///
/// Vì sao cần form riêng: bảng GIAOVIEN_DANGKY đang gánh hai việc khác nhau
/// (phân công dạy, và đăng ký kỳ thi), nhưng chỉ có sp_ChuanBiThi ghi vào nó
/// - mà thủ tục đó lại từ chối khi kho đề chưa đủ. Với môn hoàn toàn mới thì
/// Cơ sở không phân công được, giảng viên cũng không soạn được đề vì chưa
/// được phân công. Form này cắt vòng lặp đó: ghi dòng phân công KHÔNG kèm
/// kiểm tra kho đề, để trống TRINHDO/SOCAUTHI/THOIGIAN.
///
/// Sau đó màn Chuẩn bị thi (câu 7) ĐIỀN TIẾP vào chính dòng đó.
/// Xem SQL/17_TachPhanCong_DangKyThi.sql.
/// </summary>
public class frmPhanCong : Form
{
    private readonly ComboBox _cboGV = new(), _cboMon = new(), _cboLop = new();
    private readonly Button _btnPhanCong = new() { Text = "Phân công" };
    private readonly Button _btnBoPhanCong = new() { Text = "Bỏ phân công" };
    private readonly Button _btnNapLai = new() { Text = "Nạp lại" };
    private readonly Label _lblKetQua = new();
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };

    public frmPhanCong()
    {
        Text = "Phân công giảng dạy (Cơ sở)";
        ClientSize = new Size(940, 600);
        StartPosition = FormStartPosition.CenterParent;
        DungGiaoDien();

        // Trưởng chỉ xem; giảng viên mở ra để biết mình được phân công gì.
        if (Phien.VaiTro != "CoSo")
        {
            _btnPhanCong.Enabled = _btnBoPhanCong.Enabled = false;
            _cboGV.Enabled = _cboMon.Enabled = _cboLop.Enabled = false;
            Text += " — chỉ xem";
        }

        Load += (_, _) => Nap();
    }

    private void DungGiaoDien()
    {
        var bang = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = LogicalToDeviceUnits(84),
            ColumnCount = 4,
            RowCount = 2,
            Padding = new Padding(10)
        };
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, LogicalToDeviceUnits(110)));
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, LogicalToDeviceUnits(110)));
        bang.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));

        foreach (var cb in new[] { _cboGV, _cboMon, _cboLop })
        {
            cb.Dock = DockStyle.Fill;
            cb.DropDownStyle = ComboBoxStyle.DropDownList;
        }

        void Dong(int r, string l1, Control c1, string l2, Control? c2)
        {
            bang.Controls.Add(new Label { Text = l1, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, r);
            bang.Controls.Add(c1, 1, r);
            bang.Controls.Add(new Label { Text = l2, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 2, r);
            if (c2 != null) bang.Controls.Add(c2, 3, r);
        }
        Dong(0, "Giảng viên:", _cboGV, "Môn học:", _cboMon);
        Dong(1, "Lớp:", _cboLop, "", null);

        // Hàng nút dựng bằng FlowLayoutPanel tự co giãn - đặt hẳn ngoài
        // TableLayoutPanel, vì panel đó đã Dock=Top sẵn.
        _lblKetQua.AutoSize = true;
        _btnBoPhanCong.ForeColor = GiaoDien.DoCanhBao;
        _btnPhanCong.Click += (_, _) => PhanCong();
        _btnBoPhanCong.Click += (_, _) => BoPhanCong();
        _btnNapLai.Click += (_, _) => NapDanhSach();
        var hangNut = GiaoDien.TaoHangCongCu(
            _btnPhanCong, _btnBoPhanCong, _btnNapLai, _lblKetQua);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.AllowUserToDeleteRows = false;
        _luoi.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        _luoi.SelectionChanged += (_, _) => CapNhatNut();
        GiaoDien.TrangTriLuoi(_luoi);

        var box = new GroupBox
        {
            Text = "Đã phân công",
            Dock = DockStyle.Fill,
            Padding = new Padding(6)
        };
        box.Controls.Add(_luoi);

        // Thêm ngược từ trong ra: control thêm SAU nằm sát mép hơn.
        Controls.Add(box);
        Controls.Add(hangNut);
        Controls.Add(bang);
    }

    private void Nap()
    {
        try
        {
            _cboGV.DataSource = DataProvider.TruyVan(
                "SELECT MAGV, RTRIM(HO) + ' ' + RTRIM(TEN) AS HOTEN FROM dbo.GIAOVIEN ORDER BY MAGV");
            _cboGV.DisplayMember = "HOTEN"; _cboGV.ValueMember = "MAGV";

            _cboMon.DataSource = DataProvider.TruyVan(
                "SELECT MAMH, TENMH FROM dbo.MONHOC ORDER BY MAMH");
            _cboMon.DisplayMember = "TENMH"; _cboMon.ValueMember = "MAMH";

            _cboLop.DataSource = DataProvider.TruyVan(
                "SELECT MALOP, TENLOP FROM dbo.LOP ORDER BY MALOP");
            _cboLop.DisplayMember = "TENLOP"; _cboLop.ValueMember = "MALOP";

            NapDanhSach();
        }
        catch (Exception ex) { Bao(ex.Message, true); }
    }

    private void NapDanhSach()
    {
        try
        {
            var dt = DataProvider.GoiSP("dbo.sp_PhanCong_DS");
            _luoi.DataSource = dt;

            if (_luoi.Columns.Contains("XOADUOC")) _luoi.Columns["XOADUOC"]!.Visible = false;
            frmCrudBase.DatCot(_luoi, "MAGV", "Mã GV", 10);
            frmCrudBase.DatCot(_luoi, "GIANGVIEN", "Giảng viên", 20);
            frmCrudBase.DatCot(_luoi, "MAMH", "Mã môn", 10);
            frmCrudBase.DatCot(_luoi, "TENMH", "Môn học", 20);
            frmCrudBase.DatCot(_luoi, "MALOP", "Mã lớp", 10);
            frmCrudBase.DatCot(_luoi, "TENLOP", "Lớp", 12);
            frmCrudBase.DatCot(_luoi, "LAN", "Lần", 6);
            frmCrudBase.DatCot(_luoi, "TRANGTHAI", "Trạng thái", 22);

            Bao($"{dt.Rows.Count} dòng.", false);
            CapNhatNut();
        }
        catch (Exception ex) { Bao(ex.Message, true); }
    }

    /// <summary>Chỉ bỏ được phân công CHƯA đăng ký kỳ thi - SP cũng chặn lại lần nữa.</summary>
    private void CapNhatNut()
    {
        if (Phien.VaiTro != "CoSo") return;
        var dong = DongDangChon();
        _btnBoPhanCong.Enabled = dong != null
            && dong["XOADUOC"] != DBNull.Value && (bool)dong["XOADUOC"];
    }

    private DataRow? DongDangChon()
    {
        if (_luoi.CurrentRow?.DataBoundItem is DataRowView v) return v.Row;
        return null;
    }

    private void PhanCong()
    {
        try
        {
            var dt = DataProvider.GoiSP("dbo.sp_PhanCong_Them",
                new SqlParameter("@MAGV", SqlDbType.Char, 8) { Value = _cboGV.SelectedValue },
                new SqlParameter("@MAMH", SqlDbType.Char, 5) { Value = _cboMon.SelectedValue },
                new SqlParameter("@MALOP", SqlDbType.NChar, 15) { Value = _cboLop.SelectedValue });

            Bao(dt.Rows.Count > 0 ? dt.Rows[0][0]?.ToString() ?? "" : "Đã phân công.", false);
            NapDanhSach();
        }
        catch (Exception ex)
        {
            Bao(ex.Message, true);
            MessageBox.Show(ex.Message, "Không phân công được",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void BoPhanCong()
    {
        var dong = DongDangChon();
        if (dong == null) { Bao("Chưa chọn dòng nào.", true); return; }

        if (MessageBox.Show(
                $"Bỏ phân công {dong["TENMH"]} - lớp {dong["TENLOP"]} của {dong["GIANGVIEN"]}?",
                "Xác nhận", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            return;

        try
        {
            var dt = DataProvider.GoiSP("dbo.sp_PhanCong_Xoa",
                new SqlParameter("@MAMH", SqlDbType.Char, 5) { Value = dong["MAMH"] },
                new SqlParameter("@MALOP", SqlDbType.NChar, 15) { Value = dong["MALOP"] });

            Bao(dt.Rows.Count > 0 ? dt.Rows[0][0]?.ToString() ?? "" : "Đã bỏ phân công.", false);
            NapDanhSach();
        }
        catch (Exception ex)
        {
            Bao(ex.Message, true);
            MessageBox.Show(ex.Message, "Không bỏ phân công được",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void Bao(string s, bool loi)
    {
        _lblKetQua.ForeColor = loi ? Color.Firebrick : Color.SeaGreen;
        _lblKetQua.Text = s.Replace("\r\n", " ");
    }
}
