<#
    CÀI ĐẶT TOÀN BỘ HỆ THỐNG TRÊN MÁY MỚI
    ---------------------------------------------------------------
    Chạy:   .\CaiDat.ps1
            .\CaiDat.ps1 -TenMay "TEN-MAY" -ThuMucSnapshot "D:\ReplData"
            .\CaiDat.ps1 -BoQuaNhanBan          (chỉ tạo CSDL, không cấu hình replication)

    Mọi script đều lưu UTF-8 nên bắt buộc gọi sqlcmd với -f 65001,
    nếu không tiếng Việt sẽ hiện sai.
#>
param(
    [string] $TenMay          = $env:COMPUTERNAME,
    [string] $ThuMucSnapshot  = "$PSScriptRoot\..\ReplData",
    [switch] $BoQuaNhanBan
)

$ErrorActionPreference = 'Stop'
$SQL = $PSScriptRoot

$Chu    = "$TenMay\SERVER"
$CS1    = "$TenMay\SERVER1"
$CS2    = "$TenMay\SERVER2"
$TraCuu = "$TenMay\SERVER3"

function Chay {
    param([string]$MayChu, [string]$Tep, [string[]]$ThamSo = @(), [switch]$BoQuaLoi)
    $duongDan = Join-Path $SQL $Tep
    if (-not (Test-Path $duongDan)) { Write-Host "  (khong thay $Tep - bo qua)" -ForegroundColor DarkGray; return }

    Write-Host ("  {0,-42} -> {1}" -f $Tep, $MayChu) -ForegroundColor Gray
    $args = @('-S', $MayChu, '-E', '-f', '65001', '-i', $duongDan) + $ThamSo
    $ketQua = & sqlcmd @args 2>&1
    $loi = $ketQua | Select-String -Pattern '^Msg \d+' | Select-Object -First 3
    if ($loi -and -not $BoQuaLoi) {
        Write-Host "     ! Có lỗi:" -ForegroundColor Yellow
        $loi | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    }
}

function KiemTraInstance {
    param([string]$MayChu)
    try {
        $r = & sqlcmd -S $MayChu -E -l 10 -h -1 -W -Q "SELECT 1" 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

Write-Host ""
Write-Host "==== CAI DAT HE THONG THI TRAC NGHIEM ====" -ForegroundColor Cyan
Write-Host "Ten may       : $TenMay"
Write-Host "Thu muc snapshot: $ThuMucSnapshot"
Write-Host ""

# ---------- Kiểm tra 4 instance ----------
Write-Host "[0/6] Kiem tra ket noi 4 instance..." -ForegroundColor Cyan
$thieu = @()
foreach ($m in @($Chu, $CS1, $CS2, $TraCuu)) {
    if (KiemTraInstance $m) { Write-Host "  OK  $m" -ForegroundColor Green }
    else { Write-Host "  LOI $m" -ForegroundColor Red; $thieu += $m }
}
if ($thieu.Count -gt 0) {
    Write-Host ""
    Write-Host "Khong ket noi duoc cac instance tren. Kiem tra:" -ForegroundColor Red
    Write-Host "  - SQL Server va SQL Server Browser da chay chua"
    Write-Host "  - Ten may co dung khong (SELECT @@SERVERNAME)"
    exit 1
}

# ---------- 1. Cấu trúc bảng ----------
Write-Host ""
Write-Host "[1/6] Tao cau truc bang tren ca 4 instance..." -ForegroundColor Cyan
foreach ($m in @($Chu, $CS1, $CS2, $TraCuu)) { Chay $m '00_TaoCSDL_Schema.sql' }

# ---------- 2. Stored procedure ----------
Write-Host ""
Write-Host "[2/6] Nap stored procedure..." -ForegroundColor Cyan
foreach ($m in @($Chu, $CS1, $CS2)) { Chay $m '00e_StoredProcedures.sql' }

# ---------- 3. Dữ liệu mẫu (chỉ publisher) ----------
Write-Host ""
Write-Host "[3/6] Nap du lieu mau (chi may chu)..." -ForegroundColor Cyan
Chay $Chu '01_DuLieuMau.sql'

# ---------- 4. Nhóm quyền + tài khoản ----------
Write-Host ""
Write-Host "[4/6] Tao nhom quyen va tai khoan..." -ForegroundColor Cyan
Chay $Chu    '02_NhomQuyen_TaiKhoan.sql' @('-v', 'MayChu=CHU')
Chay $CS1    '02_NhomQuyen_TaiKhoan.sql' @('-v', 'MayChu=CS1')
Chay $CS2    '02_NhomQuyen_TaiKhoan.sql' @('-v', 'MayChu=CS2')
Chay $TraCuu '02_NhomQuyen_TaiKhoan.sql' @('-v', 'MayChu=TRACUU')
Chay $TraCuu '02_Cau1_TaiKhoanTraCuu_SERVER3.sql'

# ---------- 5. Phân quyền chi tiết + các bản vá ----------
Write-Host ""
Write-Host "[5/6] Phan quyen chi tiet va cac ban va..." -ForegroundColor Cyan
foreach ($m in @($Chu, $CS1, $CS2)) { Chay $m '03_PhanQuyen.sql' }
foreach ($m in @($Chu, $CS1, $CS2)) { Chay $m '01_Cau1_DangNhap_TaiKhoan.sql' }
foreach ($m in @($Chu, $CS1, $CS2)) { Chay $m '08_SP_LayThongTin_TheoMauThay.sql' }
foreach ($m in @($CS1, $CS2)) {
    Chay $m '04_Cau7_Cau8_SuaKhoMuonDe.sql'
    Chay $m '05_Cau8_SuaTrungMaCauHoi.sql'
    Chay $m '06_Cau10_Cau11_BaoCao.sql'
    Chay $m '09_VaLoHongPhanQuyen.sql'
}
foreach ($m in @($Chu, $CS1, $CS2)) { Chay $m '07_SaoLuu_PhucHoi.sql' }

# ---------- 6. Nhân bản ----------
if ($BoQuaNhanBan) {
    Write-Host ""
    Write-Host "[6/6] BO QUA buoc cau hinh nhan ban (-BoQuaNhanBan)" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "[6/6] Thiet lap nhan ban..." -ForegroundColor Cyan
    if (-not (Test-Path $ThuMucSnapshot)) { New-Item -ItemType Directory -Force $ThuMucSnapshot | Out-Null }

    # Truyền tên máy thật vào script replication
    $tepGoc = Join-Path $SQL '03_ThietLapNhanBan.sql'
    $tepTam = Join-Path $env:TEMP 'ThietLapNhanBan_tam.sql'
    $noiDung = Get-Content $tepGoc -Raw -Encoding UTF8
    $noiDung = $noiDung -replace ':setvar MayChu\s+".*?"',         (':setvar MayChu          "' + $Chu + '"')
    $noiDung = $noiDung -replace ':setvar MayCS1\s+".*?"',         (':setvar MayCS1          "' + $CS1 + '"')
    $noiDung = $noiDung -replace ':setvar MayCS2\s+".*?"',         (':setvar MayCS2          "' + $CS2 + '"')
    $noiDung = $noiDung -replace ':setvar MayTraCuu\s+".*?"',      (':setvar MayTraCuu       "' + $TraCuu + '"')
    $noiDung = $noiDung -replace ':setvar ThuMucSnapshot\s+".*?"', (':setvar ThuMucSnapshot  "' + (Resolve-Path $ThuMucSnapshot).Path + '"')
    [System.IO.File]::WriteAllText($tepTam, $noiDung, (New-Object System.Text.UTF8Encoding $false))

    Write-Host ("  {0,-42} -> {1}" -f '03_ThietLapNhanBan.sql', $Chu) -ForegroundColor Gray
    & sqlcmd -S $Chu -E -f 65001 -i $tepTam
    Remove-Item $tepTam -ErrorAction SilentlyContinue
}

# ---------- Kiểm tra kết quả ----------
Write-Host ""
Write-Host "==== KIEM TRA ====" -ForegroundColor Cyan
foreach ($m in @($Chu, $CS1, $CS2, $TraCuu)) {
    $r = & sqlcmd -S $m -d TN_CSDLPT -E -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.SINHVIEN;" 2>&1
    $n = ($r | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
    Write-Host ("  {0,-32} {1,4} sinh vien" -f $m, $n)
}

Write-Host ""
Write-Host "XONG." -ForegroundColor Green
if (-not $BoQuaNhanBan) {
    Write-Host "Buoc cuoi: mo SSMS > Replication > Replication Monitor," -ForegroundColor Yellow
    Write-Host "doi 3 snapshot chay xong roi Start Synchronizing tung subscription." -ForegroundColor Yellow
    Write-Host "Luc do so sinh vien se thanh: SERVER1=10, SERVER2=8, SERVER3=18." -ForegroundColor Yellow
}
Write-Host ""
