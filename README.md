# 🐈 DeskCat — native macOS masaüstü kedisi

comnyang tarzı masaüstü kedisinin **native Swift / SwiftUI** sürümü. Electron
sürümüyle aynı davranışlar, ama çok daha hafif: harici bağımlılık yok, görsel
asset yok (kedi tamamen kodla çiziliyor), açılış anında, RAM/CPU minimal.

İmleci izler, üstüne gelince mırlar, altı saniye
sessiz kalınca uyuklar, kaldırınca mochi gibi uzar, kuyruğunu çekince kızar ve
zamanlayıcıyla esner. Hep en üstte, şeffaf ve **odağı asla çalmadan** çalışır
(nonactivating `NSPanel`).

> Not: Global imleç/fare takibi `NSEvent.mouseLocation` ve
> `NSEvent.pressedMouseButtons` ile yapılır — **erişilebilirlik / input
> monitoring izni gerektirmez.** Klavye tepkileri ise izin ister (aşağıya bak).

## ⌨️ Klavye tepkileri (izin gerekir)

Yazarken kedinin patileriyle tıklaması ve hızlı yazınca aşırı ısınması için
uygulamanın **Input Monitoring** iznine ihtiyacı var:

- İlk açılışta sistem izin sorabilir. Sormazsa menü çubuğundan
  **“Enable keyboard reactions…”** seçeneğine tıkla; bu, Sistem Ayarları →
  Gizlilik ve Güvenlik → **Giriş İzleme (Input Monitoring)** panelini açar.
  Oradan uygulamayı işaretle ve gerekiyorsa yeniden başlat.

**Gizlilik:** Kedi yalnızca “bir tuşa basıldı” sinyalini sayar. **Hangi tuşa
basıldığı hiçbir zaman okunmaz, kaydedilmez veya saklanmaz** (`registerKeystroke`
olayın içeriğini görmez bile). Hız bilgisi sadece ısınma efekti için kullanılır.

> ⚠️ `swift run` ile çalıştırılan binary ile paketlenmiş `DeskCat.app`
> macOS açısından farklı uygulamalardır. Input Monitoring iznini klavye
> tepkileri için kullanacağın gerçek `.app` sürümüne ver.

## Gereksinim

- macOS 13 (Ventura) veya üzeri
- **Xcode** veya **Command Line Tools** (`xcode-select --install`)

## Çalıştırma (en hızlı yol)

```bash
cd /Users/kemalbeyaz/Repos/my-pet
swift run
```

Kedi sağ alt köşede belirir, menü çubuğunda bir kedi ikonu çıkar. Çıkmak için
menüden **Quit** (veya terminalde Ctrl+C).

Daha akıcı çalışması için optimize derleme:

```bash
swift run -c release
```

İmzalı `DeskCat.app` ve `DeskCat.dmg` paketini yeniden üretmek için:

```bash
./Scripts/package-dmg.sh
```

Betik Apple Silicon ve Intel Mac'ler için universal binary üretir. Başka
Mac'lerde Gatekeeper uyarısı olmadan dağıtmak için notarization kimlik
bilgilerini bir kez Keychain'e kaydet:

```bash
xcrun notarytool store-credentials DeskCatNotary \
  --apple-id "APPLE_ID_EPOSTAN" \
  --team-id "5S5NZJ7SKF"
```

Komut parola istediğinde Apple hesabının normal parolası yerine
[uygulamaya özel parola](https://appleid.apple.com/) kullan. Ardından imzalama,
notarization ve ticket stapling işlemlerini tek komutla çalıştır:

```bash
NOTARY_PROFILE=DeskCatNotary ./Scripts/package-dmg.sh
```

## Ne yapıyor?

| Durum | Tetikleyici |
|-------|-------------|
| 👀 Takip | İmleci gözleriyle izler, başını hafifçe ona doğru eğer |
| 😌 Mırlama | İmleci üstüne getirip yavaşça beklersen gözleri kapanır, kalpler/notalar uçar |
| 😴 Uyku | Birkaç saniye hareketsiz kalınca uyuklar, "z z z" çıkar |
| ⌨️ Tıklama | Yazarken ön patileriyle sırayla tıklar (kneading) |
| 🥵 Aşırı ısınma | Çok hızlı yazınca kızarır, gözleri sıkılır, başından buhar çıkar |
| 🧻 Tuvalet kâğıdı | Scroll yapınca patileriyle tuvalet kâğıdını aşağı doğru sarar |
| 🤔 Agent düşünme | Codex veya Claude Code çalışırken düşünür, bitince sevinir |
| 🫳 Kaldırma | Kediye tıklayıp sürükle — mochi gibi esner, sersemler |
| 😾 Kuyruk çekme | Kuyruğuna tıklayıp çek — kuyruk uzar, kedi kısa süre kızar |
| 🙆 Esneme | Zamanlayıcıyla veya "Stretch now" ile ayağa kalkıp esner |
| 🐾 Tırmalama | "Scratch now" ile ön patilerini sırayla uzatır ve pençe izleri bırakır |
| 🍅 Pomodoro | Focus ve mola süresini kedinin yanında gösterir |

## Menü çubuğu

- **Hide / Show cat** — gizle / geri çağır
- **Call it over** — kediyi imlecin olduğu tarafa yürüt
- **Stretch now** — hemen esnetme
- **Scratch now** — gerinerek tırmalama hareketini oynat
- **Stretch reminder** — Kapalı / 20 / 30 / 60 dk
- **Fur color** — Turuncu tekir / Gri / Krem / Smokin
- **Enable keyboard reactions…** — Input Monitoring iznini ister/açar
- **Settings…** — kedi adı, görünüm, Pomodoro ve agent bağlantıları
- **Quit**

## Gerçek bir .app yapmak (opsiyonel)

`swift run` denemek için yeterli ama kalıcı bir uygulama istersen:

1. **Xcode ile:** Xcode'da *macOS → App* projesi aç, `Sources/DesktopPet/`
   içindeki `.swift` dosyalarını ekle, `Info.plist`'e `LSUIElement = YES` ekle
   (Dock'ta görünmesin), çalıştır. `main.swift`'i silip `@main` yapısına
   geçmen gerekebilir — ya da AppDelegate'i `@NSApplicationMain` ile bağla.
2. **Komut satırıyla bundle:** `swift build -c release` sonrası
   `.build/release/DeskCat` çıkan binary'yi bir `DeskCat.app/Contents/MacOS/`
   yapısına kopyalayıp basit bir `Info.plist` eklersen .app olur.

## Dosya yapısı

```
my-pet/
├── Package.swift
└── Sources/DesktopPet/
    ├── main.swift          # giriş: NSApplication (accessory) + AppDelegate
    ├── AppDelegate.swift    # menü çubuğu, panel kurulumu, 60fps timer
    ├── PetPanel.swift       # kenarsız, şeffaf, odağı çalmayan NSPanel
    ├── PetEngine.swift      # state makinesi, imleç takibi, sürükleme, efektler
    ├── CatRenderer.swift    # kedinin prosedürel çizimi (SwiftUI Canvas)
    ├── CatView.swift        # Canvas'ı barındıran SwiftUI view
    └── Model.swift          # renk paletleri + CatModel + Color(hex:)
```

## Geliştirme notları

- **Yeni hareket:** `PetEngine.currentState()` içine yeni bir durum ekle,
  `CatRenderer.drawSprite` içinde o duruma göre poz/yüz çiz.
- **Isınma ayarı:** Aşırı ısınma eşiği ve hızı `PetEngine` içindeki `heat`
  artış/azalış katsayılarıyla ayarlanır (`heat + 0.12` / `heat - 0.006`).
- **Piksel görünüm:** Şu an kedi yumuşak vektör çiziliyor. Tam "pixel art" için
  `CatRenderer.draw` içinde küçük bir offscreen'e çizip `interpolation: .none`
  ile büyütebilirsin.
- **Çoklu ekran:** Şu an ana ekranda çalışır; her `NSScreen` için ayrı panel
  açarak genişletebilirsin.
