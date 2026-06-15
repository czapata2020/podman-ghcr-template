#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# ─────────────────────────────────────────────────────────────────────────────
# Despliegue de PRODUCCIÓN — descarga imágenes de GHCR y las (re)crea.
# No construye, no borra imágenes en uso, no toca volúmenes de datos.
#
#   ./deploy.sh                 -> tag 'latest'
#   ./deploy.sh sha-a1b2c3d     -> una versión concreta (recomendado para certeza)
#   ./deploy.sh v1.2.3          -> un tag de versión
#   Rollback: ./deploy.sh <tag-anterior>
# ─────────────────────────────────────────────────────────────────────────────

OWNER="{{OWNER}}"                  # tu usuario/org de GitHub, en minúsculas
COMPOSE_FILE="compose.prod.yaml"
export TAG="${1:-latest}"
OS="$(uname -s)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Despliegue: {{PROJECT}} — tag: $TAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Podman + comando compose -------------------------------------------------
echo ""
echo "[1/4] Verificando Podman..."
if ! podman info &>/dev/null; then
  if [ "$OS" = "Darwin" ]; then podman machine start; else echo "  ✗ Podman no responde."; exit 1; fi
fi
[ "$OS" != "Darwin" ] && systemctl --user start podman.socket 2>/dev/null || true

if command -v podman-compose &>/dev/null; then
  COMPOSE="podman-compose"
else
  COMPOSE="podman compose"
  PODMAN_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
  [ -S "$PODMAN_SOCK" ] && export DOCKER_HOST="unix://$PODMAN_SOCK"
fi
echo "  Usando: $COMPOSE"

# 2. Login a GHCR (solo si los paquetes son privados) ------------------------
if [ -n "${GHCR_TOKEN:-}" ]; then
  echo ""; echo "[2/4] Login en GHCR..."
  echo "$GHCR_TOKEN" | podman login ghcr.io -u "$OWNER" --password-stdin
  echo "  OK"
else
  echo ""; echo "[2/4] Sin GHCR_TOKEN — asumiendo paquetes públicos."
fi

# 3. Descargar delta y recrear contenedores ----------------------------------
echo ""
echo "[3/4] Descargando imágenes ($TAG) y desplegando..."
$COMPOSE -f "$COMPOSE_FILE" pull
$COMPOSE -f "$COMPOSE_FILE" up -d --force-recreate   # <-- recrea con la imagen nueva
echo "  OK"
echo ""
echo "  Versión desplegada:"
podman ps --filter "name=app" --format "    {{.Image}}  (creado {{.CreatedAt}})" || true

# 4. Healthchecks (ajusta puertos/endpoints a tu proyecto) -------------------
echo ""
echo "[4/4] Esperando servicios..."
for i in $(seq 1 20); do
  curl -sf http://localhost:3001/health &>/dev/null && { echo "  DB lista."; break; }
  [ "$i" -eq 20 ] && { echo "  ✗ DB no respondió. Logs: $COMPOSE -f $COMPOSE_FILE logs db"; exit 1; }
  sleep 3
done
for i in $(seq 1 10); do
  curl -sf http://localhost:3000 &>/dev/null && { echo "  App lista."; break; }
  sleep 3
done

# Limpieza suave: borra solo imágenes huérfanas (nunca las que están en uso)
podman image prune -f >/dev/null 2>&1 || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App → http://localhost:3000"
echo "  API → http://localhost:3001"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
