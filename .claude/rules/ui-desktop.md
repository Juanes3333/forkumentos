---
description: Ergonomía de escritorio, tema y sistema de diseño al tocar pantallas, widgets o el workbench
trigger: glob
globs: "lib/features/*/presentation/**/*.dart, lib/routing/**/*.dart, lib/core/theme/*.dart, lib/shared/widgets/*.dart"
paths:
  - "lib/features/*/presentation/**/*.dart"
  - "lib/routing/**/*.dart"
  - "lib/core/theme/*.dart"
  - "lib/shared/widgets/*.dart"
---

# UI de escritorio (Flutter Windows)

Autoridad visual: `docs/DESIGN_SYSTEM.md`. Tokens en `lib/core/theme/` (`AppColors` es una
`ThemeExtension`). Modo **Operate**: densidad, consistencia y expectativas nativas de Windows por
encima de la expresividad. Material 3, nada de CSS/HTML.

- Pensado para pantalla grande, mouse y teclado: paneles redimensionables, atajos para las acciones
  principales, hover y tooltips. Prohibidos los patrones móviles (bottom sheets, drawers, swipe).
- Las operaciones largas (parseo, exportación) no bloquean la UI: progreso visible y cancelables.
- Errores: en lenguaje claro y con cómo resolverlos; los fallos de importación van en diálogo modal,
  no en una franja discreta. Acciones destructivas piden confirmación. Estados vacíos diseñados.
- Botones con verbos específicos en activa ("Importar datos", no "Enviar"). Textos en español.
- Contraste: usa `AppColors.onAccent` para texto/íconos sobre relleno de acento y
  `AppColors.warning` tal cual (ya cumple). "Auto-mapear" y "Exportar" son `FilledButton`.
- Reutiliza widgets de `lib/shared/widgets/` antes de crear otro; no añadas paquetes de UI que
  Material 3 ya cubre. Sin lógica de negocio en widgets ni providers de presentación: si falta un
  dato del dominio, documenta el contrato que necesitas y detente.
