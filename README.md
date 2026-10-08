<div align="right">
  <a href="README.md">🇪🇸 Español</a> |
  <a href="README.en.md">🇬🇧 English</a>
</div>

# speckit-auto-agents

Un pequeño conjunto de definiciones de subagentes de [Claude Code](https://claude.com/claude-code) que ejecutan skills de [Spec-Kit](https://github.com/github/spec-kit) en un ciclo automatizado, siguiendo el **Desarrollo Guiado por Especificaciones (SDD)**. Un script CLI, `add-agents`, copia los agentes que necesites en cualquier proyecto.

> **Nota:** Este proyecto está hecho completamente con *vibecoding*. Lee los prompts de los agentes y los scripts antes de confiarles tu código.

## Qué incluye

```
.
├── add-agents      # CLI: copia los markdown de agentes en un proyecto
├── install.sh      # instala add-agents + archivos de agentes, verifica Spec-Kit
└── agents/
    ├── coordinator.md      # orquestador, el único agente que habla con el usuario
    ├── planner.md          # specify → plan → tasks (+ checklists)
    ├── developer.md        # implementa tasks.md
    ├── verifier.md         # analyze + converge, nunca corrige
    ├── bug-fixer.md        # assess → fix → test de un bug
    ├── idea-assessor.md    # intake → research → define → shape → decide
    └── AGENTS.md           # reglas comunes: capas de artefactos, formato de respuesta, skills faltantes
```

## Los agentes

| Agente | Rol | Skills de Spec-Kit |
|--------|-----|--------------------|
| `coordinator` | Enruta el trabajo y gestiona la interacción con el usuario. Nunca escribe código, planes ni informes. | `speckit-constitution`, `speckit-clarify` |
| `planner` | Escribe `spec.md`, `plan.md`, `tasks.md` y checklists en `specs/<feature>/`. | `speckit-specify`, `speckit-plan`, `speckit-tasks`, `speckit-checklist` |
| `developer` | Implementa tareas, ejecuta pruebas y hace commits en la rama de la feature. | `speckit-implement` |
| `verifier` | Juzga artefactos y código. Solo lectura sobre el código fuente. | `speckit-analyze`, `speckit-converge` |
| `bug-fixer` | Una etapa por llamada, el estado se guarda en `.specify/bugs/<slug>/`. | `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test` |
| `idea-assessor` | Una etapa por llamada, el estado se guarda en `.specify/assessments/<slug>/`. | `speckit-assess-intake`, `-research`, `-define`, `-shape`, `-decide` |

Cada agente tiene permisos acotados (herramientas, rutas escribibles) y responde con un bloque `STATUS` fijo, así el coordinador lee poco y su contexto se mantiene pequeño.

Las reglas comunes viven en `AGENTS.md` (instalado en la raíz del proyecto) en lugar de repetirse en cada agente:

- **Capas de artefactos.** constitution → spec → plan → tasks. Cada archivo contiene solo lo nuevo de su nivel y referencia al nivel superior por ID (`FR-003`, `constitution §Testing`) en vez de repetirlo. `tasks.md` es solo el checklist.
- **Respuestas compactas.** Los agentes responden solo con el bloque `STATUS`: rutas e IDs, sin prosa.
- **Skills faltantes.** Los agentes nunca improvisan una skill que no tienen; devuelven `SKILL_REQUEST`.

## Flujos de trabajo

El `coordinator` elige uno según tu solicitud.

### Ciclo SDD (nueva feature)

```
Definir:
planner: specify
   └─ [NEEDS CLARIFICATION]? → coordinator: aclara con el usuario
planner: plan → tasks
   └─ se detiene: revisas spec/plan/tasks y luego pides implementar

Implementar (a petición):
verifier: analyze      ── ¿CRITICAL? → de vuelta al planner
developer: fase 1      ── una llamada por fase, sin pausa
developer: fase 2
...
verifier: converge     ── Converged → listo
                       └─ hallazgos de código → developer (pausa) → converge
                       └─ hallazgos de spec/plan/tasks → planner → developer
```

El ciclo se detiene cuando `tasks.md` está escrito, para que revises todos los artefactos antes de escribir código. La implementación ejecuta una fase de `tasks.md` por llamada al developer, una tras otra y sin pausas. Cada llamada al developer tiene su propio contexto limpio, así el coordinador solo acumula los bloques `STATUS` cortos. Antes de cada fase reconstruye su estado desde las casillas de `tasks.md`, así la compactación automática puede ocurrir en cualquier momento sin perder nada. Para compactar antes, baja el umbral en el `.claude/settings.json` de tu proyecto: `{ "env": { "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50" } }`. Se detiene tras 5 rondas de converge sin progreso y escala a ti.

### Ciclo de bugs

`assess → fix → test`, una llamada a `bug-fixer` por etapa. El veredicto es `verified`, `partial` o `failed`. `partial` reintenta fix/test, `failed` vuelve a evaluar. Máximo 2 reintentos, luego escala.

### Ciclo de evaluación (evaluación de ideas)

`intake → research → define → shape → decide`, que termina en `go`, `needs-clarification` o `kill`. Un `go` solo recomienda: tú decides si construir, y el ciclo SDD parte desde `decision.md`.

## Requisitos

- [Claude Code](https://claude.com/claude-code)
- [Spec-Kit](https://github.com/github/spec-kit) (CLI `specify`), instalado con `uv tool install specify-cli`
- Las skills de Spec-Kit que referencian los agentes, instaladas en el proyecto destino (los agentes se detienen con un `SKILL_REQUEST` si falta una, no improvisan)
- Bash

## Instalación

Desde la raíz del repositorio:

```bash
./install.sh
```

Hace lo siguiente:

1. Valida que todos los archivos existan, no estén vacíos, y que los archivos de agentes empiecen con frontmatter.
2. Revisa `add-agents` en busca de errores de sintaxis y que su `AGENTS_SRC_DIR` coincida con la ubicación de instalación.
3. Copia `add-agents` a `~/.local/bin/` y los markdown de agentes a `~/.local/share/speckit-agents/`.
4. Avisa si `~/.local/bin` no está en tu `PATH`.
5. Verifica que exista `specify`. Si falta y existe `uv`, ofrece instalarlo.

## Uso

Ejecútalo dentro del proyecto que quieres equipar:

```bash
add-agents [-d DIR] [-f] <agent>...
```

| Opción | Copia |
|--------|-------|
| `sdd` | `coordinator`, `planner`, `developer`, `verifier` |
| `bug-fixer` | `bug-fixer` |
| `assessor` | `idea-assessor` |

| Flag | Significado |
|------|-------------|
| `-d DIR` | Directorio del proyecto destino (por defecto: el directorio actual) |
| `-f` | Sobrescribe agentes que ya existen |
| `-h` | Muestra la ayuda |

### Ejemplos

```bash
add-agents sdd                       # agentes del ciclo SDD en el proyecto actual
add-agents sdd bug-fixer assessor    # todo
add-agents -d ~/code/my-app sdd      # otro directorio
add-agents -f sdd                    # actualiza agentes existentes
```

Luego inicia Claude Code en el proyecto y habla con el `coordinator` (p. ej. `claude --agent coordinator`, o pídele a Claude que lo use).

> `bug-fixer` y `assessor` los invoca el `coordinator`. Si quieres los ciclos de bugs o de evaluación, instala también `sdd`.

## Cómo funciona `add-agents`

1. **Parseo de argumentos.** `getopts` maneja `-d`, `-f`, `-h`. Se requiere al menos una opción de agente.
2. **Validación.** El directorio del proyecto y el directorio fuente (`~/.local/share/speckit-agents`) deben existir. Las opciones desconocidas fallan antes de escribir nada.
3. **Mapeo de opciones a archivos.** `sdd`, `bug-fixer` y `assessor` se expanden en listas de archivos markdown. Se verifica que cada archivo fuente exista.
4. **Elección del destino.**
   - Existe `<project>/.claude/` → `.claude/agents/`
   - si no, existe `<project>/.agents/` → `.agents/agents/`
   - si no, avisa y pregunta si crear `.claude/`. Cualquier respuesta distinta de sí aborta sin copiar nada.
5. **Copia.** Los archivos existentes se omiten salvo con `-f`. Los duplicados (un agente pedido dos veces) se copian una sola vez.
6. **Reglas comunes.** Crea `<proyecto>/AGENTS.md`, o añade las reglas a uno existente entre los marcadores `<!-- speckit-agents:start/end -->`. Con `-f` solo se actualiza ese bloque; el resto del archivo se conserva.
7. **Reporte.** Lista los archivos omitidos, los copiados y el destino.

## Personalización

Edita los archivos en `agents/`, luego ejecuta `./install.sh` de nuevo y `add-agents -f ...` en tus proyectos. Si cambias la ruta de instalación, actualiza `AGENTS_SRC_DIR` en `add-agents` y `AGENTS_DEST_DIR` en `install.sh`. Deben coincidir, y `install.sh` lo verifica.
