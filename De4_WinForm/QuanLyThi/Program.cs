namespace QuanLyThi;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();

        // Chế độ chụp ảnh màn hình để kiểm tra giao diện (dùng khi phát triển):
        //     QuanLyThi.exe --chup <thu-muc>
        if (args.Length >= 2 && args[0] == "--chup") { ChupManHinh.Chay(args[1]); return; }

        // Vòng lặp: đăng nhập -> làm việc -> đăng xuất -> đăng nhập lại...
        while (true)
        {
            using var frmLogin = new frmDangNhap();
            if (frmLogin.ShowDialog() != DialogResult.OK) return;

            using var main = new frmMain();
            if (main.ShowDialog() != DialogResult.Retry) return;   // Retry = người dùng bấm Đăng xuất
        }
    }
}
