# CottonVPN — материалы для Google Play Console

Готовые тексты и ассеты для карточки приложения. Копируй по полям в Play Console.

## Основное
- **App name:** CottonVPN
- **Package name (applicationId):** `com.cottonvpn.app`
- **Category:** Tools (Инструменты)
- **Default language:** Русский (ru-RU); рекомендую добавить English (US) копией английских текстов ниже.
- **Privacy Policy URL:** https://cottonvpn.com/privacy.html
- **Contact email:** ialex2021@icloud.com
- **Support / website:** https://cottonvpn.com , Telegram https://t.me/cottonvpn_bot

## Короткое описание (Short description, до 80 символов)
**RU:** Быстрый и простой VPN. Вставь ключ — и одна кнопка для подключения.
**EN:** Fast, simple VPN. Paste your key and connect with a single button.

## Полное описание (Full description, до 4000 символов)
**RU:**
CottonVPN — это простой и быстрый VPN. Никаких сложных настроек: вставьте ключ, который вы получили в нашем Telegram‑боте, и нажмите одну кнопку, чтобы подключиться.

• Один экран и одна кнопка включения/выключения
• Современные протоколы, устойчивые к блокировкам
• Без рекламы, без трекеров, без сбора личных данных
• Ключ хранится только на вашем устройстве

Подключение оплачивается и выдаётся через нашего Telegram‑бота @cottonvpn_bot. Приложение само по себе бесплатно и служит клиентом для подключения к серверу по вашему ключу.

**EN:**
CottonVPN is a simple and fast VPN. No complicated setup: paste the key you received from our Telegram bot and tap a single button to connect.

• One screen, one on/off button
• Modern, censorship‑resistant protocols
• No ads, no trackers, no personal data collection
• Your key is stored only on your device

Access is purchased and issued through our Telegram bot @cottonvpn_bot. The app itself is free and acts as a client to connect to the server using your key.

## Ассеты
- **App icon (512×512, 32‑bit PNG):** `docs/play/icon-512.png` ✅ готов
- **Feature graphic (1024×500 PNG/JPG):** НУЖНО сделать (можно из `og.png` на сервере в Canva/Figma)
- **Phone screenshots (мин. 2, от 320 до 3840 px по стороне):** НУЖНО снять с устройства:
  1. первый экран с полем ключа
  2. экран с большой кнопкой питания (подключено)

## Data safety (форма в Console) — что отвечать
- Does your app collect or share user data? → **No** (приложение не собирает и не передаёт данные; ключ хранится локально).
- Если Console потребует уточнить про VPN: данные не покидают устройство, аналитики нет.
- Encryption in transit: **Yes** (VPN‑туннель шифрует трафик).

## App content / декларации
- **VPN/Privacy:** укажи, что приложение использует `VpnService` для туннелирования трафика пользователя к выбранному серверу; назначение — приватность и доступ.
- **Ads:** No ads.
- **Target audience:** 18+ (или 13+), не для детей.
- **Content rating:** заполнить анкету (получится Everyone/3+).

## Формат загрузки
- Загружать **`CottonVPN-release.aab`** (App Bundle) из GitHub Release / артефактов CI.
- Включить **Play App Signing** (наш keystore = upload key).
