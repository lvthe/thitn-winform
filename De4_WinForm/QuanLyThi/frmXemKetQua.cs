using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 9 - Xem lại bài thi (PHÚC KHẢO).
///
/// Đề: in ra mã SV, họ tên, môn thi, ngày thi, lần thi; mỗi câu có số thứ
/// tự, mã câu hỏi trong bộ đề, nội dung, 4 lựa chọn, ĐÁP ÁN ĐÚNG và
/// CÂU SINH VIÊN ĐÃ CHỌN.
///
/// Hai kiểu người dùng, hai cách dùng khác nhau:
///
///   SINH VIÊN   → chỉ xem bài của CHÍNH MÌNH, không có ô chọn ai khác.
///   GIẢNG VIÊN  → chọn LỚP rồi chọn SINH VIÊN để tra bài mà giải thích.
///   / CƠ SỞ       Thầy: "sinh viên thắc mắc tại sao chỉ có 5 điểm thì
///                 giảng viên phải có nhiệm vụ giải thích, giống phúc khảo".
///
/// Mọi truy vấn đều đi qua stored procedure: sinh viên dùng chung một
/// tài khoản SQL và nhóm Sinhvien không có quyền đọc bảng.
/// </summary>
public class frmXemKetQua : Form
{
    private readonly ComboBox _cboLop = new();
    private readonly ComboBox _cboSinhVien = new();
    private readonly ComboBox _cboBai = new();
    private readonly Button _btnXem = new() { Text = "Xem lại bài" };
    private readonly Button _btnXemTruoc = new() { Text = "🖨  Xem trước / In" };
    private readonly Label _lblDau = new();
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    /// <summary>Sinh viên đang được xem bài. Với vai trò sinh viên thì luôn là chính mình.</summary>
    private string _masv = "";
    private DataTable? _chiTiet;

    private bool LaSinhVien => Phien.VaiTro == "Sinhvien";

    public frmXemKetQua()
    {
        Text = LaSinhVien ? "Câu 9 - Xem lại bài thi của tôi"
                          : "Câu 9 - Phúc khảo: xem lại bài thi của sinh viên";
        ClientSize = new Size(1120, 640);
        StartPosition = FormStartPosition.CenterParent;

        foreach (var cb in new[] { _cboLop, _cboSinhVien, _cboBai })
            cb.DropDownStyle = ComboBoxStyle.DropDownList;
        _cboLop.Width = 240; _cboSinhVien.Width = 300; _cboBai.Width = 380;

        _btnXem.Click += (_, _) => Xem();
        _btnXemTruoc.Click += (_, _) => { var b = TaoBaoCao(); b?.XemTruoc(this); };

        // Hàng chọn lớp + sinh viên: CHỈ hiện cho giảng viên / cơ sở / trưởng
        var hangChon = GiaoDien.TaoHangCongCu(
            GiaoDien.Nhan("Lớp:"), _cboLop,
            GiaoDien.Nhan("Sinh viên:"), _cboSinhVien);
        hangChon.Visible = !LaSinhVien;

        var hangBai = GiaoDien.TaoHangCongCu(
            GiaoDien.Nhan("Bài thi:"), _cboBai, _btnXem, _btnXemTruoc);

        _lblDau.Dock = DockStyle.Top;
        _lblDau.Height = 30;
        _lblDau.Font = GiaoDien.ChuDam;
        _lblDau.Padding = new Padding(10, 6, 0, 0);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);
        _luoi.RowsDefaultCellStyle.WrapMode = DataGridViewTriState.True;
        _luoi.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.AllCells;
        _luoi.DataBindingComplete += (_, _) => ToMau();

        _tt.Items.Add(_lbl);
        Controls.Add(_luoi);
        Controls.Add(_lblDau);
        Controls.Add(hangBai);
        Controls.Add(hangChon);
        Controls.Add(_tt);

        Load += (_, _) => KhoiTao();
    }

    private void KhoiTao()
    {
        if (LaSinhVien)
        {
            _masv = Phien.Ma;                 // sinh viên chỉ xem bài của chính mình
            NapDanhSachBai();
            return;
        }

        // Giảng viên / Cơ sở / Trưởng: chọn lớp trước
        try
        {
            var dsLop = DataProvider.GoiSP("dbo.sp_DS_Lop_CoBaiThi");
            GanNguon(_cboLop, dsLop, "MOTA", "MALOP");
            _cboLop.SelectedIndexChanged += Lop_Changed;
            _cboSinhVien.SelectedIndexChanged += SinhVien_Changed;

            if (dsLop.Rows.Count == 0)
                _lbl.Text = "Chưa có lớp nào có sinh viên đã thi tại cơ sở này.";
            else NapSinhVien();
        }
        catch (Exception ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void Lop_Changed(object? s, EventArgs e) => NapSinhVien();
    private void SinhVien_Changed(object? s, EventArgs e) => ChonSinhVien();

    /// <summary>
    /// Gán nguồn dữ liệu cho ComboBox đúng thứ tự.
    /// DataSource phải gán TRƯỚC rồi mới tới DisplayMember/ValueMember:
    /// gán ngược lại thì WinForms bỏ qua vì chưa có nguồn để đối chiếu,
    /// và ComboBox sẽ hiện "System.Data.DataRowView".
    /// Người gọi tự gỡ handler trước khi gọi để tránh sự kiện bắn sớm.
    /// </summary>
    private static void GanNguon(ComboBox cbo, DataTable nguon, string hienThi, string giaTri)
    {
        cbo.DataSource = nguon;
        cbo.DisplayMember = hienThi;
        cbo.ValueMember = giaTri;
    }

    private void NapSinhVien()
    {
        var maLop = _cboLop.SelectedValue?.ToString();
        if (string.IsNullOrEmpty(maLop)) return;
        try
        {
            var ds = DataProvider.GoiSP("dbo.sp_DS_SinhVien_CoBaiThi",
                new SqlParameter("@MALOP", SqlDbType.NChar, 15) { Value = maLop });
            _cboSinhVien.SelectedIndexChanged -= SinhVien_Changed;
            GanNguon(_cboSinhVien, ds, "MOTA", "MASV");
            _cboSinhVien.SelectedIndexChanged += SinhVien_Changed;

            if (ds.Rows.Count == 0)
            {
                _masv = "";
                _cboBai.DataSource = null;
                _luoi.DataSource = null;
                _lblDau.Text = "";
                _lbl.Text = "Lớp này chưa có sinh viên nào thi.";
            }
            else ChonSinhVien();
        }
        catch (Exception ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void ChonSinhVien()
    {
        var ma = _cboSinhVien.SelectedValue?.ToString()?.Trim();
        if (string.IsNullOrEmpty(ma)) return;
        _masv = ma;
        NapDanhSachBai();
    }

    /// <summary>
    /// Nạp danh sách bài thi đã có điểm — PHẢI đi qua stored procedure vì
    /// nhóm Sinhvien không được cấp quyền đọc bảng.
    /// </summary>
    private void NapDanhSachBai()
    {
        if (_masv.Length == 0) return;
        try
        {
            var dt = DataProvider.GoiSP("dbo.sp_DS_BaiThi_SV",
                new SqlParameter("@MASV", SqlDbType.Char, 8) { Value = _masv });

            _cboBai.DataSource = dt;
            _cboBai.DisplayMember = "MOTA";

            if (dt.Rows.Count == 0)
            {
                _luoi.DataSource = null;
                _lblDau.Text = "";
                _lbl.Text = LaSinhVien ? "Bạn chưa có bài thi nào có điểm."
                                       : $"Sinh viên {_masv} chưa có bài thi nào có điểm.";
            }
            else Xem();
        }
        catch (Exception ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private void Xem()
    {
        if (_cboBai.SelectedItem is not DataRowView r || _masv.Length == 0) return;
        try
        {
            var ds = new DataSet();
            using (var cn = DataProvider.MoKetNoi())
            using (var cmd = new SqlCommand("dbo.sp_XemKetQua", cn) { CommandType = CommandType.StoredProcedure })
            {
                cmd.Parameters.Add("@MASV", SqlDbType.Char, 8).Value = _masv;
                cmd.Parameters.Add("@MAMH", SqlDbType.Char, 5).Value = r["MAMH"];
                cmd.Parameters.Add("@LAN", SqlDbType.SmallInt).Value = r["LAN"];
                using var da = new SqlDataAdapter(cmd);
                da.Fill(ds);
            }

            if (ds.Tables.Count > 0 && ds.Tables[0].Rows.Count > 0)
            {
                var d = ds.Tables[0].Rows[0];
                _lblDau.Text =
                    $"Mã SV: {_masv}   |   Họ tên: {d["HoTen"]}   |   Lớp: {d["Lop"]}   |   " +
                    $"Môn: {d["MonThi"]}   |   Ngày thi: {Convert.ToDateTime(d["NgayThi"]):dd/MM/yyyy}   |   " +
                    $"Lần {d["LanThi"]}   |   ĐIỂM: {d["Diem"]}";
            }

            if (ds.Tables.Count > 1)
            {
                _chiTiet = ds.Tables[1];
                _luoi.DataSource = _chiTiet;
                frmCrudBase.DatCot(_luoi, "STT", "STT", 5);
                frmCrudBase.DatCot(_luoi, "CauSo", "Mã câu", 7);
                frmCrudBase.DatCot(_luoi, "NOIDUNG", "Nội dung câu hỏi", 30);
                frmCrudBase.DatCot(_luoi, "A", "A", 11);
                frmCrudBase.DatCot(_luoi, "B", "B", 11);
                frmCrudBase.DatCot(_luoi, "C", "C", 11);
                frmCrudBase.DatCot(_luoi, "D", "D", 11);
                frmCrudBase.DatCot(_luoi, "DapAn", "Đáp án đúng", 8);
                frmCrudBase.DatCot(_luoi, "DaChon", "Đã chọn", 7);
                frmCrudBase.DatCot(_luoi, "KetQua", "Kết quả", 8);

                // Đếm bằng vòng lặp, KHÔNG dùng DataTable.Select: hàm đó ăn cú
                // pháp biểu thức của .NET chứ không phải T-SQL, nên tiền tố
                // N'...' sẽ ném SyntaxErrorException.
                int dung = 0;
                foreach (DataRow dong in _chiTiet.Rows)
                    if ((dong["KetQua"]?.ToString() ?? "") == "Đúng") dung++;
                _lbl.Text = $"{_chiTiet.Rows.Count} câu - đúng {dung} câu.";
            }
        }
        catch (Exception ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    /// <summary>Bài thi in ra để đưa cho sinh viên khi phúc khảo.</summary>
    private BaoCaoIn? TaoBaoCao()
    {
        if (_chiTiet == null || _chiTiet.Rows.Count == 0)
        { _lbl.Text = "Chưa có dữ liệu để in."; return null; }

        return new BaoCaoIn
        {
            TieuDeBaoCao = "BÀI LÀM CHI TIẾT (PHÚC KHẢO)",
            TieuDePhu = _lblDau.Text.Replace("   |   ", "  ·  "),
            NguonDuLieu = $"Phân mảnh: {Phien.TenPhanManh}   ·   In lúc {DateTime.Now:dd/MM/yyyy HH:mm}",
            DuLieu = _chiTiet,
            DanhSachCot =
            {
                new BaoCaoIn.Cot { Ten = "STT",     TieuDe = "STT",     RongPhanTram = 5, CanPhai = true },
                new BaoCaoIn.Cot { Ten = "CauSo",   TieuDe = "Mã câu",  RongPhanTram = 7, CanPhai = true },
                new BaoCaoIn.Cot { Ten = "NOIDUNG", TieuDe = "Nội dung câu hỏi", RongPhanTram = 40 },
                new BaoCaoIn.Cot { Ten = "DapAn",   TieuDe = "Đáp án đúng", RongPhanTram = 10 },
                new BaoCaoIn.Cot { Ten = "DaChon",  TieuDe = "Đã chọn", RongPhanTram = 9 },
                new BaoCaoIn.Cot { Ten = "KetQua",  TieuDe = "Kết quả", RongPhanTram = 9 },
                // Cột SỐ CÂU ĐÚNG tính TẠI MÁY TRẠM để có dòng tổng
                new BaoCaoIn.Cot { Ten = "DUNG",    TieuDe = "Đúng",    RongPhanTram = 8,
                                   CanPhai = true, CongTong = true,
                                   CotTinh = r => (r["KetQua"]?.ToString() == "Đúng") ? 1 : 0 }
            }
        };
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
