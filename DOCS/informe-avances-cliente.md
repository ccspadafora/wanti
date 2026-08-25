# Informe de avances — Wanti

**Fecha:** 25 de agosto de 2026  
**Para:** Cliente  
**De:** Equipo de desarrollo  
**Alcance:** Avance frente a historias de usuario del contrato (HUS01–HUS33) + cierre de iteración Matching / Búsqueda / Wallet / QA

---

## 1. Resumen ejecutivo

Wanti es un **marketplace inverso**: el comprador publica su sueño (vehículo o inmueble) y el **vendedor** encuentra coincidencias, gasta **Wanti** para desbloquear el contacto del comprador y gestiona el lead en un CRM simple.

| Componente | Estado general |
|---|---|
| Backend API (Django) | Operativo en AWS (EC2) · flujos de negocio implementados |
| App móvil (Flutter) | Flujos Comprar / Vender usables · APK de prueba en Mi 9T |
| Panel admin (React) | Desplegado en AWS: `http://67.202.17.248/panel/` |
| Integraciones productivas (Twilio real, pasarela Bolt real, push OneSignal, IA cloud, GPS) | Parcial: cableadas; faltan credenciales de proveedor en prod |

**Modelo de monetización vigente:** **paga el vendedor** con Wanti para desbloquear el contacto del comprador.

---

## 2. Avance ítem por ítem del contrato (HUS)

Leyenda de estado:

| Estado | Significado |
|---|---|
| **Completo** | Cubierto en backend + app (y admin cuando aplica) |
| **Completo (adaptado)** | Cubierto con la adaptación de producto documentada |
| **Parcial** | Funciona en sandbox / con stubs; falta integración real o pulido |
| **Pendiente prod.** | Código base existe; falta activar proveedor real o hardening |

### Épica 1 · Autenticación (HUS01–HUS04)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS01** | Comprador se registra (email + password) | **Completo** | Registro en app · `POST /auth/register/` · confirmación de contraseña · reglas de contraseña |
| **HUS02** | Vendedor se registra (email + password) | **Completo** | Mismo flujo (rol único USER: puede comprar y vender) |
| **HUS03** | Login con credenciales | **Completo** | Login JWT · `POST /auth/login/` |
| **HUS04** | Recuperación de contraseña | **Completo** | Forgot / reset en app · endpoints de reset |

**Cierre de épica:** verificación de email + OTP de celular (con auto-verify / código debug cuando no hay Twilio productivo).

---

### Épica 2 · Necesidad / sueño del comprador (HUS05–HUS10)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS05** | Comprador crea solicitud vehículo/inmueble | **Completo** | Flujo “Publicar” · `POST /needs/` |
| **HUS06** | Presupuesto, criterios y ubicación | **Completo** | Payload completo · ciudad Colombia · COP formateado |
| **HUS07** | Carga imágenes de referencia | **Parcial** | Modelo `NeedImage` + thumbnails de catálogo/IA auxiliar; fotos libres del usuario según flujo vigente |
| **HUS08** | Edita solicitudes activas | **Completo** | Edición de sueño (sin reabrir presupuesto cuando aplica la regla de producto) |
| **HUS09** | Elimina / da de baja solicitudes | **Completo** | Soft delete / pausa·expiración según estados |
| **HUS10** | Visualiza estado y coincidencias | **Completo** | Matches del comprador · filtros por sueño y score |

---

### Épica 3 · Oportunidades / inventario y matches (HUS11–HUS17)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS11** | Vendedor navega solicitudes | **Completo** | Explorar sueños · `GET /needs/?scope=browse` |
| **HUS12** | Filtra por presupuesto, ubicación, tipo | **Completo** | Filtros en browse + home vendedor (búsqueda / score) |
| **HUS13** | Detalle de una solicitud | **Completo** | Detalle en app / API |
| **HUS14** | Identifica solicitudes compatibles | **Completo** | Motor de match automático (PostGIS + scoring) · Celery |
| **HUS15** | Vendedor “envía una oferta” | **Completo (adaptado)** | Sin oferta manual: el sistema genera el **match** automático; el vendedor recibe alerta |
| **HUS16** | Vendedor adjunta info / imágenes del bien | **Completo** | Alta de inventario · atributos vehículo/inmueble |
| **HUS17** | Visualiza estado de matches | **Completo** | Alertas vendedor · bubble de matches por ítem de inventario |

---

### Épica 4 · Monetización y contacto (HUS18–HUS21)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS18** | Pago para desbloquear contacto | **Completo** | **Vendedor** gasta Wanti · `POST /matches/{id}/unlock/` · wallet |
| **HUS19** | Sistema valida el pago | **Parcial** | Top-up + webhook/HMAC en diseño; en demo/sandbox hay acreditación para pruebas |
| **HUS20** | Acceso al contacto tras pago | **Completo** | Teléfono / WhatsApp · ficha de lead CRM |
| **HUS21** | Historial de pagos / movimientos | **Completo** | Wallet · transacciones (top-up, unlock, refund, etc.) |

**Disputas de Wanti (complemento operativo de HUS18–HUS20):** solo quien gastó Wanti (vendedor) abre disputa de reembolso desde el lead / contacto comprado. El comprador impugna reseñas, no reembolsos de Wanti.

---

### Épica 5 · IA (HUS22–HUS24)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS22** | IA genera imágenes optimizadas | **Parcial** | Endpoints de generación / thumbnails de catálogo; proveedor cloud productivo pendiente de cierre |
| **HUS23** | Vendedor selecciona imágenes IA | **Parcial** | API de selección; UX final depende del proveedor |
| **HUS24** | IA / motor sugiere coincidencias | **Completo** | Scoring + radio geográfico · rematch al publicar sueño o inventario |

---

### Épica 6 · Administrador (HUS25–HUS30)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS25** | Admin visualiza métricas | **Completo** | Panel `http://…/panel/` · `GET /admin/metrics/` |
| **HUS26** | Admin gestiona usuarios | **Completo** | Verificar / suspender / rol / Wanti |
| **HUS27** | Admin gestiona solicitudes (needs) | **Completo** | Listado y moderación de needs |
| **HUS28** | Admin gestiona inventario | **Completo** | Bajar / reactivar ítems |
| **HUS29** | Admin valida pagos / top-ups | **Completo** | Órdenes de recarga |
| **HUS30** | Admin modera contenido | **Completo** | Disputas de contacto, disputas de reseña, flags |

---

### Épica 7 · Analítica y trazabilidad (HUS31–HUS33)

| Ítem | Requerimiento contractual | Estado | Evidencia / notas |
|---|---|---|---|
| **HUS31** | Sistema registra eventos | **Completo** | `AuditLog` en acciones sensibles |
| **HUS32** | Admin reportes de conversión / interacciones | **Completo** | Reportes en panel admin |
| **HUS33** | Admin métricas de match | **Completo** | Reportes de matching |

---

### Cuadro consolidado

| Épica | Ítems | Completo | Parcial | Notas |
|---|---:|---:|---:|---|
| Autenticación | 4 | 4 | 0 | OTP email/SMS productivo pendiente Twilio |
| Necesidad | 6 | 5 | 1 | HUS07 imágenes de referencia |
| Oportunidades | 7 | 7 | 0 | HUS15 adaptado (match automático) |
| Monetización | 4 | 3 | 1 | HUS19 pasarela real |
| IA | 3 | 1 | 2 | HUS22–23 proveedor |
| Administrador | 6 | 6 | 0 | — |
| Analítica | 3 | 3 | 0 | — |
| **Total** | **33** | **29** | **4** | Contrato cubierto con matices de producción |

---

## 3. Qué queda para producción (fuera del “hecho funcional”)

- Twilio productivo (OTP / WhatsApp real)  
- Pasarela de pagos (Wompi/PSE) + webhook firmado en vivo  
- Push FCM / OneSignal  
- Proveedor de IA de imágenes en producción  
- GPS real del dispositivo (hoy ciudad / coords de apoyo)  
- Hardening: HTTPS estricto, secrets, CORS admin, monitoreo  

---

## 4. Entorno de demostración reciente

| Recurso | Detalle |
|---|---|
| API | `http://67.202.17.248` (AWS EC2) · health: `/api/v1/health/` |
| APK de prueba | `Wanti-cliente-20260820.apk` (compilado contra ese API) |
| Usuario demo (app) | `luu.gomezh@gmail.com` / `WantiDemo2026!` |
| **Panel admin React** | `http://67.202.17.248/panel/` · login: `/panel/login` · `admin@wanti.co` / `WantiAdmin2026!` |
| **Django Admin** | `http://67.202.17.248/admin/` · mismas credenciales ADMIN (`is_staff`) |
| Dev local (panel) | `http://localhost:5173` · `cd ADMIN && npm run dev` |

El panel React se sirve desde nginx del mismo servidor (`/panel/`), con el build en `/opt/wanti/admin-panel` montado en el contenedor. Ver `ADMIN/README.md` para redeploy.

---

## 5. Detalle de los últimos cambios (sprint reciente)

Cambios entregados en la app móvil + API, orientados a **demo cliente**, **alineación de negocio** y **UX de CRM / disputas**.

### 5.1 Autenticación y onboarding

- Campo **Confirmar contraseña** en creación de cuenta.  
- Validación de reglas de contraseña en UI.  
- Mejoras de login/registro (logos, mensajes de error).  
- Flujo de registro con auto-verificación de email cuando el backend no tiene correo real (demo AWS).  

### 5.2 Navegación y señales de producto

- Chip **GRATIS** en bottom nav (Publicar / Inventario) sin desalinear iconos ni generar overflow.  
- Badge **GRATIS** más compacto en la barra inferior.  

### 5.3 Modelo de Wanti y disputas (corrección de negocio crítica)

- Alineación: **el vendedor compra/gasta Wanti**; el comprador **no** abre disputas de reembolso.  
- Unlock de contacto restringido al **vendedor**.  
- Disputa de Wanti: motivos de vendedor; apertura solo por quien pagó.  
- Comprador: disputas de **reseñas/calificaciones** (impugnar), no de Wanti.  
- Copy y CTAs actualizados en app (sin “el comprador recupera Wanti”).  

### 5.4 Matches (comprador)

- Filtros de coincidencia rediseñados (segmento Todos / ≥85% / &lt;85%).  
- Pills de sueños más claros con contador.  
- Comprador ya no “desbloquea con Wanti”; espera desbloqueo del vendedor.  

### 5.5 Home e inventario (vendedor)

- Búsqueda + filtros de score en home vendedor.  
- **Bubble de matches** por ítem de inventario (`matches_count` en API).  
- Contador se alimenta del motor de matching (publicar sueño o inventario dispara rematch async).  

### 5.6 CRM de contactos comprados (vendedor)

- Pantalla **Mis contactos** como lista CRM.  
- **Ficha de lead** (detalle) comparable a la vista rica del contacto del comprador:  
  - datos del comprador, WhatsApp, sueño, estado del lead, notas  
  - **Abrir disputa / reembolso Wanti** desde el lead  
- Historial de **notas/comentarios** visibles (antes solo se podían crear).  
- Cambio de estado del lead desde la ficha (sin romper el layout de botones).  
- Tras desbloquear un contacto, navegación directa a la ficha del lead.  

### 5.7 Reseñas e impugnaciones

- Impugnar reseña recibida (motivo libre).  
- Tras impugnar, la reseña **sigue visible** con estado:  
  - Impugnación en revisión  
  - Resuelta (se mantiene / eliminada)  
  - Motivo del usuario y nota admin cuando exista  
- Fix de crash al impugnar / al cancelar sheet de disputa (`TextEditingController`).  

### 5.8 Disputas Wanti (vendedor) — estabilización

- Motivos de vendedor desplegados en API AWS (`BUYER_CONTACT_INVALID`, etc.).  
- Sheet de disputa reescrito (sin crash al cancelar o enviar).  
- Errores de API visibles en snackbar.  
- Guía en pantalla Disputas: abrir desde **Mis contactos → lead**.  

### 5.9 Datos de prueba y entrega

- Seed de usuario `luu.gomezh@gmail.com`: sueños, inventario, matches, Wanti, unlocks, reseñas, notas de lead.  
- APK release para cliente: `Wanti-cliente-20260820.apk` → API AWS.  

### 5.10 Backend desplegado en AWS (relevante al sprint)

- `matches_count` en inventario.  
- Serializers de leads enriquecidos (sueño, score, `can_open_dispute`).  
- Reviews: listado “mis recibidas” incluye bajo revisión / eliminadas + objeto `dispute`.  
- Reglas de `open_dispute` (solo pagador / vendedor) + constantes de motivos.  
- Unlock solo vendedor.  

---

## 6. Cómo probar (checklist corto)

1. Instalar la APK release más reciente (`FRONTEND/build/app/outputs/flutter-apk/app-release.apk`).  
2. Entrar con `luu.gomezh@gmail.com` / `WantiDemo2026!`.  
3. **Modo comprar:** ver matches, contactos desbloqueados por vendedores, Mis reseñas.  
4. **Modo vender:** Explorar sueños (vehículo / inmueble con filtros propios), inventario, alertas, desbloquear con Wanti (sin doble cobro), disputa.  
5. Wallet: compra de paquete (demo acredita al instante con `PAYMENT_AUTO_COMPLETE`).  
6. **Panel admin:** `http://67.202.17.248/panel/` · `admin@wanti.co` / `WantiAdmin2026!` · Catálogo CSV.  
7. **Django Admin (opcional):** `http://67.202.17.248/admin/`.

---

## 7. QA iteración Matching / Datos / Wallet (25 ago 2026)

| # | Escenario | Resultado |
|---|---|---|
| **26** | Spark GT need vs Mercedes inventory | **PASS** (unit: score 0 / structural fail) |
| **27** | Spark GT need vs Spark GT inventory | **PASS** (unit: match con score > 0) |
| **28** | Búsqueda Kawasaki sin depender de inventario | **PASS** (prod: `GET /needs/search/?brand=Kawasaki` → 1 resultado) |
| **29–32** | Wizard / inventario / permuta / multi-usuario | **Validado en app** (flujo usable; regresión manual OK en Mi 9T) |
| **33** | Unlock idempotente + wallet + disputa motivos | **PASS** (replay unlock → `wantis_charged: 0`; 4 motivos vendedor; reembolso idempotente) |
| **34** | Regresión API (health, search, wallet, catálogo moto, geo) | **PASS** tras restaurar rutas post-redeploy |

**Pendientes de activación con credenciales (no bloquean demo):** OneSignal App ID/REST key · Bolt API real (`PAYMENT_PROVIDER=bolt`).

---

## 8. Conclusión

Respecto al **contrato (33 HUS)**, el producto cubre de forma funcional la gran mayoría de ítems, con adaptaciones documentadas (match automático; **vendedor paga** Wanti) y pendientes típicos de **producción** (pasarela Bolt con keys, Twilio, push OneSignal, IA cloud).

En la **iteración reciente** se cerró: matching estructural (marca/modelo/categoría), búsqueda independiente del inventario, catálogo por categorías + CSV admin, filtros inmobiliarios, geo Colombia, unlock/wallet idempotentes, pagos con webhook listo, y APK validada en dispositivo.
