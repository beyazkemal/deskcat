# 🐈 Pet (SwiftUI) — native macOS masaüstü kedisi

comnyang tarzı masaüstü kedisinin **native Swift / SwiftUI** sürümü. Electron
sürümüyle aynı davranışlar, ama çok daha hafif: harici bağımlılık yok, görsel
asset yok (kedi tamamen kodla çiziliyor), açılış anında, RAM/CPU minimal.

İmleci izler, fareyi hızlı oynatınca avlar, üstüne gelince mırlar, sessiz
kalınca uyuklar, kaldırınca mochi gibi uzar, zamanlayıcıyla esner. Hep en üstte,
şeffaf ve **odağı asla çalmadan** çalışır (nonactivating `NSPanel`).

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

> ⚠️ `swift run` ile çalıştırdığında izin, derlenen binary'ye bağlanır; her
> yeniden derlemede izni tekrar vermen gerekebilir. Kalıcı kullanım için
> aşağıdaki gibi gerçek bir `.app` yapman önerilir.

## Gereksinim

- macOS 13 (Ventura) veya üzeri
- **Xcode** veya **Command Line Tools** (`xcode-select --install`)

## Çalıştırma (en hızlı yol)

```bash
cd /Users/kemalbeyaz/Repos/my-pet-swift
swift run
```

Kedi sağ alt köşede belirir, menü çubuğunda bir kedi ikonu çıkar. Çıkmak için
menüden **Quit** (veya terminalde Ctrl+C).

Daha akıcı çalışması için optimize derleme:

```bash
swift run -c release
```

## Ne yapıyor?

| Durum | Tetikleyici |
|-------|-------------|
| 👀 Takip | İmleci gözleriyle izler, başını hafifçe ona doğru eğer |
| 🐾 Avlanma | Fareyi hızlı oynatınca çömelir, gözleri büyür, hamle yapar |
| 😌 Mırlama | İmleci üstüne getirip yavaşça beklersen gözleri kapanır, kalpler/notalar uçar |
| 😴 Uyku | Birkaç saniye hareketsiz kalınca uyuklar, "z z z" çıkar |
| ⌨️ Tıklama | Yazarken ön patileriyle sırayla tıklar (kneading) |
| 🥵 Aşırı ısınma | Çok hızlı yazınca kızarır, gözleri sıkılır, başından buhar çıkar |
| 🫳 Kaldırma | Kediye tıklayıp sürükle — mochi gibi esner, sersemler |
| 🙆 Esneme | Zamanlayıcıyla veya "Stretch now" ile ayağa kalkıp esner |

## Menü çubuğu

- **Hide / Show cat** — gizle / geri çağır
- **Call it over** — kediyi imlecin olduğu tarafa yürüt
- **Stretch now** — hemen esnetme
- **Stretch reminder** — Kapalı / 20 / 30 / 60 dk
- **Fur color** — Turuncu tekir / Gri / Krem / Smokin
- **Enable keyboard reactions…** — Input Monitoring iznini ister/açar
- **Quit**

## Gerçek bir .app yapmak (opsiyonel)

`swift run` denemek için yeterli ama kalıcı bir uygulama istersen:

1. **Xcode ile:** Xcode'da *macOS → App* projesi aç, `Sources/DesktopPet/`
   içindeki `.swift` dosyalarını ekle, `Info.plist`'e `LSUIElement = YES` ekle
   (Dock'ta görünmesin), çalıştır. `main.swift`'i silip `@main` yapısına
   geçmen gerekebilir — ya da AppDelegate'i `@NSApplicationMain` ile bağla.
2. **Komut satırıyla bundle:** `swift build -c release` sonrası
   `.build/release/DesktopPet` çıkan binary'yi bir `DesktopPet.app/Contents/MacOS/`
   yapısına kopyalayıp basit bir `Info.plist` eklersen .app olur.

## Dosya yapısı

```
my-pet-swift/
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

