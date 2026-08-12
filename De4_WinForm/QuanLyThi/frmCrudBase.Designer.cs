#nullable disable

namespace QuanLyThi;

partial class frmCrudBase
{
    private System.ComponentModel.IContainer components = null;

    protected ToolStrip thanhNut;
    protected ToolStripButton btnThem, btnXoa, btnGhi, btnPhucHoi, btnNapLai;
    protected DataGridView luoi;
    protected Panel panelLoc;
    protected ToolStripStatusLabel lblTrangThai;
    private StatusStrip thanhTrangThai;

    protected override void Dispose(bool disposing)
    {
        if (disposing && components != null) components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        thanhNut = new ToolStrip();
        btnThem = new ToolStripButton("➕  Thêm");
        btnXoa = new ToolStripButton("🗑  Xóa");
        btnGhi = new ToolStripButton("💾  Ghi");
        btnPhucHoi = new ToolStripButton("↩  Phục hồi");
        btnNapLai = new ToolStripButton("🔄  Nạp lại");
        panelLoc = new Panel();
        luoi = new DataGridView();
        thanhTrangThai = new StatusStrip();
        lblTrangThai = new ToolStripStatusLabel();
        ((System.ComponentModel.ISupportInitialize)luoi).BeginInit();
        SuspendLayout();

        // --- Thanh nút (đúng bộ nút đề yêu cầu) ---
        // Kích thước nút do GiaoDien.TrangTriThanhNut() lo (AutoSize theo DPI)
        btnGhi.ForeColor = Color.FromArgb(21, 101, 52);       // nút Ghi nổi bật
        btnXoa.ForeColor = Color.FromArgb(153, 27, 27);
        btnThem.Click += btnThem_Click;
        btnXoa.Click += btnXoa_Click;
        btnGhi.Click += btnGhi_Click;
        btnPhucHoi.Click += btnPhucHoi_Click;
        btnNapLai.Click += btnNapLai_Click;

        thanhNut.Items.AddRange(new ToolStripItem[]
        {
            btnThem, btnXoa, new ToolStripSeparator(),
            btnGhi, btnPhucHoi, new ToolStripSeparator(),
            btnNapLai
        });

        // --- Vùng bộ lọc cho lớp con đặt combobox ---
        panelLoc.Dock = DockStyle.Top;
        panelLoc.Height = 0;          // lớp con tăng chiều cao khi cần

        // --- Lưới ---
        luoi.Dock = DockStyle.Fill;
        luoi.AllowUserToAddRows = false;      // thêm dòng bằng nút Thêm
        luoi.AllowUserToDeleteRows = false;   // xóa bằng nút Xóa
        luoi.SelectionMode = DataGridViewSelectionMode.CellSelect;
        luoi.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        luoi.EditingControlShowing += (s, e) => luoi_Thay_Doi(s, e);
        luoi.CellValueChanged += (s, e) => luoi_Thay_Doi(s, e);
        luoi.RowsAdded += (s, e) => luoi_Thay_Doi(s, e);
        luoi.RowsRemoved += (s, e) => luoi_Thay_Doi(s, e);

        // --- Trạng thái ---
        lblTrangThai.Text = "";
        thanhTrangThai.Items.Add(lblTrangThai);

        AutoScaleDimensions = new SizeF(7F, 15F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(880, 520);
        Controls.Add(luoi);
        Controls.Add(panelLoc);
        Controls.Add(thanhNut);
        Controls.Add(thanhTrangThai);
        StartPosition = FormStartPosition.CenterParent;
        Text = "Nhập liệu";
        ((System.ComponentModel.ISupportInitialize)luoi).EndInit();
        ResumeLayout(false);
        PerformLayout();
    }
}
