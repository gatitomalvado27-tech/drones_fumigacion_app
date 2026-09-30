# Reglas y Memoria del Proyecto: Ícaro Proagro (Drones Fumigación App)

## 1. Directrices Generales de Antigravity
- **Idioma:** Responder siempre en español al usuario de forma predeterminada.
- **Claridad:** Mantener explicaciones claras, precisas y concisas.
- **Enlaces Clickables:** Incluir enlaces en markdown usando el esquema `file://` para cualquier archivo o símbolo modificado (ejemplo: `[archivo.dart](file:///c:/Users/ASUS/drones_fumigacion_app/lib/...)`).
- **Análisis de Código:** Ejecutar `flutter analyze` tras realizar modificaciones en Dart para garantizar 0 errores y 0 warnings.

---

## 2. Identidad del Proyecto y Tecnologías
- **Aplicación:** **Ícaro Proagro** - Gestión operativa, aeronáutica, agronómica y financiera para empresas de servicios agrícolas con drones (DJI Agras T40, T30, etc.).
- **Stack Técnico:** Flutter (SDK Dart 3.13+), Firebase Firestore (`cloud_firestore: ^6.9.0`), SharedPreferences, PDF & Printing (`pdf`, `printing`), Image Picker (`image_picker`), FL Chart (`fl_chart`), Table Calendar (`table_calendar`).
- **Control de Versiones y Release:** GitHub CLI (`gh`), repositorio `gatitomalvado27-tech/drones_fumigacion_app`.

---

## 3. Pipeline de Actualizaciones Automáticas (OTA)
- **Script Oficial:** [`scripts/publicar_actualizacion.ps1`](file:///c:/Users/ASUS/drones_fumigacion_app/scripts/publicar_actualizacion.ps1)
- **Comando de Ejecución:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\publicar_actualizacion.ps1 -Notas "• Novedad 1`n• Novedad 2"
  ```
- **Flujo Automático del Script:**
  1. Lee y aumenta la versión en [`pubspec.yaml`](file:///c:/Users/ASUS/drones_fumigacion_app/pubspec.yaml) (ejemplo: `1.0.6+7` -> `1.0.7+8`).
  2. Compila el APK Release (`flutter build apk --release`).
  3. Crea commit, tag y release en GitHub con el APK adjunto vía `gh release create`.
  4. Actualiza en tiempo real el documento Firestore `app_config/actualizacion` con la URL de descarga directa y las notas.
  5. Los usuarios reciben de inmediato la ventana emergente en la app para actualizar sin pasar por Google Play.

---

## 4. Arquitectura de Datos (Colecciones Firestore)

| Colección | Propósito Principal | Modelo Dart Asociado |
| :--- | :--- | :--- |
| `servicios` | Órdenes de fumigación y vuelos programados/completados (`clienteNombre`, `hectareas`, `precioTotal`, `saldoPendiente`, `pagado`, `estado`, `fecha`, `cultivo`, `piloto`, `dron`). | [`ServicioModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/servicio_model.dart) |
| `transacciones` | Asientos contables de caja y bancos (`tipo`: `'INGRESO'` o `'EGRESO'`, `monto`, `metodoPago`, `categoria`, `servicioId`, `fecha`, `descripcion`, `usuario`). | [`TransaccionModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/transaccion_model.dart) |
| `bitacoras_vuelo` | Bitácoras agronómicas de vuelo post-servicio (`servicioId`, `hectareasReales`, `tiempoVueloMinutos`, `bateriasUtilizadas`, `climaCondicion`, `novedades`). | [`BitacoraVueloModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/bitacora_vuelo_model.dart) |
| `bitacoras_danos` | Bitácora especializada de averías y mantenimiento (`categoriaEquipo`: `DRON`, `CAMIONETA`, `GENERADOR`, `BATERIAS`, `gravedad`: `LEVE`/`MODERADA`/`CRITICA`, `estado`: `REPORTADO`/`EN_REPARACION`/`REPARADO`, `fotosBase64`, `videoUrl`, `costoReparacion`, `piezasCambiadas`). | [`BitacoraDanoEquipoModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/bitacora_dano_equipo_model.dart) |
| `repuestos_vida_util` | Monitoreo del ciclo de vida y desgaste de piezas (`categoriaEquipo`, `tipoMedicion`: `HORAS`, `HECTAREAS`, `KILOMETRAJE`, `CICLOS`, `DIAS`, `usoActual`, `vidaUtilEstimada`, `costoAdquisicion`, `historialReemplazos`). | [`RepuestoVidaUtilModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/repuesto_vida_util_model.dart) |
| `bodega` | Inventario de insumos (químicos, repuestos, EPP, combustible) con control de stock y costo unitario. | [`BodegaItemModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/bodega_item_model.dart) |
| `pilotos` | Catálogo de pilotos y técnicos del equipo con su estado operativo. | [`PilotoModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/piloto_model.dart) |
| `app_config/actualizacion` | Documento único con los metadatos de versión para actualización remota. | [`AppVersionModel`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/models/app_version_model.dart) |

---

## 5. Mapa de Pantallas y Componentes Clave

- **Dashboard:** [`DashboardScreen`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/screens/dashboard_screen.dart)
  - Vista principal con clima en vivo, métricas rápidas de tareas y accesos directos a **Bitácoras**, **Daños** y **Repuestos**.
- **Cronograma de Vuelos:** [`CronogramaScreen`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/screens/cronograma_screen.dart)
  - Operación en tiempo real. Al marcar un vuelo como `COMPLETADO`, invoca automáticamente [`RegistroCobroServicioDialog`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/widgets/registro_cobro_servicio_dialog.dart).
- **Contabilidad y Finanzas:** [`ContabilidadScreen`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/screens/contabilidad_screen.dart)
  - Pestaña 1: Balance de caja líquida y cuentas bancarias, con **Tarjeta de Conciliación Automática** para vuelos completados sin cobro registrado.
  - Pestaña 2: Cuentas por Cobrar (Cartera general de clientes).
  - Pestaña 3: Cierres y balances mensuales archivables.
- **Historial Unificado de Bitácoras:** [`BitacorasHistorialScreen`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/screens/bitacoras_historial_screen.dart)
  - **Pestaña 1:** Vuelos y Campo (informes agronómicos de lotes y mezcla).
  - **Pestaña 2:** Daños en Equipos (averías con fotos, videos, WhatsApp y Ficha Técnica PDF).
  - **Pestaña 3:** Vida Útil Repuestos (monitoreo de desgaste, alertas y reemplazos).
- **Daños e Inspección de Equipos:** [`BitacoraDanosScreen`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/screens/bitacora_danos_screen.dart)
  - Filtros por equipo (`DRON`, `CAMIONETA`, etc.) y estado, visor de fotos, enlace a video y botón directo a **Ficha PDF**.
- **Vida Útil de Repuestos:** [`RepuestosVidaUtilScreen`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/screens/repuestos_vida_util_screen.dart)
  - Barras de progreso, botón `+ Sumar Uso`, botón `Reemplazar` con archivo de historial y asiento en contabilidad.
- **Servicio de PDF:** [`PdfService`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/services/pdf_service.dart)
  - Generación de Órdenes de Servicio, Balances Financieros, Estados de Cuenta, Cartera y la **Ficha Técnica Oficial de Daños e Inspección**.
- **Diálogos Clave:**
  - [`RegistroCobroServicioDialog`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/widgets/registro_cobro_servicio_dialog.dart): Cobro total, abono parcial o crédito.
  - [`RegistroBitacoraDialog`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/widgets/registro_bitacora_dialog.dart): Registro agronómico de vuelo.
  - [`RegistroDanoEquipoDialog`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/widgets/registro_dano_equipo_dialog.dart): Captura de daños, fotos y video.
  - [`RegistroRepuestoDialog`](file:///c:/Users/ASUS/drones_fumigacion_app/lib/widgets/registro_repuesto_dialog.dart): Alta y reemplazo de repuestos.

---

## 6. Reglas de Negocio Esenciales
1. **Regla Contable de Vuelos:** Ningún vuelo debe quedar en `COMPLETADO` sin haber registrado su cobro en `transacciones` o asignado su saldo a cartera. La tarjeta de conciliación en Contabilidad previene desajustes.
2. **Imágenes en Base64:** Para evitar dependencias externas o configuraciones de storage adicionales, las fotos se comprimen y guardan en Base64 directamente en Firestore.
3. **Mantenimiento vs Contabilidad:** Al registrar un costo de reparación o reemplazo de repuestos, el sistema ofrece asentar automáticamente un `EGRESO` contable bajo la categoría `'MANTENIMIENTO'`.
