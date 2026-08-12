#nullable disable

namespace QuanLyThi;

partial class frmTraCuu
{
    private System.ComponentModel.IContainer components = null;

    private Label lblHuongDan, lblTim, lblTongKet;
    private TextBox txtTim;
    private Button btnTim, btnKiemTraMa;
    private DataGridView grid;

    protected override void Dispose(bool disposing)
    {
        if (disposing && components != null) components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        lblHuongDan = new Label();
        lblTim = new Label();
        lblTongKet = new Label();
        txtTim = new TextBox();
        btnTim = new Button();
        btnKiemTraMa = new Button();
        grid = new DataGridView();
        ((System.ComponentModel.ISupportInitialize)grid).BeginInit();
        SuspendLayout();

        lblHuongDan.Text =
            "Dữ liệu lấy từ MẢNH 3 (phân mảnh DỌC) - gộp Lớp + Sinh viên của CẢ HAI cơ sở, " +
            "chỉ giữ các cột cần thiết. Mảnh này CHỈ ĐỌC, không cho phép cập nhật.";
        lblHuongDan.Location = new Point(14, 12);
        lblHuongDan.Size = new Size(720, 36);
        lblHuongDan.ForeColor = SystemColors.GrayText;

        lblTim.Text = "Từ khoá (mã SV / họ tên / mã lớp):";
        lblTim.Location = new Point(14, 58);
        lblTim.Size = new Size(220, 25);
        lblTim.TextAlign = ContentAlignment.MiddleLeft;

        txtTim.Location = new Point(238, 56);
        txtTim.Size = new Size(240, 25);

        btnTim.Text = "Tra cứu";
        btnTim.Location = new Point(488, 55);
        btnTim.Size = new Size(110, 28);
        btnTim.Click += btnTim_Click;

        btnKiemTraMa.Text = "Mã đã tồn tại chưa?";
        btnKiemTraMa.Location = new Point(606, 55);
        btnKiemTraMa.Size = new Size(150, 28);
        btnKiemTraMa.Click += btnKiemTraMa_Click;

        grid.Location = new Point(14, 94);
        grid.Size = new Size(742, 330);
        grid.ReadOnly = true;
        grid.AllowUserToAddRows = false;
        grid.AllowUserToDeleteRows = false;
        grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;

        lblTongKet.Location = new Point(14, 430);
        lblTongKet.Size = new Size(742, 24);

        AutoScaleDimensions = new SizeF(7F, 15F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(770, 462);
        Controls.AddRange(new Control[]
            { lblHuongDan, lblTim, txtTim, btnTim, btnKiemTraMa, grid, lblTongKet });
        AcceptButton = btnTim;
        StartPosition = FormStartPosition.CenterParent;
        Text = "Tra cứu Lớp / Sinh viên toàn trường (mảnh dọc)";
        Load += frmTraCuu_Load;
        ((System.ComponentModel.ISupportInitialize)grid).EndInit();
        ResumeLayout(false);
    }
}
