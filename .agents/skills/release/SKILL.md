---
name: release
description: Procedimiento para publicar una versión de Forkumentos - subir la versión en todos los sitios, changelog, build, instalador Inno Setup y release de GitHub con el asset ForkumentosSetup_vX.Y.Z.exe que usa el auto-actualizador. Úsala cuando se pida una release o subir la versión.
---

# Release de Forkumentos

Sustituye `X.Y.Z` por la versión nueva y `N` por el build number (`pubspec.yaml` → `version:
X.Y.Z+N`). Confirma con el usuario la versión antes de empezar.

## 1. Estado limpio
- `git status`: nada ajeno a la release. `flutter analyze` y `flutter test` en verde.

## 2. Sincronizar la versión (los cuatro sitios)
1. `pubspec.yaml` → `version: X.Y.Z+N`
2. `lib/shared/widgets/about_forkumentos_dialog.dart` → `const String forkumentosVersion = 'X.Y.Z';`
3. `installer/Forkumentos.iss` → `#define MyAppVersion "X.Y.Z"` y
   `OutputBaseFilename=ForkumentosSetup_vX.Y.Z`
4. `CHANGELOG.md` (nueva sección `## X.Y.Z` con Added/Changed/Fixed) y `README.md` si menciona
   versión o funcionalidades nuevas.

Comprueba con `grep -rn "X.Y.Z" pubspec.yaml lib/shared/widgets/about_forkumentos_dialog.dart
installer/Forkumentos.iss CHANGELOG.md` que coinciden. El `.iss` **no** debe tener `skipifsilent`
en `[Run]` y sí `CloseApplications=yes` (el auto-actualizador usa `/SILENT`).

## 3. Compilar e instalar
```powershell
flutter build windows --release
```
Compila `installer/Forkumentos.iss` con Inno Setup (`ISCC.exe installer\Forkumentos.iss`). Debe
producir `installer/ForkumentosSetup_vX.Y.Z.exe`. Verifica que existe y que su versión es la
correcta.

## 4. Commit (solo si el usuario lo confirma)
`feat: <resumen> y release X.Y.Z` (o `fix:`), terminado con la línea de coautoría que corresponda.

## 5. Publicar (siempre con confirmación explícita del usuario)
```powershell
git tag vX.Y.Z ; git push origin main --tags
gh release create vX.Y.Z installer\ForkumentosSetup_vX.Y.Z.exe --title "Forkumentos X.Y.Z" --notes-file <notas>
```
El asset debe llamarse exactamente `ForkumentosSetup_vX.Y.Z.exe`: el auto-actualizador busca un
`.exe` en `releases/latest`. Tras publicar, comprueba con `gh release view vX.Y.Z --json assets`.

## 6. Limpieza
Borra de `installer/` los instaladores anteriores (siguen disponibles en GitHub Releases).
