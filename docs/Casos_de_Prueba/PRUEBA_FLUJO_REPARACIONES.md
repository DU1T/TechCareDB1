TechCare — Preparación y prueba del flujo de reparaciones

Objetivo

Permitir que cualquier integrante, especialmente A, reproduzca en su base local el flujo:

RECIBIDO → DIAGNOSTICO → ESPERANDO_AUTORIZACION → REPARACION → LISTO.

Incluye autorización del cliente, registro de actividades y finalización de reparación.

1. Requisitos

SQL Server local y SSMS.

Repositorio TechCare actualizado con los seis procedimientos de database/41_sp_ordenes.sql.

Base local de A: TechCare_Front.

API .NET 8 configurada con conexión a la base local.

Usuarios de prueba generados mediante 80_datos_usuarios.sql.

No ejecutar estas pruebas sobre Azure.

2. Preparar la base local

Reconstruir TechCare_Front siguiendo database/README.md y el script reconstruir.ps1 del proyecto.

Ejecutar 80_datos_usuarios.sql para cargar usuarios y roles.

Ejecutar 81_datos_maestros.sql para cargar clientes y equipos.

Ejecutar el archivo completo 41_sp_ordenes.sql de la rama que incorpora las reparaciones.

Comprobar que existen seis procedimientos: registrar orden, diagnóstico, autorización, inicio de reparación, actividad y finalización.

El archivo 82_datos_compras.sql puede ejecutarse conforme al orden de carga grupal, pero no es imprescindible para probar una reparación sin repuestos.

No es necesario ejecutar 83_datos_ordenes.sql para esta prueba específica, ya que se creará una orden nueva.

3. Preparar la API

Configurar mediante dotnet user-secrets la conexión ConnectionStrings:TechCare apuntando a TechCare_Front y una clave JWT local.

Iniciar la API:

dotnet run --launch-profile http

Abrir Swagger en http://localhost:5080/swagger.

4. Ejecución del caso exitoso

Utilizar los usuarios de prueba recepcion1 y tecnico1, con la contraseña de demostración documentada en el proyecto.

Recepción: crear una orden para un equipo sin órdenes previas mediante POST /api/ordenes.

Técnico: registrar el diagnóstico mediante POST /api/ordenes/{id}/diagnostico.

Recepción: autorizar la reparación mediante POST /api/ordenes/{id}/autorizacion, enviando {"autorizado":true}.

Técnico: iniciar la reparación mediante POST /api/ordenes/{id}/reparacion.

Técnico: registrar dos actividades mediante POST /api/reparaciones/{id}/actividades, con 1.50 y 0.75 horas.

Técnico: finalizar la reparación mediante POST /api/reparaciones/{id}/finalizar, indicando un costo de mano de obra de 250.00.

Guardar los identificadores de orden y reparación devueltos por la API. No asumir que ambos serán 1.

5. Resultados esperados

Orden en estado LISTO.

Reparación en estado FINALIZADA.

Costo final de mano de obra de 250.00.

Dos actividades consecutivas.

Cinco registros en el historial de cambios de estado.

Fecha de finalización registrada.

6. Pruebas negativas

Intentar iniciar una reparación sin autorización: HTTP 409.

Intentar registrar una actividad después de finalizar: HTTP 409.

Intentar finalizar dos veces la misma reparación: HTTP 409.

Comprobar que los intentos rechazados no alteraron los datos.

7. Evidencia

Guardar resultados de Swagger y SSMS, indicando fecha, identificadores utilizados y resultado esperado/obtenido.

El archivo T03_flujo_reparacion.sql sirve como verificación de resultados. Para ejecutarlo sobre una base distinta, debe utilizarse el identificador de la orden creada en esa base en lugar del valor local original.

8. Alcance

Esta prueba valida el flujo técnico de órdenes y reparaciones. No incluye facturación, pagos, entrega, inventario de repuestos ni pruebas exhaustivas de concurrencia.