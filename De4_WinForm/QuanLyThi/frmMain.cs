namespace QuanLyThi;

/// <summary>
/// Form chính (MDI). Menu hiện ra tuỳ theo nhóm quyền của người đăng nhập,
/// nhưng quyền thật sự vẫn do SQL Server quyết định (role Truong/CoSo/Giangvien/Sinhvien).
/// </summary>
public partial class frmMain : Form
{
    public frmMain()
    {
        InitializeComponent();
        DungMenuTheoVaiTro();
        CapNhatThanhTrangThai();
    }

    private void DungMenuTheoVaiTro()
    {
        bool laTruong = Phien.VaiTro == "Truong";
        bool laCoSo = Phien.VaiTro == "CoSo";
        bool laGV = Phien.VaiTro == "Giangvien";
        bool laSV = Phien.VaiTro == "Sinhvien";

        // Đề: "nhóm Trưởng được quyền đăng nhập vào bất kỳ phân mảnh nào để
        // có thể XEM… xem thôi, không được quyền thêm xóa sửa".
        // => Trưởng vẫn MỞ ĐƯỢC các màn danh mục, nhưng ở chế độ chỉ xem
        //    (frmCrudBase tự khoá nút khi Phien.ChiXem = true, và SQL Server
        //     chỉ GRANT SELECT cho role Truong nên có lách cũng không ghi được).
        mnuDanhMuc.Visible = laCoSo || laGV || laTruong;
        mnuMonHoc.Visible = laCoSo || laTruong;
        mnuKhoaLop.Visible = laCoSo || laTruong;
        mnuSinhVien.Visible = laCoSo || laTruong;
        mnuGiaoVien.Visible = laCoSo || laTruong;
        mnuBoDe.Visible = laGV || laTruong;
        if (laTruong) mnuDanhMuc.Text = "📋  Danh mục (chỉ xem)";

        mnuThi.Visible = laSV || laGV || laCoSo;
        mnuChuanBiThi.Visible = laGV || laCoSo;
        // Đề: "giảng viên được quyền THI THỬ nhưng không ghi điểm"
        // -> giảng viên cũng phải vào được màn hình thi.
        mnuVaoThi.Visible = laSV || laGV;
        mnuVaoThi.Text = laGV ? "✍️  Thi thử (không ghi điểm)" : "✍️  Vào thi";
        mnuXemKetQua.Visible = laSV || laGV || laCoSo;

        // Đề: Trưởng "chạy được tất cả các báo cáo, có 3 báo cáo là chạy hết"
        mnuBaoCao.Visible = laCoSo || laGV || laTruong;
        mnuBangDiem.Visible = laCoSo || laGV || laTruong;
        mnuBaoCaoDangKy.Visible = laTruong || laCoSo;
        mnuTraCuu.Visible = laTruong;

        // Ai cũng vào được để ĐỔI MẬT KHẨU; riêng tab tạo tài khoản thì
        // frmTaiKhoan tự khoá theo quyền (Trưởng -> Truong, CoSo -> CoSo/Giangvien).
        mnuHeThong.Visible = true;
        mnuTaoLogin.Visible = true;
        // Sao lưu: chỉ Trưởng và Cơ sở (SP còn kiểm lại ở tầng CSDL).
        mnuSaoLuu.Visible = laTruong || laCoSo;
    }

    private void mnuTaoLogin_Click(object? sender, EventArgs e)
    {
        using var f = new frmTaiKhoan();
        f.ShowDialog(this);
    }

    private void mnuTraCuu_Click(object? sender, EventArgs e)
    {
        using var f = new frmTraCuu();
        f.ShowDialog(this);
    }

    private void mnuMonHoc_Click(object? sender, EventArgs e) => MoCon(new frmMonHoc());
    private void mnuKhoaLop_Click(object? sender, EventArgs e) => MoCon(new frmKhoaLop());
    private void mnuSinhVien_Click(object? sender, EventArgs e) => MoCon(new frmSinhVien());
    private void mnuGiaoVien_Click(object? sender, EventArgs e) => MoCon(new frmGiaoVien());
    private void mnuBoDe_Click(object? sender, EventArgs e) => MoCon(new frmBoDe());
    private void mnuBangDiem_Click(object? sender, EventArgs e) => MoCon(new frmBangDiem());
    private void mnuChuanBiThi_Click(object? sender, EventArgs e) => MoCon(new frmChuanBiThi());
    private void mnuVaoThi_Click(object? sender, EventArgs e) => MoCon(new frmThi());
    private void mnuXemKetQua_Click(object? sender, EventArgs e) => MoCon(new frmXemKetQua());

    private void mnuSaoLuu_Click(object? sender, EventArgs e)
    {
        using var f = new frmSaoLuu();
        f.ShowDialog(this);
    }
    private void mnuBaoCaoDangKy_Click(object? sender, EventArgs e) => MoCon(new frmBaoCaoDangKy());

    /// <summary>Mở form con trong khung MDI, không mở trùng.</summary>
    private void MoCon(Form f)
    {
        var dangMo = MdiChildren.FirstOrDefault(c => c.GetType() == f.GetType());
        if (dangMo != null) { f.Dispose(); dangMo.Activate(); return; }
        f.MdiParent = this;
        f.WindowState = FormWindowState.Maximized;
        f.Show();
    }

    private void CapNhatThanhTrangThai()
    {
        lblTrangThai.Text =
            $"Phân mảnh: {Phien.TenPhanManh}  ({Phien.Server})   |   " +
            $"Người dùng: {Phien.HoTen} [{Phien.Ma}]   |   Nhóm quyền: {Phien.VaiTro}";
        Text = $"Hệ thống thi trắc nghiệm - {Phien.TenPhanManh}";
    }

    private void ChuaLam(object? sender, EventArgs e)
    {
        var ten = (sender as ToolStripMenuItem)?.Text ?? "Chức năng";
        MessageBox.Show($"[{ten}] chưa được cài đặt.", "Thông báo",
            MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private void mnuDangXuat_Click(object? sender, EventArgs e)
    {
        Phien.Xoa();
        DialogResult = DialogResult.Retry;   // Program.cs sẽ mở lại form đăng nhập
        Close();
    }

    private void mnuThoat_Click(object? sender, EventArgs e) => Application.Exit();
}
