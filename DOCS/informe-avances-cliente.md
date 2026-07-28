# Informe de avances — Wanti

**Fecha:** 20 de julio de 2026  
**Para:** Cliente  
**De:** Equipo de desarrollo

---

## Resumen

Quedó operativa la **plataforma backend (API)** a un 70% según las especificaciones técnicas, y desarrollo de la **app móvil Flutter** con el flujo de registro, verificación y publicación de necesidades, ya conectado al API.

| Área | Estado |
|---|---|
| Backend | Completado (specs 00–04) |
| App móvil | En progreso — onboarding, auth y publicación de necesidades |
| Integraciones reales (Twilio, pagos, IA, push) | Pendiente — fase 2 |
| Resto de pantallas (matches, wallet, inventario, disputas) | Pendiente |

---

## Backend

- Dominio modelado (~35 entidades), servicios de negocio y **~80 endpoints** REST documentados (`/api/docs/`).
- Auth JWT, verificación correo/celular, necesidades, inventario, motor de match (PostGIS), billetera, desbloqueo de contacto, disputas, reseñas, leads, notificaciones y auditoría.
- Tareas programadas (Celery), panel admin en español, Docker/CI base para despliegue.

**Demo local**

| | |
|---|---|
| Admin | `http://127.0.0.1:8000/admin/` — `admin@wanti.co` / `WantiAdmin2026!` |
| App de prueba | `maria@wanti.test` / `MariaTest2026!` |

---

## Frontend (Flutter)

Pantallas listas y conectadas al backend:

- Welcome, crear cuenta, iniciar sesión  
- Confirmar correo, OTP celular, cuenta verificada  
- Home (necesidades activas)  
- Publicar necesidad de vehículo (3 pasos: datos → criterios → vista previa)

Matches y Wallet están en la navegación como placeholders.

---

## Arquitectura (visión general)

Wanti es un **marketplace inverso**: el comprador publica lo que busca (vehículo o inmueble) y los vendedores se acercan a esa necesidad. La plataforma conecta ambos lados, calcula coincidencias y cobra Wantis para desbloquear el contacto.

El sistema está separado en capas que se hablan por red, de modo que la app, el servidor y la base de datos puedan evolucionar o escalar por separado.

```
  App móvil (Flutter)          Persona / operación
         │                              │
         ▼                              ▼
   API REST (Django)  ◄──────────  Panel admin web
         │
    ┌────┼────────────┐
    ▼    ▼            ▼
  Base  Cola de     Servicios externos
  datos  trabajos   (SMS, pagos, push, IA)
```

### Piezas principales y para qué sirven

| Pieza | Tecnología | Para qué está |
|---|---|---|
| **App móvil** | Flutter (iOS y Android) | Interfaz del usuario: registro, publicar necesidades, ver matches, billetera, etc. Una sola base de código para ambos sistemas. |
| **API (backend)** | Django + Django REST Framework | Cerebro del negocio: valida reglas, guarda datos, expone ~80 endpoints que la app consume. |
| **Base de datos** | PostgreSQL + PostGIS | Almacena el dominio (usuarios, necesidades, inventario, matches, Wantis, etc.). PostGIS aporta las consultas geográficas del matching (ver abajo). |
| **Cola de trabajos** | Celery + Redis | Tareas que no deben bloquear la app: enviar OTP, recalcular matches, expirar necesidades, notificaciones, etc. |
| **Panel admin** | Django Admin (español) | Operación interna: usuarios, moderación, parámetros (p. ej. valor del Wanti), métricas. |
| **Despliegue** | Docker / Compose | Empaqueta API, base de datos, Redis y workers para subir el entorno de forma repetible. |

**Por qué PostGIS.** En Wanti la ubicación es parte del negocio: un comprador en Medellín no debería “matchear” con la misma prioridad que un inventario en otra ciudad lejana. PostGIS se implementó para que la base de datos entienda coordenadas (lat/lng), calcule distancias y filtre por radio **dentro del propio motor de matching**, junto con precio y criterios. Aporta matches más útiles (menos ruido geográfico) y consultas eficientes a medida que crece el inventario, sin depender de un servicio externo de mapas para cada búsqueda.

### Cómo fluye un caso típico

1. El comprador se registra en la app → la API crea el usuario y dispara verificación de correo / celular (OTP).
2. Publica una **necesidad** (presupuesto, criterios, ubicación) → queda guardada en la base de datos.
3. El **motor de matching** compara esa necesidad con el inventario de vendedores (precio, atributos, distancia) y genera coincidencias con un puntaje.
4. El vendedor ve el match y, si quiere el contacto, gasta **Wantis** de su billetera → se desbloquea el contacto y queda registro en auditoría.
5. Lo que no es inmediato (emails, SMS, recálculos, expiraciones) lo procesa Celery en segundo plano.

### Módulos del backend (qué resuelve cada uno)

El backend está organizado por dominio de negocio, no por “pantallas”. Cada módulo tiene un rol claro:

| Módulo | Rol |
|---|---|
| **users / authn** | Cuentas, roles, login JWT, verificación de email y OTP celular. |
| **needs** | Necesidades del comprador (publicar, editar, expirar). |
| **inventory** | Catálogo del vendedor (vehículos / inmuebles en oferta). |
| **matching** | Motor de coincidencias y scoring (incluye geolocalización). |
| **wallet** | Billetera Wantis, paquetes de recarga y movimientos. |
| **contacts** | Desbloqueo de contacto tras pagar Wantis. |
| **disputes / reviews** | Reclamos/reembolsos y calificaciones entre partes. |
| **leads** | CRM liviano para que el vendedor gestione prospectos. |
| **notifications** | Envío / registro de avisos (push, email, WhatsApp cuando estén conectados). |
| **admin_panel / audit / analytics** | Métricas, moderación, trazas de acciones sensibles y eventos. |
| **common / health** | Utilidades compartidas, parámetros del sistema y chequeo de salud del servicio. |

### App móvil (estado actual)

La app habla solo con la API por HTTP (JSON + JWT). Hoy cubre el camino de **entrada al producto** (cuenta verificada → home → publicar necesidad de vehículo). Matches, wallet e inventario del vendedor están previstos en la navegación pero aún no implementados de punta a punta.

### Qué queda fuera de esta fase (integraciones)

La arquitectura ya contempla conectores, pero en producción aún faltan enlazar de verdad:

- **Twilio** — OTP por WhatsApp/SMS  
- **Pasarela de pagos** (Wompi/PSE) — compra de Wantis  
- **Push** (FCM / OneSignal)  
- **IA de imágenes** — generación/optimización de fotos de inventario  

Hasta entonces, el backend puede operar en modo desarrollo / sandbox sin bloquear las pruebas de flujos principales.

---
