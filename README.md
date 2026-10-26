# Discord VPN (Windows)

Windows'ta sadece Discord'u VPN'e yönlendiren WireSock + WGCF otomasyon scripti.

*Automated WireSock + WGCF setup on Windows to route only Discord traffic via VPN.*

---

## Ne yapar?

`discord_vpn.bat`, **WGCF** ile ücretsiz bir Cloudflare WARP hesabı açar, **WireSock Secure Connect**'i kurar ve sadece **Discord uygulamasını** bu VPN üzerinden geçirecek bir Windows servisi oluşturur. Servis her açılışta otomatik başlar. Diğer tüm uygulamalar normal internet bağlantınızı kullanır.

### Özellikler

* Otomatik mimari (32-bit / 64-bit) algılama
* Gerekli dosyaların (wgcf, WireSock) otomatik indirilmesi
* İndirilen dosyaların **SHA256 ile doğrulanması**
* WireSock'un otomatik kurulumu (sihirbazda tıklama gerekmez)
* Discord'a özel `AllowedApps` yönlendirmesi
* WireSock servisi oluşturma ve başlatma
* Admin yetkisi kontrolü ve otomatik yükseltme
* Tekrar çalıştırılabilir: mevcut WARP hesabını ve kurulu WireSock'u yeniden kullanır

---

## Gereksinimler

* Windows 10 veya 11 (x64 ya da x86). ARM64 desteklenmez.
* İnternet bağlantısı
* Yönetici yetkisi

---

## Nasıl Kullanılır?

1. `discord_vpn.bat` dosyasını bilgisayarınıza indirin.
2. **Sağ tıklayın > "Yönetici olarak çalıştır"** seçin.
3. Script sırasıyla:
   * Sistem mimarinizi tespit eder
   * wgcf ve WireSock'u `Downloads` klasörüne indirir ve doğrular
   * `wgcf` ile WARP hesabı ve profil oluşturur
   * Profile `AllowedApps = Discord.exe` satırını ekler
   * Profil ve hesap dosyalarını `Belgeler` klasörüne taşır
   * WireSock'u kurar, `wiresock-client-service` servisini oluşturur ve başlatır
4. Windows izin (UAC) penceresi çıkarsa onaylayın.
5. Bitince Discord'u açıp sunuculara ve sesli kanallara bağlanarak kontrol edin.

---

## ⚠️ Dikkat Edilmesi Gerekenler

1. `wgcf` sizin adınıza bir Cloudflare WARP hesabı açar ve Cloudflare'in kullanım şartlarını kabul eder.
2. `Belgeler\wgcf-account.toml` dosyası hesabınızın gizli anahtarını içerir. Kimseyle paylaşmayın.
3. curl yoksa script onu `winget` ile kurmaya çalışır. Bu da olmazsa indirme adreslerini gösterir ve dosyaları elle indirmenizi ister.
4. WireSock kurulumu gerekirse Microsoft'tan .NET Desktop Runtime da indirir; bu biraz sürebilir.

---

## Sorun Giderme

Sorun yaşarsanız Win+R tuşlarına basın, `services.msc` yazıp Enter'a basın. Açılan pencerede **"WireSock WireGuard VPN Client Service"** (`wiresock-client-service`) isimli servisi durdurup başlatın ya da yeniden başlatın.

![image](https://github.com/user-attachments/assets/8c484221-0d0f-4aa7-ba0d-d9b5982588a8)

Script'i tekrar çalıştırmak da güvenlidir: mevcut hesap ve kurulum yeniden kullanılır, servis yeni ayarlarla yeniden başlatılır.

---

## Kaldırma

1. **Ayarlar > Uygulamalar** bölümünden **WireSock Secure Connect**'i kaldırın. Servis de birlikte silinir.
2. `Belgeler` klasöründeki `wgcf-profile.conf` ve `wgcf-account.toml` dosyalarını silin.
3. İsterseniz `Downloads` klasöründeki `wgcf_*.exe` ve `wiresock-secure-connect-*.exe` dosyalarını da silin.
