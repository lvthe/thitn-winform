using System.Drawing.Imaging;

namespace QuanLyThi;

/// <summary>
/// Tiện ích DÀNH CHO PHÁT TRIỂN: mở lần lượt các form và lưu ảnh để kiểm
/// tra giao diện (chữ có bị cắt không, lưới có đọc được không) mà không
/// phải bấm tay từng màn hình.
/// Gọi bằng:  QuanLyThi.exe --chup D:\thu-muc-luu-anh
/// Không ảnh hưởng gì tới lúc chạy bình thường.
/// </summary>
internal static class ChupManHinh
{
    /// <param name="thuMuc">Thư mục lưu ảnh</param>
    /// <param name="vaiTro">CoSo (mặc định) hoặc Truong - để kiểm chế độ chỉ xem</param>
    public static void Chay(string thuMuc, string vaiTro = "CoSo")
    {
        Directory.CreateDirectory(thuMuc);

        // Giả lập phiên đăng nhập trên phân mảnh Cơ sở 1
        Phien.Server = AppConfig.PhanManhDuPhong[0].Server;
        Phien.TenPhanManh = AppConfig.PhanManhDuPhong[0].Ten;
        if (vaiTro == "Truong")
        {
            Phien.Login = "truong01"; Phien.MatKhau = "Truong@123";
            Phien.Ma = "truong01"; Phien.HoTen = "truong01"; Phien.VaiTro = "Truong";
        }
        else
        {
            Phien.Login = "coso1"; Phien.MatKhau = "Coso@123";
            Phien.Ma = "coso1"; Phien.HoTen = "coso1"; Phien.VaiTro = "CoSo";
        }

        Chup(thuMuc, "01_MonHoc", () => new frmMonHoc());
        Chup(thuMuc, "02_KhoaLop", () => new frmKhoaLop());
        Chup(thuMuc, "03_SinhVien", () => new frmSinhVien());
        Chup(thuMuc, "04_GiaoVien", () => new frmGiaoVien());
        Chup(thuMuc, "05_BoDe", () => new frmBoDe());
        Chup(thuMuc, "06_ChuanBiThi", () => new frmChuanBiThi());
        Chup(thuMuc, "06b_XemKetQua", () => new frmXemKetQua());
        Chup(thuMuc, "07_BangDiem", () => new frmBangDiem());
        Chup(thuMuc, "08_BaoCaoDangKy", () => new frmBaoCaoDangKy());
        Chup(thuMuc, "09_TraCuu", () => new frmTraCuu());
        Chup(thuMuc, "10_TaiKhoan", () => new frmTaiKhoan());
        Chup(thuMuc, "11_SaoLuu", () => new frmSaoLuu());

        Console.WriteLine("Xong.");
    }

    private static void Chup(string thuMuc, string ten, Func<Form> tao)
    {
        try
        {
            var f = tao();
            f.StartPosition = FormStartPosition.Manual;
            f.Location = new Point(0, 0);
            f.Show();
            // Cho form kịp nạp dữ liệu và vẽ xong
            for (int i = 0; i < 40; i++) { Application.DoEvents(); Thread.Sleep(50); }

            using var bmp = new Bitmap(f.Width, f.Height);
            f.DrawToBitmap(bmp, new Rectangle(0, 0, f.Width, f.Height));
            bmp.Save(Path.Combine(thuMuc, ten + ".png"), ImageFormat.Png);

            f.Close();
            f.Dispose();
            Console.WriteLine($"OK  {ten}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"LOI {ten}: {ex.GetType().Name}: {ex.Message}");
        }
    }
}
