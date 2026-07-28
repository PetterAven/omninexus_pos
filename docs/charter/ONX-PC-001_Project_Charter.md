# Avendaño Software
## OmniNexus POS — Project Charter

| Campo | Valor |
|---|---|
| **Código** | ONX-PC-001 |
| **Versión** | 1.0 RC |
| **Fecha** | *(se actualizará con la fecha oficial de emisión)* |
| **Autor** | Avendaño Software |
| **Producto** | OmniNexus POS |
| **Clasificación** | Uso Interno — Avendaño Software |
| **Estado** | Draft para Revisión |
| **Idioma** | Español |

> **Declaración.** Este documento establece la visión, objetivos, alcance, gobernanza y estrategia inicial del producto OmniNexus POS. Su finalidad es servir como documento rector para las decisiones comerciales y de negocio del proyecto. Las especificaciones funcionales y no funcionales detalladas se documentan en **ONX-SRS-001**; el diseño técnico y arquitectónico se documenta en **ONX-SDD-001** y **ONX-ARC-001**.

---

## 1. Control de Versiones

| Versión | Fecha | Responsable | Cambios |
|---|---|---|---|
| 0.1 | Borrador | Avendaño Software | Creación inicial |
| 0.5 | Pendiente | Avendaño Software | Revisión de negocio |
| 0.8 | Pendiente | Avendaño Software | Validación ejecutiva |
| 1.0 RC | Pendiente | Avendaño Software | Versión candidata |
| 1.0 | Pendiente | Avendaño Software | Publicación oficial |

### Historial de Revisiones

| Revisión | Descripción |
|---|---|
| R001 | Creación del documento |
| R002 | Aprobación ejecutiva |
| R003 | Aprobación de negocio |
| R004 | Liberación oficial |

---

## 2. Resumen Ejecutivo y Propósito

### 2.1 Introducción

OmniNexus POS es una plataforma de punto de venta (POS) diseñada para pequeñas y medianas empresas, con un enfoque **offline-first**, sincronización segura con la nube y una experiencia moderna, multiplataforma.

El producto busca ofrecer una solución robusta, escalable y fácil de usar para negocios que requieren continuidad operativa incluso cuando no disponen de conexión a Internet.

### 2.2 Problema

Los sistemas POS disponibles en el mercado presentan, con frecuencia, uno o varios de estos inconvenientes:

- Dependencia constante de Internet para operar.
- Costos elevados de licenciamiento o de renta mensual.
- Escasa capacidad de personalización.
- Soporte y actualizaciones limitados.
- Integraciones limitadas con otras herramientas del negocio.

### 2.3 Solución

OmniNexus POS propone:

- Operación local garantizada, sin depender de la conexión a Internet.
- Sincronización con la nube cuando la conexión está disponible.
- Una base de código preparada para crecer hacia nuevos módulos de negocio.
- Una experiencia de usuario moderna y simple de operar.
- Un modelo de licenciamiento flexible, adaptado al tipo de negocio.

### 2.4 Objetivo Estratégico

Construir un producto comercial capaz de competir dentro del mercado de soluciones POS para PyMEs en México y Latinoamérica, posicionando a Avendaño Software como un proveedor confiable de software empresarial en la región.

---

## 3. Misión, Visión y Valores — Avendaño Software

**Misión.** Desarrollar software empresarial confiable que permita a las pequeñas y medianas empresas optimizar sus operaciones mediante herramientas modernas, seguras y accesibles.

**Visión.** Convertirse en una empresa referente en Latinoamérica en soluciones empresariales multiplataforma, con arquitectura moderna y enfoque offline-first.

**Valores.**

| | | |
|---|---|---|
| Calidad | Transparencia | Innovación |
| Seguridad | Escalabilidad | Simplicidad |
| Orientación al cliente | Mejora continua | |

---

## 4. Alcance Funcional y Trazabilidad Inicial de Requisitos

### 4.1 Alcance de la versión 1.0

**Incluido en v1.0:**

- Gestión de productos.
- Gestión de inventario.
- Punto de venta.
- Gestión de usuarios y autenticación.
- Sincronización con la nube.
- Reportes básicos.
- Configuración del sistema.

**Fuera de alcance de v1.0** (forman parte del roadmap posterior):

- Facturación electrónica.
- CRM.
- Compras y proveedores.
- Multiempresa.
- Inteligencia artificial aplicada al negocio.

### 4.2 Trazabilidad inicial de requisitos (RF-001 a RF-010)

Esta tabla es un punto de partida de alto nivel; la especificación completa, con criterios de aceptación, vive en **ONX-SRS-001**.

| ID | Requisito funcional | Módulo | Prioridad |
|---|---|---|---|
| RF-001 | Registrar, editar y eliminar productos | Inventario | Alta |
| RF-002 | Consultar existencias en tiempo real | Inventario | Alta |
| RF-003 | Registrar una venta desde la Terminal de Ventas | Punto de Venta | Alta |
| RF-004 | Aceptar pagos en efectivo y con tarjeta | Punto de Venta | Alta |
| RF-005 | Generar e imprimir el ticket de venta | Punto de Venta | Alta |
| RF-006 | Autenticar usuarios con distintos roles (ej. Administrador, Cajero) | Usuarios | Alta |
| RF-007 | Cerrar sesión sin dejar datos de la sesión anterior visibles | Usuarios | Alta |
| RF-008 | Sincronizar información local con la nube cuando hay conexión | Sincronización | Alta |
| RF-009 | Operar de forma local cuando no hay conexión a Internet | Sincronización | Alta |
| RF-010 | Generar reportes básicos de ventas | Reportes | Media |

---

## 5. Arquitectura de Alto Nivel y Stack Tecnológico

*(Nivel resumen para fines de negocio y gobierno del proyecto; el diseño técnico detallado se documenta en ONX-SDD-001 y ONX-ARC-001.)*

La solución se basa en una arquitectura por capas, con separación clara entre presentación, gestión de estado, lógica de negocio, acceso a datos y persistencia.

| Tecnología | Justificación de negocio |
|---|---|
| Flutter | Una sola base de código para múltiples plataformas — reduce costo y tiempo de desarrollo. |
| Riverpod | Gestión de estado predecible y comprobable — reduce el riesgo de defectos en producción. |
| SQLite | Persistencia local — sostiene la operación offline-first, un diferenciador clave del producto. |
| Supabase | Autenticación y sincronización como servicio — evita construir y mantener infraestructura propia de backend en esta etapa. |
| GitHub / GitHub Actions | Control de versiones y automatización de integración — sostiene la calidad conforme el equipo crece. |

---

## 6. Análisis del Mercado Objetivo y Modelo de Negocio

### 6.1 Mercado objetivo

**Segmento principal:** pequeñas y medianas empresas.

**Sectores prioritarios:**

- Abarrotes
- Papelerías
- Ferreterías
- Boutiques
- Cafeterías
- Refaccionarias
- Tiendas especializadas

### 6.2 Modelo de negocio

Se propone un modelo híbrido:

**Licencia perpetua** — pensada para negocios que operan completamente en local. Incluye instalación, actualizaciones por un periodo definido y soporte básico.

**SaaS** — pensado para empresas que requieren sincronización, respaldo, operación multi-dispositivo, actualizaciones continuas y servicios en la nube. Este modelo aporta ingresos recurrentes y sostiene la evolución continua del producto.

### 6.3 Stakeholders

| Rol | Responsabilidad |
|---|---|
| Dirección | Definir estrategia |
| Desarrollo | Implementación |
| QA | Validación |
| Clientes | Retroalimentación |
| Soporte | Operación |
| Ventas | Comercialización |

---

## 7. Matriz Inicial de Riesgos y Supuestos

### 7.1 Riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Cambios en APIs externas (Supabase u otras) | Alto | Abstracción mediante repositorios |
| Pérdida de conectividad del cliente final | Alto | Arquitectura offline-first |
| Crecimiento no planificado del producto | Medio | Arquitectura modular |
| Regulaciones fiscales futuras (ej. facturación electrónica) | Medio | Diseño extensible para integración futura |

### 7.2 Supuestos

- El cliente objetivo cuenta con al menos un equipo Windows para operar la Terminal de Ventas.
- La conexión a Internet, cuando existe, es intermitente pero no inexistente.
- El negocio típico opera con uno o pocos puntos de venta en esta primera versión.

---

## 8. KPIs de Éxito

### 8.1 Técnicos

- Compilación sin errores.
- Análisis estático sin advertencias (`flutter analyze --fatal-infos` en 0 issues).
- Cobertura de pruebas automatizadas objetivo ≥ 80%.
- Tiempo de sincronización promedio.
- Tiempo de respuesta de la interfaz.

### 8.2 De negocio

- Clientes activos.
- Licencias vendidas.
- Suscripciones SaaS activas.
- Retención de clientes.
- Tiempo promedio de implementación por cliente.

---

## 9. Referencias

Este documento se relaciona con:

- **ONX-SRS-001** — Software Requirements Specification.
- **ONX-SDD-001** — Software Design Document.
- **ONX-ARC-001** — Architecture Guide.
- **ONX-DB-001** — Database Design.
- **ONX-QA-001** — Testing Guide.
- **ONX-BIZ-001** — Business Plan.

## 10. Aprobaciones

| Rol | Responsable | Estado |
|---|---|---|
| Dirección General | Avendaño Software | Pendiente |
| Negocio / Producto | Avendaño Software | Pendiente |
| Desarrollo | Avendaño Software | Pendiente |