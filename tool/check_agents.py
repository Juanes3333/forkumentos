"""Comprueba que los subagentes de .claude/agents parsean y que sus skills resuelven.

ponytail: parseo manual en vez de pyyaml. El frontmatter es plano (`clave: valor` y una
lista de skills con guiones); no justifica una dependencia. Si algun dia usa YAML anidado,
cambia a pyyaml.
"""

import pathlib
import sys

SKILLS_DIR = pathlib.Path.home() / ".claude" / "skills"
REQUIRED = ("name", "description", "model")


def frontmatter(text: str) -> dict[str, object]:
    _, fm, _ = text.split("---\n", 2)
    meta: dict[str, object] = {}
    key = None
    for line in fm.splitlines():
        if line.startswith("  - ") and key:
            meta.setdefault(key, []).append(line[4:].strip())  # type: ignore[union-attr]
        elif ":" in line and not line.startswith(" "):
            key, _, value = line.partition(":")
            key = key.strip()
            meta[key] = value.strip() if value.strip() else []
    return meta


bad = 0
for path in sorted(pathlib.Path(".claude/agents").glob("*.md")):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        print(f"FALLA {path.name}: sin frontmatter")
        bad += 1
        continue
    meta = frontmatter(text)
    name = str(meta.get("name", ""))
    for field in REQUIRED:
        if not meta.get(field):
            print(f"FALLA {path.name}: falta '{field}'")
            bad += 1
    if name != path.stem:
        print(f"AVISO {path.name}: name={name!r} no coincide con el nombre del fichero")
    if not name.replace("-", "").isalnum() or name.lower() != name:
        print(f"FALLA {path.name}: name debe ser minusculas y guiones")
        bad += 1
    skills = meta.get("skills") or []
    missing = [s for s in skills if not (SKILLS_DIR / str(s) / "SKILL.md").is_file()]
    estado = f"NO RESUELVEN: {missing}" if missing else "todas resuelven"
    print(f"{path.name:26} skills={skills} -> {estado}")
    bad += len(missing)

print("\nOK" if not bad else f"\n{bad} problema(s)")
sys.exit(1 if bad else 0)
