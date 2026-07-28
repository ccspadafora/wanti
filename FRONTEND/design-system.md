---
version: 1.0
name: Wanti Design System
description: >
  Wanti es un reverse marketplace colombiano de vehículos e inmuebles donde el comprador publica
  su necesidad y los vendedores pagan por el contacto. El sistema de diseño refleja esa inversión
  del modelo convencional: confianza sin frivolidad, claridad sin frialdad. La paleta combina el
  azul marino profundo del logotipo —autoridad, seguridad— con el teal/cian vibrante —movimiento,
  posibilidad—. La tipografía es redonda y accesible. El UI es limpio, táctil y directo.

colors:
  # Brand primarios — extraídos del logotipo
  wanti-navy:       "#0A1F44"   # Azul marino oscuro — brazo derecho de la W, texto "wanti"
  wanti-teal:       "#00B2A9"   # Teal/cian brillante — brazo izquierdo de la W, acento "Publican!"
  wanti-teal-dark:  "#007A72"   # Teal oscuro — zona de intersección de la W
  wanti-teal-mid:   "#009490"   # Teal medio — degradado entre los dos brazos

  # Superficies
  canvas:           "#FFFFFF"   # Fondo principal
  surface-soft:     "#F4F8FB"   # Tarjetas y paneles neutros (azul muy pálido)
  surface-teal:     "#E6F9F8"   # Fondo teal suave — estados activos, badges positivos
  surface-navy:     "#EEF1F6"   # Fondo navy suave — paneles secundarios

  # Estado y semántica
  success:          "#00B2A9"   # = wanti-teal
  warning:          "#EF9F27"   # Ámbar — criterio flexible / "preferencia"
  warning-light:    "#FDF3DC"   # Fondo ámbar suave
  error:            "#C0392B"   # Rojo error y disputas
  error-light:      "#FCECEA"   # Fondo rojo suave

  # Texto
  ink:              "#0A1F44"   # = wanti-navy — texto principal
  ink-muted:        "#4A5568"   # Texto secundario / subtítulos
  ink-faint:        "#94A3B8"   # Placeholder, metadata, fechas
  on-dark:          "#FFFFFF"   # Texto sobre fondos oscuros
  on-teal:          "#FFFFFF"   # Texto sobre fondo teal

  # Bordes y separadores
  border:           "#D8E2EE"   # Borde estándar de tarjetas e inputs
  border-light:     "#EDF2F7"   # Separadores suaves
  border-focus:     "#00B2A9"   # Borde de focus — wanti-teal

typography:
  # Familia principal: Nunito — redonda, accesible, coherente con el logotipo
  # Familia código/mono: JetBrains Mono
  # Fallbacks: Inter, Arial, system-ui

  display-hero:
    fontFamily: "Nunito"
    fontSize: "56px"
    fontWeight: 800
    lineHeight: 1.0
    letterSpacing: "-1.12px"
    usage: "Headline principal de pantallas de bienvenida y onboarding"

  display-section:
    fontFamily: "Nunito"
    fontSize: "36px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.72px"
    usage: "Encabezados de sección principal en pantallas de home y módulos"

  heading-card:
    fontFamily: "Nunito"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.22px"
    usage: "Títulos de tarjetas, modales y bloques de contenido"

  heading-feature:
    fontFamily: "Nunito"
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "0"
    usage: "Títulos de ítems dentro de tarjetas, labels de campo activo"

  body-large:
    fontFamily: "Nunito"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0"
    usage: "Párrafos de introducción, descripciones de pantalla"

  body:
    fontFamily: "Nunito"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0"
    usage: "Cuerpo general de la app, listas, subtítulos de tarjeta"

  button:
    fontFamily: "Nunito"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.6
    letterSpacing: "0"
    usage: "Etiqueta de todos los CTAs y botones"

  label:
    fontFamily: "Nunito"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.24px"
    usage: "Labels de input, metadata de tarjeta, badges de estado"

  caption:
    fontFamily: "Nunito"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0"
    usage: "Fechas, contadores, texto de navegación inferior"

  mono:
    fontFamily: "JetBrains Mono"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0.26px"
    usage: "OTP codes, valores monetarios precisos, IDs de transacción"

rounded:
  xs:   "4px"
  sm:   "8px"
  md:   "12px"
  lg:   "16px"
  xl:   "20px"
  card: "16px"
  pill: "100px"
  full: "9999px"

spacing:
  xxs: "2px"
  xs:  "4px"
  sm:  "8px"
  md:  "12px"
  lg:  "16px"
  xl:  "24px"
  xxl: "32px"
  section: "48px"

elevation:
  flat:    "none"
  card:    "0 2px 8px rgba(10,31,68,0.06)"
  raised:  "0 4px 16px rgba(10,31,68,0.10)"
  modal:   "0 8px 32px rgba(10,31,68,0.16)"

components:
  button-primary:
    backgroundColor:  "{colors.wanti-navy}"
    textColor:        "{colors.on-dark}"
    typography:       "{typography.button}"
    rounded:          "{rounded.pill}"
    padding:          "14px 28px"
    usage:            "CTA principal por pantalla: Publicar, Confirmar, Desbloquear"

  button-teal:
    backgroundColor:  "{colors.wanti-teal}"
    textColor:        "{colors.on-teal}"
    typography:       "{typography.button}"
    rounded:          "{rounded.pill}"
    padding:          "14px 28px"
    usage:            "CTAs de acción positiva: Abrir WhatsApp, Recargar Guantes"

  button-outline:
    backgroundColor:  "transparent"
    border:           "1.5px solid {colors.wanti-navy}"
    textColor:        "{colors.wanti-navy}"
    typography:       "{typography.button}"
    rounded:          "{rounded.pill}"
    padding:          "13px 28px"
    usage:            "Acción secundaria sobre fondos claros"

  button-ghost:
    backgroundColor:  "transparent"
    textColor:        "{colors.wanti-teal}"
    typography:       "{typography.body}"
    rounded:          "{rounded.xs}"
    padding:          "8px 0"
    usage:            "Acciones terciarias: Reenviar código, Ver más, Reportar disputa"

  badge-required:
    backgroundColor:  "{colors.surface-teal}"
    textColor:        "{colors.wanti-teal-dark}"
    typography:       "{typography.label}"
    rounded:          "{rounded.full}"
    padding:          "3px 10px"
    usage:            "Criterio marcado como Obligatorio — excluye si no cumple"

  badge-preferred:
    backgroundColor:  "{colors.warning-light}"
    textColor:        "{colors.warning}"
    typography:       "{typography.label}"
    rounded:          "{rounded.full}"
    padding:          "3px 10px"
    usage:            "Criterio marcado como Preferencia — no excluye al vendedor"

  badge-match-high:
    backgroundColor:  "{colors.surface-teal}"
    textColor:        "{colors.wanti-teal-dark}"
    typography:       "{typography.heading-card}"
    rounded:          "{rounded.full}"
    usage:            "Porcentaje de afinidad ≥ 85%"

  badge-match-mid:
    backgroundColor:  "{colors.warning-light}"
    textColor:        "{colors.warning}"
    typography:       "{typography.heading-card}"
    rounded:          "{rounded.full}"
    usage:            "Porcentaje de afinidad < 85%"

  input-field:
    backgroundColor:  "{colors.surface-soft}"
    border:           "1px solid {colors.border}"
    borderFocus:      "1.5px solid {colors.border-focus}"
    textColor:        "{colors.ink}"
    placeholderColor: "{colors.ink-faint}"
    typography:       "{typography.body-large}"
    rounded:          "{rounded.lg}"
    padding:          "13px 16px"
    labelTypography:  "{typography.label}"
    labelColor:       "{colors.ink-muted}"

  otp-box:
    backgroundColor:  "{colors.surface-soft}"
    border:           "1px solid {colors.border}"
    borderFocus:      "2px solid {colors.wanti-teal}"
    width:            "48px"
    height:           "60px"
    typography:       "{typography.mono}"
    rounded:          "{rounded.lg}"
    usage:            "Cajas individuales para código OTP de 6 dígitos"

  card-match:
    backgroundColor:  "{colors.canvas}"
    border:           "1.5px solid {colors.border}"
    borderHighMatch:  "1.5px solid {colors.wanti-teal}"
    borderMidMatch:   "1.5px solid {colors.warning}"
    rounded:          "{rounded.card}"
    padding:          "16px"
    elevation:        "{elevation.card}"
    usage:            "Tarjeta de resultado de match — comprador y vendedor"

  card-need:
    backgroundColor:  "{colors.canvas}"
    border:           "1px solid {colors.border}"
    rounded:          "{rounded.card}"
    padding:          "16px"
    elevation:        "{elevation.card}"
    usage:            "Tarjeta de necesidad activa publicada por el comprador"

  card-wallet:
    backgroundColor:  "{colors.wanti-navy}"
    textColor:        "{colors.on-dark}"
    rounded:          "{rounded.xl}"
    padding:          "20px 24px"
    elevation:        "{elevation.raised}"
    usage:            "Bloque de saldo de Guantes en el wallet del usuario"

  card-alert-vendor:
    backgroundColor:  "{colors.canvas}"
    border:           "1.5px solid {colors.wanti-teal}"
    rounded:          "{rounded.card}"
    padding:          "16px"
    elevation:        "{elevation.card}"
    usage:            "Alerta de match recibida por el vendedor"

  nav-bottom:
    backgroundColor:  "{colors.canvas}"
    borderTop:        "1px solid {colors.border-light}"
    activeColor:      "{colors.wanti-teal}"
    inactiveColor:    "{colors.ink-faint}"
    activeIndicator:  "3px solid {colors.wanti-teal} — barra superior del ítem"
    typography:       "{typography.caption}"
    height:           "83px"
    usage:            "Barra de navegación inferior — 4 ítems máximo"

  header-screen:
    backgroundColor:  "{colors.canvas}"
    borderBottom:     "none"
    titleTypography:  "{typography.heading-feature}"
    titleColor:       "{colors.ink}"
    backIcon:         "← glifo, 20px, {colors.ink}"
    height:           "56px"
    topOffset:        "44px"
    usage:            "Barra de título de pantalla interior"

  progress-bar:
    trackColor:       "{colors.border-light}"
    fillColor:        "{colors.wanti-teal}"
    height:           "8px"
    rounded:          "{rounded.full}"
    usage:            "Indicador de avance en formularios multi-paso"

  toggle-criterion:
    activeColor:      "{colors.wanti-teal}"
    inactiveColor:    "{colors.border}"
    width:            "44px"
    height:           "24px"
    rounded:          "{rounded.full}"
    usage:            "Toggle para marcar criterio como Obligatorio o Preferencia"

  ai-image-box:
    backgroundColor:  "{colors.surface-teal}"
    border:           "1.5px dashed {colors.wanti-teal}"
    rounded:          "{rounded.xl}"
    padding:          "24px"
    textColor:        "{colors.wanti-teal-dark}"
    usage:            "Contenedor de imagen generada por IA basada en parámetros del comprador"

  otp-verification-badge:
    backgroundColor:  "{colors.surface-teal}"
    border:           "1.5px solid {colors.wanti-teal}"
    rounded:          "{rounded.lg}"
    textColor:        "{colors.wanti-teal-dark}"
    usage:            "Badge de verificación: Email ✓ / Celular ✓ en pantalla de cuenta activa"

  status-bar-area:
    height:           "44px"
    usage:            "Reserva de espacio para barra de estado del sistema (iOS/Android)"

  section-hero-teal:
    backgroundColor:  "{colors.surface-teal}"
    usage:            "Banda de encabezado suave detrás de logo y saludo en home"

  section-dark-navy:
    backgroundColor:  "{colors.wanti-navy}"
    textColor:        "{colors.on-dark}"
    rounded:          "{rounded.xl}"
    usage:            "Secciones de alta jerarquía: wallet, onboarding success, paneles admin"

  admin-metric-tile:
    backgroundColor:  "{colors.surface-soft}"
    rounded:          "{rounded.lg}"
    padding:          "12px 16px"
    usage:            "Mosaico de métrica en panel de administración"

  admin-action-row:
    backgroundColor:  "{colors.canvas}"
    border:           "1px solid {colors.border}"
    borderAlert:      "1.5px solid {colors.error-light}"
    rounded:          "{rounded.lg}"
    elevation:        "{elevation.card}"
    usage:            "Fila de acción en panel admin con icono, título, subtítulo y flecha"

  transaction-row:
    borderBottom:     "1px solid {colors.border-light}"
    amountPositive:   "{colors.wanti-teal}"
    amountNegative:   "{colors.ink}"
    typography:       "{typography.body}"
    usage:            "Fila de historial de transacciones en el wallet"
---

# Wanti Design System — v1.0

> **"Por qué tus sueños no se buscan, se Publican."**
> Sistema de diseño para el reverse marketplace colombiano de vehículos e inmuebles.

---

## Visión del sistema

Wanti invierte la lógica del clasificado convencional. El diseño debe comunicar esa inversión: **el poder está en el comprador**, el proceso es transparente, y cada interacción genera confianza sin fricciones.

El sistema visual se ancla en tres decisiones estratégicas:

1. **Azul marino como base de autoridad.** `#0A1F44` es el color de los datos, la confianza y las decisiones. Es el color del texto, del CTA principal, del fondo del wallet.
2. **Teal como motor de acción.** `#00B2A9` es el color del movimiento: los matches, los criterios cumplidos, el código OTP verificado, el WhatsApp activado.
3. **Tipografía Nunito — redonda y directa.** Coherente con las curvas del logotipo. Familiar pero no infantil. Legible en pantallas pequeñas.

---

## Colores

### Paleta brand — del logotipo

| Token | Hex | Uso |
|---|---|---|
| `wanti-navy` | `#0A1F44` | Texto principal, CTAs primarios, nav activo, wallet |
| `wanti-teal` | `#00B2A9` | Matches, verificaciones, CTAs positivos, bordes de focus |
| `wanti-teal-dark` | `#007A72` | Texto sobre fondos teal, íconos teal |
| `wanti-teal-mid` | `#009490` | Zonas de transición e íconos intermedios |

### Superficies

| Token | Hex | Uso |
|---|---|---|
| `canvas` | `#FFFFFF` | Fondo de pantalla y tarjetas base |
| `surface-soft` | `#F4F8FB` | Inputs, fondos de tarjeta neutral, métricas admin |
| `surface-teal` | `#E6F9F8` | Badges de obligatorio, estados activos, headers de home |
| `surface-navy` | `#EEF1F6` | Paneles secundarios, fondos de sección informativa |

### Semántica

| Token | Hex | Uso |
|---|---|---|
| `success` | `#00B2A9` | Confirmaciones, verificación exitosa |
| `warning` | `#EF9F27` | Criterio de preferencia, match parcial |
| `warning-light` | `#FDF3DC` | Fondo de badge de preferencia |
| `error` | `#C0392B` | Errores, disputas, leads inválidos |
| `error-light` | `#FCECEA` | Fondo de alerta de error |

### Texto

| Token | Hex | Uso |
|---|---|---|
| `ink` | `#0A1F44` | Texto principal — mismo que navy |
| `ink-muted` | `#4A5568` | Subtítulos, labels de campo |
| `ink-faint` | `#94A3B8` | Placeholders, metadatos, fechas |
| `on-dark` | `#FFFFFF` | Texto sobre fondos navy o teal oscuro |
| `on-teal` | `#FFFFFF` | Texto sobre botones teal |

### Bordes

| Token | Hex | Uso |
|---|---|---|
| `border` | `#D8E2EE` | Borde estándar de tarjetas e inputs |
| `border-light` | `#EDF2F7` | Separadores de listas, divisores suaves |
| `border-focus` | `#00B2A9` | Ring de focus en inputs activos |

---

## Tipografía

### Familias

| Rol | Familia | Fallback |
|---|---|---|
| Display y UI | `Nunito` | Inter, Arial, system-ui |
| Códigos y valores | `JetBrains Mono` | Courier New, monospace |

> **Justificación:** Nunito tiene terminaciones redondeadas que resuenan con las curvas del logotipo y la "W" del ícono. Crea calidez sin perder legibilidad en pantallas de 390px.

### Escala

| Rol | Familia | Tamaño | Peso | Línea | Uso principal |
|---|---|---:|---:|---:|---|
| Display Hero | Nunito | 56px | 800 | 1.0 | Headline de onboarding y splash |
| Display Sección | Nunito | 36px | 700 | 1.1 | Encabezado de módulo o sección |
| Heading Card | Nunito | 22px | 700 | 1.2 | Título de tarjeta y modal |
| Heading Feature | Nunito | 17px | 700 | 1.3 | Título de ítem dentro de tarjeta |
| Body Large | Nunito | 16px | 400 | 1.5 | Párrafo de descripción e introducción |
| Body | Nunito | 14px | 400 | 1.5 | Contenido general, listas |
| Button | Nunito | 15px | 700 | 1.6 | Etiqueta de CTA |
| Label | Nunito | 12px | 600 | 1.4 | Labels de input y badges |
| Caption | Nunito | 11px | 400 | 1.4 | Nav inferior, fechas, contadores |
| Mono | JetBrains Mono | 13px | 400 | 1.4 | OTP, importes exactos, IDs |

### Principios tipográficos

- El display (56px, 800) aparece **una sola vez por pantalla**. No uses pesos ultra-bold en listas o tarjetas.
- Los botones usan peso 700 aunque el body sea 400. El peso hace el trabajo de jerarquía, no el UPPERCASE.
- Los importes en el wallet y las transacciones usan `JetBrains Mono` para dar precisión y diferenciación visual.
- Nunca uses italic decorativo. El sistema no tiene estilo italic en uso activo.

---

## Espaciado

El sistema usa base 4px con incrementos dobles:

| Token | Valor | Ejemplo de uso |
|---|---:|---|
| `xxs` | 2px | Separación entre ícono y texto en badge |
| `xs` | 4px | Padding interno de tag/chip |
| `sm` | 8px | Separación entre elementos en fila |
| `md` | 12px | Padding interno de campo input |
| `lg` | 16px | Padding lateral de pantalla (margen estándar: 24px) |
| `xl` | 24px | Padding horizontal de pantalla — margen universal |
| `xxl` | 32px | Separación entre secciones dentro de una tarjeta |
| `section` | 48px | Separación entre bloques de pantalla |

> **Margen lateral universal:** `24px` a cada lado. Todas las tarjetas y campos respetan este margen en pantallas de 390px.

---

## Bordes redondeados

| Token | Valor | Uso |
|---|---:|---|
| `xs` | 4px | Elementos utilitarios menores |
| `sm` | 8px | Chips de tag dentro de tarjeta |
| `md` | 12px | Inputs, botones de opción |
| `lg` | 16px | Tarjetas estándar (match, necesidad, admin) |
| `xl` | 20px | Tarjetas con media o wallet |
| `card` | 16px | Radio estándar de tarjeta de contenido |
| `pill` | 100px | Todos los botones CTA |
| `full` | 9999px | Badges, toggles, indicadores de progreso |

---

## Elevación y profundidad

Wanti es mayoritariamente plano. La profundidad llega del contraste de superficie y los bordes, no de sombras agresivas.

| Nivel | Valor CSS | Uso |
|---|---|---|
| Flat | `none` | Inputs sobre `surface-soft`, filas de historial |
| Card | `0 2px 8px rgba(10,31,68,0.06)` | Tarjetas de match, necesidad y alerta |
| Raised | `0 4px 16px rgba(10,31,68,0.10)` | Wallet card, modales de confirmación |
| Modal | `0 8px 32px rgba(10,31,68,0.16)` | Bottom sheets y overlays |

---

## Componentes

### Botones

#### `button-primary` — CTA principal
```
Fondo:     wanti-navy (#0A1F44)
Texto:     on-dark (#FFFFFF)
Tipografía: Nunito 15px / Bold
Radio:     pill (100px)
Padding:   14px 28px
Ancho:     342px (pantalla 390px − 2×24px de margen)
Uso:       Una sola acción principal por pantalla. Publicar, Confirmar, Siguiente →
```

#### `button-teal` — CTA positivo / acción
```
Fondo:     wanti-teal (#00B2A9)
Texto:     on-teal (#FFFFFF)
Tipografía: Nunito 15px / Bold
Radio:     pill (100px)
Padding:   14px 28px
Uso:       Abrir WhatsApp, Recargar Guantes, Verificar código
```

#### `button-outline` — Acción secundaria
```
Fondo:     transparente
Borde:     1.5px solid wanti-navy
Texto:     wanti-navy
Radio:     pill (100px)
Padding:   13px 28px
Uso:       Segunda opción cuando hay dos CTAs en pantalla
```

#### `button-ghost` — Acción terciaria
```
Fondo:     transparente
Texto:     wanti-teal (subrayado opcional)
Tipografía: Nunito 14px / Regular
Uso:       Reenviar código, Reportar disputa, Ya verifiqué mi correo
```

---

### Badges y estado

#### `badge-required` — Obligatorio
```
Fondo:     surface-teal (#E6F9F8)
Texto:     wanti-teal-dark (#007A72) — "Obligatorio"
Radio:     full
Padding:   3px 10px
Tipografía: Nunito 12px / SemiBold
Uso:       Criterio que excluye al vendedor si no lo cumple
```

#### `badge-preferred` — Preferencia
```
Fondo:     warning-light (#FDF3DC)
Texto:     warning (#EF9F27) — "Preferencia"
Radio:     full
Padding:   3px 10px
Tipografía: Nunito 12px / SemiBold
Uso:       Criterio deseable, no excluyente. Muestra leyenda "Deseable, pero no excluyente"
```

#### `badge-match-high` — Match ≥ 85%
```
Color del porcentaje: wanti-teal (#00B2A9)
Peso: Bold, 28px
Uso: Indicador visual de alta afinidad en tarjetas de match
```

#### `badge-match-mid` — Match < 85%
```
Color del porcentaje: warning (#EF9F27)
Peso: Bold, 28px
Uso: Match parcial — criterio de preferencia no cumplido
```

---

### Inputs

#### `input-field` — Campo de formulario estándar
```
Fondo:          surface-soft (#F4F8FB)
Borde normal:   1px solid border (#D8E2EE)
Borde focus:    1.5px solid wanti-teal (#00B2A9)
Texto:          ink (#0A1F44)
Placeholder:    ink-faint (#94A3B8)
Tipografía:     Nunito 16px / Regular
Radio:          lg (16px)
Padding:        13px 16px
Label arriba:   Nunito 12px / SemiBold / ink-muted
```

#### `otp-box` — Caja de código OTP
```
Dimensiones:    48px × 60px por caja (6 cajas en fila)
Fondo:          surface-soft
Borde normal:   1px solid border
Borde activo:   2px solid wanti-teal
Tipografía:     JetBrains Mono 20px
Radio:          lg (16px)
```

#### `toggle-criterion` — Obligatorio / Preferencia
```
Estado ON (Obligatorio): wanti-teal (#00B2A9)
Estado OFF (Preferencia): border (#D8E2EE)
Dimensiones:   44px × 24px
Radio:         full
```

---

### Tarjetas

#### `card-match` — Resultado de match
```
Fondo:              canvas (#FFFFFF)
Borde match alto:   1.5px solid wanti-teal
Borde match medio:  1.5px solid warning
Radio:              card (16px)
Padding:            16px
Sombra:             card elevation
Estructura:
  — Porcentaje (28px Bold, color según nivel)
  — Título del bien (17px Bold)
  — Subtítulo: ciudad · precio (14px, ink-muted)
  — Tags de criterios cumplidos (badge-required)
  — Nota "Deseable, pero no excluyente" si aplica (11px, warning)
  — CTA Desbloquear (button-primary o button-teal full-width)
```

#### `card-need` — Necesidad activa del comprador
```
Fondo:   canvas
Borde:   1px solid border
Radio:   card (16px)
Padding: 16px
Sombra:  card elevation
Estructura:
  — Título: marca/modelo o tipo de inmueble (17px Bold)
  — Presupuesto (14px, ink-muted)
  — Badge de matches (badge-required)
  — Badge de días restantes (background: surface-soft)
```

#### `card-wallet` — Saldo de Guantes
```
Fondo:   wanti-navy (#0A1F44)
Texto:   on-dark (#FFFFFF)
Radio:   xl (20px)
Padding: 20px 24px
Sombra:  raised elevation
Estructura:
  — Label "Saldo disponible" (12px, white 70% opacidad)
  — Importe "12 🧤" (40px Bold, blanco)
  — Equivalencia COP (12px, white 70% opacidad)
```

#### `card-alert-vendor` — Alerta de match para vendedor
```
Fondo:  canvas
Borde:  1.5px solid wanti-teal
Radio:  card (16px)
Padding: 16px
Estructura:
  — Porcentaje de afinidad grande (48px Bold, wanti-teal)
  — "de afinidad con tu publicación" (13px, ink-muted)
  — Bloque de criterios con badge-required / badge-preferred
  — Presupuesto máximo del comprador (15px Bold, wanti-teal)
  — Nota sobre el proceso de desbloqueo (12px, ink-muted)
```

---

### Navegación

#### `nav-bottom` — Barra de navegación inferior
```
Altura:     83px (incluye safe area)
Fondo:      canvas
Borde top:  1px solid border-light
Ítems:      4 (Inicio, Publicar/Inventario, Matches/Alertas, Wallet/Perfil)
Activo:     wanti-teal — barra superior de 3px + texto teal + ícono teal
Inactivo:   ink-faint — sin barra
Tipografía: Nunito 10px / Regular (inactivo) / SemiBold (activo)
```

#### `header-screen` — Encabezado de pantalla interior
```
Altura:     56px
Offset top: 44px (status bar)
Fondo:      canvas (sin borde inferior)
Atrás:      "←" 20px, ink
Título:     Nunito 17px / Bold, centrado en 390px, ink
```

#### `progress-bar` — Multi-paso en formularios
```
Track:  border-light (#EDF2F7)
Fill:   wanti-teal (#00B2A9)
Altura: 8px
Radio:  full
Ancho:  342px
```

---

### AI Box — Imagen generada por IA
```
Fondo:   surface-teal (#E6F9F8)
Borde:   1.5px dashed wanti-teal (#00B2A9)
Radio:   xl (20px)
Padding: 24px
Alto:    200px
Texto:   "Imagen ilustrativa generada por IA" — 13px SemiBold wanti-teal-dark
Sub:     Descripción de parámetros — 11px, wanti-teal-dark
Uso:     Paso 3/3 del formulario de vehículo e inmueble
```

---

### Panel Admin

#### `admin-metric-tile`
```
Fondo:   surface-soft (#F4F8FB)
Radio:   lg (16px)
Padding: 12px 16px
Valor:   22px Bold — color según métrica (teal = positivo, error = disputa)
Label:   12px Regular, ink-muted
```

#### `admin-action-row`
```
Fondo:        canvas
Borde normal: 1px solid border
Borde alerta: 1.5px solid error-light
Radio:        lg (16px)
Padding:      16px
Ícono:        24px, izquierda
Título:       14px Bold, ink (o error si es alerta)
Subtítulo:    12px Regular, ink-muted (o error)
Flecha:       "→" derecha, ink-faint
```

---

## Patrones de UX

### Criterios obligatorio / preferencia

El sistema de flexibilidad de Wanti es su diferencial de producto. Cada campo parametrizable del formulario lleva un **toggle** que el comprador activa o desactiva:

```
Toggle ON  → badge-required  → color teal → borde de tarjeta teal
Toggle OFF → badge-preferred → color ámbar → borde de tarjeta estándar
```

Si el comprador marca un criterio como **Obligatorio**, el motor de match excluye automáticamente al vendedor que no lo cumple.

Si lo marca como **Preferencia**, el vendedor recibe el match pero con menor porcentaje de afinidad. La tarjeta de match muestra la leyenda:

> *"Deseable, pero no excluyente"* — 11px, warning (#EF9F27)

---

### Wallet de Guantes

La moneda interna de Wanti son los **Guantes** (1 Guante = $5.000 COP). La UI del wallet sigue estas reglas:

- El saldo siempre usa `JetBrains Mono` para el número y emoji 🧤 como ícono de unidad.
- Las entradas positivas (+) usan `wanti-teal`.
- Las salidas negativas (−) usan `ink` (neutro, no rojo — no es un error, es una transacción válida).
- Los reembolsos por disputa aparecen en `wanti-teal` con prefijo "+" para diferenciarlos del desbloqueo normal.

---

### Flujo de verificación OTP

1. El fondo de la pantalla OTP usa `surface-teal` en el header.
2. Seis cajas `otp-box` en fila, la primera con borde teal activo al cargar.
3. Timer en `JetBrains Mono` — cuenta regresiva visible.
4. El CTA de confirmación permanece deshabilitado (navy 40% opacidad) hasta que las 6 cajas estén llenas.
5. Opción secundaria "Enviar por SMS" como `button-ghost`.

---

### Estados de resultado de contacto

Tras desbloquear un contacto, el comprador debe confirmar el resultado. Los tres estados tienen colores semánticos distintos:

| Estado | Color | Uso |
|---|---|---|
| ✅ Compré | `wanti-teal` | Cierre exitoso |
| ⏳ En proceso | `warning` | Negociación activa |
| ❌ No compré | `error` | Lead no convertido |

El estado **Lead inválido** es una acción destructiva: abre un flujo de disputa y usa `error` (`#C0392B`) en texto y borde.

---

## Grilla y layout móvil

- **Ancho de pantalla:** 390px (iPhone 14 reference)
- **Margen horizontal universal:** 24px a cada lado → área de contenido: **342px**
- **Status bar reserva:** 44px en la parte superior
- **Nav bar altura:** 83px en la parte inferior
- **Área de contenido útil:** 390 − 44 − 83 = **717px** de alto

### Pantallas de formulario multi-paso

```
[ Status bar 44px                              ]
[ Header con ← y título 56px                  ]
[ Progress bar 8px + label 14px = 30px         ]
[ ─────────────────────────────────────────── ]
[ Campos apilados — spacing vertical 8px      ]
[ entre label e input, 16px entre campos      ]
[ ─────────────────────────────────────────── ]
[ CTA fijo al fondo — 52px + 24px margen      ]
[ Nav bar 83px                                 ]
```

---

## Íconos

- Sistema de íconos: **Tabler Icons** (thin-line, 24px base)
- Stroke: 1.5px
- Color: `ink-muted` en estado inactivo / `wanti-teal` en estado activo / `on-dark` sobre fondos oscuros
- Íconos clave del sistema:

| Ícono | Nombre Tabler | Uso |
|---|---|---|
| 🏠 Inicio | `ti-home` | Nav — home comprador/vendedor |
| ➕ Publicar | `ti-plus-circle` | Nav — nueva necesidad |
| 💚 Matches | `ti-heart` | Nav — lista de matches |
| 👜 Wallet | `ti-wallet` | Nav — wallet de Guantes |
| 📋 Inventario | `ti-list` | Nav vendedor |
| 🔔 Alertas | `ti-bell` | Nav vendedor |
| 🔓 Desbloquear | `ti-lock-open` | CTA de contacto |
| 💬 WhatsApp | `ti-brand-whatsapp` | CTA de apertura de chat |
| 🚗 Vehículo | `ti-car` | Selector de módulo |
| 🏢 Inmueble | `ti-building` | Selector de módulo |
| ✉ Email | `ti-mail` | Paso de verificación |
| 💬 Celular | `ti-message-circle` | Paso de OTP |
| ✓ Verificado | `ti-circle-check` | Cuenta activa |
| 🤖 IA | `ti-sparkles` | Paso de imagen generada |

---

## Do's y Don'ts

### ✅ Hacer

- Usar `wanti-navy` como color de texto principal y CTA primario.
- Usar `wanti-teal` para estados de éxito, match, verificación y CTAs de acción positiva.
- Usar el radio `pill` (100px) en **todos** los botones CTA.
- Reservar el badge `badge-preferred` (ámbar) exclusivamente para criterios de preferencia — no para advertencias genéricas.
- Mostrar siempre la leyenda *"Deseable, pero no excluyente"* cuando un criterio de preferencia no es cumplido por el vendedor.
- Mantener el margen lateral de `24px` en todas las pantallas.
- Usar `JetBrains Mono` para importes monetarios exactos y códigos OTP.

### ❌ No hacer

- No usar el rojo (`error`) para estados negativos normales — solo para disputas, leads inválidos y errores del sistema.
- No convertir el teal en color de fondo masivo — solo en superficies suaves (`surface-teal`) o en botones de acción positiva.
- No usar pesos de fuente por debajo de 400 ni tipografía en cursiva.
- No mezclar `button-primary` (navy) y `button-teal` como CTAs de igual jerarquía en la misma pantalla.
- No usar sombras por encima del nivel `raised` en elementos que no sean modales.
- No mostrar el porcentaje de match con colores distintos a `wanti-teal` (≥85%) o `warning` (<85%).
- No omitir el espacio de `status-bar` (44px) en pantallas que lo necesitan.

---

## Responsive y multiplataforma

El sistema está diseñado **mobile-first** para apps iOS y Android. Para una futura versión web:

| Breakpoint | Ancho | Adaptación |
|---|---:|---|
| Mobile | 390px | Referencia — sistema actual |
| Tablet | 768px | Dos columnas en formularios y tarjetas |
| Desktop | 1280px | Tres columnas, nav lateral, pantalla dividida comprador/match |

En desktop, el `nav-bottom` se reemplaza por un sidebar de 240px con los mismos ítems e identidad visual.

---

## Guía de implementación rápida

1. **Instala Nunito** vía Google Fonts: `https://fonts.google.com/specimen/Nunito`
2. **Instala JetBrains Mono** vía Google Fonts: `https://fonts.google.com/specimen/JetBrains+Mono`
3. **Instala Tabler Icons** vía npm: `npm install @tabler/icons` o CDN
4. Declara los tokens de color como variables CSS:
   ```css
   :root {
     --color-navy:         #0A1F44;
     --color-teal:         #00B2A9;
     --color-teal-dark:    #007A72;
     --color-teal-mid:     #009490;
     --color-canvas:       #FFFFFF;
     --color-surface-soft: #F4F8FB;
     --color-surface-teal: #E6F9F8;
     --color-warning:      #EF9F27;
     --color-error:        #C0392B;
     --color-ink:          #0A1F44;
     --color-ink-muted:    #4A5568;
     --color-ink-faint:    #94A3B8;
     --color-border:       #D8E2EE;
     --color-border-light: #EDF2F7;
     --radius-card:        16px;
     --radius-pill:        100px;
     --shadow-card:        0 2px 8px rgba(10,31,68,0.06);
     --shadow-raised:      0 4px 16px rgba(10,31,68,0.10);
   }
   ```

---
