# Ранбук

Коротко: що виконувати і в якому порядку. Пояснення «чому саме так» — у [step1-instructions.md](step1-instructions.md).

Скорочення: `P` = `~/development/minecraft-ai-bots`.

---

## A. Разова підготовка

Виконується один раз на цій машині. Усі три зроблені — лишилося дописати `~/.zshrc` нижче.

| # | Команда | Стан |
|---|---------|------|
| A1 | `nvm install 22 && cd $P/mindcraft && nvm use && npm install` | зроблено |
| A2 | `brew install openjdk@21` | зроблено (21.0.12.1) |
| A3 | `cd $P && ./scripts/fetch-server.sh` | зроблено (Paper 1.21.6 build 48) |
| A4 | інсталяція клієнта 1.21.6 в лаунчері (див. нижче) | **треба зробити** |

Java 21 з homebrew — keg-only: вона не підхоплюється системним `java` і `/usr/libexec/java_home -v 21` її не бачить (поверне стару Corretto 11). Дописати в `~/.zshrc`:

```
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
export PATH="$JAVA_HOME/bin:$PATH"
```

Перевірка: `java -version` → `21.x`, `node -v` у `$P/mindcraft` після `nvm use` → `v22.x`.

### A4. Клієнт 1.21.6

Офіційний лаунчер стоїть (`/Applications/Minecraft.app`), але встановлені в ньому версії — 26.x. Такий клієнт до нашого сервера не підключиться: буде `Outdated server` або `Outdated client`. Версія клієнта мусить збігатися з `minecraft_version` у `config/settings.js`, тобто рівно `1.21.6`.

1. Minecraft.app → вкладка **Java Edition**
2. **Installations** → **New installation**
3. **Version:** `release 1.21.6` → **Create**
4. **Play** на цій інсталяції — лаунчер докачає клієнт

Робиться один раз. Далі щоразу запускати гру саме з цієї інсталяції, а не з 26.x.

---

## B. Перший запуск сервера

Один раз, бо сервер генерує світ і перезаписує `server.properties`.

```
# 1. згенерувати світ
cd ~/development/minecraft-ai-bots/server
java -Xms2G -Xmx4G -jar paper.jar nogui
#    чекати рядок "Done (...)! For help, type "help""
#    ввести: stop

# 2. накотити наші налаштування поверх згенерованих
cd ~/development/minecraft-ai-bots && ./scripts/deploy.sh

# 3. підняти вже як слід
cd server && java -Xms2G -Xmx4G -jar paper.jar nogui
```

Перевірка: `lsof -i :25565` показує java.

---

## C. Щоденний запуск

Два термінали, по одній команді в кожному. Обидва скрипти самі підставляють Java 21 і Node 22, тому ні `export`, ні `nvm use` вручну не треба, і з якої папки запускати — теж байдуже.

**Термінал 1 — сервер:**
```
~/development/minecraft-ai-bots/scripts/start-server.sh
```
Чекати рядок `Done (...)! For help, type "help"`.

**Термінал 2 — боти:**
```
~/development/minecraft-ai-bots/scripts/start-bots.sh
```

### Скільки ботів кожної ролі — рій

Кількість задається в [../config/roster.json](../config/roster.json):

```json
{
    "porter": 1,
    "miner": 2,
    "guard": 3
}
```

Далі `./scripts/deploy.sh` — він згенерує профілі з унікальними іменами (`Miner1`, `Miner2`, `Guard1`, `Guard2`, `Guard3`) і пропише їх у `settings.js`. Роль з кількістю 1 лишається без цифри (`Porter`), з кількістю 0 не запускається зовсім.

Імена мусять бути унікальні, бо це нікнейми гравців на сервері — двох `Guard` Minecraft не пустить. Промпт ролі спільний для всіх копій, у ньому ім'я підставляється через `$NAME`.

Після зміни реєстру `start-bots.sh` підніме рівно той склад, що в `roster.json`.

Ціна: кожен бот — це окремий потік запитів до Gemini. Ліміт на цьому ключі зараз не тисне, тож обмеження радше практичне — більше ботів означає більше шуму в чаті й більше плутанини, хто що робить. Якщо все ж пішли `429`, піднімай `cooldown` у профілях або зменшуй склад.

Альтернатива — кожен бот окремим процесом і окремим терміналом:
```
./scripts/start-porter.sh    # mindserver :8130
./scripts/start-miner.sh     # Miner   -> :8140
./scripts/start-guard.sh 2   # Guard2  -> :8151
./scripts/start-crafter.sh   # Crafter -> :8160
./scripts/start-scout.sh     # Scout   -> :8170
```
Це обгортки над `start-bot.sh`, яка тримає всю логіку. Номер копії — аргументом (`start-guard.sh 2`) або злитно (`start-bot.sh guard2`). Порти рознесені по ролях: porter від 8130, miner від 8140, guard від 8150, далі +1 на кожну копію.
Так можна перезапускати одного бота, не гасячи решту, і тримати логи роздільно. Розплата: у кожного свій mindserver, тому бот не бачить інших і вважає, що він на сервері сам — і тоді всі відповідають на кожне повідомлення в загальному чаті, **включно зі службовими репліками інших ботів**. Це перевірено на практиці: Scout відповідав на рядок, який у чат написав Crafter. Лік — вписати свій нік у `only_chat_with` у `config/settings.js`, тоді боти слухають тільки тебе. Через `/msg` поводяться так само, як і при спільному запуску.
Або `start-bots.sh --log` — тоді вивід дублюється в `mindcraft/run.log`, з якого рахується кількість запитів до Gemini (розділ E).

Скрипти падають з поясненням замість того, щоб мовчки не працювати: `start-server.sh` перевіряє наявність jar і чи не зайнятий порт 25565, `start-bots.sh` — версію Node, наявність `node_modules` і чи справді хтось слухає 25565.

**Аліаси**, якщо набридне повний шлях — у `~/.zshrc`:
```
alias mc-server='~/development/minecraft-ai-bots/scripts/start-server.sh'
alias mc-bots='~/development/minecraft-ai-bots/scripts/start-bots.sh'
alias mc-porter='~/development/minecraft-ai-bots/scripts/start-porter.sh'
alias mc-miner='~/development/minecraft-ai-bots/scripts/start-miner.sh'
alias mc-guard='~/development/minecraft-ai-bots/scripts/start-guard.sh'
```

**Термінал 3 не потрібен — далі гра:**

1. Minecraft.app → **Play** на інсталяції `1.21.6` (не на 26.x, інакше `Outdated server`)
2. **Multiplayer** → **Direct Connection**
3. Адреса: `127.0.0.1:25565` → **Join Server**

Нік буде той, під яким ти залогінений у лаунчері. Своя ліцензія не обовʼязкова для входу на цей сервер (`online-mode=false`), але лаунчер усе одно вимагає акаунт Microsoft.

Сервер можна не тримати відкритим у грі, щоб зайти: порядок такий — сервер, боти, потім клієнт. Але боти не зайдуть, поки немає сервера.

Перевірка: у грі `/list` → чотири гравці (ти, Porter, Miner, Guard), кожен бот привітався в чаті.

Зупинка: `stop` у терміналі сервера, `Ctrl+C` у терміналі ботів.

## D. Після зміни конфігів

Редагується **тільки** `$P/config/`. Потім:

```
cd ~/development/minecraft-ai-bots && ./scripts/deploy.sh
```

Далі перезапустити те, що змінилося:

| Що змінив | Що перезапустити |
|-----------|------------------|
| `config/profiles/*.json` | тільки бот-процес (`Ctrl+C`, `node main.js`) |
| `config/roster.json` | тільки бот-процес |
| `config/settings.js` | тільки бот-процес |
| `config/server.properties` | сервер (`stop`, запустити знову) |
| `config/patches/`, `config/npm-pins.txt` | `cd mindcraft && nvm use && npm install` |

Правки безпосередньо в `mindcraft/` і `server/` зникають при наступному деплої.

---

## E. Тести етапу 1

Команди боту йдуть через `/msg`, **не** в загальний чат — коли ботів більше одного, загальний чат вони ігнорують.

```
/msg Porter йди за мною
/msg Porter принеси 10 дуба
/msg Miner принеси 5 заліза
```

Guard команд не потребує: дочекатися ночі й підпустити зомбі до себе.

| # | Критерій приймання |
|---|--------------------|
| 1 | Porter іде слідом, тримається 3-5 блоків |
| 2 | у твоєму інвентарі 10 колод, Porter повернувся ближче ніж на 3 блоки |
| 3 | у тебе злитки заліза; піч Miner зробив сам, якщо її не було |
| 4 | Guard убив зомбі без команди і не відійшов далі 6 блоків |

Результати записати в `docs/test-log.md`. Перевірки ролей етапу 2 — у [step2-instructions.md](step2-instructions.md). Порахувати запити до Gemini:

```
./scripts/start-bots.sh --log
grep -c 'Awaiting Google API response' mindcraft/run.log
```

---

## F. Якщо щось пішло не так

| Симптом | Причина | Дія |
|---------|---------|-----|
| `Could not locate the bindings file`, `NODE_MODULE_VERSION` | Node 25 замість 22 — запущено `node main.js` напряму, повз скрипт | `./scripts/start-bots.sh` |
| `Minecraft 1.19 requires running the server with Java 17 or above` | Java 11 замість 21. Версія `1.19` у тексті захардкоджена в перевірці Paper і до нашої версії стосунку не має — jar правильний | виконати обидва `export` з розділу A, звірити `java -version` |
| `UnsupportedClassVersionError` | те саме | те саме |
| `Unable to access jarfile paper.jar` | jar не скачаний | `./scripts/fetch-server.sh` |
| Боти не заходять, `ECONNREFUSED` | сервер не піднятий або інший порт | перевірити `lsof -i :25565` |
| Боти заходять і одразу вилітають | розбіжність версій | `minecraft_version` у `config/settings.js` має збігатися з версією сервера |
| `Outdated server` / `Outdated client` при вході в гру | запущена інсталяція 26.x замість 1.21.6 | у лаунчері вибрати інсталяцію `1.21.6`, див. A4 |
| `Connection refused` у клієнті | сервер не піднятий | `./scripts/start-server.sh` |
| Бот відповідає словами, але нічого не робить | Flash не влучає в синтаксис команд | підняти `model` профілю на `gemini-pro-latest` |
| `400 API_KEY_INVALID`, `Error with embedding model` | зіпсований ключ у `mindcraft/keys.json` | `./scripts/deploy.sh` — він тепер перевіряє довжину ключа і стукає в API, і сам скаже, якщо ключ не той |
| `429` у консолі ботів | вперлися в ліміт запитів на хвилину | підняти `cooldown` у профілях (зараз 1000) або зменшити склад рою |
| Боти не реагують на чат | ботів більше одного, загальний чат ігнорується | писати через `/msg <імʼя>` |
| Боти перемовляються між собою і палять запити | роздільний запуск: кожен вважає, що він сам, і ловить репліки інших з загального чату | вписати свій нік у `only_chat_with` або запускати всіх одним `start-bots.sh` |
| `mindserver port ... is taken by something else` | порт зайняв сторонній процес, скрипт називає його pid і команду | запустити з іншим портом: `MINDSERVER_PORT_OVERRIDE=8140 ./scripts/start-miner.sh` |
| Голоси ботів накладаються | кожен бот - окремий процес зі своєю чергою озвучування, спільної немає | лишити `speak_model` тільки в одного бота, решті прибрати |
| Боти мовчать, хоча `speak: true` | TTS-модель не відповідає | подивитись помилку в консолі; як обхід - прибрати `speak_model` з профілів, тоді читатиме системний голос macOS |
| Сервер стер налаштування | перший запуск перезаписав `server.properties` | `./scripts/deploy.sh` і перезапустити |
