using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// Câu 1 - phần quản trị: tạo tài khoản đăng nhập + đổi mật khẩu.
/// Quyền tạo tài khoản (đề quy định, SP_TAOLOGIN kiểm lại ở tầng CSDL):
///   - Trưởng  -> CHỈ tạo được nhóm Truong
///   - Cơ sở   -> tạo được CoSo và Giangvien
/// </summary>
public partial class frmTaiKhoan : Form
{
    public frmTaiKhoan() => InitializeComponent();

    private void frmTaiKhoan_Load(object? sender, EventArgs e)
    {
        // Danh sách nhóm hiện ra đúng theo quyền của người đang đăng nhập.
        cboNhom.Items.Clear();
        switch (Phien.VaiTro)
        {
            case "Truong":
                cboNhom.Items.Add("Truong");
                lblGhiChu.Text = "Nhóm Trưởng chỉ được tạo tài khoản thuộc nhóm Truong.";
                break;
            case "CoSo":
                cboNhom.Items.AddRange(new object[] { "CoSo", "Giangvien" });
                lblGhiChu.Text = "Nhóm Cơ sở tạo được tài khoản CoSo và Giangvien.\r\n" +
                                 "Với Giangvien: tên đăng nhập PHẢI trùng mã giáo viên (MAGV) " +
                                 "và giáo viên đó phải được khai báo trước.";
                break;
            default:
                tabTao.Enabled = false;
                lblGhiChu.Text = "Bạn không có quyền tạo tài khoản.";
                break;
        }
        if (cboNhom.Items.Count > 0) cboNhom.SelectedIndex = 0;

        // Sinh viên đổi mật khẩu trong bảng SINHVIEN; cán bộ đổi mật khẩu SQL login.
        tabDoiMK.Text = Phien.LaSinhVien ? "Đổi mật khẩu (sinh viên)" : "Đổi mật khẩu";
    }

    private void btnTao_Click(object? sender, EventArgs e)
    {
        lblKetQua.ForeColor = Color.Firebrick;
        var user = txtUser.Text.Trim();
        var pass = txtPass.Text;
        var nhom = cboNhom.SelectedItem?.ToString();

        if (user.Length == 0 || pass.Length < 3 || nhom == null)
        {
            lblKetQua.Text = "Nhập đủ tên đăng nhập, mật khẩu (>= 3 ký tự) và chọn nhóm quyền.";
            return;
        }

        try
        {
            var dt = DataProvider.GoiSP("dbo.SP_TAOLOGIN",
                new SqlParameter("@username", SqlDbType.NVarChar, 128) { Value = user },
                new SqlParameter("@password", SqlDbType.NVarChar, 128) { Value = pass },
                new SqlParameter("@role", SqlDbType.NVarChar, 128) { Value = nhom });

            lblKetQua.ForeColor = Color.SeaGreen;
            lblKetQua.Text = dt.Rows.Count > 0
                ? dt.Rows[0][0]?.ToString()
                : $"Đã tạo tài khoản {user}.";
            txtUser.Clear(); txtPass.Clear();
        }
        catch (SqlException ex)
        {
            lblKetQua.Text = ex.Message;
        }
    }

    private void btnDoi_Click(object? sender, EventArgs e)
    {
        lblKetQua.ForeColor = Color.Firebrick;

        if (txtMoi.Text != txtXacNhan.Text)
        {
            lblKetQua.Text = "Mật khẩu mới nhập lại không khớp.";
            txtXacNhan.SelectAll(); txtXacNhan.Focus();
            return;
        }
        if (txtMoi.Text.Length < 3)
        {
            lblKetQua.Text = "Mật khẩu mới phải có ít nhất 3 ký tự.";
            return;
        }

        try
        {
            DataTable dt;
            if (Phien.LaSinhVien)
            {
                // Sinh viên dùng SQL login chung -> mật khẩu nằm trong bảng SINHVIEN.
                dt = DataProvider.GoiSP("dbo.sp_DoiMatKhau_SV",
                    new SqlParameter("@MASV", SqlDbType.NChar, 8) { Value = Phien.Ma },
                    new SqlParameter("@MatKhauCu", SqlDbType.NVarChar, 30) { Value = txtCu.Text },
                    new SqlParameter("@MatKhauMoi", SqlDbType.NVarChar, 30) { Value = txtMoi.Text });
            }
            else
            {
                // Cán bộ có SQL login riêng -> ALTER LOGIN.
                dt = DataProvider.GoiSP("dbo.SP_DOIMATKHAU",
                    new SqlParameter("@MatKhauCu", SqlDbType.NVarChar, 128) { Value = txtCu.Text },
                    new SqlParameter("@MatKhauMoi", SqlDbType.NVarChar, 128) { Value = txtMoi.Text });
                // Mật khẩu của phiên đã đổi -> cập nhật để các kết nối sau vẫn chạy.
                Phien.MatKhau = txtMoi.Text;
            }

            lblKetQua.ForeColor = Color.SeaGreen;
            lblKetQua.Text = dt.Rows.Count > 0 ? dt.Rows[0][0]?.ToString() : "Đổi mật khẩu thành công.";
            txtCu.Clear(); txtMoi.Clear(); txtXacNhan.Clear();
        }
        catch (SqlException ex)
        {
            lblKetQua.Text = ex.Message;
        }
    }
}
