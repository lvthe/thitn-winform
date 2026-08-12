namespace QuanLyThi;

/// <summary>
/// Chức năng SỬ DỤNG MẢNH 3 (phân mảnh dọc trên SERVER3).
/// Đề yêu cầu: mảnh 3 không cho đăng nhập, nhưng phải có ít nhất một
/// chức năng dùng tới nó để "tra cứu mã sinh viên có chưa, mã lớp có chưa".
/// Ứng dụng kết nối bằng tài khoản dịch vụ chỉ-đọc [tracuu].
/// </summary>
public partial class frmTraCuu : Form
{
    public frmTraCuu()
    {
        InitializeComponent();
        GiaoDien.TrangTriLuoi(grid);
        GiaoDien.TrangTriNut(btnTim, nhanManh: true);
        GiaoDien.TrangTriNut(btnKiemTraMa);
        Font = GiaoDien.ChuThuong;
    }

    private void frmTraCuu_Load(object? sender, EventArgs e) => Nap();

    private void btnTim_Click(object? sender, EventArgs e) => Nap();

    private void Nap()
    {
        Cursor = Cursors.WaitCursor;
        try
        {
            var dt = DataProvider.TraCuuSinhVien(txtTim.Text);
            grid.DataSource = dt;
            lblTongKet.ForeColor = SystemColors.ControlText;
            lblTongKet.Text = $"Tìm thấy {dt.Rows.Count} sinh viên (cả hai cơ sở).";
        }
        catch (Exception ex)
        {
            lblTongKet.ForeColor = Color.Firebrick;
            lblTongKet.Text = "Không đọc được mảnh tra cứu: " + ex.Message;
        }
        finally { Cursor = Cursors.Default; }
    }

    private void btnKiemTraMa_Click(object? sender, EventArgs e)
    {
        var ma = txtTim.Text.Trim();
        if (ma.Length == 0)
        {
            lblTongKet.ForeColor = Color.Firebrick;
            lblTongKet.Text = "Nhập mã cần kiểm tra vào ô từ khoá.";
            return;
        }

        try
        {
            bool coSV = DataProvider.MaSinhVienDaTonTai(ma);
            bool coLop = DataProvider.MaLopDaTonTai(ma);

            lblTongKet.ForeColor = (coSV || coLop) ? Color.Firebrick : Color.SeaGreen;
            lblTongKet.Text = (coSV, coLop) switch
            {
                (true, _) => $"Mã sinh viên '{ma}' ĐÃ TỒN TẠI (ở một trong hai cơ sở).",
                (_, true) => $"Mã lớp '{ma}' ĐÃ TỒN TẠI (ở một trong hai cơ sở).",
                _ => $"Mã '{ma}' chưa tồn tại - có thể dùng."
            };
        }
        catch (Exception ex)
        {
            lblTongKet.ForeColor = Color.Firebrick;
            lblTongKet.Text = "Lỗi tra cứu: " + ex.Message;
        }
    }
}
