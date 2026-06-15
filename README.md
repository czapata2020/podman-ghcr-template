# Template: deploy con Podman + GHCR

Estructura base para desplegar un proyecto en un servidor con Podman, jalando
imágenes ya construidas desde GitHub Container Registry (GHCR). El servidor
nunca compila: GitHub Actions construye y publica, el servidor solo descarga.

## Flujo

```
Mac/PC dev:  programas -> git push
GitHub:      Actions construye y publica imágenes a GHCR  (automático)
Servidor:    ./deploy.sh                                  (pull + recrear)
```

## Setup de un proyecto nuevo (una vez)

1. Crea el repo desde este template ("Use this template" en GitHub).
2. Reemplaza los marcadores:
   ```
   ./setup.sh <owner-github> <nombre-proyecto>      # ambos en minúsculas
   ```
3. Renombra `Dockerfile.example` -> `Dockerfile` y adáptalo (o pon los tuyos).
4. Ajusta `compose.prod.yaml` y el `matrix` del workflow a tus servicios reales.
5. `git add -A && git commit -m "setup" && git push`
6. En GitHub: pestaña **Actions**, espera a que los jobs estén en VERDE.
7. En GitHub: haz **PÚBLICOS** los paquetes (perfil -> Packages -> cada uno ->
   Package settings -> Change visibility). O, si los dejas privados, en el
   servidor define `GHCR_TOKEN` (token con permiso `read:packages`).
8. En el servidor: copia `compose.prod.yaml` + `deploy.sh`, corre `./deploy.sh`.

## Día a día

```
git push          # esperar a que Actions ponga verde
./deploy.sh       # en el servidor (o por ssh desde tu maquina dev)
```

Desplegar una versión exacta o hacer rollback:
```
./deploy.sh sha-a1b2c3d
./deploy.sh v1.2.3
```

## Checklist anti-tropiezos (lecciones aprendidas)

- [ ] `npm run build` LOCAL pasa en verde ANTES de hacer push.
      (`next dev` no valida tipos; `next build` sí. Caza errores aquí, no en CI.)
- [ ] Tras editar: `git add` -> `git commit` -> `git push`.
      Verifica que el push diga `main -> main`, NO "Everything up-to-date".
- [ ] El stage de prod es autocontenido: sin bind mounts ni volumen de
      node_modules. dev y prod son composes SEPARADOS.
- [ ] Los PAQUETES son públicos (distinto de que el repo sea público).
      Si no, `pull` da `unauthorized`.
- [ ] `deploy.sh` usa `up -d --force-recreate` (si no, queda corriendo el
      contenedor viejo aunque la imagen nueva ya esté descargada).
- [ ] Si corres VARIOS proyectos en el mismo servidor: dales puertos distintos
      en `compose.prod.yaml` para que no choquen.

## Archivos

- `.github/workflows/build-and-push.yml` — build + push a GHCR (matrix por servicio)
- `compose.prod.yaml` — referencia imágenes de GHCR (no construye)
- `deploy.sh` — pull + up --force-recreate en el servidor
- `setup.sh` — reemplaza {{OWNER}} y {{PROJECT}} (córrelo una vez)
- `Dockerfile.example` — patrón multi-stage Next.js (renombrar y adaptar)
