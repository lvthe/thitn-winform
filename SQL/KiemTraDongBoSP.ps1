<#
    KIỂM TRA ĐỒNG BỘ STORED PROCEDURE GIỮA MÁY CHỦ VÀ CÁC PHÂN MẢNH
    ---------------------------------------------------------------
    Chạy:  .\KiemTraDongBoSP.ps1
           .\KiemTraDongBoSP.ps1 -TenMay "TEN-MAY-CUA-BAN"

    VÌ SAO CẦN CÔNG CỤ NÀY

    23 thủ tục của đồ án được khai báo là ARTICLE của merge replication.
    Khi một thủ tục đã là Article thì nhân bản sẽ GHI ĐÈ bản sửa trực tiếp
    trên phân mảnh bằng bản của máy chủ. Nghĩa là:

        Sửa thủ tục trực tiếp trên SERVER1 / SERVER2
                    -> lần đồng bộ kế tiếp sẽ MẤT

    Thực tế đã xảy ra: ba bản vá quan trọng (sp_LayDeThi, sp_ChuanBiThi,
    sp_BangDiemMonHoc) từng bị nhân bản hoàn tác trên CS2 mà giao diện
    vẫn chạy bình thường nên không lộ ra.

    => QUY TẮC: chỉ sửa thủ tục trên MÁY CHỦ, rồi để nhân bản đẩy xuống.
       Chạy script này sau mỗi lần sửa để chắc chắn ba nơi khớp nhau.
#>
param([string] $TenMay = $env:COMPUTERNAME)

Add-Type -AssemblyName System.Data

# Chuẩn hoá để bỏ qua khác biệt KHÔNG ảnh hưởng logic:
#   [dbo].[sp_X] và dbo.sp_X là một; khoảng trắng thừa không tính.
function ChuanHoa($t) {
    if (-not $t) { return "" }
    ($t -replace '\[', '' -replace '\]', '' -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function LaySP($server) {
    $d = @{}
    try {
        $cn = New-Object System.Data.SqlClient.SqlConnection(
            "Server=$server;Database=TN_CSDLPT;Integrated Security=True;TrustServerCertificate=True;Connect Timeout=10")
        $cn.Open()
        $c = $cn.CreateCommand()
        $c.CommandText = @"
SELECT o.name, m.definition
FROM sys.sql_modules m JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type='P' AND o.is_ms_shipped=0
  AND o.name NOT LIKE 'MSmerge%' AND o.name NOT LIKE 'sp_MS%'
  AND o.name NOT LIKE 'sp_%diagram%'
"@
        $r = $c.ExecuteReader()
        while ($r.Read()) { $d[$r.GetString(0)] = ChuanHoa $r.GetString(1) }
        $r.Close(); $cn.Close()
    } catch {
        Write-Host "  Không kết nối được $server : $($_.Exception.Message)" -ForegroundColor Red
    }
    return $d
}

# Tiện ích chỉ chạy ở máy chủ, không cần có mặt ở phân mảnh
$ChiOMayChu = @('sp_LamMoi_BodeMuon',      # gom BODE của CẢ HAI cơ sở
                'sp_ChotBaoCao_DangKy',    # job chốt số liệu
                'SP_SAOLUU', 'SP_PHUCHOI_CSDL', 'SP_DS_SAOLUU', 'SP_TAOLOGIN')

Write-Host ""
Write-Host "=== KIEM TRA DONG BO STORED PROCEDURE ===" -ForegroundColor Cyan
$chu = LaySP "$TenMay\SERVER"
$s1  = LaySP "$TenMay\SERVER1"
$s2  = LaySP "$TenMay\SERVER2"

if ($chu.Count -eq 0) { Write-Host "Không đọc được máy chủ. Dừng." -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host ("{0,-32} {1,-12} {2,-12}" -f "THU TUC", "SERVER1", "SERVER2")
Write-Host ("-" * 58)

$soLech = 0
foreach ($ten in ($chu.Keys | Sort-Object)) {
    if ($ChiOMayChu -contains $ten) { continue }

    $c1 = if (-not $s1.ContainsKey($ten)) { "THIEU" }
          elseif ($s1[$ten] -eq $chu[$ten]) { "khop" } else { "LECH" }
    $c2 = if (-not $s2.ContainsKey($ten)) { "THIEU" }
          elseif ($s2[$ten] -eq $chu[$ten]) { "khop" } else { "LECH" }

    if ($c1 -ne "khop" -or $c2 -ne "khop") {
        $mau = if ($c1 -eq "LECH" -or $c2 -eq "LECH") { "Red" } else { "Yellow" }
        Write-Host ("{0,-32} {1,-12} {2,-12}" -f $ten, $c1, $c2) -ForegroundColor $mau
        $soLech++
    }
}

Write-Host ""
if ($soLech -eq 0) {
    Write-Host "TAT CA THU TUC DEU KHOP giua may chu va hai phan manh." -ForegroundColor Green
} else {
    Write-Host "$soLech thu tuc LECH hoac THIEU." -ForegroundColor Red
    Write-Host ""
    Write-Host "Cach xu ly:" -ForegroundColor Yellow
    Write-Host "  1. Sua thu tuc tren MAY CHU (SERVER), khong sua tren phan manh"
    Write-Host "  2. Chay Merge Agent de day xuong, hoac tao lai snapshot"
    Write-Host "  3. Chay lai script nay de xac nhan"
}
Write-Host ""
Write-Host ("Da doi chieu {0} thu tuc (bo qua {1} tien ich chi o may chu)." -f `
            ($chu.Count - ($ChiOMayChu | Where-Object { $chu.ContainsKey($_) }).Count), `
            ($ChiOMayChu | Where-Object { $chu.ContainsKey($_) }).Count)
Write-Host ""
