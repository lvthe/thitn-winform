using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>Cấu hình cố định của ứng dụng.</summary>
public static class AppConfig
{
    /// <summary>Server chủ (Publisher) - nơi chứa view V_DS_PHANMANH.</summary>
    public const string ServerChu = @"localhost\SERVER";

    public const string TenCSDL = "TN_CSDLPT";

    /// <summary>Tài khoản SQL dùng CHUNG cho toàn bộ sinh viên (đề câu 1).</summary>
    public const string LoginSinhVien = "sv";
    public const string MatKhauSinhVien = "Sv@123";

    /// <summary>Danh sách dự phòng khi không đọc được V_DS_PHANMANH.</summary>
    public static readonly (string Ten, string Server)[] PhanManhDuPhong =
    {
        ("Co so 1", @"localhost\SERVER1"),
        ("Co so 2", @"localhost\SERVER2"),
    };

    /// <summary>
    /// Mảnh 3 (phân mảnh DỌC) - CHỈ dùng để TRA CỨU, KHÔNG cho đăng nhập.
    /// Đề: "không cho người ta đăng nhập vào server này, nhưng vẫn dùng nó
    /// để tra cứu mã sinh viên có chưa, mã lớp có chưa".
    /// </summary>
    public const string ServerTraCuu = @"localhost\SERVER3";

    /// <summary>
    /// Tài khoản DỊCH VỤ chỉ-đọc dùng cho mảnh 3. Người dùng không có tài
    /// khoản trên mảnh này (đề: "không cho đăng nhập"), nên chính ứng dụng
    /// đứng ra tra cứu. Tài khoản bị DENY INSERT/UPDATE/DELETE.
    /// Tạo bằng script SQL/02_Cau1_TaiKhoanTraCuu_SERVER3.sql
    /// </summary>
    public const string LoginTraCuu = "tracuu";
    public const string MatKhauTraCuu = "TraCuu@123";

    /// <summary>Tên publication của mảnh tra cứu - dùng để loại khỏi ComboBox đăng nhập.</summary>
    public const string TenPhanManhTraCuu = "Tra cuu";
}

/// <summary>Thông tin phiên làm việc hiện tại (sau khi đăng nhập thành công).</summary>
public static class Phien
{
    public static string Server = "";
    public static string TenPhanManh = "";
    public static string Login = "";
    public static string MatKhau = "";
    public static string Ma = "";        // MAGV hoặc MASV
    public static string HoTen = "";
    public static string VaiTro = "";    // Truong | CoSo | Giangvien | Sinhvien

    public static bool LaSinhVien => VaiTro == "Sinhvien";

    /// <summary>
    /// Nhóm Trưởng CHỈ ĐƯỢC XEM. Đề: "nhóm trưởng được quyền đăng nhập vào
    /// bất kỳ phân mảnh nào để có thể xem ... xem thôi, không được quyền
    /// thêm xóa sửa". Ràng buộc thật nằm ở SQL Server (role Truong chỉ được
    /// GRANT SELECT); cờ này chỉ để giao diện khoá nút cho khỏi bấm nhầm.
    /// </summary>
    public static bool ChiXem => VaiTro == "Truong";

    public static void Xoa() { Server = TenPhanManh = Login = MatKhau = Ma = HoTen = VaiTro = ""; }
}

public static class DataProvider
{
    /// <summary>Chuỗi kết nối của phiên hiện tại.</summary>
    public static string ChuoiKetNoi => TaoChuoiKetNoi(Phien.Server, Phien.Login, Phien.MatKhau);

    public static string TaoChuoiKetNoi(string server, string login, string matKhau) =>
        new SqlConnectionStringBuilder
        {
            DataSource = server,
            InitialCatalog = AppConfig.TenCSDL,
            UserID = login,
            Password = matKhau,
            TrustServerCertificate = true,
            ConnectTimeout = 10
        }.ConnectionString;

    public static SqlConnection MoKetNoi()
    {
        var cn = new SqlConnection(ChuoiKetNoi);
        cn.Open();
        return cn;
    }

    /// <summary>
    /// Đọc danh sách phân mảnh từ view V_DS_PHANMANH trên Publisher.
    /// LOẠI BỎ mảnh tra cứu: đề yêu cầu KHÔNG cho đăng nhập vào mảnh 3.
    /// Nếu không đọc được thì trả về danh sách dự phòng.
    /// </summary>
    public static DataTable LayDanhSachPhanManh()
    {
        var dt = DocTatCaPhanManh();
        for (int i = dt.Rows.Count - 1; i >= 0; i--)
        {
            var ten = dt.Rows[i]["TENCN"]?.ToString() ?? "";
            var srv = dt.Rows[i]["TENSERVER"]?.ToString() ?? "";
            if (ten.Contains("Tra c", StringComparison.OrdinalIgnoreCase) ||
                srv.EndsWith("SERVER3", StringComparison.OrdinalIgnoreCase))
                dt.Rows.RemoveAt(i);
        }
        return dt;
    }

    private static DataTable DocTatCaPhanManh()
    {
        var dt = new DataTable();
        dt.Columns.Add("TENCN", typeof(string));
        dt.Columns.Add("TENSERVER", typeof(string));
        try
        {
            var csb = new SqlConnectionStringBuilder
            {
                DataSource = AppConfig.ServerChu,
                InitialCatalog = AppConfig.TenCSDL,
                IntegratedSecurity = true,
                TrustServerCertificate = true,
                ConnectTimeout = 5
            };
            using var cn = new SqlConnection(csb.ConnectionString);
            cn.Open();
            using var da = new SqlDataAdapter("SELECT TENCN, TENSERVER FROM dbo.V_DS_PHANMANH", cn);
            da.Fill(dt);
        }
        catch
        {
            // Bỏ qua - dùng danh sách dự phòng bên dưới.
        }

        if (dt.Rows.Count == 0)
            foreach (var (ten, server) in AppConfig.PhanManhDuPhong)
                dt.Rows.Add(ten, server);

        return dt;
    }

    /// <summary>
    /// Đăng nhập theo đề câu 1 - hai cách khác nhau:
    ///  1) Cán bộ (Giảng viên / Cơ sở / Trưởng): mỗi người MỘT SQL login + mật khẩu riêng.
    ///  2) Sinh viên: dùng CHUNG một SQL login, danh tính xác thực bằng MASV + PASSWORD
    ///     lưu trong bảng SINHVIEN (gọi sp_DangNhap_SV).
    /// </summary>
    public static void DangNhap(string server, string tenPhanManh, string ma, string matKhau)
    {
        Phien.Xoa();
        Phien.Server = server;
        Phien.TenPhanManh = tenPhanManh;

        // --- Cách 1: thử coi "ma" là SQL login của cán bộ ---
        try
        {
            using var cn = new SqlConnection(TaoChuoiKetNoi(server, ma, matKhau));
            cn.Open();

            var tt = DocThongTinNguoiDung(cn, ma);
            Phien.Login = ma;
            Phien.MatKhau = matKhau;
            Phien.Ma = tt.Ma.Length > 0 ? tt.Ma : ma;
            Phien.VaiTro = tt.Nhom;

            if (Phien.VaiTro == "")
                throw new ApplicationException(
                    $"Tài khoản '{ma}' chưa được gán nhóm quyền nào trên {server}.");

            Phien.HoTen = tt.HoTen.Length > 0 ? tt.HoTen : Phien.Ma;
            return;
        }
        catch (SqlException)
        {
            // Không phải SQL login hợp lệ -> chuyển sang xác thực sinh viên.
        }

        // --- Cách 2: coi "ma" là MASV, dùng tài khoản chung của sinh viên ---
        try
        {
            using var cn = new SqlConnection(
                TaoChuoiKetNoi(server, AppConfig.LoginSinhVien, AppConfig.MatKhauSinhVien));
            cn.Open();

            using var cmd = new SqlCommand("dbo.sp_DangNhap_SV", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@MASV", SqlDbType.Char, 8).Value = ma;
            cmd.Parameters.Add("@PASSWORD", SqlDbType.NVarChar, 60).Value = matKhau ?? "";

            using var rd = cmd.ExecuteReader();
            if (!rd.Read())
                throw new ApplicationException("Sai mã số hoặc mật khẩu.");

            Phien.Login = AppConfig.LoginSinhVien;
            Phien.MatKhau = AppConfig.MatKhauSinhVien;
            Phien.Ma = ma;
            Phien.VaiTro = "Sinhvien";
            Phien.HoTen = LayChuoi(rd, "HOTEN") ?? LayChuoi(rd, "HO_TEN") ?? ma;
        }
        catch (SqlException ex)
        {
            throw new ApplicationException(
                $"Không kết nối được phân mảnh {server}.\r\n{ex.Message}", ex);
        }
    }

    /// <summary>
    /// Lấy MÃ - HỌ TÊN - NHÓM QUYỀN của một login, bằng thủ tục
    /// SP_LayThongTinNguoiDung viết theo đúng mẫu SP_LayThongTinNhanVien
    /// trong tài liệu "HD FORM DANG NHAP" của Thầy:
    ///   login --(SUSER_SID)--> sys.sysusers --(sys.sysmembers)--> nhóm quyền
    /// Nhóm quyền đọc thẳng từ hệ thống, KHÔNG viết cứng trong ứng dụng.
    /// </summary>
    private static (string Ma, string HoTen, string Nhom) DocThongTinNguoiDung(
        SqlConnection cn, string tenLogin)
    {
        using var cmd = new SqlCommand("dbo.SP_LayThongTinNguoiDung", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@TENLOGIN", SqlDbType.NVarChar, 50).Value = tenLogin;

        using var rd = cmd.ExecuteReader();
        if (!rd.Read()) return (tenLogin, "", "");

        string Lay(string cot)
        {
            for (int i = 0; i < rd.FieldCount; i++)
                if (string.Equals(rd.GetName(i), cot, StringComparison.OrdinalIgnoreCase))
                    return rd.IsDBNull(i) ? "" : rd.GetValue(i)?.ToString()?.Trim() ?? "";
            return "";
        }
        return (Lay("MA"), Lay("HOTEN"), Lay("TENNHOM"));
    }

    private static string? LayChuoi(SqlDataReader rd, string ten)
    {
        for (int i = 0; i < rd.FieldCount; i++)
            if (string.Equals(rd.GetName(i), ten, StringComparison.OrdinalIgnoreCase))
                return rd.IsDBNull(i) ? null : rd.GetValue(i)?.ToString()?.Trim();
        return null;
    }

    /// <summary>Chạy một câu SELECT trên kết nối của phiên hiện tại.</summary>
    public static DataTable TruyVan(string sql, params SqlParameter[] thamSo)
    {
        using var cn = MoKetNoi();
        using var cmd = new SqlCommand(sql, cn);
        cmd.Parameters.AddRange(thamSo);
        using var da = new SqlDataAdapter(cmd);
        var dt = new DataTable();
        da.Fill(dt);
        return dt;
    }

    /* ================================================================
       TRA CỨU QUA MẢNH 3 (phân mảnh DỌC, SERVER3)
       Mảnh này gom Lớp + Sinh viên của CẢ HAI cơ sở nhưng chỉ giữ các
       cột cần thiết. Dùng để kiểm tra nhanh "mã đã tồn tại chưa" mà
       KHÔNG phải hỏi vòng qua từng cơ sở.
       ================================================================ */

    /// <summary>Mở kết nối chỉ-đọc tới mảnh tra cứu (mảnh 3).</summary>
    private static SqlConnection MoKetNoiTraCuu()
    {
        // KHÔNG dùng tài khoản của phiên: giảng viên / cơ sở không hề có login
        // trên mảnh 3. Ứng dụng dùng tài khoản dịch vụ chỉ-đọc riêng.
        var cn = new SqlConnection(
            TaoChuoiKetNoi(AppConfig.ServerTraCuu, AppConfig.LoginTraCuu, AppConfig.MatKhauTraCuu));
        cn.Open();
        return cn;
    }

    /// <summary>Mã sinh viên đã tồn tại ở BẤT KỲ cơ sở nào chưa? (tra trên mảnh 3)</summary>
    public static bool MaSinhVienDaTonTai(string maSV)
    {
        using var cn = MoKetNoiTraCuu();
        using var cmd = new SqlCommand(
            "SELECT COUNT(*) FROM dbo.SINHVIEN WHERE RTRIM(MASV) = RTRIM(@m)", cn);
        cmd.Parameters.Add("@m", SqlDbType.Char, 8).Value = maSV;
        return Convert.ToInt32(cmd.ExecuteScalar()) > 0;
    }

    /// <summary>Mã lớp đã tồn tại ở BẤT KỲ cơ sở nào chưa? (tra trên mảnh 3)</summary>
    public static bool MaLopDaTonTai(string maLop)
    {
        using var cn = MoKetNoiTraCuu();
        using var cmd = new SqlCommand(
            "SELECT COUNT(*) FROM dbo.LOP WHERE RTRIM(MALOP) = RTRIM(@m)", cn);
        cmd.Parameters.Add("@m", SqlDbType.NChar, 15).Value = maLop;
        return Convert.ToInt32(cmd.ExecuteScalar()) > 0;
    }

    /// <summary>Danh sách lớp + sinh viên của cả 2 cơ sở (mảnh 3) - phục vụ màn tra cứu.</summary>
    public static DataTable TraCuuSinhVien(string? loc = null)
    {
        using var cn = MoKetNoiTraCuu();
        var sql = @"SELECT sv.MASV, sv.HO, sv.TEN, sv.MALOP, l.TENLOP
                    FROM dbo.SINHVIEN sv LEFT JOIN dbo.LOP l ON sv.MALOP = l.MALOP";
        if (!string.IsNullOrWhiteSpace(loc))
            sql += " WHERE sv.MASV LIKE @k OR sv.HO LIKE @k OR sv.TEN LIKE @k OR sv.MALOP LIKE @k";
        sql += " ORDER BY sv.MALOP, sv.MASV";

        using var cmd = new SqlCommand(sql, cn);
        if (!string.IsNullOrWhiteSpace(loc))
            cmd.Parameters.AddWithValue("@k", "%" + loc.Trim() + "%");
        using var da = new SqlDataAdapter(cmd);
        var dt = new DataTable();
        da.Fill(dt);
        return dt;
    }

    /* ================================================================
       CÂU 11 - BÁO CÁO ĐĂNG KÝ THI CỦA CẢ HAI CƠ SỞ
       Đề (Thầy nhắc 2 lần): "riêng câu 11 KHÔNG được về server chủ,
       bắt buộc chạy trên 2 phân mảnh ... dùng phép UNION".
       => Gọi sp_BaoCao_DangKy trên TỪNG PHÂN MẢNH rồi UNION kết quả.
          Tuyệt đối không mở kết nối tới Publisher.
       ================================================================ */

    /// <summary>Kết quả gộp báo cáo + nhật ký từng phân mảnh (để hiển thị minh bạch).</summary>
    public record KetQuaHopNhat(DataTable Data, List<string> NhatKy);

    public static KetQuaHopNhat BaoCaoDangKy_HaiCoSo(DateTime tuNgay, DateTime denNgay)
    {
        var gop = new DataTable();
        var nhatKy = new List<string>();

        foreach (DataRow pm in LayDanhSachPhanManh().Rows)   // đã loại mảnh tra cứu
        {
            var ten = pm["TENCN"]?.ToString() ?? "";
            var server = pm["TENSERVER"]?.ToString() ?? "";
            if (server.Length == 0) continue;

            try
            {
                using var cn = new SqlConnection(
                    TaoChuoiKetNoi(server, Phien.Login, Phien.MatKhau));
                cn.Open();
                using var cmd = new SqlCommand("dbo.sp_BaoCao_DangKy", cn)
                { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.Add("@tungay", SqlDbType.Date).Value = tuNgay.Date;
                cmd.Parameters.Add("@denngay", SqlDbType.Date).Value = denNgay.Date;

                var phan = new DataTable();
                using (var da = new SqlDataAdapter(cmd)) da.Fill(phan);

                // UNION: gộp dòng của phân mảnh này vào bảng kết quả chung.
                if (gop.Columns.Count == 0) gop = phan.Clone();
                foreach (DataRow r in phan.Rows) gop.ImportRow(r);

                nhatKy.Add($"{ten} ({server}): {phan.Rows.Count} dòng");
            }
            catch (SqlException ex)
            {
                // Tài khoản Cơ sở chỉ đăng nhập được cơ sở của mình -> bỏ qua phân mảnh kia.
                nhatKy.Add($"{ten} ({server}): không đọc được - {ex.Message.Split('\n')[0]}");
            }
        }

        if (gop.Columns.Contains("NGAYTHI"))
            gop.DefaultView.Sort = "MACS, NGAYTHI";

        return new KetQuaHopNhat(gop, nhatKy);
    }

    /// <summary>Gọi stored procedure trả về bảng dữ liệu.</summary>
    public static DataTable GoiSP(string tenSP, params SqlParameter[] thamSo)
    {
        using var cn = MoKetNoi();
        using var cmd = new SqlCommand(tenSP, cn) { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.AddRange(thamSo);
        using var da = new SqlDataAdapter(cmd);
        var dt = new DataTable();
        da.Fill(dt);
        return dt;
    }
}
