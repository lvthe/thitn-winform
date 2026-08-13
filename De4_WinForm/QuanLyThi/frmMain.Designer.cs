#nullable disable

namespace QuanLyThi;

partial class frmMain
{
    private System.ComponentModel.IContainer components = null;

    private MenuStrip menuChinh;
    private StatusStrip thanhTrangThai;
    private ToolStripStatusLabel lblTrangThai;

    private ToolStripMenuItem mnuDanhMuc, mnuMonHoc, mnuKhoaLop, mnuSinhVien, mnuGiaoVien, mnuBoDe;
    private ToolStripMenuItem mnuThi, mnuPhanCong, mnuChuanBiThi, mnuVaoThi, mnuXemKetQua;
    private ToolStripMenuItem mnuBaoCao, mnuBangDiem, mnuBaoCaoDangKy, mnuTraCuu;
    private ToolStripMenuItem mnuHeThong, mnuTaoLogin, mnuSaoLuu, mnuDangXuat, mnuThoat;

    protected override void Dispose(bool disposing)
    {
        if (disposing && components != null) components.Dispose();
        base.Dispose(disposing);
    }

    /// <summary>Mục menu cha (chỉ chứa mục con, không có hành động).</summary>
    private ToolStripMenuItem Muc(string text) => new ToolStripMenuItem(text);

    /// <summary>Mục menu có hành động khi bấm.</summary>
    private ToolStripMenuItem Muc(string text, EventHandler click)
    {
        var m = new ToolStripMenuItem(text);
        m.Click += click;
        return m;
    }

    private void InitializeComponent()
    {
        menuChinh = new MenuStrip();
        thanhTrangThai = new StatusStrip();
        lblTrangThai = new ToolStripStatusLabel();
        SuspendLayout();

        // --- Danh mục (câu 2..6) ---
        mnuMonHoc = Muc("📚  Môn học", mnuMonHoc_Click);
        mnuKhoaLop = Muc("🏫  Khoa && Lớp (chung form)", mnuKhoaLop_Click);
        mnuSinhVien = Muc("🎓  Sinh viên", mnuSinhVien_Click);
        mnuGiaoVien = Muc("👨‍🏫  Giáo viên", mnuGiaoVien_Click);
        mnuBoDe = Muc("❓  Bộ đề", mnuBoDe_Click);
        mnuDanhMuc = Muc("📋  Danh mục");
        mnuDanhMuc.DropDownItems.AddRange(new ToolStripItem[]
            { mnuMonHoc, mnuKhoaLop, mnuSinhVien, mnuGiaoVien, mnuBoDe });

        // --- Thi (câu 7,8,9) ---
        // Phân công đứng TRƯỚC Chuẩn bị thi vì đó là thứ tự nghiệp vụ:
        // Cơ sở phân công -> giảng viên soạn đề -> mới đăng ký được kỳ thi.
        mnuPhanCong = Muc("🧑‍🏫  Phân công giảng dạy", mnuPhanCong_Click);
        mnuChuanBiThi = Muc("📅  Chuẩn bị thi (đăng ký)", mnuChuanBiThi_Click);
        mnuVaoThi = Muc("✍️  Vào thi", mnuVaoThi_Click);
        mnuXemKetQua = Muc("🔍  Xem lại bài thi", mnuXemKetQua_Click);
        mnuThi = Muc("📝  Thi");
        mnuThi.DropDownItems.AddRange(new ToolStripItem[]
            { mnuPhanCong, mnuChuanBiThi, mnuVaoThi, mnuXemKetQua });

        // --- Báo cáo (câu 10, 11) + tra cứu phân mảnh ---
        mnuBangDiem = Muc("🏆  Bảng điểm môn học", mnuBangDiem_Click);
        mnuBaoCaoDangKy = Muc("🌐  Đăng ký thi (2 cơ sở)", mnuBaoCaoDangKy_Click);
        mnuTraCuu = Muc("🔎  Tra cứu (mảnh dọc)", mnuTraCuu_Click);
        mnuBaoCao = Muc("📊  Báo cáo");
        mnuBaoCao.DropDownItems.AddRange(new ToolStripItem[]
            { mnuBangDiem, mnuBaoCaoDangKy, mnuTraCuu });

        // --- Hệ thống (câu 1: tạo login) ---
        mnuTaoLogin = Muc("🔑  Tài khoản && mật khẩu", mnuTaoLogin_Click);
        mnuDangXuat = Muc("🚪  Đăng xuất", mnuDangXuat_Click);
        mnuThoat = Muc("❌  Thoát", mnuThoat_Click);
        mnuSaoLuu = Muc("💾  Sao lưu / Phục hồi dữ liệu", mnuSaoLuu_Click);
        mnuHeThong = Muc("⚙️  Hệ thống");
        mnuHeThong.DropDownItems.AddRange(new ToolStripItem[] { mnuTaoLogin, mnuSaoLuu });

        var mnuTapTin = Muc("📁  Tệp");
        mnuTapTin.DropDownItems.AddRange(new ToolStripItem[]
            { mnuDangXuat, new ToolStripSeparator(), mnuThoat });

        menuChinh.Items.AddRange(new ToolStripItem[]
            { mnuTapTin, mnuDanhMuc, mnuThi, mnuBaoCao, mnuHeThong });

        // Giao diện menu: chữ to hơn, có khoảng thở
        menuChinh.Font = new Font("Segoe UI", 10F);
        menuChinh.Padding = new Padding(6, 3, 6, 3);
        menuChinh.RenderMode = ToolStripRenderMode.System;

        // --- Thanh trạng thái ---
        lblTrangThai.Text = "";
        thanhTrangThai.Items.Add(lblTrangThai);

        // --- frmMain ---
        AutoScaleDimensions = new SizeF(7F, 15F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(1000, 620);
        Controls.Add(thanhTrangThai);
        Controls.Add(menuChinh);
        MainMenuStrip = menuChinh;
        IsMdiContainer = true;
        StartPosition = FormStartPosition.CenterScreen;
        Text = "Hệ thống thi trắc nghiệm";
        ResumeLayout(false);
        PerformLayout();
    }
}
