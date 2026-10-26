---
description: Convenciones de pruebas (unit, widget, fixtures en memoria) al crear o editar tests
trigger: glob
globs: "test/**/*.dart"
paths:
  - "test/**/*.dart"
---

# Pruebas

Línea base: `flutter test` = 581 en verde; `flutter analyze` sin avisos en tests también.

- `test/unit/**` sin Flutter; `test/widget/**` con `ProviderScope` y overrides inyectados en el
  `ProviderScope`; fakes compartidos en `test/support/fakes.dart`; `test/integration/` reservado a
  flujos críticos.
- Sin disco real, rutas de Windows ni red. Los DOCX/XLSX se **construyen en memoria** con
  `package:archive`; no versiones documentos binarios.
- Por capa: `core` y `domain` → entrada/salida pura; `data` → implementaciones en memoria;
  `presentation` → widget tests. Un test sin aserciones es peor que ninguno.
- Todo bug se reproduce primero con un test. Cambios de comportamiento llevan test.
- Strings con escapes → raw strings; líneas de máximo 80 caracteres (`very_good_analysis`).
