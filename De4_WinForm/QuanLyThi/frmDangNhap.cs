using System.Data;

namespace QuanLyThi;

/// <summary>
/// Form đăng nhập - theo mẫu "HD FORM DANG NHAP":
/// ComboBox liệt kê các phân mảnh lấy từ view V_DS_PHANMANH trên Publisher.
/// </summary>
public partial class frmDangNhap : Form
{
    public frmDangNhap()
    {
        InitializeComponent();

        // Dải tiêu đề màu + biểu tượng cho dễ nhìn
        lblTieuDe.Text = "🎓  HỆ THỐNG THI TRẮC NGHIỆM";
        lblTieuDe.ForeColor = Color.White;
        lblTieuDe.BackColor = GiaoDien.XanhChinh;
        lblTieuDe.Dock = DockStyle.Top;
        lblTieuDe.Height = 56;

        lblPhanManh.Text = "🌐  Phân mảnh:";
        lblMa.Text = "👤  Mã / Tài khoản:";
        lblMatKhau.Text = "🔒  Mật khẩu:";

        GiaoDien.TrangTriNut(btnDangNhap, nhanManh: true);
        GiaoDien.TrangTriNut(btnThoat);
        btnDangNhap.Text = "Đăng nhập";
        btnThoat.Text = "Thoát";

        BackColor = Color.White;
        Font = GiaoDien.ChuThuong;
    }

    private void frmDangNhap_Load(object? sender, EventArgs e)
    {
        var dt = DataProvider.LayDanhSachPhanManh();
        cboPhanManh.DataSource = dt;
        cboPhanManh.DisplayMember = "TENCN";     // tên hiển thị
        cboPhanManh.ValueMember = "TENSERVER";   // giá trị dùng để kết nối
        cboPhanManh.SelectedIndex = dt.Rows.Count > 0 ? 0 : -1;
        txtMa.Focus();
    }

    private void btnDangNhap_Click(object? sender, EventArgs e)
    {
        lblThongBao.Text = "";

        if (cboPhanManh.SelectedIndex < 0)
        {
            lblThongBao.Text = "Chưa chọn phân mảnh.";
            return;
        }
        var ma = txtMa.Text.Trim();
        if (ma.Length == 0)
        {
            lblThongBao.Text = "Chưa nhập mã / tài khoản.";
            txtMa.Focus();
            return;
        }

        var server = cboPhanManh.SelectedValue?.ToString() ?? "";
        var tenPhanManh = (cboPhanManh.SelectedItem as DataRowView)?["TENCN"]?.ToString() ?? server;

        Cursor = Cursors.WaitCursor;
        try
        {
            DataProvider.DangNhap(server, tenPhanManh, ma, txtMatKhau.Text);
            DialogResult = DialogResult.OK;
            Close();
        }
        catch (Exception ex)
        {
            lblThongBao.Text = ex.Message;
            txtMatKhau.SelectAll();
            txtMatKhau.Focus();
        }
        finally
        {
            Cursor = Cursors.Default;
        }
    }

    private void btnThoat_Click(object? sender, EventArgs e)
    {
        DialogResult = DialogResult.Cancel;
        Close();
    }
}
