using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// Form nhập liệu chuẩn dùng lại cho câu 2..6.
/// Bộ nút theo đúng yêu cầu của đề: Thêm - Sửa - Xóa - Ghi - Phục hồi.
///   * Ghi      : tự biết đang Thêm (INSERT) hay đang Sửa (UPDATE).
///   * Phục hồi : hủy các thao tác CHƯA ghi, trả về dữ liệu ban đầu.
/// Lớp con chỉ cần gọi CauHinh(...) trong Load.
/// </summary>
public partial class frmCrudBase : Form
{
    protected BangCrud? Bang;
    protected readonly BindingSource Nguon = new();
    private bool _chiDoc;

    public frmCrudBase()
    {
        InitializeComponent();
        GiaoDien.TrangTriLuoi(luoi);
        GiaoDien.TrangTriThanhNut(thanhNut);
        Font = GiaoDien.ChuThuong;
    }

    /// <summary>
    /// Lớp con gọi hàm này để khai báo bảng và cột hiển thị.
    /// Nếu người đăng nhập thuộc nhóm Trưởng thì form TỰ ĐỘNG chuyển sang
    /// chế độ chỉ xem, không cần lớp con phải nhớ truyền tham số.
    /// </summary>
    protected void CauHinh(BangCrud bang, bool chiDoc = false)
    {
        Bang = bang;
        _chiDoc = chiDoc || Phien.ChiXem;
        if (_chiDoc) HienBangChiXem();
        Nap();
    }

    /// <summary>Băng nhắc phía trên lưới khi form đang ở chế độ chỉ xem.</summary>
    private void HienBangChiXem()
    {
        if (Controls.ContainsKey("bangChiXem")) return;
        var bang = new Label
        {
            Name = "bangChiXem",
            Dock = DockStyle.Top,
            Height = LogicalToDeviceUnits(30),
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(LogicalToDeviceUnits(10), 0, 0, 0),
            BackColor = Color.FromArgb(255, 244, 214),
            ForeColor = Color.FromArgb(124, 84, 0),
            Font = GiaoDien.ChuDam,
            Text = "🔒  Chế độ CHỈ XEM — nhóm Trưởng không được thêm / sửa / xóa dữ liệu."
        };
        Controls.Add(bang);
        // Với control neo Top, control có z-index LỚN hơn được neo TRƯỚC.
        // Muốn thứ tự trên xuống là: thanh nút -> băng nhắc -> lưới,
        // thì băng phải đứng NGAY TRƯỚC thanh nút trong danh sách
        // (đặt vào đúng vị trí của thanh nút, đẩy thanh nút lùi 1 bậc).
        Controls.SetChildIndex(bang, Controls.GetChildIndex(thanhNut));
    }

    protected virtual SqlParameter[] ThamSoNap() => Array.Empty<SqlParameter>();

    /// <summary>Lớp con ghi đè để đặt giá trị mặc định cho dòng mới.</summary>
    protected virtual void KhiThemDong(DataRow dong) { }

    protected void Nap()
    {
        if (Bang == null) return;
        try
        {
            Bang.Nap(ThamSoNap());
            Nguon.DataSource = Bang.Data;
            luoi.DataSource = Nguon;
            CapNhatNut();
            BaoTrangThai($"Đã nạp {Bang.Data.Rows.Count} dòng.", false);
        }
        catch (Exception ex) { BaoTrangThai(ex.Message, true); }
    }

    private void CapNhatNut()
    {
        bool coThayDoi = Bang?.CoThayDoi == true;
        int soBuoc = Bang?.SoBuocLuiDuoc ?? 0;

        btnThem.Enabled = !_chiDoc;
        btnXoa.Enabled = !_chiDoc && Nguon.Count > 0;
        btnGhi.Enabled = !_chiDoc && coThayDoi;
        // Phục hồi bật khi có thay đổi chưa ghi HOẶC còn bước đã ghi để lùi.
        btnPhucHoi.Enabled = !_chiDoc && (coThayDoi || soBuoc > 0);
        btnPhucHoi.Text = coThayDoi ? "Phục hồi"
                        : soBuoc > 0 ? $"Phục hồi ({soBuoc})" : "Phục hồi";
        luoi.ReadOnly = _chiDoc;
    }

    /// <summary>Đặt tiêu đề (và độ rộng) cho một cột nếu cột đó tồn tại.</summary>
    public static void DatCot(DataGridView g, string cot, string tieuDe, int trongSo = 0)
    {
        if (!g.Columns.Contains(cot)) return;
        var c = g.Columns[cot];
        if (c == null) return;
        c.HeaderText = tieuDe;
        if (trongSo > 0) c.FillWeight = trongSo;
    }

    protected void BaoTrangThai(string text, bool loi)
    {
        lblTrangThai.ForeColor = loi ? Color.Firebrick : SystemColors.ControlText;
        lblTrangThai.Text = text;
    }

    /* ---------------- Sự kiện các nút ---------------- */

    private void btnThem_Click(object? sender, EventArgs e)
    {
        if (Bang == null) return;
        try
        {
            Nguon.EndEdit();
            var dong = BangCrud.TaoDongMoi(Bang.Data);   // điền sẵn cột NOT NULL
            KhiThemDong(dong);
            Bang.Data.Rows.Add(dong);
            Nguon.Position = Nguon.Count - 1;
            CapNhatNut();
            BaoTrangThai("Đang thêm dòng mới - nhập xong bấm Ghi.", false);
            luoi.Focus();
        }
        catch (Exception ex)
        {
            BaoTrangThai("Không thêm được dòng mới: " + ex.Message, true);
        }
    }

    private void btnXoa_Click(object? sender, EventArgs e)
    {
        if (Nguon.Current is not DataRowView drv) return;
        if (MessageBox.Show("Xóa dòng đang chọn?", "Xác nhận",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        drv.Row.Delete();
        CapNhatNut();
        BaoTrangThai("Đã đánh dấu xóa - bấm Ghi để lưu, hoặc Phục hồi để hủy.", false);
    }

    /// <summary>
    /// Kiểm tra dữ liệu trước khi ghi. Mặc định: các dòng THÊM MỚI phải
    /// nhập đủ khóa chính (không để trống). Lớp con ghi đè để kiểm thêm,
    /// nhớ gọi base.KiemTraTruocKhiGhi() để giữ phần kiểm này.
    /// Trả về false thì hủy thao tác Ghi.
    /// </summary>
    protected virtual bool KiemTraTruocKhiGhi()
    {
        if (Bang == null) return false;
        if (Bang.CotKhoa.Length == 0) return true;

        foreach (var dong in Bang.Data.Select(null, null, DataViewRowState.Added))
            foreach (var cot in Bang.CotKhoa)
            {
                var v = dong[cot]?.ToString()?.Trim() ?? "";
                if (v.Length == 0)
                {
                    BaoTrangThai($"Chưa nhập {cot} cho dòng mới.", true);
                    return false;
                }
            }
        return true;
    }

    private void btnGhi_Click(object? sender, EventArgs e)
    {
        if (Bang == null) return;
        try
        {
            Nguon.EndEdit();
            if (!KiemTraTruocKhiGhi()) return;
            var n = Bang.Ghi();
            CapNhatNut();
            BaoTrangThai($"Đã ghi {n} dòng.", false);
        }
        catch (SqlException ex) { BaoTrangThai("Không ghi được: " + ex.Message, true); }
        catch (DBConcurrencyException) { BaoTrangThai("Dữ liệu đã bị người khác thay đổi. Hãy Nạp lại.", true); }
    }

    /// <summary>
    /// PHỤC HỒI (Undo) hai mức:
    ///   1. Còn thay đổi CHƯA ghi  -> hủy phần chưa ghi (mức cơ bản của đề).
    ///   2. Không còn gì chưa ghi  -> LÙI MỘT BƯỚC đã ghi, lấy từ Stack lịch
    ///      sử. Bấm tiếp để lùi thêm -> undo NHIỀU CẤP (option cộng điểm).
    /// </summary>
    private void btnPhucHoi_Click(object? sender, EventArgs e)
    {
        if (Bang == null) return;

        if (Bang.CoThayDoi)
        {
            Nguon.CancelEdit();
            Bang.PhucHoi();
            CapNhatNut();
            BaoTrangThai("Đã phục hồi - mọi thay đổi chưa ghi đã được hủy.", false);
            return;
        }

        if (Bang.SoBuocLuiDuoc == 0)
        {
            BaoTrangThai("Không còn thao tác nào để phục hồi.", false);
            return;
        }

        try
        {
            Nguon.CancelEdit();
            var n = Bang.LuiMotBuoc();
            Nguon.ResetBindings(false);
            CapNhatNut();
            BaoTrangThai($"Đã lùi lại 1 bước đã ghi ({n} dòng được khôi phục). "
                       + $"Còn {Bang.SoBuocLuiDuoc} bước có thể lùi tiếp.", false);
        }
        catch (SqlException ex) { BaoTrangThai("Không lùi được: " + ex.Message, true); }
        catch (InvalidOperationException ex) { BaoTrangThai(ex.Message, true); }
    }

    private void btnNapLai_Click(object? sender, EventArgs e) => Nap();

    private void luoi_Thay_Doi(object? sender, EventArgs e) => CapNhatNut();
}
