# Етап 1 — інструкція виконання

## Щоденне правило: спочатку `nvm use`

Кожну нову сесію терміналу, перед будь-якою командою в `mindcraft/`:

```
./scripts/start-server.sh     # термінал 1, чекати "Done (...)"
./scripts/start-bots.sh       # термінал 2
```

Скрипти самі підставляють Java 21 і Node 22 — ні `export JAVA_HOME`, ні `nvm use` вручну не треба, і папка запуску байдужа. Вони ж роблять передпольотні перевірки (є jar, вільний порт, правильний Node, є `node_modules`, сервер справді слухає) і падають з поясненням замість незрозумілої помилки нативних модулів.

Зайти в гру самому: Minecraft.app → інсталяція **1.21.6** (не 26.x, інакше `Outdated server`) → Multiplayer → Direct Connection → `127.0.0.1:25565`. Інсталяцію 1.21.6 треба один раз створити в лаунчері: Installations → New installation → Version `release 1.21.6`.

`nvm use` підхоплює Node 22 з `.nvmrc`. Без нього візьметься системний homebrew Node 25, на якому нативні модулі (`gl`, `canvas`) не завантажаться — причина в кроці 1. Симптом: `node main.js` падає з `Error: Could not locate the bindings file` або `invalid ELF header`/`NODE_MODULE_VERSION` ще до того, як боти спробують зайти на сервер.

Швидка перевірка, що версія правильна: `node -v` має дати `v22.x`, не `v25.x`.

Щоб не памʼятати про це щоразу, можна ввімкнути автоперемикання nvm по `.nvmrc` — додати в `~/.zshrc` хук `chpwd`, як описано в README nvm (розділ "Deeper Shell Integration"). Тоді `cd` у папку проєкту сам перемикає версію.

Що вже зроблено в репозиторії (не повторювати):

- `mindcraft/` — клон `kolbytn/mindcraft` (shallow, гілка main).
- `config/` — усі конфіги етапу 1, це джерело правди.
- `.nvmrc` + `config/patches/` + `config/npm-pins.txt` — фіксація Node 22 і версій нативних залежностей (див. крок 1).
- `scripts/deploy.sh` — розкладає конфіги по місцях, де їх реально читає mindcraft, і генерує `mindcraft/keys.json` з ключа `GEMINI_API_KEY` проєкту lumi (`~/development/lumi/.env`). Уже запущений один раз, ключ перевірений живим запитом до Google AI.
- `server/` — `paper.jar` (Paper 1.21.6 build 48, sha256 звірений), `eula.txt`, `server.properties`. Світ ще не згенерований.
- `scripts/fetch-server.sh` — качає і звіряє jar, приймає EULA.

Лишається: поставити Java 21 і запустити сервер (крок 2), потім кроки 3-5.

## Крок 1. Залежності mindcraft — ЗРОБЛЕНО

Виконано, повторювати не треба. Нижче що саме зроблено і чому, бо з першого разу не встановилося.

### Потрібен Node 22, не системний Node 25

Системний homebrew Node 25 не підходить. Пакет `gl` (OpenGL-біндинг, тягнеться через `node-canvas-webgl` і `prismarine-viewer`) має готові бінарники лише до Node 22 включно (ABI 127). На Node 25 `prebuild-install` нічого не знаходить і `node-gyp` починає збирати ANGLE з початкових кодів, що падає на `/bin/sh: python: command not found` — у системі є `python3`, а gyp-файл ANGLE викликає саме `python`.

Ставити `python`-шим і збирати ANGLE не треба. Правильний шлях — Node 22 LTS:

```
nvm install 22
nvm use 22          # або просто зайти в папку проєкту: тут є .nvmrc з "22"
cd ~/development/minecraft-ai-bots/mindcraft && npm install
```

`.nvmrc` лежить у корені проєкту і копіюється в `mindcraft/`. **Кожну сесію перед `node main.js` робити `nvm use`**, інакше підхопиться Node 25 і нативні модулі не завантажаться.

Прибрати `gl` з залежностей не можна: `src/agent/agent.js` статично імпортує `vision/browser_viewer.js` і `vision/vision_interpreter.js`, а ті тягнуть `prismarine-viewer` і `node-canvas-webgl` на рівні модуля. Прапорці `render_bot_view: false` і `allow_vision: false` вимикають використання, але не імпорт.

### Патч mineflayer перероблений

`npm install` ставить mineflayer 4.39.0, а upstream-патч `patches/mineflayer+4.33.0.patch` написаний під 4.33.0 і не накладається. З трьох його хунків два вже полагоджені в самому mineflayer краще, ніж у патчі (`use_item` рахує поворот через `toNotchianYaw/Pitch`, `place_block` чекає підтвердження сервера замість зменшеного таймауту). Третій досі потрібен:

```js
if (block.material === 'incorrect_for_wooden_tool')
  block.material = 'mineable/pickaxe'
```

У minecraft-data 1.21.6 руди мають матеріал `incorrect_for_wooden_tool`, чия таблиця швидкостей не містить нормальних кайл. Без цього рядка `digTime` для залізної руди кам'яною кайлою дає 4550 мс замість 1150 мс — тобто б'є саме по критерію приймання Miner-а.

Тому старий патч видалений, а новий, тільки з цим хунком, лежить у `config/patches/mineflayer+4.39.0.patch` і розкладається скриптом деплою. Заодно `scripts/deploy.sh` прибиває версії в `mindcraft/package.json` за списком `config/npm-pins.txt` (`mineflayer=4.39.0`, `minecraft-data=3.116.0`), щоб наступний `npm install` знову не з'їхав з-під патчів.

### Перевірка

```
cd ~/development/minecraft-ai-bots/mindcraft && nvm use
node -e "Promise.all([import('mineflayer'),import('prismarine-viewer'),import('node-canvas-webgl/lib/index.js'),import('./src/agent/agent.js')]).then(()=>console.log('ok'))"
```

Має вивести `ok`. Вже перевірено. Попередження `npm audit` і `deprecated` ігнорувати — це залежності upstream.

## Крок 2. Minecraft-сервер 1.21.6

Версія зафіксована в `config/settings.js` як `1.21.6` — рекомендована версія з README mindcraft (mineflayer тримає до 1.21.11). Не піднімати новішу.

### 2.1 Java 21

Paper 1.21.6 не стартує на Java нижче 21. У системі стояла Corretto 11, тому:

```
brew install openjdk@21
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
export PATH="$JAVA_HOME/bin:$PATH"
java -version    # має показати 21.x
```

Якщо сервер каже `Minecraft 1.19 requires running the server with Java 17 or above` — це не про версію гри, рядок `1.19` захардкоджений у перевірці Paper. Це означає рівно одне: у поточному терміналі стара Java.

Поставлено: 21.0.12.1. Формула keg-only, тобто homebrew навмисно не підмінює нею системну Java, і `/usr/libexec/java_home -v 21` теж її не знайде — поверне стару Corretto 11. Тому шлях вказується явно, а два `export` треба дописати в `~/.zshrc`. Інакше в кожній новій сесії підхопиться Java 11 і сервер впаде з `UnsupportedClassVersionError`.

### 2.2 Завантаження Paper — скриптом, не руками

```
./scripts/fetch-server.sh
```

Скрипт качає останній стабільний білд у `server/paper.jar`, звіряє sha256 і приймає EULA (`server/eula.txt`). Ідемпотентний: якщо jar уже правильний, нічого не робить.

Чому скрипт, а не посилання з сайту: старий `api.papermc.io/v2` вимкнений і віддає `{"ok":false,"error":"sunset"}`. Актуальний — `fill.papermc.io/v3`, і він вимагає заголовок `User-Agent`, інакше відмовляє. Версію можна перебити змінною: `MC_VERSION=1.21.7 ./scripts/fetch-server.sh`, але тоді треба міняти й `minecraft_version` у `config/settings.js`.

Станом на зараз скачано: Paper 1.21.6 build 48, 50 MB, sha256 звірений.

### 2.3 Запуск

```
cd ~/development/minecraft-ai-bots/server
java -Xms2G -Xmx4G -jar paper.jar nogui
```

Перший запуск генерує світ — це кілька хвилин. Сервер при старті перезаписує `server.properties` своїми дефолтами, тому **після першого запуску зупинити його (`stop`), накотити наші налаштування і підняти знову**:

```
cd ~/development/minecraft-ai-bots && ./scripts/deploy.sh
cd server && java -Xms2G -Xmx4G -jar paper.jar nogui
```

`deploy.sh` зливає файли: наші ключі (`online-mode=false`, порт, складність) перекривають серверні, решта згенерованих рядків лишається.

Перевірка: у логах `Done (...)! For help, type "help"`, і `lsof -i :25565` показує java.

## Крок 3. Запуск ботів

```
./scripts/start-server.sh     # термінал 1, чекати "Done (...)"
./scripts/start-bots.sh       # термінал 2
```

Скрипти самі підставляють Java 21 і Node 22 — ні `export JAVA_HOME`, ні `nvm use` вручну не треба, і папка запуску байдужа. Вони ж роблять передпольотні перевірки (є jar, вільний порт, правильний Node, є `node_modules`, сервер справді слухає) і падають з поясненням замість незрозумілої помилки нативних модулів.

Зайти в гру самому: Minecraft.app → інсталяція **1.21.6** (не 26.x, інакше `Outdated server`) → Multiplayer → Direct Connection → `127.0.0.1:25565`. Інсталяцію 1.21.6 треба один раз створити в лаунчері: Installations → New installation → Version `release 1.21.6`.

Підніметься mindserver UI на http://localhost:8080 і три боти зайдуть на сервер: Porter, Miner, Guard. Кожен привітається одним реченням українською (`init_message`).

Перевірка: у грі `/list` показує чотирьох гравців (ти + три боти).

## Крок 4. Як з ними говорити — важливо

**Публічний чат не працює, коли ботів більше одного.** У `src/agent/agent.js` обробник `chat` виходить одразу, якщо на сервері є інші агенти; боти слухають тільки whisper. Тому весь тестовий сценарій з CONCEPT.md ганяти через `/msg`:

```
/msg Porter йди за мною
/msg Porter принеси 10 дуба
/msg Miner принеси 5 заліза
```

Guard працює без команд — він реагує на мобів режимами, а не чатом.

## Крок 5. Тестовий сценарій і критерії приймання

| # | Команда | Критерій приймання |
|---|---------|--------------------|
| 1 | `/msg Porter йди за мною` | бот тримається в межах 3-5 блоків, іде слідом |
| 2 | `/msg Porter принеси 10 дуба` | в інвентарі гравця 10 колод, бот повернувся на відстань до 3 блоків |
| 3 | `/msg Miner принеси 5 заліза` | у гравця злитки заліза; піч зроблена самим ботом, якщо її не було |
| 4 | ніч, підпустити зомбі до гравця | Guard убив моба без команди і не відійшов далі 6 блоків |

Порушення, які теж треба ловити: Porter щось будує або атакує, Miner б'є гравця, Guard б'є корову. Це заборонено промптом, а не конфігом (див. крок 6), тому реально перевіряється лише в грі.

Результати записати в `docs/test-log.md`: що спрацювало, що ні, скільки запитів пішло до Gemini. Кількість запитів видно в консолі `node main.js` (рядки `Awaiting Google API response...`) — порахувати `node main.js 2>&1 | tee run.log` і потім `grep -c 'Awaiting Google API response' run.log`.

## Крок 6. Обмеження, які треба знати перед правками

- **`blocked_actions` глобальний.** У mindcraft це поле `settings.js`, а не профілю (`src/agent/agent.js:62`). Тому в конфіг винесено тільки те, що заборонено всім трьом ролям: `!newAction`, `!attackPlayer`, `!goal`, `!endGoal`. Індивідуальні заборони ("Porter не будує") тримаються виключно на промпті і можуть бути порушені моделлю. Якщо роль систематично робить заборонене — це не баг конфіга, це або промпт, або потреба підняти чат на `gemini-pro-latest`.
- **`allow_insecure_coding: false`** вимикає виконання згенерованого коду, `!newAction` додатково заблокований. Не вмикати до етапу 2 і тільки для Builder.
- **Плейсхолдери в промптах обов'язкові.** `conversing` у профілях перевизначає дефолтний промпт, тому кожен профіль мусить містити `$COMMAND_DOCS`, `$EXAMPLES`, `$STATS`, `$INVENTORY`, `$MEMORY`, `$SELF_PROMPT`. Без `$COMMAND_DOCS` бот не знає жодної команди і просто розмовляє.
- **Озвучування.** `speak: true` у `config/settings.js`, голос — з поля `speak_model` профілю у форматі `провайдер/модель/голос`. Зараз: Porter — Puck, Miner — Charon, Guard — Kore, модель `gemini-2.5-flash-preview-tts`. Усі шість перевірених голосів (Puck, Charon, Kore, Leda, Fenrir, Aoede) читають українську; вони багатомовні й беруть мову з тексту, окремих українських голосів у Gemini немає. TTS іде окремим запитом на кожну репліку бота.
- **Моделі.** `gemini-flash-latest` для чату, `gemini-pro-latest` для коду, `gemini-embedding-001` для ембедингів — перевірено через ListModels цим ключем. Це алиаси, вони самі переїжджають на нові версії.
- **Темп.** `cooldown: 1000` у кожному профілі. Ліміт запитів на цьому ключі зараз не тисне, тому пауза мінімальна; ознака, що вперлися — 429 у консолі, тоді піднімати cooldown. `!goal` заблокований не через ліміти, а щоб бот не ставив собі завдання сам і поведінка на етапі 1 лишалася передбачуваною.
- **Ключ.** `mindcraft/keys.json` генерується скриптом, у git не потрапляє (`.gitignore` тут і в `mindcraft/.gitignore`). Не копіювати ключ у профілі чи в `settings.js`.
- **Пастка з перевіркою ключа.** У `lumi/.env` після ключа стоїть інлайн-коментар, і перша версія скрипта тягнула його разом з ключем — виходило 83 символи замість 39. Перевірка через `?key=...` в URL цього не ловить: `#` з коментаря curl трактує як початок фрагмента і відрізає хвіст, тому запит проходить. Mindcraft шле ключ заголовком `x-goog-api-key`, де хвіст нікуди не дінеться, і кожен хід бота падає в `400 API_KEY_INVALID`. Тому `deploy.sh` тепер зрізає коментар, звіряє формат `AIza` + 35 символів і робить контрольний `generateContent` саме заголовком.

## Порядок роботи з конфігами

Редагувати тільки `config/`, потім `./scripts/deploy.sh`. `mindcraft/` і `server/` — це вивід, вони в `.gitignore` і будь-яка ручна правка там зникне при наступному деплої.
