# hyprmon — Design Spec

**Date:** 2026-05-15
**Owner:** Felipe (@pipe0919)
**Status:** Approved (pending written-spec review)

## 1. Resumen

`hyprmon` es un widget de monitoreo de sistema para macOS con estética estilo Hyprland/rice. Es una app SwiftUI nativa que dibuja un panel flotante a nivel de escritorio (bajo las ventanas, sobre el wallpaper) mostrando en tiempo real: CPU, RAM, batería, top-5 procesos por CPU, y el uso acumulado de Claude Code dentro de la ventana rolling de 5 horas y la ventana semanal del plan del usuario.

El proyecto será open-source en `github.com/pipe0919/hyprmon` bajo licencia Apache 2.0 e instalable vía Homebrew tap (`brew install pipe0919/tap/hyprmon`).

## 2. Objetivos y no-objetivos

### Objetivos

- Mostrar 6 métricas en vivo en un panel persistente, no intrusivo, con estética dark glass / bento.
- Latencia visual ≤ 1 segundo para métricas de sistema.
- No robar foco al usuario nunca; no aparecer en Dock ni en Cmd-Tab.
- Configurable por archivo TOML editable, con reload en vivo.
- Instalable en cualquier Mac (Apple Silicon o Intel) con un solo comando de Homebrew.
- Construible y empaquetable sin Xcode, solo con `swiftc` y un `build.sh` (mismo flujo que el proyecto `DiskCleaner` del autor).

### No-objetivos (YAGNI)

- Gráficas históricas / sparklines / time-series.
- Notificaciones o alertas por umbral.
- Ventana de Preferences nativa SwiftUI (la config vive en TOML).
- Múltiples temas o personalización profunda más allá de accent color + opacity.
- Métricas adicionales (GPU, red, disco, temperaturas) — posible futuro, no v1.
- Soporte activamente testeado en Intel Mac (el universal binary debe funcionar, pero el desarrollo se prueba en Apple Silicon).
- Code signing notarizado con Apple Developer Program ($99/año) — la distribución vía Homebrew se hace ad-hoc-signed; usuarios que descarguen .dmg directo verán el aviso de Gatekeeper la primera vez.

## 3. Arquitectura

### 3.1 Stack y proceso

- **Lenguaje:** Swift (SwiftUI + AppKit + IOKit + Darwin libproc).
- **Build:** `swiftc` directo, sin Xcode ni Swift Package Manager para la app principal. Un `build.sh` que ensambla `Hyprmon.app` con `Info.plist`, ícono, y binario universal (`-target arm64-apple-macos13.0` y `-target x86_64-apple-macos13.0`, luego `lipo -create`).
- **Mínimo:** macOS 13 (Ventura). Justificación: APIs de `Material` modernas y `Observation` framework.
- **Empaquetado:** `Hyprmon.app/Contents/MacOS/hyprmon` (binario), `Info.plist` con `LSUIElement = true` y `CFBundleIdentifier = com.pipe0919.hyprmon`.

### 3.2 Ventana

- Una sola `NSPanel` (no `NSWindow`) construida en `AppKit` para tener control fino sobre nivel y comportamiento.
- `level = .desktop` (constante `kCGDesktopWindowLevel`).
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` → aparece en todos los Spaces, no se mueve con Mission Control, no entra en Cmd-Tab.
- `styleMask = [.borderless, .nonactivatingPanel]`.
- `becomesKeyOnlyIfNeeded = true`, `hidesOnDeactivate = false`.
- `ignoresMouseEvents = true` (el widget es display-only — para abrir Activity Monitor o mover el panel, el usuario edita TOML o usa la menubar app si se añade en el futuro).
- `backgroundColor = .clear`; el fondo lo provee un `NSVisualEffectView` con material `.underWindowBackground`.

### 3.3 Sampling loop

- Un actor `SystemSampler` que centraliza la lectura cada 1000 ms (configurable):
  - `CPUSampler`, `MemorySampler`, `BatterySampler`, `ProcessSampler` corren en serie dentro del tick — operaciones baratas, no hace falta paralelizar.
- Un actor `ClaudeUsageReader` independiente que muestrea cada 30 000 ms (más caro: implica leer y parsear archivos JSONL grandes).
- Ambos actores publican su estado vía `@Observable` o `Published`, y la vista SwiftUI reacciona.

### 3.4 Arranque

- `hyprmon` ejecutable acepta flags:
  - `--install-agent` → crea `~/Library/LaunchAgents/com.pipe0919.hyprmon.plist` apuntando al binario y lo carga con `launchctl bootstrap gui/$UID`.
  - `--uninstall-agent` → revierte.
  - `--config <path>` → fuerza ruta de config alternativa (útil para tests).
  - `--version` → imprime versión y exit 0.
  - Sin flags → corre el widget en foreground.

## 4. Fuentes de datos

### 4.1 CPU

API: `host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, ...)`.

Estrategia: leer ticks `user + system + nice` y `idle` por cada core en dos muestras consecutivas; el % CPU global es `(usedΔ) / (usedΔ + idleΔ)`. Cachear la muestra anterior entre ticks.

### 4.2 RAM

API: `host_statistics64(mach_host_self(), HOST_VM_INFO64, ...)`.

Estrategia: `usado = (wired_count + active_count + compressor_page_count) * page_size`. `total` se obtiene una sola vez con `sysctlbyname("hw.memsize")`. `% = usado / total`.

### 4.3 Batería

Framework: `IOKit` (`IOPowerSources`).

Estrategia:
- `IOPSCopyPowerSourcesInfo()` → blob.
- `IOPSCopyPowerSourcesList(blob)` → array.
- Por cada fuente, `IOPSGetPowerSourceDescription(blob, src)` → dict con `kIOPSCurrentCapacityKey` (%), `kIOPSIsChargingKey`, `kIOPSPowerSourceStateKey` (AC / Battery).

En desktops sin batería la sección se oculta automáticamente.

### 4.4 Top procesos

API: `proc_listpids(PROC_ALL_PIDS, ...)` + `proc_pid_taskinfo(pid, ...)` (libproc) + `proc_pidpath` para nombre.

Estrategia:
- Listar todos los PIDs.
- Para cada uno, leer `pti_total_user + pti_total_system` (tiempo CPU acumulado en nanosegundos).
- Restar la muestra anterior por PID → CPU% en el intervalo.
- Agregar por nombre de ejecutable (varios procesos del mismo binario se suman).
- Ordenar desc, tomar top 5.
- `RAM` por proceso viene de `pti_resident_size`.

### 4.5 Claude usage

Fuente: archivos JSONL en `~/.claude/projects/**/*.jsonl`. Cada línea es un evento; los relevantes contienen `message.usage` con `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, y un `timestamp` ISO8601.

Estrategia:
- En cada tick (30 s), `FileManager` enumera archivos `.jsonl` modificados en los últimos 8 días (descartar viejos rápido).
- Cachear offset leído por archivo en memoria → solo leer las nuevas líneas (tail incremental). Reset del cache si el `mtime` retrocede o el archivo desaparece.
- Parsear cada línea como JSON; extraer `timestamp` y `usage`.
- Total tokens por línea: `input + output + cache_creation + cache_read` (mismo cálculo que `ccusage`).
- Mantener dos rolling buckets:
  - 5 h: descartar eventos con `timestamp < now - 5h`.
  - 7 d: descartar eventos con `timestamp < now - 7d`.
- `% = sum_tokens / plan_limit`.

Límites por plan (definidos en `PlanLimits.swift`, configurables vía TOML):
- `pro` → 5h: ~45k tokens, 7d: pendiente de definir (Anthropic no publica número fijo, se trata como soft).
- `max5` → 5h: ~220k, 7d: ~1.5M.
- `max20` → 5h: ~880k, 7d: ~6M.

(Estos números son aproximados basados en lo que reporta `ccusage` y se documentan como configurables; el usuario puede overridearlos en TOML si su experiencia real difiere.)

Si el plan es `pro`, `show_weekly = false` por default porque Anthropic no publica un cap semanal claro para Pro.

### 4.6 Reset time

- 5 h: el reset es rolling, no fijo — el panel muestra "resets in Xh Ym" calculado como (timestamp del evento más antiguo dentro de la ventana de 5h) + 5h − now.
- 7 d: mismo cálculo con 7d.

## 5. UI

### 5.1 Layout

Panel ancho 320 px, alto dinámico (~ 380 px con todos los módulos activos), posición top-right respetando la menubar (offset 12 px desde el borde derecho y desde la base de la menubar). La posición exacta es configurable en TOML (`corner = "top-right" | "top-left" | "bottom-right" | "bottom-left"`).

Secciones (de arriba a abajo). El borde y el header "HYPRMON" del mockup son ilustrativos: el panel real es un rectángulo redondeado sin titlebar, con un `SectionHeader` "HYPRMON" arriba en el mismo estilo que los demás headers de sección.



```
╭─ HYPRMON ───────────────────╮
│                              │
│  SYSTEM                      │
│  CPU  ████████░░░  42%       │
│  RAM  ██████░░░░░  68%       │
│  BAT  █████████░░  84% ⚡    │
│                              │
│  ─────────────────────       │
│  TOP PROCESSES               │
│  Xcode          18.2%        │
│  WindowServer    6.8%        │
│  Chrome          5.1%        │
│  kernel_task     3.9%        │
│  claude          2.4%        │
│                              │
│  ─────────────────────       │
│  CLAUDE                      │
│  5h   ████░░░░░░░  47%       │
│       resets in 2h 18m       │
│  7d   ██████░░░░░  61%       │
│       resets in 4d 09h       │
│                              │
╰──────────────────────────────╯
```

### 5.2 Estilo visual

- Fondo: `NSVisualEffectView` material `.underWindowBackground`, blending mode `.behindWindow`, state `.active`.
- Corner radius: 16.
- Padding interno: 16.
- Sin sombra agresiva (el material ya da profundidad).
- Sin titlebar.

### 5.3 Theme tokens (Theme.swift)

```
background      → Color.clear (lo da el material)
surface         → .white.opacity(0.04) para separadores y filas alt
fgPrimary       → .white.opacity(0.92)
fgMuted         → .white.opacity(0.55)
accent          → Color(hex: config.accent)  // default #7AA2F7
warn            → #E0AF68
danger          → #F7768E
ok              → #9ECE6A
trackBg         → .white.opacity(0.08)
```

### 5.4 MetricBar

Barra horizontal con corner radius 4, altura 6 px. Color del fill = heat-map:
- `value < 0.5` → `ok`
- `0.5 <= value < 0.8` → `warn`
- `value >= 0.8` → `danger`

Animación `.easeInOut(duration: 0.2)` al cambiar valor.

### 5.5 Tipografía

- Labels (`CPU`, `RAM`, etc): SF Pro Text, 11 pt, weight `.medium`, color `fgMuted`, tracking +0.5.
- Números: SF Mono, 12 pt, weight `.regular`, color `fgPrimary`, `.monospacedDigit()`.
- Sección headers (`SYSTEM`, `TOP PROCESSES`, `CLAUDE`): SF Pro Text, 10 pt, weight `.semibold`, color `fgMuted`, uppercase, tracking +1.

## 6. Configuración

### 6.1 Ubicación

`~/.config/hyprmon/config.toml` (XDG-style). Si no existe al primer arranque, se copia desde `examples/config.toml` embebido en el bundle.

### 6.2 Schema

```toml
# ~/.config/hyprmon/config.toml

corner       = "top-right"   # top-right | top-left | bottom-right | bottom-left
margin       = 12             # px desde el borde
opacity      = 0.85           # 0.0 - 1.0
accent       = "#7AA2F7"      # hex color
refresh_ms   = 1000           # intervalo de muestreo de sistema
claude_refresh_ms = 30000     # intervalo de re-cálculo de uso de Claude

[modules]
cpu       = true
ram       = true
battery   = true              # se ignora en desktops sin batería
processes = true
claude    = true

[processes]
count    = 5                  # cuántos mostrar
sort_by  = "cpu"              # cpu | ram

[claude]
plan         = "max20"        # pro | max5 | max20 | custom
show_5h      = true
show_weekly  = true

# Solo si plan = "custom":
[claude.limits]
window_5h_tokens   = 880000
window_weekly_tokens = 6000000
```

### 6.3 Reload en vivo

- `ConfigLoader` usa `FSEventStreamCreate` apuntando a `~/.config/hyprmon/`.
- Al detectar cambio en `config.toml`, recarga, valida, y si hay error de parseo mantiene la config anterior y loggea a `~/Library/Logs/hyprmon/hyprmon.log`.
- Cambios aplicables en vivo: opacity, accent, módulos visibles, refresh_ms, plan de Claude.
- Cambios que requieren restart: corner, margin (mover NSPanel en vivo es ruidoso visualmente — más simple pedir restart).

### 6.4 Parser TOML

TOML mínimo embebido (`TOMLParser.swift`, ~150 LOC) que soporta el subset que usamos: strings, ints, floats, bools, hex, tablas. No usamos dependencias externas para no complicar el build con SwiftPM.

## 7. Distribución

### 7.1 Repos

- `github.com/pipe0919/hyprmon` — código fuente, Apache 2.0, README, CHANGELOG.
- `github.com/pipe0919/homebrew-tap` — formula Homebrew.

### 7.2 Install path

```bash
brew install pipe0919/tap/hyprmon
hyprmon --install-agent    # opcional: arranque al login
open -a Hyprmon            # primera ejecución
```

### 7.3 CI/CD (GitHub Actions)

**`.github/workflows/ci.yml`** — corre en cada push a cualquier rama y en PRs:
- macOS 14 runner.
- `swift --version` (debe ser ≥ 5.9 → en macOS 14 runner default).
- `./build.sh` → produce `Hyprmon.app`.
- `swift test` → tests unitarios sobre lógica pura (Sampling, Claude parsing, Config).

**`.github/workflows/release.yml`** — corre cuando se hace push de un tag `v*`:
1. macOS 14 runner.
2. `./build.sh --universal` → `Hyprmon.app` con binario universal (arm64 + x86_64).
3. `codesign --sign - --deep Hyprmon.app` (ad-hoc signing, suficiente para Homebrew; sin hardened runtime porque eso requeriría notarización con Apple Developer Program).
4. `tar -czf hyprmon-${VERSION}.tar.gz Hyprmon.app`.
5. `shasum -a 256 hyprmon-${VERSION}.tar.gz` → captura sha.
6. `gh release create v${VERSION} hyprmon-${VERSION}.tar.gz --notes-file CHANGELOG-${VERSION}.md`.
7. Genera `Formula/hyprmon.rb` con el nuevo url y sha, y abre PR a `pipe0919/homebrew-tap`.

### 7.4 Formula Homebrew (ejemplo final)

```ruby
class Hyprmon < Formula
  desc "Hyprland-style system monitor widget for macOS (CPU/RAM/battery/processes/Claude usage)"
  homepage "https://github.com/pipe0919/hyprmon"
  url "https://github.com/pipe0919/hyprmon/releases/download/v0.1.0/hyprmon-0.1.0.tar.gz"
  sha256 "<sha>"
  license "Apache-2.0"

  depends_on macos: :ventura

  def install
    prefix.install "Hyprmon.app"
    bin.write_exec_script "#{prefix}/Hyprmon.app/Contents/MacOS/hyprmon"
  end

  def caveats
    <<~EOS
      To run on login:
        hyprmon --install-agent

      Configuration file:
        ~/.config/hyprmon/config.toml
    EOS
  end

  test do
    system "#{bin}/hyprmon", "--version"
  end
end
```

## 8. Estructura del repo

```
hyprmon/
├── Sources/
│   ├── HyprmonApp.swift              # @main, NSApp setup
│   ├── App/
│   │   ├── DesktopPanel.swift        # NSPanel desktop-level
│   │   └── LaunchAgent.swift         # install/uninstall agent
│   ├── Sampling/
│   │   ├── SystemSampler.swift       # actor 1Hz orquestador
│   │   ├── CPUSampler.swift
│   │   ├── MemorySampler.swift
│   │   ├── BatterySampler.swift
│   │   └── ProcessSampler.swift
│   ├── Claude/
│   │   ├── ClaudeUsageReader.swift   # tail + parse JSONL
│   │   ├── RollingWindow.swift       # buckets por timestamp
│   │   └── PlanLimits.swift          # pro / max5 / max20 / custom
│   ├── Config/
│   │   ├── Config.swift              # struct + defaults
│   │   ├── ConfigLoader.swift        # FSEvents + reload
│   │   └── TOMLParser.swift          # parser mínimo embebido
│   ├── Theme/
│   │   └── Theme.swift               # tokens semánticos
│   └── Views/
│       ├── ContentView.swift
│       ├── SectionHeader.swift
│       ├── MetricBar.swift
│       ├── ProcessTable.swift
│       └── ClaudeQuotaView.swift
├── Tests/                            # XCTest sobre lógica pura
│   ├── CPUSamplerTests.swift
│   ├── ClaudeUsageReaderTests.swift
│   ├── RollingWindowTests.swift
│   └── TOMLParserTests.swift
├── Resources/
│   ├── Info.plist
│   └── AppIcon.iconset/
├── Formula/
│   └── hyprmon.rb                    # se sincroniza a homebrew-tap en release
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── release.yml
├── examples/
│   └── config.toml                   # todas las opciones comentadas
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-05-15-hyprmon-design.md  # este documento
│       └── plans/                    # writing-plans dejará el plan aquí
├── build.sh                          # dev build local
├── Makefile                          # install / uninstall conveniences
├── README.md                         # demo GIF, install, config, screenshots
├── CONTRIBUTING.md
├── LICENSE                           # Apache 2.0
├── CHANGELOG.md
└── .gitignore
```

## 9. Testing

Tests unitarios cubren lógica pura, sin UI:

- **`CPUSamplerTests`**: feed muestras sintéticas de ticks, verificar % calculado.
- **`MemorySamplerTests`**: stub de `host_statistics64`, verificar agregación.
- **`ClaudeUsageReaderTests`**:
  - Fixture con varios `.jsonl` con eventos en distintos timestamps.
  - Verifica sumas para ventana 5h y 7d.
  - Verifica tail incremental (segunda llamada no relee).
- **`RollingWindowTests`**: añadir eventos con timestamps, avanzar tiempo, verificar pruning.
- **`TOMLParserTests`**: round-trip de `examples/config.toml` y casos edge (comentarios, escapes, hex en strings).

UI testing es manual:
- Arrancar el .app y verificar que el panel queda bajo ventanas y sobre el wallpaper.
- Generar carga (`yes > /dev/null &`) y ver CPU subir.
- Desconectar charger y ver batería cambiar de estado.
- Editar `config.toml` y ver opacity/accent cambiar sin reiniciar.

## 10. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| App no firmada → Gatekeeper bloquea | Homebrew bypassa el quarantine bit; usuarios que bajen .dmg directo verán instrucciones en README para right-click → Open. Codesign ad-hoc en el release. |
| `proc_listpids` requiere permisos elevados para procesos de otros usuarios | En práctica solo nos importan procesos del usuario actual; los que no podemos leer se ignoran sin error. |
| Formato del JSONL de Claude Code cambia | El parser es tolerante: si una línea no tiene `message.usage`, se ignora. Tests fixture documenta el formato esperado al momento de v1. |
| Límites de los planes de Anthropic cambian | Son configurables en TOML; el README documenta cómo overridarlos. |
| Reload de TOML con error de sintaxis | Mantiene la config anterior y loggea el error; no crashea. |
| Universal binary aumenta tamaño | Aceptable (~5-8 MB); Homebrew lo maneja sin problema. |
| Race conditions en sampling | Actor-based isolation en Swift; cada sampler tiene su propio estado, el orquestador agrega. |

## 11. Plan de versionado

- `v0.1.0` — MVP: las 6 métricas funcionando, panel a desktop level, TOML config, instalable vía Homebrew.
- `v0.2.0` — Posibles añadidos basados en feedback: posición arrastrable interactivamente, sparklines de CPU, GPU/red/disco.
- `v1.0.0` — Cuando esté estable, con ≥ 3 versiones menores acumuladas sin issues críticos abiertos.

## 12. Próximos pasos

1. Felipe revisa este spec.
2. Si aprobado → invocar `superpowers:writing-plans` para generar el plan de implementación step-by-step.
3. Implementación.
4. Crear los dos repos en GitHub y hacer push inicial.
5. Tag `v0.1.0` → CI publica release y Formula.
