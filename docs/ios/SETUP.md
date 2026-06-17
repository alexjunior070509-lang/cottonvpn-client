# CottonVPN iOS — что нужно настроить (после покупки Apple Developer)

iOS-приложение — это **тот же код**, что и Android (Qt/amnezia-client fork), просто другой
таргет сборки. AmneziaWG на iOS поддерживается (Packet Tunnel + `amneziawg-apple`). Дизайн,
логика, выдача ключа из бота — общие.

⚠️ В отличие от Android, **.ipa нельзя раздавать напрямую**. Установка только через
**TestFlight** (бета по ссылке-приглашению, до 10 000 чел.) или App Store (полный ревью,
риск отклонения VPN-приложения для РФ). Рекомендуемый путь запуска — TestFlight.

## Шаг 1. Apple Developer ($99/год)
1. Зарегистрируйся: https://developer.apple.com/programs/ — оплати $99, пройди верификацию.
2. После активации узнай свой **Team ID**: developer.apple.com → Membership → Team ID
   (10 символов, напр. `A1B2C3D4E5`).

## Шаг 2. Идентификаторы в Apple-портале (Certificates, IDs & Profiles)
Создай **два App ID** (Identifiers → App IDs):
- `com.cottonvpn.app` — основное приложение.
- `com.cottonvpn.app.network-extension` — VPN-расширение.

У обоих включи capability **Network Extensions** (и **Personal VPN** у основного).
У обоих включи **App Groups** и добавь группу:
- App Groups → создать `group.com.cottonvpn.app`, привязать к обоим App ID.

## Шаг 3. Сертификаты
- **Apple Distribution** (для TestFlight/App Store) и **Apple Development** (для отладки) —
  создай в Certificates. Скачай `.cer`, добавь в Keychain на Mac (или сгенерь CSR онлайн).
- Экспортируй как `.p12` с паролем (для CI).

## Шаг 4. Provisioning Profiles
Создай 4 профиля (Profiles), имена — **точно как тут** (CI на них ссылается через CMake):
| Профиль | App ID | Тип | Имя (XCODE PROVISIONING_PROFILE_SPECIFIER) |
|---|---|---|---|
| App, distribution | com.cottonvpn.app | App Store | **CottonVPN App Store** |
| App, development | com.cottonvpn.app | Development | **CottonVPN Dev** |
| NE, distribution | …​.network-extension | App Store | **CottonVPN NE App Store** |
| NE, development | …​.network-extension | Development | **CottonVPN NE Dev** |

(Имена меняются в `client/CMakeLists.txt`: `BUILD_IOS_PROFILE_*` / `BUILD_IOS_NE_PROFILE_*`,
если захочешь другие.)

## Шаг 5. App Store Connect → новое приложение
- appstoreconnect.apple.com → My Apps → «+» → New App.
- Platform iOS, bundle ID `com.cottonvpn.app`, имя «CottonVPN».
- Заполни Privacy Policy URL: `https://cottonvpn.com/privacy.html` (уже готова).

## Шаг 6. Секреты в GitHub (репо cottonvpn-client → Settings → Secrets → Actions)
Добавь:
- `APPLE_TEAM_ID` — Team ID из шага 1.
- `IOS_DIST_CERT_P12_B64` — `.p12` distribution-сертификата в base64 (`base64 -i cert.p12`).
- `IOS_CERT_PASSWORD` — пароль от `.p12`.
- `IOS_PROFILE_APP_B64`, `IOS_PROFILE_NE_B64` — `.mobileprovision` (App Store) в base64.
- Для аплоада в TestFlight — **App Store Connect API key** (Users and Access → Integrations →
  App Store Connect API): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64` (содержимое `.p8`).

## Шаг 7. Сборка
Workflow `.github/workflows/cottonvpn-ios.yml` (пока запуск только вручную — `workflow_dispatch`).
Он собирает на `macos-latest`, подписывает импортированными серт+профилями и (когда настроишь
ASC API key) грузит билд в TestFlight. Идентификаторы/team/профили подставляются из секретов.

**Что я (Claude) уже сделал в коде:**
- bundle id → `com.cottonvpn.app` (+ `.network-extension`), app group → `group.com.cottonvpn.app`.
- Team ID и имена профилей вынесены в CMake-переменные (больше не зашит амнезиевский `X7UJ388FXK`).
- Имя приложения на iOS → «CottonVPN», строки доступа к камере — тоже.

**Чего нельзя сделать без аккаунта:** сами сертификаты/профили (создаются под твоим Apple ID,
часть шагов интерактивные с 2FA) и первая реальная сборка (вероятно 1–2 итерации по логам CI —
это нормально для первого iOS-пайплайна).

## Порядок запуска
1. Купил аккаунт → прислал мне Team ID.
2. Я доведу workflow и подскажу по экспорту сертов/профилей.
3. Создаёшь App ID/группу/серты/профили (по шагам выше) → кладёшь секреты.
4. Запускаем сборку → правим если что → билд в TestFlight → ссылка подписчикам.
