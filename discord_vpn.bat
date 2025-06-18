@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

:: Script Title
title WireSock & WGCF Otomatik Kurulum ve Yapilandirma (v3.4 - Final ErrorLevel Fix Attempt)

:: Renk Ayarlari (Opsiyonel)
color 0A

:: == 1. Yönetici Hakları Kontrolü ==
cls
echo Yönetici hakları kontrol ediliyor^.^.^.
net session >nul 2>&1
set NET_SESSION_EC=%errorlevel%

REM *** DEĞİŞİKLİK: Ana IF kontrolü de değişkene göre yapılıyor ***
if %NET_SESSION_EC% neq 0 (
    REM Yönetici DEĞİL bloku
    echo ===============================================================================
    echo HATA: Bu scriptin düzgün çalışabilmesi için Yönetici olarak çalıştırılması gerekmektedir.
    echo ===============================================================================
    echo.
    echo Talimatlar:
    echo 1. Bu pencereyi kapatın.
    echo 2. Script dosyasına ^(.bat veya .cmd^) sağ tıklayın.
    echo 3. "Yönetici olarak çalıştır" seçeneğini seçin.
    echo.
    choice /C EH /M "Script'i yönetici olarak yeniden başlatmak ister misiniz? (E/H): "
    set CHOICE_ADMIN_EC=%errorlevel%
    if %CHOICE_ADMIN_EC% == 2 (
        echo İşlem iptal edildi. Lütfen script'i yönetici olarak çalıştırın.
        goto :EndScript
    )
    if %CHOICE_ADMIN_EC% == 1 (
        echo Script yönetici olarak yeniden başlatılıyor...
        powershell -command "Start-Process '%~f0' -Verb RunAs" >nul 2>&1
        set POWERSHELL_EC=%errorlevel%
        if %POWERSHELL_EC% neq 0 (
           echo HATA: Script yönetici olarak yeniden başlatılamadı (Hata Kodu: %POWERSHELL_EC%). Lütfen manuel yapın.
           goto :EndScript
        )
        exit /b 0
    )
    REM Buraya gelinmemeli ama güvenlik için
    goto :ErrorExit
) else (
    REM Yönetici bloku
    echo Yönetici haklarıyla çalıştırılıyor. Devam ediliyor...
    echo.
    timeout /t 1 /nobreak > nul
)

:: == 2. İşletim Sistemi Mimarisi Tespiti (Tek Seferlik - Ortam Değişkeni Yöntemi) ==
cls
echo ===============================================================================
echo Adım 2: İşletim Sistemi Mimarisi Tespiti
echo ===============================================================================
echo İşletim sistemi mimarisi ortam değişkenleri kullanılarak tespit ediliyor^.^.^.

if defined PROCESSOR_ARCHITEW6432 (
    set "ARCH=x64"
) else (
    if /i "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
        set "ARCH=x64"
    ) else if /i "%PROCESSOR_ARCHITECTURE%" == "x86" (
        set "ARCH=x86"
    ) else (
        echo HATA: İşlemci mimarisi tanınamadı: %PROCESSOR_ARCHITECTURE%. Script durduruluyor.
        goto :ErrorExit
    )
)

if "%ARCH%"=="x64" (
    set "ARCH_DISPLAY=64-bit (x64)"
    set "WGCF_URL=https://github.com/ViRb3/wgcf/releases/download/v2.2.25/wgcf_2.2.25_windows_amd64.exe"
    set "WGCF_EXE=wgcf_2.2.25_windows_amd64.exe"
    set "WIRESOCK_URL=https://wiresock.net/_api/download-release.php?product=wiresock-secure-connect&platform=windows_x64&version=2.4.5.1"
    set "WIRESOCK_EXE=wiresock-secure-connect-x64-2.4.5.1.exe"
    set "WIRESOCK_INSTALLER_NAME=wiresock-secure-connect-x64-2.4.5.1.exe"
) else (
    set "ARCH_DISPLAY=32-bit (x86)"
    set "WGCF_URL=https://github.com/ViRb3/wgcf/releases/download/v2.2.25/wgcf_2.2.25_windows_386.exe"
    set "WGCF_EXE=wgcf_2.2.25_windows_386.exe"
    set "WIRESOCK_URL=https://wiresock.net/_api/download-release.php?product=wiresock-secure-connect&platform=windows_x32&version=2.4.5.1"
    set "WIRESOCK_EXE=wiresock-secure-connect-x86-2.4.5.1.exe"
    set "WIRESOCK_INSTALLER_NAME=wiresock-secure-connect-x86-2.4.5.1.exe"
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

timeout /t 3 /nobreak > nul

:: == 3. Curl Kontrolü ve Kurulumu ==
:CheckCurl
cls
echo ===============================================================================
echo Adım 3: Curl Uygulaması Kontrolü ve Kurulumu
echo ===============================================================================
echo Curl uygulamasının yüklü olup olmadığı kontrol ediliyor^.^.^.

curl --version >nul 2>&1
set CURL_CHECK_EC=%errorlevel%

if %CURL_CHECK_EC% == 0 (
    echo Curl zaten yüklü ve çalıştırılabilir. Otomatik indirme işlemine geçiliyor.
    timeout /t 2 /nobreak > nul
    goto :DownloadFiles
) else (
    echo Curl bulunamadı veya çalıştırılamadı (Hata Kodu: %CURL_CHECK_EC%). Winget ile yüklenmeye çalışılacak...
    timeout /t 2 /nobreak > nul
    goto :InstallCurlWithWinget
)
goto :ErrorExit


:InstallCurlWithWinget
echo Winget kontrol ediliyor^.^.^.
where winget >nul 2>&1
set WINGET_CHECK_EC=%errorlevel%
if %WINGET_CHECK_EC% neq 0 (
    echo Winget bulunamadı. Curl otomatik olarak yüklenemiyor. Manuel indirme gerekli.
    call :ManualDownloadInstructions
    goto :CheckManualDownloads
)

echo Winget kullanılarak curl yükleniyor (Gerekirse izinleri onaylayın)...
winget install --id=cURL.cURL -e --accept-package-agreements --accept-source-agreements
set WINGET_INSTALL_EC=%errorlevel%
if %WINGET_INSTALL_EC% neq 0 (
    echo Winget ile curl kurulumu başarısız oldu (Hata Kodu: %WINGET_INSTALL_EC%). Manuel indirme gerekli.
    call :ManualDownloadInstructions
    goto :CheckManualDownloads
) else (
    echo Curl kurulumu için Winget komutu çalıştırıldı. Tekrar kontrol ediliyor...
    curl --version >nul 2>&1
    set CURL_POST_WINGET_EC=%errorlevel%
    if %CURL_POST_WINGET_EC% neq 0 (
         echo Curl kurulumu başarısız oldu (Winget sonrası kontrol - Hata Kodu: %CURL_POST_WINGET_EC%). Manuel indirme gerekli.
         call :ManualDownloadInstructions
         goto :CheckManualDownloads
    ) else (
         echo Curl başarıyla yüklendi/çalıştırıldı. Otomatik indirme işlemine geçiliyor.
         timeout /t 2 /nobreak > nul
         goto :DownloadFiles
    )
)
goto :ErrorExit


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
echo 1. WGCF (%ARCH%): %WGCF_URL%
echo 2. WireSock (%ARCH%): %WIRESOCK_URL%
echo.
echo Talimatlar:
echo 1. Yukarıdaki adresleri kopyalayın:
echo    - Bu pencerede fare ile adresi seçin.
echo    - Sağ tıklayarak kopyalayın ^(veya Ctrl+C^).
echo 2. Web tarayıcınızı açın ve adresi yapıştırıp Enter'a basın.
echo 3. İndirilen dosyaları "%DOWNLOAD_DIR%" klasörüne kaydedin veya indirdikten sonra bu klasöre taşıyın.
echo 4. İki dosyayı da indirme işlemi bittikten sonra bu ekrana dönün.
echo.
choice /C EH /N /M "Dosyaları indirip Downloads klasörüne taşıdınız mı? (E/H): "
set CHOICE_MANUAL_EC=%errorlevel%
if %CHOICE_MANUAL_EC% == 2 (
    echo İşlem iptal edildi. Lütfen dosyaları indirip script'i tekrar çalıştırın.
    goto :EndScript
)
goto :CheckManualDownloads

:CheckManualDownloads
cls
echo ===============================================================================
echo Manuel İndirme Kontrolü
echo ===============================================================================
echo İndirilen dosyaların "%DOWNLOAD_DIR%" klasöründe olup olmadığı kontrol ediliyor^.^.^.
if not exist "%DOWNLOAD_DIR%\%WGCF_EXE%" (
    echo HATA: %WGCF_EXE% dosyası "%DOWNLOAD_DIR%" klasöründe bulunamadı.
    echo Lütfen "%WGCF_URL%" adresinden indirip doğru yere taşıyın ve script'i tekrar çalıştırın.
    goto :ErrorExit
)
if not exist "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" (
    echo HATA: %WIRESOCK_EXE% dosyası "%DOWNLOAD_DIR%" klasöründe bulunamadı.
    echo Lütfen "%WIRESOCK_URL%" adresinden indirip doğru yere taşıyın ve script'i tekrar çalıştırın.
    goto :ErrorExit
)
echo Gerekli dosyalar Downloads klasöründe bulundu. Devam ediliyor...
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

set MAX_RETRIES=2
set RETRY_WGCF=0
set RETRY_WIRESOCK=0

:DownloadWGCF
set /a RETRY_WGCF+=1
if %RETRY_WGCF% gtr %MAX_RETRIES% (
    echo HATA: %WGCF_EXE% dosyası %MAX_RETRIES% denemeden sonra indirilemedi.
    echo Lütfen manuel olarak indirin: %WGCF_URL%
    echo İndirdikten sonra "%DOWNLOAD_DIR%" klasörüne taşıyın ve script'i tekrar çalıştırın.
    goto :ErrorExit
)
echo %WGCF_EXE% indiriliyor (Deneme: %RETRY_WGCF%/%MAX_RETRIES%)...

curl -L -o "%DOWNLOAD_DIR%\%WGCF_EXE%" "%WGCF_URL%"
set CURL_WGCF_EC=%errorlevel%

if %CURL_WGCF_EC% == 0 (
    echo %WGCF_EXE% başarıyla indirildi.
    echo.
    goto :DownloadWireSockPrep
) else (
    echo İndirme hatası (%WGCF_EXE% - Hata Kodu: %CURL_WGCF_EC%). Tekrar deneniyor^.^.^.
    timeout /t 5 /nobreak > nul
    goto :DownloadWGCF
)


:DownloadWireSockPrep
set RETRY_WIRESOCK=0

:DownloadWireSock
set /a RETRY_WIRESOCK+=1
if %RETRY_WIRESOCK% gtr %MAX_RETRIES% (
    echo HATA: %WIRESOCK_EXE% dosyası %MAX_RETRIES% denemeden sonra indirilemedi.
    echo Lütfen manuel olarak indirin: %WIRESOCK_URL%
    echo İndirdikten sonra "%DOWNLOAD_DIR%" klasörüne taşıyın ve script'i tekrar çalıştırın.
    goto :ErrorExit
)
echo %WIRESOCK_EXE% indiriliyor (Deneme: %RETRY_WIRESOCK%/%MAX_RETRIES%)...

curl -L -o "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" "%WIRESOCK_URL%"
set CURL_WIRESOCK_EC=%errorlevel%

if %CURL_WIRESOCK_EC% == 0 (
    echo %WIRESOCK_EXE% başarıyla indirildi.
    echo.
    timeout /t 3 /nobreak > nul
    goto :RunWGCF
) else (
    echo İndirme hatası (%WIRESOCK_EXE% - Hata Kodu: %CURL_WIRESOCK_EC%). Tekrar deneniyor^.^.^.
    timeout /t 5 /nobreak > nul
    goto :DownloadWireSock
)

:: == 5. WGCF Komutlarını Çalıştırma ve Dosya Kontrolü ==
:RunWGCF
cls
echo ===============================================================================
echo Adım 5: WGCF Komutlarını Çalıştırma
echo ===============================================================================
echo "%DOWNLOAD_DIR%" klasörüne geçiliyor...
cd /d "%DOWNLOAD_DIR%"
set CD_EC=%errorlevel%
if %CD_EC% neq 0 (
   echo HATA: "%DOWNLOAD_DIR%" klasörüne geçilemedi (Hata Kodu: %CD_EC%). Klasörün var olduğundan emin olun.
   goto :ErrorExit
)

echo "%WGCF_EXE% register --accept-tos" komutu çalıştırılıyor...
"%DOWNLOAD_DIR%\%WGCF_EXE%" register --accept-tos
set WGCF_REG_EC=%errorlevel%
if %WGCF_REG_EC% neq 0 (
   echo HATA: WGCF register komutu başarısız oldu. (Hata Kodu: %WGCF_REG_EC%)
   echo Manuel olarak çalıştırmayı deneyin:
   echo 1. Başlat menüsüne cmd yazın ve Komut İstemi'ni Yönetici olarak çalıştırın.
   echo 2. cd "%DOWNLOAD_DIR%" komutunu girin.
   echo 3. "%WGCF_EXE%" register --accept-tos komutunu girin.
   echo Sorun devam ederse WGCF uygulamasında veya internet bağlantınızda bir sorun olabilir.
   goto :ErrorExit
)
echo.

echo "%WGCF_EXE% generate" komutu çalıştırılıyor...
"%DOWNLOAD_DIR%\%WGCF_EXE%" generate
set WGCF_GEN_EC=%errorlevel%
if %WGCF_GEN_EC% neq 0 (
   echo HATA: WGCF generate komutu başarısız oldu. (Hata Kodu: %WGCF_GEN_EC%)
   echo Manuel olarak çalıştırmayı deneyin:
   echo 1. Başlat menüsüne cmd yazın ve Komut İstemi'ni Yönetici olarak çalıştırın.
   echo 2. cd "%DOWNLOAD_DIR%" komutunu girin.
   echo 3. "%WGCF_EXE%" generate komutunu girin.
   echo Sorun devam ederse WGCF uygulamasında bir sorun olabilir.
   goto :ErrorExit
)
echo.

echo Oluşturulan dosyalar kontrol ediliyor (%WGCF_PROFILE_CONF_DOWNLOAD% ve %WGCF_ACCOUNT_TOML_DOWNLOAD%)...
if not exist "%WGCF_PROFILE_CONF_DOWNLOAD%" (
    echo HATA: wgcf-profile.conf dosyası oluşturulamadı.
    echo Lütfen WGCF komutlarının hatasız çalıştığından emin olun.
    echo Manuel olarak "%DOWNLOAD_DIR%" klasöründe %WGCF_EXE% generate komutunu çalıştırmayı deneyin.
    goto :ErrorExit
)
if not exist "%WGCF_ACCOUNT_TOML_DOWNLOAD%" (
    echo HATA: wgcf-account.toml dosyası oluşturulamadı.
    echo Lütfen WGCF komutlarının hatasız çalıştığından emin olun.
    echo Manuel olarak "%DOWNLOAD_DIR%" klasöründe %WGCF_EXE% register komutunu çalıştırmayı deneyin.
    goto :ErrorExit
)
echo WGCF dosyaları başarıyla oluşturuldu.
echo.
timeout /t 3 /nobreak > nul

:: == 6. wgcf-profile.conf Dosyasını Düzenleme ==
:ModifyConfig
cls
echo ===============================================================================
echo Adım 6: wgcf-profile.conf Dosyasını Düzenleme
echo ===============================================================================
echo "%WGCF_PROFILE_CONF_DOWNLOAD%" dosyası kontrol ediliyor...

findstr /L /C:"AllowedApps = Discord.exe" "%WGCF_PROFILE_CONF_DOWNLOAD%" > nul
set FINDSTR_EC=%errorlevel%
if %FINDSTR_EC% == 0 (
    echo "AllowedApps = Discord.exe" satırı zaten dosyada mevcut.
) else (
    echo "AllowedApps = Discord.exe" satırı dosyaya ekleniyor...
    (echo AllowedApps = Discord.exe) >> "%WGCF_PROFILE_CONF_DOWNLOAD%"
    findstr /L /C:"AllowedApps = Discord.exe" "%WGCF_PROFILE_CONF_DOWNLOAD%" > nul
    set FINDSTR_AFTER_EC=%errorlevel%
    if %FINDSTR_AFTER_EC% == 0 (
       echo Satır başarıyla eklendi.
    ) else (
       echo HATA: "AllowedApps = Discord.exe" satırı dosyaya eklenemedi (Hata Kodu: %FINDSTR_AFTER_EC%).
       echo Lütfen "%WGCF_PROFILE_CONF_DOWNLOAD%" dosyasını manuel olarak açıp
       echo en alt satıra "AllowedApps = Discord.exe" (tırnaklar olmadan) ekleyin.
       pause
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
set MOVE_CONF_EC=%errorlevel%
if %MOVE_CONF_EC% neq 0 (
    echo HATA: "%WGCF_PROFILE_CONF_DOWNLOAD%" dosyası taşınamadı (Hata Kodu: %MOVE_CONF_EC%).
    echo Lütfen manuel olarak taşıyın:
    echo Kaynak: "%WGCF_PROFILE_CONF_DOWNLOAD%"
    echo Hedef: "%WGCF_PROFILE_CONF_DEST%"
    goto :ErrorExit
)

echo "%WGCF_ACCOUNT_TOML_DOWNLOAD%" dosyası "%DOCS_DIR%" klasörüne taşınıyor...
move /Y "%WGCF_ACCOUNT_TOML_DOWNLOAD%" "%WGCF_ACCOUNT_TOML_DEST%" > nul
set MOVE_TOML_EC=%errorlevel%
if %MOVE_TOML_EC% neq 0 (
    echo HATA: "%WGCF_ACCOUNT_TOML_DOWNLOAD%" dosyası taşınamadı (Hata Kodu: %MOVE_TOML_EC%).
    echo Lütfen manuel olarak taşıyın:
    echo Kaynak: "%WGCF_ACCOUNT_TOML_DOWNLOAD%"
    echo Hedef: "%WGCF_ACCOUNT_TOML_DEST%"
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
echo Şimdi WireSock uygulaması (%WIRESOCK_INSTALLER_NAME%) kurulacak.
echo Kurulum dosyası: "%DOWNLOAD_DIR%\%WIRESOCK_EXE%"
echo Kurulum sihirbazı ayrı bir pencerede başlayacak.
echo Lütfen kurulum adımlarını takip edin ve tamamlayın.
echo Kurulum bittikten sonra BU PENCEREYE geri dönün ve sorulan soruyu yanıtlayın.
echo.
if not exist "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" (
    echo HATA: Kurulum dosyası "%DOWNLOAD_DIR%\%WIRESOCK_EXE%" bulunamadı.
    echo Lütfen dosyayı indirip/taşıyıp scripti tekrar çalıştırın.
    goto :ErrorExit
)
pause

echo WireSock kurulumu başlatılıyor...
start "WireSock Kurulumu" /wait "%DOWNLOAD_DIR%\%WIRESOCK_EXE%"

echo.
choice /C EH /N /M "WireSock kurulumu başarıyla tamamlandı mı? (E/H): "
set CHOICE_INSTALL_EC=%errorlevel%
if %CHOICE_INSTALL_EC% == 2 (
    echo İşlem iptal edildi. WireSock kurulmadan devam edilemez.
    goto :EndScript
)

echo WireSock kurulumu kontrol ediliyor...
set "WIRESOCK_CLIENT_EXE_PATH="
if exist "%ProgramFiles%\WireSock Secure Connect\wiresock-client.exe" (
   set "WIRESOCK_CLIENT_EXE_PATH=%ProgramFiles%\WireSock Secure Connect\wiresock-client.exe"
) else if exist "%ProgramFiles(x86)%\WireSock Secure Connect\wiresock-client.exe" (
   set "WIRESOCK_CLIENT_EXE_PATH=%ProgramFiles(x86)%\WireSock Secure Connect\wiresock-client.exe"
)

if "%WIRESOCK_CLIENT_EXE_PATH%"=="" (
    echo HATA: WireSock istemcisi (wiresock-client.exe) standart yollarda bulunamadı. Kurulum başarısız olmuş olabilir.
    echo Lütfen WireSock'u manuel olarak kurduğunuzdan emin olun veya Program Files klasörünü kontrol edin.
    goto :ErrorExit
)

echo WireSock istemcisi ("%WIRESOCK_CLIENT_EXE_PATH%") çalıştırılarak test ediliyor...
"%WIRESOCK_CLIENT_EXE_PATH%" /? > nul 2>&1
set WIRESOCK_TEST_EC=%errorlevel%
if %WIRESOCK_TEST_EC% gtr 1 (
    echo HATA: wiresock-client.exe çalıştırılamadı veya bir hata ile karşılaştı (Hata Kodu: %WIRESOCK_TEST_EC%).
    echo WireSock kurulumunda bir sorun olabilir. Lütfen kontrol edin.
    goto :ErrorExit
)

echo WireSock başarıyla kurulmuş ve çalıştırılabilir görünüyor.
echo.
timeout /t 3 /nobreak > nul

:: == 9. WireSock Servisini Oluşturma ve Ayarlama ==
:InstallService
cls
echo ===============================================================================
echo Adım 9: WireSock Servisini Oluşturma ve Ayarlama
echo ===============================================================================
set SERVICE_NAME=wiresock-client-service
set SERVICE_CONFIG_CMD="""%WIRESOCK_CLIENT_EXE_PATH%"" install -start-type 2 -config ""%WGCF_PROFILE_CONF_DEST%"" -log-level none"

echo WireSock servisi oluşturuluyor... Komut:
echo %SERVICE_CONFIG_CMD%
echo Bu işlem biraz zaman alabilir, lütfen bekleyin...
echo ^(Ayrı bir pencere açılıp kapanabilir^)

start "WireSock Servis Kurulumu" /wait cmd /c %SERVICE_CONFIG_CMD%
set SERVICE_INSTALL_CMD_EC=%errorlevel%

echo Servis kurulum komutu tamamlandı (Çıkış Kodu: %SERVICE_INSTALL_CMD_EC%). Servisin varlığı kontrol ediliyor...

:CheckServiceExistsLoop
sc query "%SERVICE_NAME%" > nul 2>&1
set SC_QUERY_EC=%errorlevel%
if %SC_QUERY_EC% neq 0 (
    echo HATA: WireSock servisi (%SERVICE_NAME%) oluşturulamadı veya bulunamadı (sc query hatası: %SC_QUERY_EC%).
    if %SERVICE_INSTALL_CMD_EC% neq 0 echo       Ayrıca, kurulum komutu da bir hata kodu (%SERVICE_INSTALL_CMD_EC%) döndürdü.
    echo.
    echo Manuel olarak oluşturmayı deneyebilirsiniz:
    echo 1. Başlat menüsüne cmd yazın ve Komut İstemi'ni Yönetici olarak çalıştırın.
    echo 2. Şu komutu yapıştırıp çalıştırın:
    echo    %SERVICE_CONFIG_CMD%
    echo.
    choice /C EH /N /M "Komutu manuel olarak çalıştırdınız mı? Tekrar kontrol edilsin mi? (E/H): "
    set CHOICE_MANUAL_SVC_EC=%errorlevel%
    if %CHOICE_MANUAL_SVC_EC% == 2 (
       echo Servis oluşturulamadığı için işlem durduruldu.
       goto :ErrorExit
    )
    echo Tekrar kontrol ediliyor...
    timeout /t 2 /nobreak > nul
    goto :CheckServiceExistsLoop
)

echo Servis (%SERVICE_NAME%) başarıyla bulundu/oluşturuldu.
echo.
echo Servisin başlangıç türü kontrol ediliyor...
sc qc "%SERVICE_NAME%" | findstr /i /C:"START_TYPE" | findstr /i /C:"AUTO_START" > nul
set SC_QC_EC=%errorlevel%
if %SC_QC_EC% neq 0 (
    echo Servis otomatik başlayacak şekilde ayarlanmamış. Ayarlanıyor...
    sc config "%SERVICE_NAME%" start=auto
    set SC_CONFIG_EC=%errorlevel%
    if %SC_CONFIG_EC% neq 0 (
        echo HATA: Servis başlangıç türü otomatik olarak ayarlanamadı (Hata Kodu: %SC_CONFIG_EC%).
        echo Manuel olarak ayarlamayı deneyin:
        echo 1. 'services.msc' yazıp Çalıştır'ı açın.
        echo 2. '%SERVICE_NAME%' servisini bulun.
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
sc query "%SERVICE_NAME%" | findstr /i /C:"STATE" | findstr /i /C:"RUNNING" > nul
set SC_QUERY_STATE_EC=%errorlevel%
if %SC_QUERY_STATE_EC% neq 0 (
    echo Servis çalışmıyor. Başlatılıyor...
    net start "%SERVICE_NAME%"
    set NET_START_EC=%errorlevel%
    if %NET_START_EC% neq 0 (
        echo HATA: Servis başlatılamadı (Hata Kodu: %NET_START_EC%).
        echo Manuel olarak başlatmayı deneyin:
        echo 1. 'services.msc' yazıp Çalıştır'ı açın.
        echo 2. '%SERVICE_NAME%' servisini bulun.
        echo 3. Sağ tıklayıp 'Başlat'ı seçin.
        echo VEYA Yönetici Komut İstemcisinden 'net start %SERVICE_NAME%' komutunu çalıştırın.
        echo Sorun devam ederse sistem günlüklerini veya WireSock günlüklerini kontrol edin ^('-log-level' parametresini değiştirerek^).
        goto :ErrorExit
    )
    :: Başlatma sonrası kısa bir bekleme ve tekrar kontrol
    timeout /t 3 /nobreak > nul
    sc query "%SERVICE_NAME%" | findstr /i /C:"STATE" | findstr /i /C:"RUNNING" > nul
    set SC_QUERY_POST_START_EC=%errorlevel%
    if %SC_QUERY_POST_START_EC% neq 0 (
         echo UYARI: Servis başlatıldı ancak hemen ardından çalışan durumda bulunamadı (sc query hatası: %SC_QUERY_POST_START_EC%). Bir sorun olabilir. Lütfen manuel kontrol edin.
         pause
    ) else (
         echo Servis başarıyla başlatıldı ve çalışıyor.
    )
) else (
    echo Servis zaten çalışıyor.
)
echo.
timeout /t 3 /nobreak > nul

:: == 11. Başarı Mesajı ==
:Success
cls
echo ===============================================================================
echo                            İŞLEM BAŞARIYLA TAMAMLANDI!
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
echo.
echo ===============================================================================
echo                                 HATA OLUŞTU!
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
exit /b %errorlevel%

:: ALT RUTİNLER BURADA BAŞLIYOR (Önceki versiyondaki :CheckDownloadStatus kaldırıldı)
:: Şu an için ek alt rutin gerekmiyor.
