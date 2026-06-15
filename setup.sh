#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# ─────────────────────────────────────────────────────────────────────────────
# Reemplaza los marcadores {{OWNER}} y {{PROJECT}} en todos los archivos.
# Córrelo UNA vez al crear un proyecto nuevo desde este template.
#
#   ./setup.sh <owner-github> <nombre-proyecto>
#   ej:  ./setup.sh czapata2020 mi-nuevo-app
#
# Ambos en minúsculas (GHCR siempre usa minúsculas en las rutas).
# ─────────────────────────────────────────────────────────────────────────────

if [ $# -ne 2 ]; then
  echo "Uso: ./setup.sh <owner-github> <nombre-proyecto>"
  echo "Ej:  ./setup.sh czapata2020 mi-nuevo-app"
  exit 1
fi

OWNER="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
PROJECT="$(echo "$2" | tr '[:upper:]' '[:lower:]')"

FILES=(
  ".github/workflows/build-and-push.yml"
  "compose.prod.yaml"
  "deploy.sh"
)

echo "Configurando proyecto:"
echo "  OWNER   = $OWNER"
echo "  PROJECT = $PROJECT"
echo ""

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    sed -i.bak "s/{{OWNER}}/$OWNER/g; s/{{PROJECT}}/$PROJECT/g" "$f"
    rm -f "$f.bak"
    echo "  ✓ $f"
  fi
done

chmod +x deploy.sh

echo ""
echo "Listo. Verifica que no quede ningún marcador:"
echo "  grep -rn '{{' . --include='*.yml' --include='*.yaml' --include='*.sh' || echo 'limpio'"
echo ""
echo "Siguientes pasos:"
echo "  1. Pon tu código y tus Dockerfile(s)."
echo "  2. git add -A && git commit -m 'setup' && git push"
echo "  3. En GitHub: haz PÚBLICOS los paquetes (o usa GHCR_TOKEN en el server)."
echo "  4. En el servidor: copia compose.prod.yaml + deploy.sh y corre ./deploy.sh"
