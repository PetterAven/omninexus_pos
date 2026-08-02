# 🛒 Omninexus POS

Sistema de Punto de Venta (POS) multiplataforma desarrollado en **Flutter**.  
Soporta ventas offline, sincronización con Supabase y está estructurado con **Clean Architecture**.

## Características

- Ventas offline con SQLite
- Sincronización automática cuando hay conexión
- Arquitectura limpia (Domain / Data / Presentation)
- Multiplataforma (Android, iOS, Web, Desktop)
- Integración con Supabase

## Arquitectura

```text
lib/
 ├── core/                  # Constantes, temas y estado global
 ├── data/                  # Datasources y repositorios
 │   ├── datasources/local/
 │   └── repositories/
 ├── domain/                # Entidades y contratos
 │   ├── entities/
 │   └── repositories/
 ├── presentation/          # UI (pantallas y widgets)
 ├── services/              # Supabase, Telegram, etc.
 └── main.dart
