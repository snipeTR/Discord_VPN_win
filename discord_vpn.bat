@echo off
:: < nul: chcp girisi okumasin (giris yonlendirilirse cevaplari yutmasin).
chcp 65001 > nul < nul
setlocal enabledelayedexpansion

:: Script Title
title WireSock ^& WGCF Otomatik Kurulum ve Yapilandirma (v3.5)

:: Renk Ayarlari (Opsiyonel)
color 0A

:: KURAL: Parantezli bloklarin ( ... ) icinde degiskenler !VAR! ile okunur.
:: %VAR% blok calismadan once acilir; blok icinde atanan degeri goremez ve
:: icindeki ( ) ^& gibi karakterler blogu bozar. Blok icindeki echo satirlarinda
:: parantezler ^( ^) ile kacirilir.
set "EXIT_CODE=0"

:: == 1. Yönetici Hakları Kontrolü ==
cls
echo Yönetici hakları kontrol ediliyor...
net session >nul 2>&1
if errorlevel 1 (
    echo ===============================================================================
    echo HATA: Bu scriptin düzgün çalışabilmesi için Yönetici olarak çalıştırılması gerekmektedir.
    echo ===============================================================================
    echo.
    echo Talimatlar:
    echo 1. Bu pencereyi kapatın.
    echo 2. Script dosyasına ^(.bat veya .cmd^) sağ tıklayın.
    echo 3. "Yönetici olarak çalıştır" seçeneğini seçin.
    echo.
    choice /C EH /M "Script'i yönetici olarak yeniden başlatmak ister misiniz?"
    if errorlevel 2 (
        echo İşlem iptal edildi. Lütfen script'i yönetici olarak çalıştırın.
        set "EXIT_CODE=1"
        goto :EndScript
    )
    echo Script yönetici olarak yeniden başlatılıyor...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo HATA: Script yönetici olarak yeniden başlatılamadı. Lütfen manuel yapın.
        goto :ErrorExit
    )
    exit /b 0
)
echo Yönetici haklarıyla çalıştırılıyor. Devam ediliyor...
echo.
timeout /t 1 /nobreak > nul

:: == 2. İşletim Sistemi Mimarisi Tespiti ==
cls
echo ===============================================================================
echo Adım 2: İşletim Sistemi Mimarisi Tespiti
echo ===============================================================================
echo İşletim sistemi mimarisi ortam değişkenleri kullanılarak tespit ediliyor...

:: 32-bit cmd 64-bit Windows'ta çalışıyorsa gerçek mimari PROCESSOR_ARCHITEW6432'dedir.
set "OS_ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "OS_ARCH=%PROCESSOR_ARCHITEW6432%"

if /i "%OS_ARCH%"=="AMD64" (
    set "ARCH=x64"
) else if /i "%OS_ARCH%"=="x86" (
    set "ARCH=x86"
) else (
    echo HATA: Bu işlemci mimarisi desteklenmiyor: !OS_ARCH! ^(sadece x64 ve x86^). Script durduruluyor.
    goto :ErrorExit
)

:: İndirilen dosyalar SHA256 ile doğrulanır. Sürüm değişirse hash'ler de güncellenmelidir.
if "%ARCH%"=="x64" (
    set "ARCH_DISPLAY=64-bit (x64)"
    set "WGCF_URL=https://github.com/ViRb3/wgcf/releases/download/v2.3.1/wgcf_2.3.1_windows_amd64.exe"
    set "WGCF_EXE=wgcf_2.3.1_windows_amd64.exe"
    set "WGCF_SHA256=e222fd9443d7cb3264d825a3e86967797fc9c938507c5d93e3cc21e4aed11dcc"
    set "WIRESOCK_URL=https://wiresock.net/_api/download-release.php?product=wiresock-secure-connect&platform=windows_x64&version=2.4.5.1"
    set "WIRESOCK_EXE=wiresock-secure-connect-x64-2.4.5.1.exe"
    set "WIRESOCK_SHA256=a8274e8241a34154eaa70ba6a5e942423ef8bb820e77822f911d967275c4d2a5"
) else (
    set "ARCH_DISPLAY=32-bit (x86)"
    set "WGCF_URL=https://github.com/ViRb3/wgcf/releases/download/v2.3.1/wgcf_2.3.1_windows_386.exe"
    set "WGCF_EXE=wgcf_2.3.1_windows_386.exe"
    set "WGCF_SHA256=98492e85ce9a690e2f143e2ad9272ce59f6915ceeb604ad25c89d9123fbb5a82"
    set "WIRESOCK_URL=https://wiresock.net/_api/download-release.php?product=wiresock-secure-connect&platform=windows_x32&version=2.4.5.1"
    set "WIRESOCK_EXE=wiresock-secure-connect-x86-2.4.5.1.exe"
    set "WIRESOCK_SHA256=34298cfd56ad258996fb55d2bc3cb3deefb87ec1c8ce8b1a502277d361132891"
)

echo Mimari: %ARCH_DISPLAY% olarak tespit edildi. İlgili dosyalar buna göre seçilecek.
echo.
set "DOWNLOAD_DIR=%USERPROFILE%\Downloads"
set "DOCS_DIR=%USERPROFILE%\Documents"
if not exist "%DOWNLOAD_DIR%" mkdir "%DOWNLOAD_DIR%" > nul 2>&1
if not exist "%DOCS_DIR%" mkdir "%DOCS_DIR%" > nul 2>&1

set "WGCF_PROFILE_CONF_DOWNLOAD=%DOWNLOAD_DIR%\wgcf-profile.conf"
set "WGCF_ACCOUNT_TOML_DOWNLOAD=%DOWNLOAD_DIR%\wgcf-account.toml"
set "WGCF_PROFILE_CONF_DEST=%DOCS_DIR%\wgcf-profile.conf"
set "WGCF_ACCOUNT_TOML_DEST=%DOCS_DIR%\wgcf-account.toml"

:: WireSock Secure Connect, wiresock-client.exe'yi "Program Files\WireSock Secure Connect\bin" altına kurar.
set "WIRESOCK_CLIENT_REL=WireSock Secure Connect\bin\wiresock-client.exe"
set "SERVICE_NAME=wiresock-client-service"

timeout /t 3 /nobreak > nul

:: == 3. Curl Kontrolü ve Kurulumu ==
:CheckCurl
cls
echo ===============================================================================
echo Adım 3: Curl Uygulaması Kontrolü ve Kurulumu
echo ===============================================================================
echo Curl uygulamasının yüklü olup olmadığı kontrol ediliyor...

curl --version >nul 2>&1
if errorlevel 1 goto :InstallCurlWithWinget
echo Curl zaten yüklü ve çalıştırılabilir. Otomatik indirme işlemine geçiliyor.
timeout /t 2 /nobreak > nul
goto :DownloadFiles


:InstallCurlWithWinget
echo Curl bulunamadı veya çalıştırılamadı. Winget ile yüklenmeye çalışılacak...
echo Winget kontrol ediliyor...
where winget >nul 2>&1
if errorlevel 1 (
    echo Winget bulunamadı. Curl otomatik olarak yüklenemiyor. Manuel indirme gerekli.
    pause
    goto :ManualDownloadInstructions
)

echo Winget kullanılarak curl yükleniyor (Gerekirse izinleri onaylayın)...
winget install --id=cURL.cURL -e --accept-package-agreements --accept-source-agreements
set WINGET_INSTALL_EC=!errorlevel!
if !WINGET_INSTALL_EC! neq 0 (
    echo Winget ile curl kurulumu başarısız oldu ^(Hata Kodu: !WINGET_INSTALL_EC!^). Manuel indirme gerekli.
    pause
    goto :ManualDownloadInstructions
)
:: Winget PATH değişkenini bu pencerede yenilemez; curl ancak yeni pencerede görünebilir.
curl --version >nul 2>&1
if errorlevel 1 (
    echo Curl kuruldu ancak bu pencerede henüz kullanılamıyor.
    echo Lütfen bu pencereyi kapatıp script'i yeniden yönetici olarak çalıştırın.
    goto :EndScript
)
echo Curl başarıyla yüklendi. Otomatik indirme işlemine geçiliyor.
timeout /t 2 /nobreak > nul
goto :DownloadFiles


:: == Manuel İndirme Talimatları ve Sorgu ==
:ManualDownloadInstructions
cls
echo ===============================================================================
echo ÖNEMLİ: Otomatik Kurulum Başarısız Oldu - Manuel İndirme Gerekli
echo ===============================================================================
echo Curl uygulaması otomatik olarak yüklenemedi veya bulunamadı/çalıştırılamadı.
echo Aşağıdaki uygulamaları manuel olarak indirmeniz gerekmektedir.
echo İşletim Sistemi Mimarisi: %ARCH_DISPLAY%
echo.
echo İndirmeniz Gerekenler:
echo 1. WGCF (%ARCH%): !WGCF_URL!
echo 2. WireSock (%ARCH%): !WIRESOCK_URL!
echo.
echo Talimatlar:
echo 1. Yukarıdaki adresleri kopyalayın:
echo    - Bu pencerede fare ile adresi seçin.
echo    - Sağ tıklayarak kopyalayın (veya Ctrl+C).
echo 2. Web tarayıcınızı açın ve adresi yapıştırıp Enter'a basın.
echo 3. İndirilen dosyaları "%DOWNLOAD_DIR%" klasörüne kaydedin veya indirdikten sonra bu klasöre taşıyın.
echo 4. İki dosyayı da indirme işlemi bittikten sonra bu ekrana dönün.
echo.
choice /C EH /N /M "Dosyaları indirip Downloads klasörüne taşıdınız mı? (E/H): "
if errorlevel 2 (
    echo İşlem iptal edildi. Lütfen dosyaları indirip script'i tekrar çalıştırın.
    set "EXIT_CODE=1"
    goto :EndScript
)

:CheckManualDownloads
cls
echo ===============================================================================
echo Manuel İndirme Kontrolü
echo ===============================================================================
echo İndirilen dosyalar "%DOWNLOAD_DIR%" klasöründe kontrol ediliyor...
call :VerifyFile "%DOWNLOAD_DIR%\%WGCF_EXE%" %WGCF_SHA256%
if errorlevel 1 (
    echo HATA: !WGCF_EXE! dosyası "!DOWNLOAD_DIR!" klasöründe bulunamadı veya bozuk.
    echo Lütfen "!WGCF_URL!" adresinden indirip doğru yere taşıyın ve script'i tekrar çalıştırın.
    goto :ErrorExit
)
call :VerifyFile "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" %WIRESOCK_SHA256%
if errorlevel 1 (
    echo HATA: !WIRESOCK_EXE! dosyası "!DOWNLOAD_DIR!" klasöründe bulunamadı veya bozuk.
    echo Lütfen "!WIRESOCK_URL!" adresinden indirip doğru yere taşıyın ve script'i tekrar çalıştırın.
    goto :ErrorExit
)
echo Gerekli dosyalar Downloads klasöründe bulundu ve doğrulandı. Devam ediliyor...
echo.
timeout /t 3 /nobreak > nul
goto :RunWGCF

:: == 4. Gerekli Dosyaları İndirme (Curl Varsa) ==
:DownloadFiles
cls
echo ===============================================================================
echo Adım 4: Gerekli Dosyaları İndirme (Mimari: %ARCH_DISPLAY%)
echo ===============================================================================
echo Gerekli dosyalar "%DOWNLOAD_DIR%" klasörüne indirilecek.
echo.
call :DownloadOne "%WGCF_EXE%" "%WGCF_URL%" %WGCF_SHA256%
if errorlevel 1 goto :ErrorExit
call :DownloadOne "%WIRESOCK_EXE%" "%WIRESOCK_URL%" %WIRESOCK_SHA256%
if errorlevel 1 goto :ErrorExit
timeout /t 3 /nobreak > nul

:: == 5. WGCF Komutlarını Çalıştırma ve Dosya Kontrolü ==
:RunWGCF
cls
echo ===============================================================================
echo Adım 5: WGCF Komutlarını Çalıştırma
echo ===============================================================================
echo "%DOWNLOAD_DIR%" klasörüne geçiliyor...
cd /d "%DOWNLOAD_DIR%"
if errorlevel 1 (
   echo HATA: "!DOWNLOAD_DIR!" klasörüne geçilemedi. Klasörün var olduğundan emin olun.
   goto :ErrorExit
)

:: Önceki çalıştırmadan kalan hesap varsa onu kullan; her seferinde yeni WARP hesabı açılmasın.
if not exist "%WGCF_ACCOUNT_TOML_DOWNLOAD%" if exist "%WGCF_ACCOUNT_TOML_DEST%" (
    echo Önceki WGCF hesabı bulundu, yeniden kullanılıyor: "!WGCF_ACCOUNT_TOML_DEST!"
    copy /Y "!WGCF_ACCOUNT_TOML_DEST!" "!WGCF_ACCOUNT_TOML_DOWNLOAD!" > nul
)

if exist "%WGCF_ACCOUNT_TOML_DOWNLOAD%" (
    echo WGCF hesabı zaten mevcut, register adımı atlanıyor.
) else (
    echo "!WGCF_EXE! register --accept-tos" komutu çalıştırılıyor...
    "!DOWNLOAD_DIR!\!WGCF_EXE!" register --accept-tos
    set WGCF_REG_EC=!errorlevel!
    if !WGCF_REG_EC! neq 0 (
       echo HATA: WGCF register komutu başarısız oldu. ^(Hata Kodu: !WGCF_REG_EC!^)
       echo Manuel olarak çalıştırmayı deneyin:
       echo 1. Başlat menüsüne cmd yazın ve Komut İstemi'ni Yönetici olarak çalıştırın.
       echo 2. cd "!DOWNLOAD_DIR!" komutunu girin.
       echo 3. "!WGCF_EXE!" register --accept-tos komutunu girin.
       echo Sorun devam ederse WGCF uygulamasında veya internet bağlantınızda bir sorun olabilir.
       goto :ErrorExit
    )
)
echo.

echo "%WGCF_EXE% generate" komutu çalıştırılıyor...
"%DOWNLOAD_DIR%\%WGCF_EXE%" generate
set WGCF_GEN_EC=!errorlevel!
if !WGCF_GEN_EC! neq 0 (
   echo HATA: WGCF generate komutu başarısız oldu. ^(Hata Kodu: !WGCF_GEN_EC!^)
   echo Manuel olarak çalıştırmayı deneyin:
   echo 1. Başlat menüsüne cmd yazın ve Komut İstemi'ni Yönetici olarak çalıştırın.
   echo 2. cd "!DOWNLOAD_DIR!" komutunu girin.
   echo 3. "!WGCF_EXE!" generate komutunu girin.
   echo Sorun devam ederse WGCF uygulamasında bir sorun olabilir.
   goto :ErrorExit
)
echo.

echo Oluşturulan dosyalar kontrol ediliyor...
if not exist "%WGCF_PROFILE_CONF_DOWNLOAD%" (
    echo HATA: wgcf-profile.conf dosyası oluşturulamadı.
    echo Lütfen WGCF komutlarının hatasız çalıştığından emin olun.
    echo Manuel olarak "!DOWNLOAD_DIR!" klasöründe !WGCF_EXE! generate komutunu çalıştırmayı deneyin.
    goto :ErrorExit
)
if not exist "%WGCF_ACCOUNT_TOML_DOWNLOAD%" (
    echo HATA: wgcf-account.toml dosyası oluşturulamadı.
    echo Lütfen WGCF komutlarının hatasız çalıştığından emin olun.
    echo Manuel olarak "!DOWNLOAD_DIR!" klasöründe !WGCF_EXE! register komutunu çalıştırmayı deneyin.
    goto :ErrorExit
)
echo WGCF dosyaları başarıyla oluşturuldu.
echo.
timeout /t 3 /nobreak > nul

:: == 6. wgcf-profile.conf Dosyasını Düzenleme ==
:: Profil [Peer] bölümüyle biter; sona eklenen satır bu bölüme düşer.
:ModifyConfig
cls
echo ===============================================================================
echo Adım 6: wgcf-profile.conf Dosyasını Düzenleme
echo ===============================================================================
echo "%WGCF_PROFILE_CONF_DOWNLOAD%" dosyası kontrol ediliyor...

findstr /L /C:"AllowedApps = Discord.exe" "%WGCF_PROFILE_CONF_DOWNLOAD%" > nul
if not errorlevel 1 (
    echo "AllowedApps = Discord.exe" satırı zaten dosyada mevcut.
) else (
    echo "AllowedApps = Discord.exe" satırı dosyaya ekleniyor...
    (echo AllowedApps = Discord.exe) >> "!WGCF_PROFILE_CONF_DOWNLOAD!"
    findstr /L /C:"AllowedApps = Discord.exe" "!WGCF_PROFILE_CONF_DOWNLOAD!" > nul
    if errorlevel 1 (
       echo HATA: "AllowedApps = Discord.exe" satırı dosyaya eklenemedi.
       echo Lütfen "!WGCF_PROFILE_CONF_DOWNLOAD!" dosyasını manuel olarak açıp
       echo en alt satıra "AllowedApps = Discord.exe" ^(tırnaklar olmadan^) ekleyin.
       pause
    ) else (
       echo Satır başarıyla eklendi.
    )
)
echo.
timeout /t 3 /nobreak > nul

:: == 7. Yapılandırma Dosyalarını Taşıma ==
:MoveFiles
cls
echo ===============================================================================
echo Adım 7: Yapılandırma Dosyalarını Taşıma
echo ===============================================================================

echo "%WGCF_PROFILE_CONF_DOWNLOAD%" dosyası "%DOCS_DIR%" klasörüne taşınıyor...
move /Y "%WGCF_PROFILE_CONF_DOWNLOAD%" "%WGCF_PROFILE_CONF_DEST%" > nul
if errorlevel 1 (
    echo HATA: "!WGCF_PROFILE_CONF_DOWNLOAD!" dosyası taşınamadı.
    echo Lütfen manuel olarak taşıyın:
    echo Kaynak: "!WGCF_PROFILE_CONF_DOWNLOAD!"
    echo Hedef: "!WGCF_PROFILE_CONF_DEST!"
    goto :ErrorExit
)

echo "%WGCF_ACCOUNT_TOML_DOWNLOAD%" dosyası "%DOCS_DIR%" klasörüne taşınıyor...
move /Y "%WGCF_ACCOUNT_TOML_DOWNLOAD%" "%WGCF_ACCOUNT_TOML_DEST%" > nul
if errorlevel 1 (
    echo HATA: "!WGCF_ACCOUNT_TOML_DOWNLOAD!" dosyası taşınamadı.
    echo Lütfen manuel olarak taşıyın:
    echo Kaynak: "!WGCF_ACCOUNT_TOML_DOWNLOAD!"
    echo Hedef: "!WGCF_ACCOUNT_TOML_DEST!"
    goto :ErrorExit
)
echo Dosyalar başarıyla Belgeler klasörüne (%DOCS_DIR%) taşındı.
echo.
timeout /t 3 /nobreak > nul

:: == 8. WireSock Kurulumu ==
:InstallWireSock
cls
echo ===============================================================================
echo Adım 8: WireSock Kurulumu
echo ===============================================================================
call :FindWireSockClient
if not errorlevel 1 (
    echo WireSock zaten kurulu: "!WIRESOCK_CLIENT_EXE_PATH!"
    echo Kurulum adımı atlanıyor.
    goto :WireSockReady
)

echo Şimdi WireSock Secure Connect kurulacak.
echo Kurulum dosyası: "%DOWNLOAD_DIR%\%WIRESOCK_EXE%"
echo Kurulum kendi kendine ilerler; Windows izin (UAC) penceresi çıkarsa onaylayın.
echo Kurulum sırasında gerekirse .NET Desktop Runtime da indirilir, biraz sürebilir.
echo.
call :VerifyFile "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" %WIRESOCK_SHA256%
if errorlevel 1 (
    echo HATA: Kurulum dosyası "!DOWNLOAD_DIR!\!WIRESOCK_EXE!" bulunamadı veya bozuk.
    echo Lütfen dosyayı indirip/taşıyıp scripti tekrar çalıştırın.
    goto :ErrorExit
)

echo WireSock kurulumu başlatılıyor...
start "WireSock Kurulumu" /wait "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" /passive /norestart
set WS_SETUP_EC=!errorlevel!
:: 0 = başarılı, 3010 = başarılı ama yeniden başlatma gerekli.
if !WS_SETUP_EC! neq 0 if !WS_SETUP_EC! neq 3010 (
    echo Otomatik kurulum başarısız oldu ^(Kod: !WS_SETUP_EC!^).
    echo Kurulum sihirbazı açılıyor; lütfen adımları elle tamamlayın.
    start "WireSock Kurulumu" /wait "!DOWNLOAD_DIR!\!WIRESOCK_EXE!"
)

echo WireSock kurulumu kontrol ediliyor...
call :FindWireSockClient
if errorlevel 1 (
    echo HATA: WireSock istemcisi ^(wiresock-client.exe^) bulunamadı. Kurulum başarısız olmuş olabilir.
    echo Beklenen yer: "!ProgramFiles!\!WIRESOCK_CLIENT_REL!"
    echo Lütfen WireSock'u manuel olarak kurduğunuzdan emin olun.
    goto :ErrorExit
)

:WireSockReady
echo WireSock istemcisi bulundu: "%WIRESOCK_CLIENT_EXE_PATH%"
echo.
timeout /t 3 /nobreak > nul

:: == 9. WireSock Servisini Oluşturma ve Ayarlama ==
:InstallService
cls
echo ===============================================================================
echo Adım 9: WireSock Servisini Oluşturma ve Ayarlama
echo ===============================================================================
sc query "%SERVICE_NAME%" > nul 2>&1
if not errorlevel 1 (
    echo Servis ^(!SERVICE_NAME!^) zaten kurulu, yeniden oluşturulmayacak.
    goto :CheckServiceStartType
)

echo WireSock servisi oluşturuluyor. Bu işlem biraz zaman alabilir, lütfen bekleyin...
"%WIRESOCK_CLIENT_EXE_PATH%" install -start-type 2 -config "%WGCF_PROFILE_CONF_DEST%" -log-level none
set SERVICE_INSTALL_CMD_EC=!errorlevel!
echo Servis kurulum komutu tamamlandı (Çıkış Kodu: %SERVICE_INSTALL_CMD_EC%). Servisin varlığı kontrol ediliyor...

:CheckServiceExistsLoop
sc query "%SERVICE_NAME%" > nul 2>&1
if errorlevel 1 (
    echo HATA: WireSock servisi ^(!SERVICE_NAME!^) oluşturulamadı veya bulunamadı.
    echo.
    echo Manuel olarak oluşturmayı deneyebilirsiniz:
    echo 1. Başlat menüsüne cmd yazın ve Komut İstemi'ni Yönetici olarak çalıştırın.
    echo 2. Şu komutu yapıştırıp çalıştırın:
    echo    "!WIRESOCK_CLIENT_EXE_PATH!" install -start-type 2 -config "!WGCF_PROFILE_CONF_DEST!" -log-level none
    echo.
    choice /C EH /N /M "Komutu manuel olarak çalıştırdınız mı? Tekrar kontrol edilsin mi? (E/H): "
    if errorlevel 2 (
       echo Servis oluşturulamadığı için işlem durduruldu.
       goto :ErrorExit
    )
    echo Tekrar kontrol ediliyor...
    timeout /t 2 /nobreak > nul
    goto :CheckServiceExistsLoop
)
echo Servis (%SERVICE_NAME%) başarıyla bulundu/oluşturuldu.
echo.

:CheckServiceStartType
echo Servisin başlangıç türü kontrol ediliyor...
sc qc "%SERVICE_NAME%" | findstr /i /C:"START_TYPE" | findstr /i /C:"AUTO_START" > nul
if errorlevel 1 (
    echo Servis otomatik başlayacak şekilde ayarlanmamış. Ayarlanıyor...
    sc config "!SERVICE_NAME!" start= auto > nul
    if errorlevel 1 (
        echo HATA: Servis başlangıç türü otomatik olarak ayarlanamadı.
        echo Manuel olarak ayarlamayı deneyin:
        echo 1. 'services.msc' yazıp Çalıştır'ı açın.
        echo 2. '!SERVICE_NAME!' servisini bulun.
        echo 3. Sağ tıklayıp Özellikler'i seçin.
        echo 4. Başlangıç türünü 'Otomatik' olarak ayarlayın ve Uygula'ya basın.
        pause
    ) else (
        echo Servis başlangıç türü başarıyla 'Otomatik' olarak ayarlandı.
    )
) else (
    echo Servis zaten otomatik başlayacak şekilde ayarlı.
)
echo.
timeout /t 3 /nobreak > nul

:: == 10. WireSock Servisini Başlatma ==
:StartService
cls
echo ===============================================================================
echo Adım 10: WireSock Servisini Başlatma
echo ===============================================================================
echo Servisin durumu kontrol ediliyor...
sc query "%SERVICE_NAME%" | findstr /i /C:"RUNNING" > nul
if not errorlevel 1 (
    echo Servis zaten çalışıyor. Yeni yapılandırmanın yüklenmesi için yeniden başlatılıyor...
    net stop "!SERVICE_NAME!" > nul 2>&1
)
net start "%SERVICE_NAME%"
set NET_START_EC=!errorlevel!
if !NET_START_EC! neq 0 (
    echo HATA: Servis başlatılamadı ^(Hata Kodu: !NET_START_EC!^).
    echo Manuel olarak başlatmayı deneyin:
    echo 1. 'services.msc' yazıp Çalıştır'ı açın.
    echo 2. '!SERVICE_NAME!' servisini bulun.
    echo 3. Sağ tıklayıp 'Başlat'ı seçin.
    echo VEYA Yönetici Komut İstemcisinden 'net start !SERVICE_NAME!' komutunu çalıştırın.
    echo Sorun devam ederse sistem günlüklerini veya WireSock günlüklerini kontrol edin ^('-log-level' parametresini değiştirerek^).
    goto :ErrorExit
)
:: Başlatma sonrası kısa bir bekleme ve tekrar kontrol
timeout /t 3 /nobreak > nul
sc query "%SERVICE_NAME%" | findstr /i /C:"RUNNING" > nul
if errorlevel 1 (
    echo UYARI: Servis başlatıldı ancak hemen ardından çalışan durumda bulunamadı. Bir sorun olabilir. Lütfen manuel kontrol edin.
    pause
) else (
    echo Servis başarıyla başlatıldı ve çalışıyor.
)
echo.
timeout /t 3 /nobreak > nul

:: == 11. Başarı Mesajı ==
:Success
cls
echo ===============================================================================
echo                            İŞLEM BAŞARIYLA TAMAMLANDI
echo ===============================================================================
echo.
echo WireSock ve WGCF kullanılarak Discord için özel bir VPN bağlantısı
echo başarıyla yapılandırıldı ve servis olarak kuruldu.
echo.
echo Sisteminiz her başladığında WireSock servisi (%SERVICE_NAME%) otomatik olarak
echo çalışacak ve sadece Discord uygulaması bu VPN bağlantısını kullanacaktır.
echo (Yapılandırma dosyası: %WGCF_PROFILE_CONF_DEST%)
echo.
echo Lütfen Discord'u açıp sunuculara ve sesli kanallara bağlanarak
echo her şeyin düzgün çalıştığını kontrol edin.
echo.
echo ===============================================================================
goto :EndScript

:: == Hata Çıkışı ==
:ErrorExit
set "EXIT_CODE=1"
echo.
echo ===============================================================================
echo                                 HATA OLUŞTU
echo ===============================================================================
echo Script bir hata nedeniyle durduruldu. Yukarıdaki mesajları kontrol edin.
echo Sorunu çözdükten sonra script'i tekrar çalıştırmayı deneyebilirsiniz.
echo ===============================================================================
goto :EndScript

:: == Script Sonu ==
:EndScript
echo.
echo Çıkmak için bir tuşa basın...
pause > nul
exit /b %EXIT_CODE%


:: ===============================================================================
:: ALT RUTİNLER
:: ===============================================================================

:: Dosya var mı ve SHA256 değeri doğru mu?
:: Kullanım: call :VerifyFile "dosya_yolu" beklenen_sha256   (errorlevel 0 = doğru)
:VerifyFile
if not exist "%~1" exit /b 1
certutil -hashfile "%~1" SHA256 | findstr /i /C:"%~2" > nul
exit /b

:: Dosyayı Downloads klasörüne indirir ve doğrular (en fazla 2 deneme).
:: Doğru dosya zaten varsa tekrar indirmez.
:: Kullanım: call :DownloadOne dosya_adı "url" beklenen_sha256   (errorlevel 0 = tamam)
:DownloadOne
set "DL_FILE=%DOWNLOAD_DIR%\%~1"
set "DL_URL=%~2"
call :VerifyFile "%DL_FILE%" %~3
if not errorlevel 1 (
    echo %~1 zaten indirilmiş ve doğrulanmış.
    echo.
    exit /b 0
)
for /L %%n in (1,1,2) do (
    echo %~1 indiriliyor ^(Deneme: %%n/2^)...
    curl -L --fail -o "!DL_FILE!" "!DL_URL!"
    call :VerifyFile "!DL_FILE!" %~3
    if not errorlevel 1 (
        echo %~1 başarıyla indirildi ve doğrulandı.
        echo.
        exit /b 0
    )
    echo İndirme hatası veya dosya doğrulanamadı. Tekrar deneniyor...
    timeout /t 5 /nobreak > nul
)
echo HATA: %~1 dosyası 2 denemeden sonra indirilemedi veya doğrulanamadı.
echo Lütfen manuel olarak indirin: !DL_URL!
echo İndirdikten sonra "%DOWNLOAD_DIR%" klasörüne taşıyın ve script'i tekrar çalıştırın.
exit /b 1

:: wiresock-client.exe'yi bulur ve WIRESOCK_CLIENT_EXE_PATH'e yazar (errorlevel 0 = bulundu).
:: 32-bit cmd'de %ProgramFiles% "Program Files (x86)" olur; bu yüzden önce ProgramW6432'ye bakılır.
:FindWireSockClient
set "WIRESOCK_CLIENT_EXE_PATH="
if defined ProgramW6432 if exist "%ProgramW6432%\%WIRESOCK_CLIENT_REL%" set "WIRESOCK_CLIENT_EXE_PATH=%ProgramW6432%\%WIRESOCK_CLIENT_REL%"
if not defined WIRESOCK_CLIENT_EXE_PATH if exist "%ProgramFiles%\%WIRESOCK_CLIENT_REL%" set "WIRESOCK_CLIENT_EXE_PATH=%ProgramFiles%\%WIRESOCK_CLIENT_REL%"
if defined WIRESOCK_CLIENT_EXE_PATH exit /b 0
exit /b 1
