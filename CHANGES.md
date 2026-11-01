# HubParking — actualización de interfaz y edición

Esta carpeta es una copia del proyecto del Escritorio. El original no fue modificado.
Abrir HubParking.xcodeproj: esta aplicación utiliza Supabase mediante Swift Package Manager.

## Cambios
- Home con dos tarjetas de acceso a FLL y MIA, contadores y búsqueda global.
- Selector de autos con búsqueda por marca, modelo o matrícula y una lista estable durante la selección.
- Identidad estable de las secciones de búsqueda; se eliminó la modificación de estado durante el renderizado.
- Nuevo botón Edit en las tarjetas activas: editar/borrar notas, agregar varias fotos y eliminar cualquier foto individual con confirmación.
- Las eliminaciones de fotos se aplican inmediatamente; Cancel no revierte esas eliminaciones. Las notas y las fotos nuevas se guardan con Save.
- Actualización de notas limitada a su columna para evitar sobrescribir fotos y otros datos.
- Se envía NULL explícitamente al borrar notas o la última foto.
- IBIS agregado a los garages de MIA.
- Tarjetas con jerarquía tipográfica y esquinas renovadas.

## Verificación
- Compilación del esquema HubParking para iOS Simulator sin firma.
- Pendiente: revisión visual y pruebas con una cuenta real en simulador o iPhone. No se ejecutaron escrituras contra Supabase durante el desarrollo.

## Prueba manual sugerida
1. Home: abrir FLL/MIA, comprobar contadores y buscar una matrícula.
2. Add: buscar un auto, desplazarse y seleccionarlo sin saltos; seleccionar MIA > IBIS.
3. En una tarjeta de prueba, editar notas y luego borrarlas; cerrar y volver a abrir.
4. Agregar dos fotos, guardar, cerrar y volver a abrir. Borrar la segunda foto; verificar que permanece la primera. Borrar la última y comprobar que desaparece también tras recargar.
5. Comprobar que recogida e historial siguen funcionando y que los cambios sobreviven al reinicio.

## Gestión de vehículos
Settings > Manage Vehicles permite buscar, agregar, editar y eliminar vehículos.
Campos: marca, modelo, matrícula y AirTag opcional. La matrícula se normaliza a mayúsculas y se comprueba contra la flota antes de guardar.
La edición conserva el ID y la fecha original del vehículo. El borrado requiere confirmación y se bloquea si hay estacionamientos, historial o cambios offline pendientes asociados.
No se modificaron las políticas RLS ni el esquema de Supabase. Los permisos existentes deben permitir INSERT/UPDATE/DELETE sobre vehicles; si no, se muestra el error sin descartar el formulario.
Las comprobaciones de referencias y matrículas se realizan desde el cliente: las restricciones de la base de datos siguen siendo necesarias para garantizar integridad ante cambios simultáneos de varios dispositivos.
Pendiente: probar alta, edición, quitar AirTag y borrado con una cuenta real; no se escribieron datos de producción durante esta tarea.

## Segunda revisión — Home, History, AirTags y juegos
- Home ocupa el espacio disponible con tres accesos verticales: MIA, FLL, OFFICE.
- Selector superior MIA/FLL/OFFICE dentro de las listas de estacionamientos.
- OFFICE disponible al estacionar, con garage Office. Ibis normalizado en nuevos registros y presentación.
- Notas sin lápiz independiente: edición centralizada en Edit.
- Galería con swipe, miniaturas, contador y reintento de carga por foto.
- Add incluye Home y Done en el teclado.
- History con filtros de ubicación y últimos 7/30 días, búsqueda ampliada, resumen y agrupación diaria según created_at (fallback date_parked). Detalle conserva fotos y Return to Parking.
- AirTags permite agregar, editar y quitar asignaciones; no crea un inventario independiente de dispositivos sin auto.
- Juegos: dos dados recuperados y Snake con controles, pausa, mejor puntuación y pausa al pasar a segundo plano.

### Requisito pendiente: archivado en Supabase
Ejecutar Migrations/001_archive_vehicles.sql una vez desde el SQL Editor de Supabase.
La app quita los vehículos de la flota activa usando is_archived, conservando la fila para que estacionamientos e historial sigan funcionando. Hasta aplicar el SQL, quitar vehículos mostrará un error de columna faltante. Las demás funciones siguen usando el esquema existente.
Las versiones antiguas de la app no filtran archivados; actualizar el equipo a esta versión para ocultarlos en todos los dispositivos.
No se modificó el esquema ni datos remotos desde esta sesión.

## Home, barra inferior y Face ID
- Home vacía la ruta de navegación incluso cuando ya es la pestaña seleccionada.
- La barra es una región separada del contenido, con fondo opaco hasta el borde inferior; las listas quedan recortadas antes de la barra.
- Face ID/Touch ID opcional después de validar el PIN con el interruptor Enable Face ID on this iPhone.
- El identificador vinculado se guarda en Keychain con biometryCurrentSet y accesibilidad WhenPasscodeSetThisDeviceOnly. El PIN no se guarda en Keychain ni UserDefaults.
- Use PIN / Switch user permanece disponible. Para cambiar la identidad vinculada se valida el PIN y se activa de nuevo la opción biométrica.
- Incluye NSFaceIDUsageDescription para Debug y Release. Validación en iPhone pendiente; compilación de simulador no verifica biometría real.
