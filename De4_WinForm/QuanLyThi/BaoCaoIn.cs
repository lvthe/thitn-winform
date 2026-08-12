using System.Data;
using System.Drawing.Printing;

namespace QuanLyThi;

/// <summary>
/// Bộ máy in báo cáo, dựng theo đúng cấu trúc BAND mà Thầy dạy trong
/// bài giảng "Tạo báo cáo trên hệ thống phân tán":
///
///     ReportHeader  - tiêu đề báo cáo, CHỈ in ở đầu TRANG 1
///     PageHeader    - tiêu đề CỘT, in lại ở đầu MỖI TRANG
///     Detail        - các dòng dữ liệu
///     PageFooter    - số trang, cuối MỖI TRANG
///     ReportFooter  - dòng TỔNG, nằm ngay dưới dòng cuối cùng
///
/// Vì sao tự viết thay vì dùng XtraReport: XtraReport nằm trong bộ
/// DevExpress (thư viện thương mại, không kèm .NET). Lớp này dùng
/// PrintDocument có sẵn nên vẫn đủ các band Thầy yêu cầu, xem trước
/// được, in được và xuất được ra tệp.
///
/// NGUYÊN TẮC GIẢM TẢI ĐƯỜNG TRUYỀN (Thầy nhấn mạnh):
///   "dữ liệu nào TÍNH ĐƯỢC trong report thì KHÔNG truy vấn từ server"
///   -> cột dẫn xuất và dòng tổng đều tính tại máy trạm, xem CotTinh().
/// </summary>
public class BaoCaoIn
{
    /*---------------- Khai báo cột ----------------*/
    public class Cot
    {
        public string Ten = "";                 // tên cột trong DataTable
        public string TieuDe = "";              // chữ in ở PageHeader
        public int RongPhanTram = 10;           // tỉ lệ bề ngang
        public bool CanPhai;                    // số thì căn phải
        public string DinhDang = "";            // vd "N1", "dd/MM/yyyy"
        /// <summary>Cột TÍNH TẠI MÁY TRẠM (không tải từ server).</summary>
        public Func<DataRow, object>? CotTinh;
        /// <summary>Cột này có cộng TỔNG ở ReportFooter không.</summary>
        public bool CongTong;
    }

    public string TieuDeBaoCao = "";            // dòng 1 của ReportHeader (động)
    public string TieuDePhu = "";               // dòng 2 của ReportHeader (động)
    public string NguonDuLieu = "";             // ghi chú nguồn - phục vụ bảo vệ đồ án
    public List<Cot> DanhSachCot = new();
    public DataTable? DuLieu;

    /*---------------- Trạng thái khi in ----------------*/
    private int _dongHienTai;
    private int _soTrang;
    private readonly Dictionary<string, double> _tong = new();

    private static readonly Font FontTieuDe = new("Segoe UI", 15F, FontStyle.Bold);
    private static readonly Font FontTieuDePhu = new("Segoe UI", 10.5F);
    private static readonly Font FontCot = new("Segoe UI", 9.5F, FontStyle.Bold);
    private static readonly Font FontDong = new("Segoe UI", 9.5F);
    private static readonly Font FontTong = new("Segoe UI", 10F, FontStyle.Bold);
    private static readonly Font FontChan = new("Segoe UI", 8.5F, FontStyle.Italic);

    /*================= Giao diện gọi =================*/

    /// <summary>Mở cửa sổ xem trước (từ đó người dùng bấm in).</summary>
    public void XemTruoc(IWin32Window? chu = null)
    {
        using var doc = TaoTaiLieu();
        using var hop = new PrintPreviewDialog
        {
            Document = doc,
            Width = 1000,
            Height = 760,
            StartPosition = FormStartPosition.CenterParent,
            Text = "Xem trước - " + TieuDeBaoCao
        };
        if (hop is Form f) f.Icon = null;
        hop.ShowDialog(chu);
    }

    /// <summary>In thẳng ra máy in (có hộp thoại chọn máy in).</summary>
    public void In(IWin32Window? chu = null)
    {
        using var doc = TaoTaiLieu();
        using var hop = new PrintDialog { Document = doc, UseEXDialog = true };
        if (hop.ShowDialog(chu) == DialogResult.OK) doc.Print();
    }

    private PrintDocument TaoTaiLieu()
    {
        var doc = new PrintDocument();
        doc.DocumentName = TieuDeBaoCao;
        doc.DefaultPageSettings.Landscape = DanhSachCot.Count > 6;
        doc.BeginPrint += (_, _) => { _dongHienTai = 0; _soTrang = 0; _tong.Clear(); };
        doc.PrintPage += VeMotTrang;
        return doc;
    }

    /*================= Vẽ từng trang =================*/

    private void VeMotTrang(object? sender, PrintPageEventArgs e)
    {
        if (e.Graphics is not Graphics g || DuLieu == null) return;
        var vung = e.MarginBounds;
        _soTrang++;
        float y = vung.Top;

        /*---- ReportHeader: CHỈ trang 1 ----*/
        if (_soTrang == 1)
        {
            g.DrawString(TieuDeBaoCao, FontTieuDe, Brushes.Black,
                new RectangleF(vung.Left, y, vung.Width, 34),
                new StringFormat { Alignment = StringAlignment.Center });
            y += 34;

            if (TieuDePhu.Length > 0)
            {
                g.DrawString(TieuDePhu, FontTieuDePhu, Brushes.Black,
                    new RectangleF(vung.Left, y, vung.Width, 22),
                    new StringFormat { Alignment = StringAlignment.Center });
                y += 24;
            }
            if (NguonDuLieu.Length > 0)
            {
                g.DrawString(NguonDuLieu, FontChan, Brushes.DimGray,
                    new RectangleF(vung.Left, y, vung.Width, 18),
                    new StringFormat { Alignment = StringAlignment.Center });
                y += 20;
            }
            y += 8;
        }

        /*---- PageHeader: tiêu đề cột, LẶP LẠI mỗi trang ----*/
        var beRong = TinhBeRongCot(vung.Width);
        float yHeader = y;
        g.FillRectangle(new SolidBrush(Color.FromArgb(30, 64, 124)),
                        vung.Left, y, vung.Width, 24);
        float x = vung.Left;
        for (int i = 0; i < DanhSachCot.Count; i++)
        {
            g.DrawString(DanhSachCot[i].TieuDe, FontCot, Brushes.White,
                new RectangleF(x + 4, y + 4, beRong[i] - 8, 20));
            x += beRong[i];
        }
        y += 24;

        /*---- Detail ----*/
        float caoDong = 20;
        bool het = false;
        while (_dongHienTai < DuLieu.Rows.Count)
        {
            // chừa chỗ cho PageFooter (+ ReportFooter nếu là dòng cuối)
            float canChua = caoDong + 30;
            if (y + canChua > vung.Bottom) break;

            var dong = DuLieu.Rows[_dongHienTai];
            if (_dongHienTai % 2 == 1)
                g.FillRectangle(new SolidBrush(Color.FromArgb(240, 244, 250)),
                                vung.Left, y, vung.Width, caoDong);

            x = vung.Left;
            for (int i = 0; i < DanhSachCot.Count; i++)
            {
                var c = DanhSachCot[i];
                var giaTri = LayGiaTri(dong, c);
                var chu = DinhDangGiaTri(giaTri, c);

                var dinhDang = new StringFormat
                {
                    Alignment = c.CanPhai ? StringAlignment.Far : StringAlignment.Near,
                    LineAlignment = StringAlignment.Center,
                    Trimming = StringTrimming.EllipsisCharacter,
                    FormatFlags = StringFormatFlags.NoWrap
                };
                g.DrawString(chu, FontDong, Brushes.Black,
                    new RectangleF(x + 4, y, beRong[i] - 8, caoDong), dinhDang);

                // Cộng dồn TỔNG ngay khi in - không cần truy vấn lại server
                if (c.CongTong && double.TryParse(Convert.ToString(giaTri), out var so))
                    _tong[c.Ten] = _tong.GetValueOrDefault(c.Ten) + so;

                x += beRong[i];
            }
            g.DrawLine(Pens.LightGray, vung.Left, y + caoDong, vung.Right, y + caoDong);
            y += caoDong;
            _dongHienTai++;
        }
        het = _dongHienTai >= DuLieu.Rows.Count;

        /*---- ReportFooter: dòng TỔNG, ngay dưới dòng cuối cùng ----*/
        if (het && DanhSachCot.Any(c => c.CongTong))
        {
            g.DrawLine(new Pen(Color.Black, 1.5f), vung.Left, y, vung.Right, y);
            y += 3;
            x = vung.Left;
            for (int i = 0; i < DanhSachCot.Count; i++)
            {
                var c = DanhSachCot[i];
                string chu = i == 0 ? $"TỔNG CỘNG ({DuLieu.Rows.Count} dòng)"
                           : c.CongTong ? _tong.GetValueOrDefault(c.Ten).ToString(
                                             c.DinhDang.Length > 0 ? c.DinhDang : "N0")
                           : "";
                g.DrawString(chu, FontTong, Brushes.Black,
                    new RectangleF(x + 4, y, beRong[i] - 8, 22),
                    new StringFormat { Alignment = c.CanPhai ? StringAlignment.Far : StringAlignment.Near });
                x += beRong[i];
            }
        }

        /*---- PageFooter: số trang ----*/
        g.DrawString($"Trang {_soTrang}", FontChan, Brushes.DimGray,
            new RectangleF(vung.Left, vung.Bottom + 4, vung.Width, 18),
            new StringFormat { Alignment = StringAlignment.Center });
        g.DrawString(DateTime.Now.ToString("dd/MM/yyyy HH:mm"), FontChan, Brushes.DimGray,
            new RectangleF(vung.Left, vung.Bottom + 4, vung.Width, 18),
            new StringFormat { Alignment = StringAlignment.Far });

        e.HasMorePages = !het;
    }

    /*================= Hàm phụ =================*/

    private object LayGiaTri(DataRow dong, Cot c)
        => c.CotTinh != null ? c.CotTinh(dong)                    // tính TẠI MÁY TRẠM
         : DuLieu!.Columns.Contains(c.Ten) ? dong[c.Ten] : "";

    private static string DinhDangGiaTri(object giaTri, Cot c)
    {
        if (giaTri == null || giaTri is DBNull) return "";
        if (c.DinhDang.Length == 0) return Convert.ToString(giaTri)?.Trim() ?? "";
        return giaTri switch
        {
            DateTime d => d.ToString(c.DinhDang),
            IFormattable f => f.ToString(c.DinhDang, null),
            _ => Convert.ToString(giaTri)?.Trim() ?? ""
        };
    }

    private int[] TinhBeRongCot(int tongRong)
    {
        var tongTyLe = DanhSachCot.Sum(c => c.RongPhanTram);
        return DanhSachCot.Select(c => (int)(tongRong * c.RongPhanTram / (double)tongTyLe)).ToArray();
    }

    /*================= Xuất tệp =================*/

    /// <summary>Xuất ra CSV (Excel mở được).</summary>
    public void XuatCsv(string duongDan)
    {
        if (DuLieu == null) return;
        var sb = new System.Text.StringBuilder();
        sb.AppendLine(TieuDeBaoCao);
        if (TieuDePhu.Length > 0) sb.AppendLine(TieuDePhu);
        if (NguonDuLieu.Length > 0) sb.AppendLine(NguonDuLieu);
        sb.AppendLine();
        sb.AppendLine(string.Join(",", DanhSachCot.Select(c => "\"" + c.TieuDe + "\"")));

        var tong = new Dictionary<string, double>();
        foreach (DataRow r in DuLieu.Rows)
        {
            var o = new List<string>();
            foreach (var c in DanhSachCot)
            {
                var v = LayGiaTri(r, c);
                o.Add("\"" + DinhDangGiaTri(v, c).Replace("\"", "\"\"") + "\"");
                if (c.CongTong && double.TryParse(Convert.ToString(v), out var s))
                    tong[c.Ten] = tong.GetValueOrDefault(c.Ten) + s;
            }
            sb.AppendLine(string.Join(",", o));
        }

        if (DanhSachCot.Any(c => c.CongTong))
            sb.AppendLine(string.Join(",", DanhSachCot.Select((c, i) =>
                i == 0 ? $"\"TỔNG CỘNG ({DuLieu.Rows.Count} dòng)\""
              : c.CongTong ? "\"" + tong.GetValueOrDefault(c.Ten) + "\"" : "\"\"")));

        // UTF-8 BOM để Excel đọc đúng tiếng Việt
        File.WriteAllText(duongDan, sb.ToString(), new System.Text.UTF8Encoding(true));
    }
}
