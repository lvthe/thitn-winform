using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 11 - Danh sách đăng ký thi trắc nghiệm.
///
/// Hai yêu cầu phải thoả CÙNG LÚC:
///
///  (a) Đề câu 11: báo cáo của CẢ HAI CƠ SỞ, và Thầy nhắc 2 lần
///      "KHÔNG được về server chủ, bắt buộc chạy trên 2 phân mảnh,
///       dùng phép UNION".
///      -> mục "(Tất cả — gộp 2 cơ sở)" gọi SP trên TỪNG phân mảnh
///         rồi UNION kết quả. Tuyệt đối không mở kết nối tới Publisher.
///
///  (b) Bài giảng làm báo cáo phân tán: phải có ComboBox CHI NHÁNH để
///      "rẽ về server đó" và xem riêng từng chi nhánh.
///      -> chọn một chi nhánh cụ thể thì chỉ kết nối đúng server đó.
///
/// Nhóm Trưởng chọn được cả 3 mục; nhóm Cơ sở bị khoá vào cơ sở mình.
/// </summary>
public class frmBaoCaoDangKy : Form
{
    private readonly ComboBox _cboChiNhanh = new();
    private readonly DateTimePicker _tuNgay = new() { Format = DateTimePickerFormat.Short };
    private readonly DateTimePicker _denNgay = new() { Format = DateTimePickerFormat.Short };
    private readonly Button _btnXem = new() { Text = "Xem dữ liệu" };
    private readonly Button _btnXemTruoc = new() { Text = "🖨  Xem trước / In" };
    private readonly Button _btnXuat = new() { Text = "📄  Xuất Excel" };
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly Label _lblNguon = new() { Dock = DockStyle.Bottom, Height = 44 };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    private ChonChiNhanh _chiNhanh = null!;
    private DataTable? _duLieu;
    private string _nguonMoTa = "";

    public frmBaoCaoDangKy()
    {
        Text = "Câu 11 - Đăng ký thi trắc nghiệm (cả hai cơ sở)";
        ClientSize = new Size(1080, 620);
        StartPosition = FormStartPosition.CenterParent;

        _cboChiNhanh.Width = 260;
        _tuNgay.Width = 120; _tuNgay.Value = DateTime.Today.AddMonths(-6);
        _denNgay.Width = 120; _denNgay.Value = DateTime.Today.AddMonths(6);
        _btnXem.Click += (_, _) => Xem();
        _btnXemTruoc.Click += (_, _) => { var b = TaoBaoCao(); b?.XemTruoc(this); };
        _btnXuat.Click += (_, _) => Xuat();

        // Hai hàng công cụ TỰ CO GIÃN theo cỡ chữ / mức phóng màn hình
        var hang2 = GiaoDien.TaoHangCongCu(
            GiaoDien.Nhan("Từ ngày:"), _tuNgay,
            GiaoDien.Nhan("Đến ngày:"), _denNgay,
            _btnXem, _btnXemTruoc, _btnXuat);
        var hang1 = GiaoDien.TaoHangCongCu(
            GiaoDien.Nhan("Chi nhánh:"), _cboChiNhanh);

        _luoi.ReadOnly = true;
        _luoi.AllowUserToAddRows = false;
        _luoi.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        GiaoDien.TrangTriLuoi(_luoi);
        GiaoDien.TrangTriNut(_btnXemTruoc, nhanManh: true);
        GiaoDien.TrangTriNut(_btnXem);
        GiaoDien.TrangTriNut(_btnXuat);

        _lblNguon.ForeColor = SystemColors.GrayText;
        _lblNguon.Padding = new Padding(10, 4, 10, 4);
        _lblNguon.Height = 52;
        _tt.Items.Add(_lbl);

        // Thứ tự Add quyết định thứ tự neo: thêm SAU thì nằm TRÊN
        Controls.Add(_luoi);
        Controls.Add(_lblNguon);
        Controls.Add(hang2);
        Controls.Add(hang1);
        Controls.Add(_tt);

        Load += (_, _) =>
        {
            // choPhepGopTatCa: thêm mục "(Tất cả — gộp 2 cơ sở)" cho nhóm Trưởng
            _chiNhanh = new ChonChiNhanh(_cboChiNhanh, choPhepGopTatCa: true);
            _chiNhanh.KhiDoiChiNhanh += Xem;
            _chiNhanh.Nap();
        };
    }

    private void Xem()
    {
        Cursor = Cursors.WaitCursor;
        try
        {
            if (_chiNhanh.GopTatCa) LayGopHaiCoSo();
            else LayMotChiNhanh();

            _luoi.DataSource = _duLieu;
            frmCrudBase.DatCot(_luoi, "MACS", "Cơ sở", 8);
            frmCrudBase.DatCot(_luoi, "COSO", "Tên cơ sở", 13);
            frmCrudBase.DatCot(_luoi, "TENLOP", "Lớp", 12);
            frmCrudBase.DatCot(_luoi, "TENMH", "Môn học", 15);
            frmCrudBase.DatCot(_luoi, "GIANGVIEN", "Giảng viên", 15);
            frmCrudBase.DatCot(_luoi, "TRINHDO", "TĐ", 5);
            frmCrudBase.DatCot(_luoi, "SOCAUTHI", "Số câu", 7);
            frmCrudBase.DatCot(_luoi, "THOIGIAN", "Phút", 6);
            frmCrudBase.DatCot(_luoi, "NGAYTHI", "Ngày thi", 11);
            frmCrudBase.DatCot(_luoi, "LAN", "Lần", 5);
            frmCrudBase.DatCot(_luoi, "DATHI", "Đã thi", 7);
            frmCrudBase.DatCot(_luoi, "GHICHU", "Ghi chú", 16);

            _lblNguon.Text = _nguonMoTa;
            _lbl.Text = $"Tổng cộng {_duLieu?.Rows.Count ?? 0} lượt đăng ký.";
        }
        catch (Exception ex) { _lbl.Text = "Lỗi: " + ex.Message; }
        finally { Cursor = Cursors.Default; }
    }

    /// <summary>Chọn một chi nhánh cụ thể: rẽ kết nối sang đúng server đó.</summary>
    private void LayMotChiNhanh()
    {
        using var cn = _chiNhanh.MoKetNoi();
        using var cmd = new SqlCommand("dbo.sp_BaoCao_DangKy", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@tungay", SqlDbType.Date).Value = _tuNgay.Value.Date;
        cmd.Parameters.Add("@denngay", SqlDbType.Date).Value = _denNgay.Value.Date;

        _duLieu = new DataTable();
        using var da = new SqlDataAdapter(cmd);
        da.Fill(_duLieu);
        _nguonMoTa = $"Nguồn: phân mảnh {_chiNhanh.TenDangChon} — {_duLieu.Rows.Count} dòng. "
                   + "Không truy vấn server chủ.";
    }

    /// <summary>Gộp 2 cơ sở: gọi SP trên TỪNG phân mảnh rồi UNION.</summary>
    private void LayGopHaiCoSo()
    {
        var kq = DataProvider.BaoCaoDangKy_HaiCoSo(_tuNgay.Value, _denNgay.Value);
        _duLieu = kq.Data;
        _nguonMoTa = "Nguồn dữ liệu (UNION từ các PHÂN MẢNH, không qua server chủ):\r\n    "
                   + string.Join("    |    ", kq.NhatKy);
    }

    private BaoCaoIn? TaoBaoCao()
    {
        if (_duLieu == null || _duLieu.Rows.Count == 0)
        { _lbl.Text = "Chưa có dữ liệu để in."; return null; }

        return new BaoCaoIn
        {
            TieuDeBaoCao = "DANH SÁCH ĐĂNG KÝ THI TRẮC NGHIỆM",
            // Tiêu đề ĐỘNG: phạm vi ngày + chi nhánh lấy từ chính form,
            // không truy vấn thêm về server.
            TieuDePhu = $"Từ ngày {_tuNgay.Value:dd/MM/yyyy} đến ngày {_denNgay.Value:dd/MM/yyyy}"
                      + $"  —  {_chiNhanh.TenDangChon}",
            NguonDuLieu = _nguonMoTa.Replace("\r\n", " ").Replace("    ", " "),
            DuLieu = _duLieu,
            DanhSachCot =
            {
                new BaoCaoIn.Cot { Ten = "COSO",      TieuDe = "Cơ sở",      RongPhanTram = 12 },
                new BaoCaoIn.Cot { Ten = "TENLOP",    TieuDe = "Lớp",        RongPhanTram = 13 },
                new BaoCaoIn.Cot { Ten = "TENMH",     TieuDe = "Môn học",    RongPhanTram = 17 },
                new BaoCaoIn.Cot { Ten = "GIANGVIEN", TieuDe = "Giảng viên", RongPhanTram = 16 },
                new BaoCaoIn.Cot { Ten = "NGAYTHI",   TieuDe = "Ngày thi",   RongPhanTram = 11,
                                   DinhDang = "dd/MM/yyyy" },
                new BaoCaoIn.Cot { Ten = "LAN",       TieuDe = "Lần",        RongPhanTram = 5, CanPhai = true },
                new BaoCaoIn.Cot { Ten = "SOCAUTHI",  TieuDe = "Số câu",     RongPhanTram = 8,
                                   CanPhai = true, CongTong = true },
                new BaoCaoIn.Cot { Ten = "DATHI",     TieuDe = "Đã thi",     RongPhanTram = 7 },
                new BaoCaoIn.Cot { Ten = "GHICHU",    TieuDe = "Ghi chú",    RongPhanTram = 18 }
            }
        };
    }

    private void Xuat()
    {
        var bc = TaoBaoCao();
        if (bc == null) return;
        using var hop = new SaveFileDialog
        { Filter = "Tệp CSV cho Excel (*.csv)|*.csv", FileName = "DangKyThi.csv" };
        if (hop.ShowDialog(this) != DialogResult.OK) return;
        bc.XuatCsv(hop.FileName);
        _lbl.Text = "Đã xuất: " + hop.FileName;
    }
}
