#nullable disable

namespace QuanLyThi;

partial class frmTaiKhoan
{
    private System.ComponentModel.IContainer components = null;

    private TabControl tab;
    private TabPage tabTao, tabDoiMK;

    // --- Tab tạo tài khoản ---
    private Label lblUser, lblPass, lblNhom, lblGhiChu;
    private TextBox txtUser, txtPass;
    private ComboBox cboNhom;
    private Button btnTao;

    // --- Tab đổi mật khẩu ---
    private Label lblCu, lblMoi, lblXacNhan;
    private TextBox txtCu, txtMoi, txtXacNhan;
    private Button btnDoi;

    private Label lblKetQua;

    protected override void Dispose(bool disposing)
    {
        if (disposing && components != null) components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        tab = new TabControl();
        tabTao = new TabPage("Tạo tài khoản");
        tabDoiMK = new TabPage("Đổi mật khẩu");

        lblUser = new Label(); lblPass = new Label(); lblNhom = new Label(); lblGhiChu = new Label();
        txtUser = new TextBox(); txtPass = new TextBox(); cboNhom = new ComboBox(); btnTao = new Button();

        lblCu = new Label(); lblMoi = new Label(); lblXacNhan = new Label();
        txtCu = new TextBox(); txtMoi = new TextBox(); txtXacNhan = new TextBox(); btnDoi = new Button();

        lblKetQua = new Label();
        SuspendLayout();

        /* ---------- Tab TẠO TÀI KHOẢN ---------- */
        lblUser.Text = "Tên đăng nhập:";
        lblUser.Location = new Point(24, 26); lblUser.Size = new Size(130, 23);
        lblUser.TextAlign = ContentAlignment.MiddleLeft;

        txtUser.Location = new Point(160, 24); txtUser.Size = new Size(240, 25);
        txtUser.CharacterCasing = CharacterCasing.Upper;

        lblPass.Text = "Mật khẩu:";
        lblPass.Location = new Point(24, 62); lblPass.Size = new Size(130, 23);
        lblPass.TextAlign = ContentAlignment.MiddleLeft;

        txtPass.Location = new Point(160, 60); txtPass.Size = new Size(240, 25);
        txtPass.UseSystemPasswordChar = true;

        lblNhom.Text = "Nhóm quyền:";
        lblNhom.Location = new Point(24, 98); lblNhom.Size = new Size(130, 23);
        lblNhom.TextAlign = ContentAlignment.MiddleLeft;

        cboNhom.Location = new Point(160, 96); cboNhom.Size = new Size(240, 25);
        cboNhom.DropDownStyle = ComboBoxStyle.DropDownList;

        lblGhiChu.Location = new Point(24, 130); lblGhiChu.Size = new Size(420, 56);
        lblGhiChu.ForeColor = SystemColors.GrayText;

        btnTao.Text = "Tạo tài khoản";
        btnTao.Location = new Point(160, 192); btnTao.Size = new Size(140, 34);
        btnTao.Click += btnTao_Click;

        tabTao.Controls.AddRange(new Control[]
            { lblUser, txtUser, lblPass, txtPass, lblNhom, cboNhom, lblGhiChu, btnTao });

        /* ---------- Tab ĐỔI MẬT KHẨU ---------- */
        lblCu.Text = "Mật khẩu hiện tại:";
        lblCu.Location = new Point(24, 26); lblCu.Size = new Size(130, 23);
        lblCu.TextAlign = ContentAlignment.MiddleLeft;
        txtCu.Location = new Point(160, 24); txtCu.Size = new Size(240, 25);
        txtCu.UseSystemPasswordChar = true;

        lblMoi.Text = "Mật khẩu mới:";
        lblMoi.Location = new Point(24, 62); lblMoi.Size = new Size(130, 23);
        lblMoi.TextAlign = ContentAlignment.MiddleLeft;
        txtMoi.Location = new Point(160, 60); txtMoi.Size = new Size(240, 25);
        txtMoi.UseSystemPasswordChar = true;

        lblXacNhan.Text = "Nhập lại:";
        lblXacNhan.Location = new Point(24, 98); lblXacNhan.Size = new Size(130, 23);
        lblXacNhan.TextAlign = ContentAlignment.MiddleLeft;
        txtXacNhan.Location = new Point(160, 96); txtXacNhan.Size = new Size(240, 25);
        txtXacNhan.UseSystemPasswordChar = true;

        btnDoi.Text = "Đổi mật khẩu";
        btnDoi.Location = new Point(160, 150); btnDoi.Size = new Size(140, 34);
        btnDoi.Click += btnDoi_Click;

        tabDoiMK.Controls.AddRange(new Control[]
            { lblCu, txtCu, lblMoi, txtMoi, lblXacNhan, txtXacNhan, btnDoi });

        /* ---------- Form ---------- */
        tab.Location = new Point(12, 12);
        tab.Size = new Size(470, 250);
        tab.TabPages.AddRange(new TabPage[] { tabTao, tabDoiMK });

        lblKetQua.Location = new Point(16, 270);
        lblKetQua.Size = new Size(466, 44);

        AutoScaleDimensions = new SizeF(7F, 15F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(498, 324);
        Controls.Add(tab);
        Controls.Add(lblKetQua);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false; MinimizeBox = false;
        StartPosition = FormStartPosition.CenterParent;
        Text = "Quản trị tài khoản";
        Load += frmTaiKhoan_Load;
        ResumeLayout(false);
    }
}
