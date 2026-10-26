# Discord VPN (Windows)

Windows'ta sadece Discord'u VPN'e yönlendiren WireSock + WGCF kurulum scripti (PowerShell).

*PowerShell installer for Windows that routes only Discord traffic through Cloudflare WARP using WireSock + WGCF.*

---

## Ne yapar?

`discord_vpn.ps1`, **WGCF** ile ücretsiz bir Cloudflare WARP hesabı açar, **WireSock Secure Connect**'i kurar ve sadece **Discord uygulamasını** bu VPN üzerinden geçirecek bir Windows servisi oluşturur. Servis her açılışta otomatik başlar. Diğer tüm uygulamalar normal internet bağlantınızı kullanır.

### Özellikler

* Açılışta ne yapacağını anlatan kısa bir açıklama ve seçim menüsü:
  * **Tam otomatik kurulum**
  * **Adım adım kurulum** (her adımdan önce onay ister)
  * **İptal**
* Seçimden sonra yönetici izni ister (UAC) ve kurulumu yönetici penceresinde sürdürür
* Otomatik mimari (32-bit / 64-bit) algılama
* İndirilen dosyaların **SHA256 ile doğrulanması**
* WireSock'un otomatik kurulumu (sihirbazda tıklama gerekmez)
* Discord'a özel `AllowedApps` yönlendirmesi
* Tekrar çalıştırılabilir: mevcut WARP hesabını, kurulu WireSock'u ve servisi yeniden kullanır

---

## Gereksinimler

* Windows 10 veya 11 (x64 ya da x86). ARM64 desteklenmez.
* Windows PowerShell 5.1 (Windows'ta hazır gelir)
* İnternet bağlantısı
* Yönetici yetkisi

---

## Nasıl Kullanılır?

1. `discord_vpn.ps1` dosyasını bilgisayarınıza indirin.
2. Dosyaya **sağ tıklayın > "PowerShell ile çalıştır"** seçin.
   (Windows 11'de önce "Diğer seçenekleri göster" demeniz gerekebilir.)
3. Açıklamayı okuyun ve bir seçenek seçin: `1` tam otomatik, `2` adım adım, `3` iptal.
4. Windows izin (UAC) penceresinde **Evet** deyin. Kurulum yeni açılan yönetici penceresinde devam eder.
5. Kurulum adımları:
   1. wgcf ve WireSock `Downloads` klasörüne indirilir ve doğrulanır
   2. `wgcf` ile WARP hesabı açılır (`Belgeler\wgcf-account.toml`)
   3. VPN profili oluşturulur ve sadece Discord'a izin verilir (`Belgeler\wgcf-profile.conf`)
   4. WireSock kurulur
   5. `wiresock-client-service` servisi oluşturulur
   6. Servis başlatılır
6. Bitince Discord'u açıp sunuculara ve sesli kanallara bağlanarak kontrol edin.

Komut satırından da çalıştırabilirsiniz:

```powershell
powershell -ExecutionPolicy Bypass -File .\discord_vpn.ps1
```

---

## ⚠️ Dikkat Edilmesi Gerekenler

1. `wgcf` sizin adınıza bir Cloudflare WARP hesabı açar ve Cloudflare'in kullanım şartlarını kabul eder.
2. `Belgeler\wgcf-account.toml` dosyası hesabınızın gizli anahtarını içerir. Kimseyle paylaşmayın.
3. Bir dosya indirilemezse script, indirme adresini gösterir. Dosyayı tarayıcıyla `Downloads` klasörüne indirip script'i tekrar çalıştırabilirsiniz.
4. WireSock kurulumu gerekirse Microsoft'tan .NET Desktop Runtime da indirir; bu biraz sürebilir.
5. Eski `discord_vpn.bat` ile kurulum yaptıysanız script aynı dosyaları ve servisi kullanmaya devam eder.

---

## Sorun Giderme

Sorun yaşarsanız Win+R tuşlarına basın, `services.msc` yazıp Enter'a basın. Açılan pencerede **"WireSock WireGuard VPN Client Service"** (`wiresock-client-service`) isimli servisi durdurup başlatın ya da yeniden başlatın.

![image](https://github.com/user-attachments/assets/8c484221-0d0f-4aa7-ba0d-d9b5982588a8)

Script'i tekrar çalıştırmak da güvenlidir: tamamlanmış adımlar atlanır, servis yeni ayarlarla yeniden başlatılır.

---

## Kaldırma

1. **Ayarlar > Uygulamalar** bölümünden **WireSock Secure Connect**'i kaldırın. Servis de birlikte silinir.
2. `Belgeler` klasöründeki `wgcf-profile.conf` ve `wgcf-account.toml` dosyalarını silin.
3. İsterseniz `Downloads` klasöründeki `wgcf_*.exe` ve `wiresock-secure-connect-*.exe` dosyalarını da silin.
