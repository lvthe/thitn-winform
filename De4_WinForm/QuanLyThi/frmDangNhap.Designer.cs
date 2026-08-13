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
        // 
        // lblTieuDe
        // 
        lblTieuDe.Font = new Font("Segoe UI", 13F, FontStyle.Bold);
        lblTieuDe.Location = new Point(0, 0);
        lblTieuDe.Margin = new Padding(4, 0, 4, 0);
        lblTieuDe.Name = "lblTieuDe";
        lblTieuDe.Size = new Size(660, 93);
        lblTieuDe.TabIndex = 0;
        lblTieuDe.Text = "ĐĂNG NHẬP HỆ THỐNG THI TRẮC NGHIỆM";
        lblTieuDe.TextAlign = ContentAlignment.MiddleCenter;
        // 
        // lblPhanManh
        // 
        lblPhanManh.Location = new Point(43, 137);
        lblPhanManh.Margin = new Padding(4, 0, 4, 0);
        lblPhanManh.Name = "lblPhanManh";
        lblPhanManh.Size = new Size(194, 38);
        lblPhanManh.TabIndex = 1;
        lblPhanManh.Text = "Phân mảnh (cơ sở):";
        lblPhanManh.TextAlign = ContentAlignment.MiddleLeft;
        // 
        // cboPhanManh
        // 
        cboPhanManh.DropDownStyle = ComboBoxStyle.DropDownList;
        cboPhanManh.Location = new Point(243, 133);
        cboPhanManh.Margin = new Padding(4, 5, 4, 5);
        cboPhanManh.Name = "cboPhanManh";
        cboPhanManh.Size = new Size(370, 33);
        cboPhanManh.TabIndex = 2;
        // 
        // lblMa
        // 
        lblMa.Location = new Point(43, 203);
        lblMa.Margin = new Padding(4, 0, 4, 0);
        lblMa.Name = "lblMa";
        lblMa.Size = new Size(194, 38);
        lblMa.TabIndex = 3;
        lblMa.Text = "Mã / Tài khoản:";
        lblMa.TextAlign = ContentAlignment.MiddleLeft;
        // 
        // txtMa
        // 
        txtMa.CharacterCasing = CharacterCasing.Upper;
        txtMa.Location = new Point(243, 200);
        txtMa.Margin = new Padding(4, 5, 4, 5);
        txtMa.Name = "txtMa";
        txtMa.Size = new Size(370, 31);
        txtMa.TabIndex = 4;
        // 
        // lblMatKhau
        // 
        lblMatKhau.Location = new Point(43, 270);
        lblMatKhau.Margin = new Padding(4, 0, 4, 0);
        lblMatKhau.Name = "lblMatKhau";
        lblMatKhau.Size = new Size(194, 38);
        lblMatKhau.TabIndex = 5;
        lblMatKhau.Text = "Mật khẩu:";
        lblMatKhau.TextAlign = ContentAlignment.MiddleLeft;
        // 
        // txtMatKhau
        // 
        txtMatKhau.Location = new Point(243, 267);
        txtMatKhau.Margin = new Padding(4, 5, 4, 5);
        txtMatKhau.Name = "txtMatKhau";
        txtMatKhau.Size = new Size(370, 31);
        txtMatKhau.TabIndex = 6;
        txtMatKhau.UseSystemPasswordChar = true;
        // 
        // btnDangNhap
        // 
        btnDangNhap.Location = new Point(243, 400);
        btnDangNhap.Margin = new Padding(4, 5, 4, 5);
        btnDangNhap.Name = "btnDangNhap";
        btnDangNhap.Size = new Size(179, 57);
        btnDangNhap.TabIndex = 8;
        btnDangNhap.Text = "Đăng nhập";
        btnDangNhap.Click += btnDangNhap_Click;
        // 
        // btnThoat
        // 
        btnThoat.Location = new Point(436, 400);
        btnThoat.Margin = new Padding(4, 5, 4, 5);
        btnThoat.Name = "btnThoat";
        btnThoat.Size = new Size(179, 57);
        btnThoat.TabIndex = 9;
        btnThoat.Text = "Thoát";
        btnThoat.Click += btnThoat_Click;
        // 
        // lblThongBao
        // 
        lblThongBao.ForeColor = Color.Firebrick;
        lblThongBao.Location = new Point(43, 323);
        lblThongBao.Margin = new Padding(4, 0, 4, 0);
        lblThongBao.Name = "lblThongBao";
        lblThongBao.Size = new Size(571, 67);
        lblThongBao.TabIndex = 7;
        // 
        // frmDangNhap
        // 
        AcceptButton = btnDangNhap;
        AutoScaleDimensions = new SizeF(10F, 25F);
        AutoScaleMode = AutoScaleMode.Font;
        CancelButton = btnThoat;
        ClientSize = new Size(660, 500);
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
        FormBorderStyle = FormBorderStyle.FixedDialog;
        Margin = new Padding(4, 5, 4, 5);
        MaximizeBox = false;
        MinimizeBox = false;
        Name = "frmDangNhap";
        StartPosition = FormStartPosition.CenterScreen;
        Text = "Đăng nhập";
        Load += frmDangNhap_Load;
        ResumeLayout(false);
        PerformLayout();
    }
}
