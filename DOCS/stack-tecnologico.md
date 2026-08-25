# Stack tecnológico — Wanti

**Fecha:** 21 de agosto de 2026  
**Propósito:** Resumen de qué tecnologías usa el proyecto y para qué sirve cada una.

---

## Vista rápida de arquitectura

```
 App móvil Flutter (iOS / Android)     Panel admin React (/panel/)
                 │                                │
                 └──────────────┬─────────────────┘
                                ▼
                      Nginx (reverse proxy)
                         │            │
                    /api/v1/*      /panel/ (SPA)
                         │
                         ▼
              Django API (Gunicorn) + JWT
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   PostgreSQL+PostGIS   Redis      Celery worker/beat
   (datos + geo)     (cola/caché)  (tareas async)
```

| Capa | Tecnología principal | Rol |
|---|---|---|
| App usuarios | Flutter + Dart | Comprar / vender en móvil |
| Panel operación | React + Vite + TypeScript | Admin / moderación / métricas |
| API | Django + DRF | Lógica de negocio y REST |
| Datos | PostgreSQL + PostGIS | Persistencia y matching geo |
| Colas | Redis + Celery | Trabajos en segundo plano |
| Infra | Docker + Nginx + AWS EC2 | Despliegue y exposición HTTP |

---

## 1. Aplicación móvil (`FRONTEND/`)

| Tecnología | Para qué sirve |
|---|---|
| **Flutter** | Framework multiplataforma: una base de código para **iOS y Android**. |
| **Dart** | Lenguaje de la app Flutter. |
| **Provider** | Estado global (auth, modo comprar/vender, etc.). |
| **go_router** | Navegación y rutas de pantallas. |
| **http** | Llamadas al API REST. |
| **flutter_secure_storage** | Guardar tokens JWT de forma segura en el dispositivo. |
| **shared_preferences** | Preferencias ligeras no sensibles. |
| **google_fonts / Nunito** | Tipografía alineada al design system. |
| **url_launcher** | Abrir WhatsApp, enlaces externos. |
| **intl** | Formato de fechas, monedas (COP), etc. |

**Para qué existe esta capa:** experiencia del comprador y del vendedor (sueños, inventario, matches, wallet, leads, disputas, reseñas).

---

## 2. Panel de administración (`ADMIN/`)

| Tecnología | Para qué sirve |
|---|---|
| **React 19** | UI del panel web de operación. |
| **TypeScript** | Tipado estático en el front admin. |
| **Vite** | Bundler / servidor de desarrollo y build de producción. |
| **react-router-dom** | Rutas (`/users`, `/needs`, `/panel` basename en prod). |
| **Nunito + design system Wanti** | Misma identidad visual que la app. |

**Para qué existe esta capa:** el dueño/operador gestiona usuarios, necesidades, inventario, Wantis, disputas, settings y ve el **dashboard CRM** de métricas.  
**URL demo:** `http://67.202.17.248/panel/`

---

## 3. Backend API (`BACKEND/`)

| Tecnología | Para qué sirve |
|---|---|
| **Python 3.12+** | Lenguaje del servidor. |
| **Django 5.2+** | Framework web: modelos, auth, admin técnico, settings. |
| **Django REST Framework (DRF)** | Endpoints REST versionados (`/api/v1/…`). |
| **djangorestframework-simplejwt** | Login con **JWT** (access + refresh). |
| **djangorestframework-gis** | Serializar/consultar puntos y distancias geográficas. |
| **django-filter** | Filtros en listados (status, ciudad, etc.). |
| **django-cors-headers** | CORS para el panel React / orígenes permitidos. |
| **drf-spectacular** | Documentación OpenAPI / Swagger (`/api/docs/`). |
| **Gunicorn** | Servidor WSGI que ejecuta Django en producción. |
| **WhiteNoise** | Servir estáticos Django cuando aplica. |
| **Argon2** | Hash seguro de contraseñas. |
| **Pillow** | Procesamiento de imágenes (thumbnails, etc.). |
| **python-dotenv** | Carga de variables de entorno. |
| **Sentry SDK** | Monitoreo de errores (preparado para prod). |
| **python-json-logger** | Logs estructurados. |

**Módulos de dominio (apps Django):**  
`users`, `authn`, `needs`, `inventory`, `matching`, `wallet`, `contacts`, `leads`, `disputes`, `reviews`, `notifications`, `audit`, `admin_panel`, `health`.

**Para qué existe esta capa:** toda la lógica de negocio (matching, Wantis, unlock, CRM, disputas, reseñas) expuesta como API.

---

## 4. Base de datos y geolocalización

| Tecnología | Para qué sirve |
|---|---|
| **PostgreSQL 16** | Base de datos relacional principal. |
| **PostGIS 3.4** | Extensión geoespacial: ubicaciones, radios, distancia en matching. |
| **psycopg** | Driver Python ↔ Postgres. |

**Para qué existe esta capa:** persistir usuarios, sueños, inventario, matches, wallet, leads, etc., y calcular cercanía geográfica.

---

## 5. Tareas asíncronas y caché

| Tecnología | Para qué sirve |
|---|---|
| **Redis 7** | Broker de mensajes de Celery y caché liviana. |
| **Celery** | Ejecutar trabajos **fuera** del request HTTP. |
| **Celery worker** | Consume colas (`high`, `default`, `low`): matching, notificaciones, etc. |
| **Celery beat** + **django-celery-beat** | Scheduler de tareas periódicas (expirar needs/leads, reconciliaciones). |

**Ejemplos de uso en Wanti:**  
generar matches al publicar un sueño o ítem de inventario, notificaciones, timeouts de disputas, jobs de mantenimiento.

---

## 6. Infraestructura y despliegue

| Tecnología | Para qué sirve |
|---|---|
| **Docker** | Empaqueta API y servicios en contenedores reproducibles. |
| **Docker Compose** | Orquesta Postgres, Redis, API, Celery worker/beat y Nginx en un solo host. |
| **Nginx** | Reverse proxy: `/api/` → Django, `/panel/` → SPA admin, `/admin/` → Django Admin, estáticos/media. |
| **AWS EC2** | Máquina virtual donde corre el stack de demo/producción bootstrap. |
| **Elastic IP** | IP fija pública (p. ej. `67.202.17.248`). |

**Compose de servidor:** `BACKEND/docker-compose.server.yml`  
**Nginx bootstrap:** `BACKEND/docker/nginx.bootstrap.conf`

---

## 7. Autenticación y seguridad

| Tecnología / pieza | Para qué sirve |
|---|---|
| **JWT (SimpleJWT)** | Sesión de app y panel sin cookies de sesión clásicas. |
| **Verificación email** | Confirmar correo al registrarse. |
| **OTP teléfono** | Verificar celular (Twilio en prod; modo debug en demo). |
| **Django Admin** | Panel técnico de modelos (`/admin/`) — distinto del React `/panel/`. |
| **Roles** | `USER`, `MODERATOR`, `ADMIN` para permisos de API admin. |
| **AuditLog** | Trazabilidad de acciones sensibles. |

---

## 8. Integraciones externas (diseñadas / parciales)

| Integración | Para qué sirve | Estado típico |
|---|---|---|
| **Twilio** | SMS / WhatsApp OTP | Stub / debug en demo; real en prod |
| **Pasarela (Wompi / PSE)** | Compra de paquetes Wantis | Sandbox / webhook preparado |
| **FCM / OneSignal** | Push a dispositivos | Inbox en DB hoy; push real pendiente |
| **S3 + django-storages + boto3** | Archivos/media en cloud | Preparado en stack |
| **IA de imágenes** | Generar/optimizar fotos de inventario | Endpoints; proveedor cloud pendiente |
| **Sentry** | Errores en producción | SDK listo |

---

## 9. Herramientas de desarrollo

| Tecnología | Para qué sirve |
|---|---|
| **Git** | Control de versiones. |
| **TypeScript / oxlint** | Calidad en el panel admin. |
| **flutter_lints** | Calidad en la app Flutter. |
| **OpenAPI / Swagger** | Contrato y prueba de endpoints. |

---

## 10. Cómo encaja cada pieza en el producto

| Necesidad de negocio | Qué lo resuelve |
|---|---|
| App para compradores y vendedores | Flutter |
| Operar la plataforma (métricas, moderación, Wantis) | React Admin + `/api/v1/admin/*` |
| Reglas de matching, wallet, disputas | Django + servicios de dominio |
| “¿Quién está cerca / compatible?” | PostGIS + motor de scoring + Celery |
| No bloquear la API al matchear | Celery + Redis |
| Exponer todo de forma segura en un servidor | Nginx + Docker + EC2 |
| Identidad de marca | Design system (navy/teal, Nunito, logos) |

---

## 11. Mapa de carpetas del monorepo

```
WANTI/
├── FRONTEND/     # App Flutter (usuarios finales)
├── ADMIN/        # Panel React (operación)
├── BACKEND/      # API Django + Docker + Nginx
├── DOCS/         # Informes y documentación
└── specs/        # Especificaciones técnicas (modelos, endpoints, deploy)
```

---

## Resumen en una frase

Wanti es un **marketplace inverso** donde la **app Flutter** habla con una **API Django**, los datos viven en **Postgres/PostGIS**, el trabajo pesado corre en **Celery/Redis**, el **panel React** opera el negocio, y **Docker + Nginx en AWS** lo exponen al mundo.
