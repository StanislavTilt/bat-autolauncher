# BatLauncher

Лёгкая обёртка для автозапуска нескольких ботов (или вообще любых `.bat`/`.cmd`)
при входе в Windows. Все батники из папки `bats\` стартуют параллельно,
без видимых окон, под одной иконкой в трее. Падение одного бата не ломает
запуск остальных.

A lightweight wrapper that auto-starts a bunch of bots (or any `.bat`/`.cmd`
scripts) on Windows logon. Everything in `bats\` runs in parallel, hidden,
under a single tray icon. One script crashing does not stop the others.

---

## RU

### Зачем

Когда хочется при каждом логине поднимать сразу несколько штук —
discord-бот, парсер, локальный API, что-то ещё — а городить службу,
шедулер или nssm под каждую мелочь лень.

### Что внутри

- `BatLauncherTray.exe` — приложение в трее с иконкой-роботом.
  Стартует при входе в Windows, обходит `bats\`, запускает каждый батник
  скрытым процессом, держит их в [Windows Job Object](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects),
  чтобы можно было прибить всю ветку разом.
- `launcher.bat` — собственно обходчик. Можно запустить руками для отладки
  (с видимым окном).
- `_run_one.bat` — внутренний раннер одного бата: вешает заголовок,
  редиректит stdout/stderr в отдельный лог, ловит код выхода.
- `launcher.vbs` — запасной запускатель без окна (если по какой-то
  причине exe не подходит).
- `install.bat` / `uninstall.bat` — прописывают или удаляют запись
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\BatLauncher`.
- `build.bat` + `TrayLauncher.cs` + `gen_icon.ps1` — исходник трей-приложения
  и сборка через системный `csc.exe` из .NET Framework 4.

### Установка

1. Положить папку в любое место (например, `Desktop\BatLauncher`).
2. Запустить `install.bat` — он впишет в реестр
   `HKCU\...\Run\BatLauncher` ссылку на `BatLauncherTray.exe`.
   Если exe ещё не собран, `install.bat` выберет ближайший вариант
   по приоритету `.exe` → `.vbs` → `.bat`.
3. Положить свои батники в `bats\`. Они будут запускаться при следующем
   входе в Windows.

Админских прав не нужно — запись только для текущего пользователя.

### Как использовать

Положить рабочий `.bat`/`.cmd` в `bats\`. На следующем логине он запустится
автоматически и будет работать в фоне, пока пользователь не выйдет из
Windows. В трее появится иконка с роботом — там же меню управления.

### Меню в трее

| Пункт | Что делает |
|---|---|
| Открыть папку логов | Открывает `logs\` в Explorer. То же по двойному клику. |
| Перезапустить ботов | Убивает текущее дерево процессов и запускает `launcher.bat` заново. |
| Остановить ботов | Убивает дерево, иконка остаётся. |
| Выход | Убивает дерево и выходит из tray. |

Job Object с флагом `KILL_ON_JOB_CLOSE` гарантирует, что даже если
exe убьют через диспетчер задач — все его потомки тоже умрут.

### Логи

```
logs\
  launcher.log          - главный лог: кого запустил, куда направил
  tray.log              - необработанные исключения трей-приложения
  <имя_бата>\
    <имя_бата>.log      - stdout+stderr одного бата + код выхода
```

Каждый лог ротируется: при превышении 1 МБ переименовывается в `.log.old`,
старый `.old` перезаписывается. Места не сжирает.

### Запуск без автостарта

Просто двойной клик по любому из:

- `launcher.bat` — увидишь окно консоли, удобно для отладки.
- `launcher.vbs` — без окна.
- `BatLauncherTray.exe` — с иконкой в трее.

### Сборка трей-приложения

`BatLauncherTray.exe` собирается из `TrayLauncher.cs` через
`csc.exe v4.0.30319` (входит в Windows 10/11). Иконка генерируется
скриптом `gen_icon.ps1` и зашивается в exe как managed-resource.

```
build.bat
```

Зависимостей кроме .NET Framework 4 и PowerShell нет.

### Удаление

```
uninstall.bat
```

Удаляет только запись из реестра. Файлы и логи остаются на диске —
можно стереть руками.

### Перенос в другую папку

После перемещения `BatLauncher\` запусти `install.bat` из нового места —
он перепишет ключ реестра на актуальный путь.

### Поиск проблем

**Окно cmd мелькает или сыпет ошибками на русских словах.**
Бат-файлы должны быть в UTF-8 с BOM и с переводами строк CRLF. Файлы из
этой папки уже такие. Если правишь в редакторе — следи за кодировкой.

**SmartScreen ругается на `BatLauncherTray.exe`.**
Exe не подписан. Правый клик по файлу, Свойства, внизу галка
«Разблокировать». Или используй `launcher.vbs` — VBScript не триггерит
SmartScreen.

**Один бат падает на старте — остальные не запускаются.**
Так не бывает. Цикл в `launcher.bat` идёт через все файлы независимо.
Если кажется, что не запустился — проверь `logs\<имя>\<имя>.log`.

**После «Выход» процессы продолжают жить.**
Проверь, что в реестре стоит именно `BatLauncherTray.exe`, а не старый
`launcher.bat` или `launcher.vbs` (они не управляют деревом процессов).
Проверяется командой:

```cmd
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v BatLauncher
```

**Бат с pause работает только видимо.**
В фоне `pause` не сработает — `_run_one.bat` подаёт ему `< nul`,
он считывает EOF и сразу идёт дальше. В видимом режиме всё нормально.

---

## EN

### Why

When every logon you want a handful of things running at once — a Discord
bot, a parser, a local API, whatever — and writing a Windows service,
scheduled task or nssm wrapper for each one is overkill.

### What is inside

- `BatLauncherTray.exe` — tray application with a small robot icon.
  Starts on logon, walks `bats\`, launches every script as a hidden child
  process, and parents them all into a [Windows Job Object](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects)
  so the whole tree can be torn down at once.
- `launcher.bat` — the actual walker. Can be run by hand for debugging
  (visible console).
- `_run_one.bat` — internal per-script runner: header, stdout+stderr
  redirected to a dedicated log, exit code recorded.
- `launcher.vbs` — fallback that runs `launcher.bat` with no window
  (for setups where the `.exe` is unavailable).
- `install.bat` / `uninstall.bat` — add or remove the
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\BatLauncher` value.
- `build.bat` + `TrayLauncher.cs` + `gen_icon.ps1` — source of the tray
  application and its build script (system `csc.exe` from .NET Framework 4).

### Installation

1. Drop the folder anywhere (for example, `Desktop\BatLauncher`).
2. Run `install.bat`. It writes a `HKCU\...\Run\BatLauncher` value pointing
   at `BatLauncherTray.exe`. If the exe is not built yet, `install.bat`
   picks the closest available variant in the order `.exe` → `.vbs` → `.bat`.
3. Drop your scripts into `bats\`. They will run on the next logon.

No administrator rights required — the entry is per-user.

### Usage

Place your `.bat`/`.cmd` into `bats\`. On the next logon it runs in the
background until the user logs off. A robot icon appears in the system
tray with the control menu.

### Tray menu

| Item | What it does |
|---|---|
| Open logs folder | Opens `logs\` in Explorer. Same as double-click on the tray icon. |
| Restart bots | Kills the current process tree and re-runs `launcher.bat`. |
| Stop bots | Kills the tree; the tray icon stays. |
| Exit | Kills the tree and unloads the tray app. |

The Job Object is created with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, so
even if the exe is killed from Task Manager, every descendant dies with it.

### Logs

```
logs\
  launcher.log          - main log: what was started, where
  tray.log              - unhandled exceptions from the tray app
  <script>\
    <script>.log        - stdout+stderr + exit code for one script
```

Each log rotates: once it exceeds 1 MB it is renamed to `.log.old`,
the previous `.old` is overwritten. Disk usage stays bounded.

### Run without autostart

Double-click any of:

- `launcher.bat` — visible console window, useful for debugging.
- `launcher.vbs` — no window.
- `BatLauncherTray.exe` — with the tray icon.

### Building the tray application

`BatLauncherTray.exe` is built from `TrayLauncher.cs` using
`csc.exe v4.0.30319` (shipped with Windows 10/11). The icon is generated
by `gen_icon.ps1` and embedded into the exe as a managed resource.

```
build.bat
```

No dependencies beyond .NET Framework 4 and PowerShell.

### Uninstall

```
uninstall.bat
```

Only removes the registry value. Files and logs stay on disk —
delete the folder manually if you want a clean wipe.

### Moving to a different folder

After moving `BatLauncher\` somewhere else, run `install.bat` from the new
location — it overwrites the registry value with the up-to-date path.

### Troubleshooting

**Console flashes or shows mojibake on Cyrillic.**
Batch files must be UTF-8 with BOM and CRLF line endings. The files in
this folder already are. Watch the encoding in your editor.

**SmartScreen complains about `BatLauncherTray.exe`.**
The exe is unsigned. Right-click, Properties, tick "Unblock" at the
bottom. Or use `launcher.vbs` — VBScript does not trigger SmartScreen.

**One script fails at startup and the rest do not run.**
That cannot happen. The loop in `launcher.bat` iterates over every file
independently. If something looks missing, check `logs\<name>\<name>.log`.

**After "Exit" the child processes keep running.**
Make sure the registry value points at `BatLauncherTray.exe`, not the old
`launcher.bat` / `launcher.vbs` (those do not own the process tree). Verify with:

```cmd
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v BatLauncher
```

**A script that uses `pause` only works in visible mode.**
In the background `pause` cannot work — `_run_one.bat` feeds it `< nul`,
it reads EOF and falls through immediately. In visible mode it behaves
normally.

---

## License / Лицензия

MIT.
