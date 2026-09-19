# Запуск

## 1. Сервер — термінал 1

```
~/development/minecraft-ai-bots/scripts/start-server.sh
```

Чекати рядок:

```
Done (9.747s)! For help, type "help"
```

## 2. Боти — термінал 2

Усі троє одним процесом:

```
~/development/minecraft-ai-bots/scripts/start-bots.sh
```

Чекати рядки `Porter logged in!`, `Miner logged in!`, `Guard logged in!`.

Склад рою — у `config/roster.json` (скільки ботів якої ролі); після правки зробити `./scripts/deploy.sh`.

Або кожен бот окремо, своїм терміналом — тоді будь-якого можна перезапустити, не чіпаючи інших:

```
~/development/minecraft-ai-bots/scripts/start-porter.sh
~/development/minecraft-ai-bots/scripts/start-miner.sh
~/development/minecraft-ai-bots/scripts/start-guard.sh      # або з номером копії: start-guard.sh 2
```

Важливо: при окремому запуску кожен бот вважає, що він на сервері сам, і тоді **всі троє відповідають на кожне повідомлення в загальному чаті**. Пиши через `/msg`, як і раніше.

## 3. Гра

1. Minecraft.app → **Play** на інсталяції `1.21.6`
2. **Multiplayer** → **Direct Connection**
3. `127.0.0.1:25565` → **Join Server**

## 4. Команди ботам

Тільки через `/msg`, у загальному чаті вони не чують:

```
/msg Porter йди за мною
/msg Porter принеси 10 дуба
/msg Miner принеси 5 заліза
```

## 5. Зупинка

- термінал 1: написати `stop`
- термінал 2: `Ctrl+C`

---

Якщо щось не запускається — таблиця симптомів у [docs/runbook.md](docs/runbook.md), розділ F.
