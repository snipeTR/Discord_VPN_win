<#
    Discord VPN kurulumu (WireSock + WGCF)

    Sadece Discord'u Cloudflare WARP üzerinden geçirir; diğer programlar normal
    internet bağlantısını kullanır.

    Çalıştırma: dosyaya sağ tıklayın > "PowerShell ile çalıştır".
    Ya da:      powershell -ExecutionPolicy Bypass -File .\discord_vpn.ps1

    -Mode auto | step   Menüyü atlar (yönetici penceresi kendini bununla açar).
#>
param(
    [ValidateSet('', 'auto', 'step')]
    [string]$Mode = ''
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '4.0'
$ScriptPath = $PSCommandPath

# ---------------------------------------------------------------------------
# Ayarlar
# ---------------------------------------------------------------------------

# Sürüm değişirse dosya adları ve SHA256 değerleri de güncellenmelidir.
$WgcfVersion     = '2.3.1'
$WireSockVersion = '2.4.5.1'
$Packages = @{
    AMD64 = @{
        Wgcf             = 'wgcf_2.3.1_windows_amd64.exe'
        WgcfSha256       = 'e222fd9443d7cb3264d825a3e86967797fc9c938507c5d93e3cc21e4aed11dcc'
        WireSock         = 'wiresock-secure-connect-x64-2.4.5.1.exe'
        WireSockPlatform = 'windows_x64'
        WireSockSha256   = 'a8274e8241a34154eaa70ba6a5e942423ef8bb820e77822f911d967275c4d2a5'
    }
    x86 = @{
        Wgcf             = 'wgcf_2.3.1_windows_386.exe'
        WgcfSha256       = '98492e85ce9a690e2f143e2ad9272ce59f6915ceeb604ad25c89d9123fbb5a82'
        WireSock         = 'wiresock-secure-connect-x86-2.4.5.1.exe'
        WireSockPlatform = 'windows_x32'
        WireSockSha256   = '34298cfd56ad258996fb55d2bc3cb3deefb87ec1c8ce8b1a502277d361132891'
    }
}

$AllowedApp  = 'Discord.exe'
$ServiceName = 'wiresock-client-service'
# WireSock Secure Connect, istemciyi "Program Files\WireSock Secure Connect\bin" altına kurar.
$WireSockClientRel = 'WireSock Secure Connect\bin\wiresock-client.exe'

# İndirilenler Downloads'a, WARP hesabı ve VPN profili Belgeler'e konur.
try   { $DownloadDir = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path }
catch { $DownloadDir = Join-Path $env:USERPROFILE 'Downloads' }
$DocsDir     = [Environment]::GetFolderPath('MyDocuments')
$AccountFile = Join-Path $DocsDir 'wgcf-account.toml'
$ProfileFile = Join-Path $DocsDir 'wgcf-profile.conf'

# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------

function Write-Ok([string]$Text)   { Write-Host "  [OK] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "  [!]  $Text" -ForegroundColor Yellow }
function Write-Line                { Write-Host ('=' * 70) -ForegroundColor DarkCyan }

# E/H sorusu sorar; Evet ise $true döner.
function Read-YesNo([string]$Question) {
    while ($true) {
        $answer = Read-Host "$Question (E/H)"
        if ($null -eq $answer) { return $false }   # Giriş kapandıysa (konsol yok) hayır say.
        $answer = $answer.Trim().ToUpperInvariant()
        if ($answer -eq 'E') { return $true }
        if ($answer -eq 'H') { return $false }
        Write-Warn 'Lütfen E veya H yazıp Enter''a basın.'
    }
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Gerçek işletim sistemi mimarisi (32-bit PowerShell'de de doğru sonuç verir).
function Get-OsArch {
    (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
}

function Test-Sha256([string]$Path, [string]$Sha256) {
    (Test-Path -LiteralPath $Path) -and ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $Sha256)
}

# Harici programı çalıştırır, çıkış kodunu döner.
function Invoke-Exe([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments | Out-Host
    $LASTEXITCODE
}

function Find-WireSockClient {
    foreach ($root in @($env:ProgramW6432, $env:ProgramFiles)) {
        if (-not $root) { continue }
        $path = Join-Path $root $WireSockClientRel
        if (Test-Path -LiteralPath $path) { return $path }
    }
    $null
}

# Dosyayı Downloads'a indirir ve doğrular (en fazla 2 deneme).
# Doğru dosya zaten varsa tekrar indirmez.
function Get-VerifiedFile([string]$Name, [string]$Url, [string]$Sha256) {
    $path = Join-Path $DownloadDir $Name
    if (Test-Sha256 $path $Sha256) {
        Write-Ok "$Name zaten indirilmiş ve doğrulanmış."
        return
    }
    $ProgressPreference = 'SilentlyContinue'   # İlerleme çubuğu indirmeyi çok yavaşlatıyor.
    for ($try = 1; $try -le 2; $try++) {
        Write-Host "  $Name indiriliyor (deneme $try/2)..."
        try   { Invoke-WebRequest -Uri $Url -OutFile $path -UseBasicParsing }
        catch { Write-Warn "İndirme hatası: $($_.Exception.Message)" }
        if (Test-Sha256 $path $Sha256) {
            Write-Ok "$Name indirildi ve doğrulandı."
            return
        }
        Write-Warn "$Name doğrulanamadı."
    }
    Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
    throw "$Name indirilemedi. Tarayıcıyla indirip `"$DownloadDir`" klasörüne koyun ve script'i tekrar çalıştırın: $Url"
}

# ---------------------------------------------------------------------------
# Kurulum adımları
# ---------------------------------------------------------------------------

function Step-Download {
    Get-VerifiedFile $Pkg.Wgcf "https://github.com/ViRb3/wgcf/releases/download/v$WgcfVersion/$($Pkg.Wgcf)" $Pkg.WgcfSha256
    Get-VerifiedFile $Pkg.WireSock "https://wiresock.net/_api/download-release.php?product=wiresock-secure-connect&platform=$($Pkg.WireSockPlatform)&version=$WireSockVersion" $Pkg.WireSockSha256
}

function Step-Account {
    if (Test-Path -LiteralPath $AccountFile) {
        Write-Ok "WARP hesabı zaten var, yeniden kullanılıyor: $AccountFile"
        return
    }
    $code = Invoke-Exe (Join-Path $DownloadDir $Pkg.Wgcf) @('register', '--accept-tos', '--config', $AccountFile)
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $AccountFile)) {
        throw "WARP hesabı oluşturulamadı (wgcf kodu: $code). İnternet bağlantınızı kontrol edip tekrar deneyin."
    }
    Write-Ok "WARP hesabı oluşturuldu: $AccountFile"
}

function Step-Profile {
    $code = Invoke-Exe (Join-Path $DownloadDir $Pkg.Wgcf) @('generate', '--config', $AccountFile, '--profile', $ProfileFile)
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $ProfileFile)) {
        throw "VPN profili oluşturulamadı (wgcf kodu: $code)."
    }
    # wgcf profili [Peer] bölümüyle bitirir; sona eklenen satır bu bölüme düşer.
    $text = [IO.File]::ReadAllText($ProfileFile)
    if ($text -notmatch '(?m)^AllowedApps\s*=') {
        if (-not $text.EndsWith("`n")) { $text += "`r`n" }
        [IO.File]::WriteAllText($ProfileFile, $text + "AllowedApps = $AllowedApp`r`n")
    }
    Write-Ok "Profil hazır, sadece $AllowedApp VPN'i kullanacak: $ProfileFile"
}

function Step-InstallWireSock {
    $client = Find-WireSockClient
    if ($client) {
        Write-Ok "WireSock zaten kurulu: $client"
        return
    }
    $setup = Join-Path $DownloadDir $Pkg.WireSock
    if (-not (Test-Sha256 $setup $Pkg.WireSockSha256)) { throw "Kurulum dosyası bulunamadı veya bozuk: $setup" }

    Write-Host '  WireSock kuruluyor. Gerekirse .NET Desktop Runtime da indirilir, biraz sürebilir...'
    $process = Start-Process -FilePath $setup -ArgumentList '/passive /norestart' -Wait -PassThru
    # 0 = başarılı, 3010 = başarılı ama yeniden başlatma gerekli.
    if ($process.ExitCode -notin 0, 3010) {
        Write-Warn "Otomatik kurulum başarısız oldu (kod: $($process.ExitCode)). Kurulum sihirbazı açılıyor, lütfen adımları tamamlayın."
        Start-Process -FilePath $setup -Wait | Out-Null
    }
    $client = Find-WireSockClient
    if (-not $client) { throw "WireSock kurulamadı: $WireSockClientRel bulunamadı." }
    Write-Ok "WireSock kuruldu: $client"
    if ($process.ExitCode -eq 3010) { Write-Warn 'Kurulum bittikten sonra bilgisayarı yeniden başlatmanız gerekebilir.' }
}

function Step-Service {
    $client = Find-WireSockClient
    if (-not $client) { throw 'WireSock kurulu değil. Önce WireSock kurulum adımı çalışmalı.' }
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Ok "Servis ($ServiceName) zaten var."
    } else {
        $code = Invoke-Exe $client @('install', '-start-type', '2', '-config', $ProfileFile, '-log-level', 'none')
        if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
            throw "Servis oluşturulamadı (wiresock-client kodu: $code)."
        }
        Write-Ok "Servis ($ServiceName) oluşturuldu."
    }
    Set-Service -Name $ServiceName -StartupType Automatic
    Write-Ok 'Servis Windows açılışında otomatik başlayacak.'
}

function Step-StartService {
    if ((Get-Service -Name $ServiceName).Status -eq 'Running') {
        Write-Host '  Servis çalışıyor, yeni ayarların yüklenmesi için yeniden başlatılıyor...'
        Restart-Service -Name $ServiceName -Force
    } else {
        Start-Service -Name $ServiceName
    }
    Start-Sleep -Seconds 3
    if ((Get-Service -Name $ServiceName).Status -ne 'Running') {
        throw "Servis başlatılamadı. services.msc'den '$ServiceName' servisini kontrol edin."
    }
    Write-Ok 'Servis çalışıyor.'
}

$Steps = @(
    @{ Title = 'Dosyaları indir';     Run = { Step-Download };        Info = "wgcf ve WireSock, Downloads klasörüne indirilir ve SHA256 ile doğrulanır." }
    @{ Title = 'WARP hesabı';         Run = { Step-Account };         Info = "wgcf ile ücretsiz bir Cloudflare WARP hesabı açılır (varsa yeniden kullanılır)." }
    @{ Title = 'VPN profili';         Run = { Step-Profile };         Info = "WireGuard profili oluşturulur; VPN'i sadece Discord ($AllowedApp) kullanır." }
    @{ Title = 'WireSock kurulumu';   Run = { Step-InstallWireSock }; Info = "WireSock Secure Connect kurulur (kuruluysa atlanır)." }
    @{ Title = 'Windows servisi';     Run = { Step-Service };         Info = "VPN için Windows açılışında otomatik başlayan bir servis oluşturulur." }
    @{ Title = 'Servisi başlat';      Run = { Step-StartService };    Info = "Servis başlatılır; Discord bundan sonra VPN üzerinden bağlanır." }
)

# ---------------------------------------------------------------------------
# Akış
# ---------------------------------------------------------------------------

function Show-Intro {
    Write-Line
    Write-Host "  Discord VPN Kurulumu  (v$ScriptVersion)" -ForegroundColor Cyan
    Write-Line
    Write-Host '  Bu script sadece Discord''u Cloudflare WARP (ücretsiz VPN) üzerinden'
    Write-Host '  geçirir. Diğer programlarınız normal internetinizi kullanmaya devam eder.'
    Write-Host ''
    Write-Host '  Yapılacaklar:'
    for ($i = 0; $i -lt $Steps.Count; $i++) {
        Write-Host ("   {0}. {1}" -f ($i + 1), $Steps[$i].Info)
    }
    Write-Host ''
    Write-Host '  Kurulum için yönetici izni istenecek.'
    Write-Line
}

# Menü; 'auto', 'step' ya da iptal için '' döner.
function Read-Menu {
    Write-Host '  [1] Tam otomatik kurulum'
    Write-Host '  [2] Adım adım kurulum (her adımı onaylayarak)'
    Write-Host '  [3] İptal'
    while ($true) {
        $answer = Read-Host 'Seçiminiz (1/2/3)'
        if ($null -eq $answer) { return '' }   # Giriş kapandıysa (konsol yok) iptal say.
        switch ($answer.Trim()) {
            '1' { return 'auto' }
            '2' { return 'step' }
            '3' { return '' }
        }
        Write-Warn 'Lütfen 1, 2 veya 3 yazıp Enter''a basın.'
    }
}

function Invoke-Setup([string]$SetupMode) {
    $arch = Get-OsArch
    if (-not $Packages.ContainsKey($arch)) { throw "Bu işlemci mimarisi desteklenmiyor: $arch (sadece x64 ve x86)." }
    $script:Pkg = $Packages[$arch]
    Write-Host "  Mimari: $arch    Mod: $(if ($SetupMode -eq 'step') { 'adım adım' } else { 'tam otomatik' })"

    # Windows PowerShell 5.1 varsayılan olarak GitHub'ın istediği TLS 1.2'yi açmıyor.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    for ($i = 0; $i -lt $Steps.Count; $i++) {
        $step = $Steps[$i]
        Write-Host ''
        Write-Host ("[{0}/{1}] {2}" -f ($i + 1), $Steps.Count, $step.Title) -ForegroundColor Cyan
        Write-Host "  $($step.Info)"
        if ($SetupMode -eq 'step' -and -not (Read-YesNo '  Bu adım çalıştırılsın mı?')) {
            throw (New-Object OperationCanceledException 'Kurulum iptal edildi.')
        }
        & $step.Run
    }
}

function Main {
    Show-Intro
    $selected = $Mode
    if (-not $selected) { $selected = Read-Menu }
    if (-not $selected) {
        Write-Host 'Kurulum iptal edildi. Hiçbir değişiklik yapılmadı.'
        Read-Host 'Çıkmak için Enter''a basın' | Out-Null
        exit 0
    }

    # Yönetici değilsek seçilen modla yönetici penceresinde yeniden başla.
    if (-not (Test-Admin)) {
        Write-Host 'Yönetici izni isteniyor...'
        try {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Mode $selected"
        } catch {
            Write-Warn 'Yönetici izni verilmedi. Hiçbir değişiklik yapılmadı.'
            Read-Host 'Çıkmak için Enter''a basın' | Out-Null
            exit 1
        }
        Write-Host 'Kurulum yönetici penceresinde devam ediyor. Bu pencere kapanabilir.'
        Start-Sleep -Seconds 3
        exit 0
    }

    $exitCode = 0
    try {
        Invoke-Setup $selected
        Write-Host ''
        Write-Line
        Write-Host '  KURULUM TAMAMLANDI' -ForegroundColor Green
        Write-Line
        Write-Host "  Discord artık VPN üzerinden bağlanıyor. Servis ($ServiceName) her açılışta"
        Write-Host '  otomatik başlar. Discord''u açıp sesli kanallara bağlanarak kontrol edin.'
        Write-Host "  Profil: $ProfileFile"
    } catch [OperationCanceledException] {
        Write-Host ''
        Write-Warn "$($_.Exception.Message) Bu adıma kadar yapılanlar yerinde kaldı."
        $exitCode = 1
    } catch {
        Write-Host ''
        Write-Host "HATA: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Sorunu çözdükten sonra script''i tekrar çalıştırabilirsiniz; tamamlanan adımlar atlanır.'
        $exitCode = 1
    }
    Write-Host ''
    Read-Host 'Çıkmak için Enter''a basın' | Out-Null
    exit $exitCode
}

# Testlerde dosya ". .\discord_vpn.ps1" ile yüklenebilsin diye Main sadece doğrudan çalıştırılınca başlar.
if ($MyInvocation.InvocationName -ne '.') { Main }
