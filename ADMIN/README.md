# Wanti Admin Panel

Panel web (React + Vite) para operación interna. Consume `/api/v1/admin/*` con JWT de un usuario `ADMIN` o `MODERATOR`.

## URLs

| Entorno | URL |
|---|---|
| **Producción (AWS)** | http://67.202.17.248/panel/ |
| Login producción | http://67.202.17.248/panel/login |
| Desarrollo local | http://localhost:5173 |

Credenciales demo: `admin@wanti.co` / `WantiAdmin2026!`

> Django Admin (técnico) es distinto: http://67.202.17.248/admin/

## Desarrollo

```bash
cd ADMIN
npm install
npm run dev
```

El proxy de Vite reenvía `/api` a `http://127.0.0.1:8000`.

## Build / despliegue en el servidor

El panel se sirve en el **mismo origen** que el API, bajo la ruta `/panel/` (nginx del stack `docker-compose.server.yml`).

```bash
cd ADMIN
VITE_BASE=/panel/ npm run build

# Copiar el build al directorio que monta nginx
rm -rf ../BACKEND/admin-panel && mkdir -p ../BACKEND/admin-panel
cp -R dist/. ../BACKEND/admin-panel/

# Subir a EC2 y recrear nginx
rsync -az --delete -e "ssh -i wanti.pem" \
  ../BACKEND/admin-panel/ ec2-user@67.202.17.248:/opt/wanti/admin-panel/
rsync -az -e "ssh -i wanti.pem" \
  ../BACKEND/docker/nginx.bootstrap.conf \
  ../BACKEND/docker-compose.server.yml \
  ec2-user@67.202.17.248:/opt/wanti/
rsync -az -e "ssh -i wanti.pem" \
  ../BACKEND/docker/nginx.bootstrap.conf \
  ec2-user@67.202.17.248:/opt/wanti/docker/

ssh -i wanti.pem ec2-user@67.202.17.248 \
  'cd /opt/wanti && sudo docker-compose --env-file .env.production -f docker-compose.server.yml up -d nginx'
```

Notas:

- `VITE_BASE=/panel/` hace que assets y el router usen el prefijo `/panel`.
- Sin `VITE_API_BASE_URL`, las llamadas van a `/api/v1` (mismo host → sin CORS extra).
- El volumen `./admin-panel` se monta en nginx como `/var/www/panel`.
