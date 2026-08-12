using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// CÂU 10 - Bảng điểm môn học của một lớp.
///
/// Form này là "FORM TRUNG GIAN" theo bước 4 trong bài giảng của Thầy:
/// cầu nối giữa người dùng và báo cáo — người dùng cung cấp tham số
/// (chi nhánh, lớp, môn, lần thi) rồi bấm Xem trước / In.
///
/// Điểm bắt buộc của đề tài PHÂN TÁN (Thầy nhấn mạnh):
///   có ComboBox CHI NHÁNH để rẽ kết nối sang server tương ứng.
///   Nhóm Trưởng chọn được mọi chi nhánh; nhóm Cơ sở bị khoá (mờ đi).
/// </summary>
public class frmBangDiem : Form
{
    private readonly ComboBox _cboChiNhanh = new();
    private readonly ComboBox _cboDangKy = new();
    private readonly Button _btnXem = new() { Text = "Xem dữ liệu" };
    private readonly Button _btnXemTruoc = new() { Text = "🖨  Xem trước / In" };
    private readonly Button _btnXuat = new() { Text = "📄  Xuất Excel" };
    private readonly DataGridView _luoi = new() { Dock = DockStyle.Fill };
    private readonly StatusStrip _tt = new();
    private readonly ToolStripStatusLabel _lbl = new();

    private ChonChiNhanh _chiNhanh = null!;
    private DataTable _dsDangKy = new();

    public frmBangDiem()
    {
        Text = "Câu 10 - Bảng điểm môn học";
        ClientSize = new Size(1120, 620);
        StartPosition = FormStartPosition.CenterParent;

        _cboChiNhanh.Width = 240;
        _cboDangKy.Width = 420;
        _cboDangKy.DropDownStyle = ComboBoxStyle.DropDownList;
        _btnXem.Click += (_, _) => Xem();
        _btnXemTruoc.Click += (_, _) => XemTruoc();
        _btnXuat.Click += (_, _) => Xuat();

        // Hàng công cụ tự co giãn - không dùng toạ độ pixel cứng
        var hang2 = GiaoDien.TaoHangCongCu(
            GiaoDien.Nhan("Lớp / Môn / Lần:"), _cboDangKy,
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

        _tt.Items.Add(_lbl);
        Controls.Add(_luoi);
        Controls.Add(hang2);
        Controls.Add(hang1);
        Controls.Add(_tt);

        Load += (_, _) =>
        {
            _chiNhanh = new ChonChiNhanh(_cboChiNhanh);
            _chiNhanh.KhiDoiChiNhanh += NapDanhSachDangKy;   // đổi chi nhánh -> nạp lại
            _chiNhanh.Nap();
        };
    }

    /// <summary>
    /// Chỉ liệt kê các kỳ thi ĐÃ ĐĂNG KÝ của chi nhánh đang chọn —
    /// không bắt người dùng gõ tay rồi mới báo lỗi.
    /// </summary>
    private void NapDanhSachDangKy()
    {
        try
        {
            const string SQL = @"
                SELECT dk.MALOP, dk.MAMH, dk.LAN,
                       MOTA = RTRIM(l.TENLOP) + N' - ' + RTRIM(mh.TENMH)
                            + N' - lần ' + CAST(dk.LAN AS nvarchar(2))
                            + N' (' + CONVERT(nvarchar(10), dk.NGAYTHI, 103) + N')'
                FROM dbo.Giaovien_Dangky dk
                  JOIN dbo.Lop    l  ON dk.MALOP = l.MALOP
                  JOIN dbo.Monhoc mh ON dk.MAMH  = mh.MAMH
                ORDER BY dk.NGAYTHI DESC";

            using var cn = _chiNhanh.MoKetNoi();          // <-- RẼ sang chi nhánh đang chọn
            using var da = new SqlDataAdapter(SQL, cn);
            _dsDangKy = new DataTable();
            da.Fill(_dsDangKy);

            _cboDangKy.DataSource = _dsDangKy;
            _cboDangKy.DisplayMember = "MOTA";

            if (_dsDangKy.Rows.Count == 0)
            {
                _luoi.DataSource = null;
                _lbl.Text = $"Chi nhánh {_chiNhanh.TenDangChon}: chưa có kỳ thi nào được đăng ký.";
            }
            else Xem();
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    private DataTable? _duLieu;

    private void Xem()
    {
        if (_cboDangKy.SelectedItem is not DataRowView r) return;
        try
        {
            using var cn = _chiNhanh.MoKetNoi();
            using var cmd = new SqlCommand("dbo.sp_BangDiemMonHoc", cn)
            { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@MALOP", SqlDbType.NChar, 15).Value = r["MALOP"];
            cmd.Parameters.Add("@MAMH", SqlDbType.Char, 5).Value = r["MAMH"];
            cmd.Parameters.Add("@LAN", SqlDbType.SmallInt).Value = r["LAN"];

            _duLieu = new DataTable();
            using (var da = new SqlDataAdapter(cmd)) da.Fill(_duLieu);

            _luoi.DataSource = _duLieu;
            frmCrudBase.DatCot(_luoi, "TENLOP", "Lớp", 14);
            frmCrudBase.DatCot(_luoi, "TENMH", "Môn học", 18);
            frmCrudBase.DatCot(_luoi, "LAN", "Lần", 6);
            frmCrudBase.DatCot(_luoi, "MASV", "Mã SV", 10);
            frmCrudBase.DatCot(_luoi, "HOTEN", "Họ tên", 22);
            frmCrudBase.DatCot(_luoi, "DIEM", "Điểm", 8);
            frmCrudBase.DatCot(_luoi, "DIEMCHU", "Điểm chữ", 10);
            frmCrudBase.DatCot(_luoi, "NGAYTHI", "Ngày thi", 12);

            _lbl.Text = $"{_chiNhanh.TenDangChon} — {_duLieu.Rows.Count} sinh viên. "
                      + "Điểm đã làm tròn đến 0.5 theo mẫu của trường.";
        }
        catch (SqlException ex) { _lbl.Text = "Lỗi: " + ex.Message; }
    }

    /// <summary>Dựng báo cáo theo đúng cấu trúc band Thầy dạy.</summary>
    private BaoCaoIn? TaoBaoCao()
    {
        if (_duLieu == null || _duLieu.Rows.Count == 0)
        { _lbl.Text = "Chưa có dữ liệu để in."; return null; }

        var d0 = _duLieu.Rows[0];
        // Tiêu đề ĐỘNG: lấy từ dữ liệu đã có sẵn, KHÔNG truy vấn lại server
        return new BaoCaoIn
        {
            TieuDeBaoCao = "BẢNG ĐIỂM MÔN HỌC",
            TieuDePhu = $"Lớp {d0["TENLOP"]}  —  Môn {d0["TENMH"]}  —  Lần thi {d0["LAN"]}",
            NguonDuLieu = $"Chi nhánh: {_chiNhanh.TenDangChon}   ·   In lúc {DateTime.Now:dd/MM/yyyy HH:mm}",
            DuLieu = _duLieu,
            DanhSachCot =
            {
                new BaoCaoIn.Cot { Ten = "MASV",    TieuDe = "Mã SV",     RongPhanTram = 12 },
                new BaoCaoIn.Cot { Ten = "HOTEN",   TieuDe = "Họ và tên", RongPhanTram = 34 },
                new BaoCaoIn.Cot { Ten = "DIEM",    TieuDe = "Điểm",      RongPhanTram = 12,
                                   CanPhai = true, DinhDang = "N1" },
                new BaoCaoIn.Cot { Ten = "DIEMCHU", TieuDe = "Điểm chữ",  RongPhanTram = 12 },
                // Cột XẾP LOẠI: TÍNH TẠI MÁY TRẠM, không tải từ server
                // (Thầy: dữ liệu nào tính được trong report thì đừng truy vấn)
                new BaoCaoIn.Cot { Ten = "XEPLOAI", TieuDe = "Xếp loại",  RongPhanTram = 18,
                                   CotTinh = r => XepLoai(r) },
                new BaoCaoIn.Cot { Ten = "DAT",     TieuDe = "Đạt",       RongPhanTram = 12,
                                   CanPhai = true, CongTong = true,
                                   CotTinh = r => Convert.ToDouble(r["DIEM"]) >= 5 ? 1 : 0 }
            }
        };
    }

    private static string XepLoai(DataRow r)
    {
        var d = Convert.ToDouble(r["DIEM"]);
        return d >= 8.5 ? "Giỏi" : d >= 7 ? "Khá" : d >= 5.5 ? "Trung bình khá"
             : d >= 5 ? "Trung bình" : d >= 4 ? "Yếu" : "Kém";
    }

    private void XemTruoc()
    {
        var bc = TaoBaoCao();
        bc?.XemTruoc(this);
    }

    private void Xuat()
    {
        var bc = TaoBaoCao();
        if (bc == null) return;
        using var hop = new SaveFileDialog
        { Filter = "Tệp CSV cho Excel (*.csv)|*.csv", FileName = "BangDiem.csv" };
        if (hop.ShowDialog(this) != DialogResult.OK) return;
        bc.XuatCsv(hop.FileName);
        _lbl.Text = "Đã xuất: " + hop.FileName;
    }
}
