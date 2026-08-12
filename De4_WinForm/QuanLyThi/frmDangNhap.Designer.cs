#nullable disable

namespace QuanLyThi;

partial class frmDangNhap
{
    private System.ComponentModel.IContainer components = null;

    private Label lblTieuDe;
    private Label lblPhanManh;
    private ComboBox cboPhanManh;
    private Label lblMa;
    private TextBox txtMa;
    private Label lblMatKhau;
    private TextBox txtMatKhau;
    private Button btnDangNhap;
    private Button btnThoat;
    private Label lblThongBao;

    protected override void Dispose(bool disposing)
    {
        if (disposing && components != null) components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        lblTieuDe = new Label();
        lblPhanManh = new Label();
        cboPhanManh = new ComboBox();
        lblMa = new Label();
        txtMa = new TextBox();
        lblMatKhau = new Label();
        txtMatKhau = new TextBox();
        btnDangNhap = new Button();
        btnThoat = new Button();
        lblThongBao = new Label();
        SuspendLayout();

        // lblTieuDe
        lblTieuDe.Text = "ĐĂNG NHẬP HỆ THỐNG THI TRẮC NGHIỆM";
        lblTieuDe.Font = new Font("Segoe UI", 13F, FontStyle.Bold);
        lblTieuDe.TextAlign = ContentAlignment.MiddleCenter;
        lblTieuDe.Location = new Point(0, 0);
        lblTieuDe.Size = new Size(462, 56);

        // lblPhanManh
        lblPhanManh.Text = "Phân mảnh (cơ sở):";
        lblPhanManh.Location = new Point(30, 82);
        lblPhanManh.Size = new Size(136, 23);
        lblPhanManh.TextAlign = ContentAlignment.MiddleLeft;

        // cboPhanManh
        cboPhanManh.DropDownStyle = ComboBoxStyle.DropDownList;
        cboPhanManh.Location = new Point(170, 80);
        cboPhanManh.Size = new Size(260, 25);

        // lblMa
        lblMa.Text = "Mã / Tài khoản:";
        lblMa.Location = new Point(30, 122);
        lblMa.Size = new Size(136, 23);
        lblMa.TextAlign = ContentAlignment.MiddleLeft;

        // txtMa
        txtMa.Location = new Point(170, 120);
        txtMa.Size = new Size(260, 25);
        txtMa.CharacterCasing = CharacterCasing.Upper;

        // lblMatKhau
        lblMatKhau.Text = "Mật khẩu:";
        lblMatKhau.Location = new Point(30, 162);
        lblMatKhau.Size = new Size(136, 23);
        lblMatKhau.TextAlign = ContentAlignment.MiddleLeft;

        // txtMatKhau
        txtMatKhau.Location = new Point(170, 160);
        txtMatKhau.Size = new Size(260, 25);
        txtMatKhau.UseSystemPasswordChar = true;

        // lblThongBao
        lblThongBao.ForeColor = Color.Firebrick;
        lblThongBao.Location = new Point(30, 194);
        lblThongBao.Size = new Size(400, 40);

        // btnDangNhap
        btnDangNhap.Text = "Đăng nhập";
        btnDangNhap.Location = new Point(170, 240);
        btnDangNhap.Size = new Size(125, 34);
        btnDangNhap.Click += btnDangNhap_Click;

        // btnThoat
        btnThoat.Text = "Thoát";
        btnThoat.Location = new Point(305, 240);
        btnThoat.Size = new Size(125, 34);
        btnThoat.Click += btnThoat_Click;

        // frmDangNhap
        AutoScaleDimensions = new SizeF(7F, 15F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(462, 300);
        Controls.Add(lblTieuDe);
        Controls.Add(lblPhanManh);
        Controls.Add(cboPhanManh);
        Controls.Add(lblMa);
        Controls.Add(txtMa);
        Controls.Add(lblMatKhau);
        Controls.Add(txtMatKhau);
        Controls.Add(lblThongBao);
        Controls.Add(btnDangNhap);
        Controls.Add(btnThoat);
        AcceptButton = btnDangNhap;
        CancelButton = btnThoat;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        Text = "Đăng nhập";
        Load += frmDangNhap_Load;
        ResumeLayout(false);
    }
}
