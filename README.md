# 🛒 Omninexus POS

Sistema de Punto de Venta (POS) multiplataforma desarrollado en **Flutter**, diseñado bajo principios de **Clean Architecture**, resiliencia **Offline-First** y sincronización en tiempo real.

---

## 🏛️ Arquitectura del Sistema

El proyecto sigue una arquitectura limpia en capas desacopladas, lo que garantiza testabilidad, escalabilidad y mantenibilidad.

```text
lib/
 ├── core/                  # Constantes globales, temas y sincronización de estado
 ├── data/                  # Fuentes de datos y repositorios concretos
 │   ├── datasources/local/ # Persistencia SQLite (app_database.dart)
 │   └── repositories/      # Implementaciones con fallback offline (Supabase + SQLite)
 ├── domain/                # Lógica de negocio e interfaces
 │   ├── entities/          # Product, Sale, SaleDetail, AppUser
 │   └── repositories/      # Contratos (Interfaces abstractas)
 ├── presentation/          # Capa de interfaz de usuario (Pantallas y Widgets)
 ├── services/              # Integraciones externas (Telegram, Supabase Client)
 └── main.dart              # Punto de entrada