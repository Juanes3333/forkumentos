---
description: Capas, fronteras de feature, estado con Riverpod y rendimiento al tocar código de lib/
trigger: glob
globs: "lib/**/*.dart"
paths:
  - "lib/**/*.dart"
---

# Arquitectura (lib/)

**Capas:** `app` → `routing` → `features` → `shared` → `core`. `core` no importa nada de las demás.
Detalle y acoplamiento real existente: `.agents/AGENTS.md` §3.

- **No añadas imports entre features.** Si dos features necesitan hablar, el contrato va en
  `shared/` o la composición en `lib/routing/` (como `ExportPlaceholder`, que `routing` construye).
  Los acoplamientos existentes (`mapping`→`template`/`datasource`, `preview`→varias) son deuda.
- ¿Dónde va una clase? Una feature → su `domain/` o `data/`. Dos o más → `shared/`. Infraestructura
  sin significado de negocio → `core/`. Si nada encaja sin violar capas, **pregunta al usuario**.
- `domain/` no importa Flutter. La lógica de negocio no vive en widgets ni en `lib/app/`.

**Estado (Riverpod):**
- Toda operación de negocio es un método de un `Notifier`/`AsyncNotifier`, no una función suelta
  llamada desde un widget. `setState` solo para estado puramente visual (hover, animación, scroll).
- Los providers nunca dependen de `BuildContext`. Los valores derivados son `Provider`s que
  observan el origen; no se guardan como campo de un notifier ni se calculan dentro de `build()`.
- Los ajustes se consumen solo vía `lib/shared/providers/`. Un ajuste nuevo = esquema +
  persistencia + provider + UI en el mismo commit; se persiste al instante.
- Hay un único proyecto activo o ninguno; abrir y cerrar son atómicos (se limpian los estados que
  dependen de él).

**Rendimiento:** nada de I/O síncrono en el hilo principal; trabajo pesado (DOCX/XLSX grandes) con
`Isolate`/`compute`; listas largas con `ListView.builder`; cancela trabajo en `ref.onDispose`.
Exportar es un `Command` cancelable (`lib/core/commands/`) que reporta progreso y no deja
archivos parciales al cancelar o fallar.

**Nombres:** archivos `snake_case` según su clase principal; modelos sin sufijo técnico
(`Project`, no `ProjectModel`); sin `Manager`/`Helper`/`Util`; providers `[concepto]Provider`.
