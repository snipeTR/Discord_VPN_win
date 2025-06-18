### ✅ Kısa Açıklama (Repository Description - Türkçe ve İngilizce)

**Türkçe:**
Windows'ta sadece Discord'u VPN'e yönlendiren WireSock + WGCF otomasyon scripti.

**İngilizce:**
Automated WireSock + WGCF setup on Windows to route only Discord traffic via VPN.

---

### 📄 Ayrıntılı Açıklama (README Başlığı Altında Kullanılabilir)

#### Discord VPN Otomasyon Scripti (`discord_vpn.bat`)

Bu script, Windows sisteminizde **WireSock** ve **WGCF** araçlarını otomatik olarak indirip kurar, yapılandırır ve sadece **Discord uygulamasını VPN üzerinden yönlendirecek şekilde ayar yapar**. Sistem başlangıcında otomatik çalışan bir servis olarak yapılandırılır.

#### Temel Özellikler:

* Otomatik mimari (32-bit / 64-bit) algılama
* Gerekli araçların (curl, wgcf, WireSock) otomatik kurulumu
* Discord'a özel `AllowedApps` yönlendirmesi
* WireSock servisi oluşturma ve başlatma
* Admin yetkisi kontrolü ve otomatik yükseltme
* Hata kontrolü ve manuel müdahale yönergeleri

---

### ⚠️ Dikkat Edilmesi Gerekenler

1. **Script mutlaka "Yönetici olarak" çalıştırılmalıdır.** Aksi halde otomatik servis kurulumu yapılamaz.
2. **İnternet bağlantınızın aktif olması gerekir.** Dosyalar internetten indirilecektir.
3. `curl` ve `winget` sisteminizde yoksa script bunları otomatik yüklemeye çalışır, bu işlem için kullanıcı izni gerekebilir.
4. **WireSock kurulum sihirbazı çalıştırılacaktır** — bu pencereye geçerek manuel kurulum adımlarını tamamlamanız gerekir.
5. `wgcf` aracı Cloudflare WARP hesabı oluşturur. Eğer bu işlem başarısız olursa, script hata mesajlarıyla yönlendirme yapar.

---

### ▶️ Nasıl Kullanılır?

1. **Script'i İndir:**
   `discord_vpn.bat` dosyasını bilgisayarınıza indirin.

2. **Sağ tıklayın > "Yönetici olarak çalıştır" seçin.**

3. Script sırasıyla:

   * Sistem mimarinizi tespit eder
   * Gerekli dosyaları indirir (curl, wgcf, WireSock)
   * `wgcf` ile profil oluşturur
   * Discord uygulamasını özel VPN'e yönlendirir
   * WireSock’u kurar ve servis olarak başlatır

4. Kurulum sırasında ek pencereler açılabilir (özellikle WireSock kurulumu sırasında). Bu pencerelerde yönergeleri takip edin.

5. **Kurulum tamamlandığında:**
   Discord uygulaması sadece WireSock üzerinden internete çıkacak şekilde yapılandırılmış olur. Diğer tüm uygulamalar sistem bağlantısını doğrudan kullanır.

---

Sorun ile karşılaşırsanız ilgili servisi win+R tuşlarına basarak çıkan çalıştır ekranına "services.msc" yazıp enter'a basarak açılan servis penceresinden "WireSock WireGuard VPN Client Service" isimli servisi, kapatıp, açıp, yada yeniden başlatarak düzeltebilirsiniz.
![image](https://github.com/user-attachments/assets/8c484221-0d0f-4aa7-ba0d-d9b5982588a8)

