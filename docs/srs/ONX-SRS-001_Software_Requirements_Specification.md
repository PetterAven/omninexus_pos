# Avendaño Software
## OmniNexus POS — Software Requirements Specification

| Campo | Valor |
|---|---|
| **Código** | ONX-SRS-001 |
| **Versión** | 1.0 RC |
| **Fecha** | *(se actualizará con la fecha oficial de emisión)* |
| **Autor** | Avendaño Software |
| **Producto** | OmniNexus POS |
| **Clasificación** | Uso Interno — Avendaño Software |
| **Estado** | Draft para Revisión |
| **Idioma** | Español |
| **Documento relacionado** | ONX-PC-001 — Project Charter |

---

## 1. Control de Versiones e Historial de Revisiones

| Versión | Fecha | Responsable | Cambios |
|---|---|---|---|
| 0.1 | Borrador | Avendaño Software | Creación inicial |
| 0.5 | Pendiente | Avendaño Software | Revisión de requisitos por módulo |
| 0.8 | Pendiente | Avendaño Software | Validación técnica |
| 1.0 RC | Pendiente | Avendaño Software | Versión candidata |
| 1.0 | Pendiente | Avendaño Software | Publicación oficial |

| Revisión | Descripción |
|---|---|
| R001 | Creación del documento |
| R002 | Revisión de requisitos funcionales |
| R003 | Revisión de requisitos no funcionales |
| R004 | Aprobación técnica y liberación |

---

## 2. Introducción, Propósito y Alcance

### 2.1 Propósito

Este documento especifica los requisitos funcionales y no funcionales del producto **OmniNexus POS v1.0**, a un nivel de detalle suficiente para guiar el diseño técnico (ONX-SDD-001), la arquitectura (ONX-ARC-001) y las pruebas (ONX-QA-001).

Sustituye, para efectos de requisitos detallados, cualquier mención equivalente en **ONX-PC-001**, que se mantiene únicamente a nivel de visión y negocio.

### 2.2 Alcance del documento

Este SRS cubre los módulos incluidos en el alcance funcional de la versión 1.0 definido en ONX-PC-001:

- Autenticación & Sesión
- Terminal de Ventas / Carrito
- Gestión de Inventario
- Sincronización y `SyncStatus`

Quedan fuera de este documento — por estar fuera del alcance de v1.0 — los requisitos de facturación electrónica, CRM, compras/proveedores, multiempresa e inteligencia artificial.

### 2.3 Definiciones y convenciones

| Término | Significado |
|---|---|
| RF | Requisito Funcional |
| RNF | Requisito No Funcional |
| UC | Caso de Uso |
| Cajero | Usuario con rol operativo en la Terminal de Ventas |
| Administrador | Usuario con permisos de gestión de inventario y usuarios |
| Offline-first | El sistema opera con normalidad sin conexión a Internet, y sincroniza cuando la conexión está disponible |

---

## 3. Requisitos Funcionales

### 3.1 Módulo: Autenticación & Sesión

| ID | Requisito | Descripción |
|---|---|---|
| RF-001 | Inicio de sesión | El sistema debe permitir a un usuario autenticarse con usuario y contraseña. |
| RF-002 | Roles de usuario | El sistema debe distinguir, al menos, entre rol Administrador y rol Cajero, y habilitar/restringir funciones según el rol activo. |
| RF-003 | Migración de contraseñas heredadas | Si una cuenta existente tiene la contraseña almacenada en texto plano, el sistema debe migrarla automáticamente a un hash seguro en el primer inicio de sesión exitoso, sin intervención del usuario. |
| RF-004 | Cierre de sesión sin fuga de estado | El sistema debe permitir cerrar sesión desde la Terminal de Ventas invalidando el carrito y el cobro en curso, de forma que el siguiente usuario que inicie sesión no vea datos de la sesión anterior. |

### 3.2 Módulo: Terminal de Ventas / Carrito

| ID | Requisito | Descripción |
|---|---|---|
| RF-005 | Agregar producto al carrito | El sistema debe permitir agregar un producto al carrito por búsqueda o por código de barras, respetando el stock disponible. |
| RF-006 | Ajustar cantidad en el carrito | El sistema debe permitir incrementar o decrementar la cantidad de un producto en el carrito, sin exceder el stock disponible ni permitir cantidades menores a 1 (al llegar a 0, el producto se retira del carrito). |
| RF-007 | Calcular el total del carrito | El sistema debe calcular y mostrar el total del carrito como la suma de los subtotales (precio × cantidad) de cada producto, actualizándose ante cualquier cambio en el carrito. |
| RF-008 | Cobrar en efectivo | El sistema debe permitir registrar un cobro en efectivo, validar que el monto recibido cubra el total, y calcular el cambio a entregar. |
| RF-009 | Cobrar con tarjeta | El sistema debe permitir registrar un cobro con tarjeta, sin requerir cálculo de cambio. |

### 3.3 Módulo: Gestión de Inventario

| ID | Requisito | Descripción |
|---|---|---|
| RF-010 | Alta de producto | El sistema debe permitir dar de alta un producto nuevo (código, nombre, precio, stock), rechazando altas con un código ya existente. |
| RF-011 | Edición de producto | El sistema debe permitir editar los datos de un producto existente (nombre, precio, stock) sin alterar su código. |
| RF-012 | Baja de producto | El sistema debe permitir eliminar un producto del inventario, dejando de mostrarlo en búsquedas posteriores. |

### 3.4 Módulo: Sincronización y `SyncStatus`

| ID | Requisito | Descripción |
|---|---|---|
| RF-013 | Sincronización con la nube | El sistema debe intentar reflejar en la nube toda alta, edición o baja de productos, ventas y usuarios, sin bloquear la operación local si la sincronización falla. |
| RF-014 | Aviso de estado de sincronización | El sistema debe exponer, de forma reactiva, si la última sincronización fue exitosa o no, para que cualquier pantalla relevante (ej. Inventario) pueda mostrar un aviso al usuario sin acoplarse al ciclo de vida de otro módulo. |
| RF-015 | Reintento diferido | Cuando una operación no pudo sincronizarse por falta de conexión, el sistema debe conservar el cambio localmente para que quede disponible en la siguiente sincronización exitosa. |

---

## 4. Requisitos No Funcionales

| ID | Categoría | Requisito |
|---|---|---|
| RNF-001 | Rendimiento | Las operaciones sobre el carrito (agregar, incrementar, decrementar, calcular total) deben reflejarse en la interfaz en menos de 50 ms, al ser operaciones en memoria sin espera de red o disco. |
| RNF-002 | Disponibilidad offline | El sistema debe permitir registrar ventas, consultar y modificar inventario, e iniciar sesión, sin conexión a Internet. |
| RNF-003 | Seguridad de credenciales | Las contraseñas deben almacenarse siempre como hash (bcrypt), nunca en texto plano, incluyendo las cuentas migradas por RF-003. |
| RNF-004 | Aislamiento de sesión | Al cerrar sesión, el estado de los providers de carrito y cobro debe invalidarse explícitamente (`ref.invalidate`), de forma que ningún dato de la sesión anterior sobreviva en memoria para el siguiente usuario. |
| RNF-005 | Concurrencia local | Las escrituras a la base de datos local (SQLite) deben mantener consistencia cuando ocurren en secuencia rápida (ej. varias ventas seguidas, o una venta mientras corre una sincronización en segundo plano). |
| RNF-006 | Tolerancia a fallas de red | Ante un error de red o de Supabase, el sistema debe degradar a modo local automáticamente, sin mostrar errores bloqueantes al usuario operativo. |
| RNF-007 | Mantenibilidad | El código debe pasar `flutter analyze --fatal-infos` con 0 incidencias antes de cada entrega. |
| RNF-008 | Portabilidad | La base de código debe permitir agregar plataformas adicionales a Windows en el futuro sin reescritura de la lógica de negocio, apoyándose en la naturaleza multiplataforma de Flutter. |

---

## 5. Casos de Uso Críticos y Límites del Sistema

### 5.1 Actores

- **Cajero** — opera la Terminal de Ventas.
- **Administrador** — gestiona inventario y usuarios.
- **Supabase** — sistema externo de sincronización y autenticación en la nube.
- **Servicio de impresión / PDF** — sistema externo (plugin nativo) para emitir el ticket de venta.
- **Telegram** — sistema externo para el envío opcional del ticket al cliente vinculado.

### 5.2 Casos de uso críticos

| ID | Caso de uso | Actor principal | Resumen |
|---|---|---|---|
| UC-01 | Registrar una venta en efectivo | Cajero | El cajero arma el carrito, cobra en efectivo, el sistema calcula el cambio, registra la venta y emite el ticket. |
| UC-02 | Registrar una venta con tarjeta | Cajero | El cajero arma el carrito, cobra con tarjeta, el sistema registra la venta y emite el ticket sin cálculo de cambio. |
| UC-03 | Iniciar sesión | Cajero / Administrador | El usuario ingresa credenciales; el sistema valida contra la base local y, si aplica, migra la contraseña a hash. |
| UC-04 | Cerrar sesión | Cajero / Administrador | El usuario cierra sesión; el sistema limpia el carrito y el cobro en curso antes de regresar a la pantalla de inicio de sesión. |
| UC-05 | Dar de alta un producto | Administrador | El administrador captura los datos del producto; el sistema valida que el código no exista y lo agrega al inventario local y remoto. |
| UC-06 | Sincronizar tras reconexión | Sistema (automático) | Al recuperar conexión, el sistema reintenta reflejar en la nube los cambios pendientes y actualiza el estado de sincronización. |

### 5.3 Límites del sistema

**Dentro del sistema (in scope):** Terminal de Ventas, carrito, cobro, inventario, autenticación local, sincronización con Supabase, generación del ticket.

**Fuera del sistema (actores externos, no se rediseñan en este SRS):** el propio backend de Supabase, el servicio de Telegram, el subsistema de impresión térmica/PDF del sistema operativo, y el hardware del punto de venta (escáner, impresora).

```
                 ┌───────────────────────────┐
   Cajero  ───▶  │                           │
                 │      OmniNexus POS        │ ───▶  Supabase (nube)
Administrador ─▶ │ (Terminal de Ventas,      │ ───▶  Telegram (ticket)
                 │  Inventario, Sesión,      │ ───▶  Impresión / PDF
                 │  Sincronización)          │
                 └───────────────────────────┘
```

---

## 6. Matriz de Trazabilidad Inicial

*Requisito → Módulo → Pruebas unitarias.* Se referencian los archivos de prueba ya existentes en el repositorio; las pruebas de módulos aún no cubiertas quedan marcadas como pendientes.

| Requisito | Módulo | Pruebas unitarias |
|---|---|---|
| RF-001, RF-003 | Autenticación & Sesión | `test/database_helper_test.dart` (AuthRepository: registro, login, migración de contraseña heredada) |
| RF-002 | Autenticación & Sesión | Pendiente (cobertura de reglas de rol) |
| RF-004 | Autenticación & Sesión | Verificación manual documentada (Sprint 4, Paso 1); pendiente de test automatizado dedicado |
| RF-005, RF-006, RF-007 | Terminal de Ventas / Carrito | `test/cart_controller_test.dart` (`addProduct`, `increaseQuantity`, `decreaseQuantity`, `cartTotalProvider`) |
| RF-008 | Terminal de Ventas / Carrito | `test/checkout_controller_test.dart` (validación de `payCash` con monto insuficiente) |
| RF-009 | Terminal de Ventas / Carrito | Pendiente — camino feliz de `payCard` fuera de cobertura automática (Opción A) |
| RF-010, RF-011, RF-012 | Gestión de Inventario | `test/product_controller_test.dart` (`addProduct`, `updateProduct`, `deleteProduct`) y `test/database_helper_test.dart` (ProductRepository) |
| RF-013, RF-015 | Sincronización | `test/database_helper_test.dart` (modo offline vía Supabase falso) |
| RF-014 | Sincronización y `SyncStatus` | Verificado manualmente en modo offline (Sprint 4, Paso 2); pendiente de test automatizado dedicado |

---

## 7. Referencias

- **ONX-PC-001** — Project Charter.
- **ONX-SDD-001** — Software Design Document.
- **ONX-ARC-001** — Architecture Guide.
- **ONX-QA-001** — Testing Guide.

## 8. Aprobaciones

| Rol | Responsable | Estado |
|---|---|---|
| Dirección General | Avendaño Software | Pendiente |
| Arquitectura | Avendaño Software | Pendiente |
| Desarrollo | Avendaño Software | Pendiente |
| Control de Calidad | Avendaño Software | Pendiente |