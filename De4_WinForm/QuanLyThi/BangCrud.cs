using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyThi;

/// <summary>
/// Bọc một bảng dữ liệu để nạp / ghi qua SqlDataAdapter.
/// Dùng chung cho các form nhập liệu câu 2..6.
///
/// UNDO NHIỀU CẤP (option cộng điểm của đề):
/// Trước MỖI lần Ghi thành công, trạng thái cũ của bảng được đẩy vào một
/// NGĂN XẾP (Stack). Bấm Phục hồi nhiều lần sẽ lùi ngược từng bước, kể cả
/// các thao tác ĐÃ GHI xuống CSDL - đúng như Thầy gợi ý dùng cấu trúc
/// dữ liệu Stack đã học ở môn Cấu trúc dữ liệu.
/// </summary>
public class BangCrud
{
    private readonly string _selectSql;
    private readonly string _tenBang;
    private SqlDataAdapter? _da;

    /// <summary>Ngăn xếp trạng thái: mỗi phần tử là ảnh chụp bảng TRƯỚC một lần Ghi.</summary>
    private readonly Stack<DataTable> _lichSu = new();

    public DataTable Data { get; private set; } = new();

    /// <summary>
    /// Tên các cột khóa chính (tự lưu, KHÔNG đặt vào DataTable.PrimaryKey).
    ///
    /// Vì sao không đặt PrimaryKey: khi đặt, DataTable áp luôn ràng buộc
    /// NOT NULL + UNIQUE ở phía máy trạm. Người dùng vừa bấm "Thêm" là
    /// .NET ném lỗi ngay ("Column 'MAMH' does not allow nulls"), chưa kịp
    /// gõ gì. Ta chỉ cần biết TÊN cột khóa để đối chiếu khi Undo, còn việc
    /// ràng buộc cứ để CSDL lo - đó mới là nơi đúng để kiểm.
    /// </summary>
    public string[] CotKhoa { get; private set; } = Array.Empty<string>();

    /// <summary>Số bước có thể lùi lại (đã ghi xuống CSDL).</summary>
    public int SoBuocLuiDuoc => _lichSu.Count;

    public BangCrud(string tenBang, string selectSql)
    {
        _tenBang = tenBang;
        _selectSql = selectSql;
    }

    /// <summary>Nạp lại dữ liệu từ CSDL, bỏ mọi thay đổi chưa ghi.</summary>
    public void Nap(params SqlParameter[] thamSo)
    {
        var cn = new SqlConnection(DataProvider.ChuoiKetNoi);
        var cmd = new SqlCommand(_selectSql, cn);
        cmd.Parameters.AddRange(thamSo);

        _da = new SqlDataAdapter(cmd);
        // AddWithKey để DataTable có PrimaryKey -> đối chiếu được từng dòng khi Undo.
        _da.MissingSchemaAction = MissingSchemaAction.AddWithKey;
        _ = new SqlCommandBuilder(_da) { ConflictOption = ConflictOption.OverwriteChanges };

        Data = new DataTable(_tenBang);
        _da.Fill(Data);

        // Ghi nhớ khóa chính rồi GỠ ràng buộc phía máy trạm, để nút "Thêm"
        // tạo được dòng trống cho người dùng gõ. CSDL vẫn chặn dữ liệu sai.
        CotKhoa = Data.PrimaryKey.Select(c => c.ColumnName).ToArray();
        Data.PrimaryKey = Array.Empty<DataColumn>();
        Data.Constraints.Clear();
        foreach (DataColumn c in Data.Columns)
            if (!c.AutoIncrement && !c.ReadOnly) c.AllowDBNull = true;
    }

    /// <summary>Tìm dòng theo giá trị khóa (thay cho Rows.Find vì đã gỡ PrimaryKey).</summary>
    private DataRow? TimTheoKhoa(DataTable bang, object?[] giaTriKhoa)
    {
        foreach (DataRow r in bang.Rows)
        {
            if (r.RowState == DataRowState.Deleted) continue;
            bool khop = true;
            for (int i = 0; i < CotKhoa.Length; i++)
            {
                var a = r[CotKhoa[i]]?.ToString()?.Trim() ?? "";
                var b = giaTriKhoa[i]?.ToString()?.Trim() ?? "";
                if (!string.Equals(a, b, StringComparison.OrdinalIgnoreCase)) { khop = false; break; }
            }
            if (khop) return r;
        }
        return null;
    }

    public bool CoThayDoi => Data.GetChanges() != null;

    /// <summary>Ghi mọi thay đổi xuống CSDL, đồng thời lưu trạng thái cũ vào Stack.</summary>
    public int Ghi()
    {
        if (_da == null) throw new InvalidOperationException("Chưa nạp dữ liệu.");

        // Ảnh chụp TRƯỚC khi ghi: bản sao chỉ gồm các giá trị GỐC của từng dòng.
        var truocKhiGhi = TaoAnhChup();

        var n = _da.Update(Data);
        Data.AcceptChanges();

        if (n > 0) _lichSu.Push(truocKhiGhi);
        return n;
    }

    /// <summary>Ảnh chụp bảng theo giá trị GỐC (trạng thái đang có dưới CSDL).</summary>
    private DataTable TaoAnhChup()
    {
        var anh = Data.Clone();
        foreach (DataRow r in Data.Rows)
        {
            if (r.RowState == DataRowState.Added) continue;          // chưa có dưới CSDL
            var moi = anh.NewRow();
            foreach (DataColumn c in Data.Columns)
                moi[c.ColumnName] = r[c.ColumnName, DataRowVersion.Original];
            anh.Rows.Add(moi);
        }
        anh.AcceptChanges();
        return anh;
    }

    /// <summary>
    /// PHỤC HỒI mức 1: hủy các thao tác CHƯA ghi (giống nút Undo của Word
    /// khi chưa lưu). Không đụng tới CSDL.
    /// </summary>
    public void PhucHoi() => Data.RejectChanges();

    /// <summary>
    /// PHỤC HỒI mức 2: lùi lại MỘT bước ĐÃ GHI (lấy từ Stack) rồi ghi
    /// trạng thái cũ xuống CSDL. Gọi nhiều lần để lùi nhiều cấp.
    /// Trả về số dòng đã điều chỉnh.
    /// </summary>
    public int LuiMotBuoc()
    {
        if (_da == null) throw new InvalidOperationException("Chưa nạp dữ liệu.");
        if (_lichSu.Count == 0) throw new InvalidOperationException("Không còn bước nào để lùi.");

        Data.RejectChanges();                 // bỏ phần chưa ghi trước đã
        var cu = _lichSu.Pop();

        if (CotKhoa.Length == 0)
            throw new InvalidOperationException(
                "Bảng không có khóa chính nên không lùi được từng bước.");

        // 1) Dòng có ở trạng thái cũ -> khôi phục giá trị (thêm lại nếu đã bị xóa)
        foreach (DataRow rCu in cu.Rows)
        {
            var giaTriKhoa = CotKhoa.Select(k => rCu[k]).ToArray();
            var rHienTai = TimTheoKhoa(Data, giaTriKhoa);

            if (rHienTai == null)
            {
                var them = Data.NewRow();
                foreach (DataColumn c in Data.Columns) them[c.ColumnName] = rCu[c.ColumnName];
                Data.Rows.Add(them);
            }
            else
            {
                foreach (DataColumn c in Data.Columns)
                    if (!CotKhoa.Contains(c.ColumnName) &&
                        !Equals(rHienTai[c.ColumnName], rCu[c.ColumnName]))
                        rHienTai[c.ColumnName] = rCu[c.ColumnName];
            }
        }

        // 2) Dòng KHÔNG có ở trạng thái cũ -> vốn là dòng mới thêm -> xóa đi
        for (int i = Data.Rows.Count - 1; i >= 0; i--)
        {
            var r = Data.Rows[i];
            if (r.RowState == DataRowState.Deleted) continue;
            var giaTriKhoa = CotKhoa.Select(k => r[k]).ToArray();
            if (TimTheoKhoa(cu, giaTriKhoa) == null) r.Delete();
        }

        var n = _da.Update(Data);
        Data.AcceptChanges();
        return n;
    }

    public void XoaLichSu() => _lichSu.Clear();

    /// <summary>
    /// Tạo một dòng mới để người dùng nhập.
    /// Ràng buộc phía máy trạm đã được gỡ trong Nap() nên dòng trống thêm
    /// được bình thường; tính đúng đắn do CSDL và hàm kiểm trước khi Ghi lo.
    /// </summary>
    public static DataRow TaoDongMoi(DataTable dt) => dt.NewRow();
}
