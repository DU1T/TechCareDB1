//Este middleware hará que los errores de los procedimientos almacenados se traduzcan a respuestas HTTP
// que mostrar en la interfaz
using Microsoft.Data.SqlClient;

namespace TechCare.Api.Middleware;

public sealed class SqlErrorMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<SqlErrorMiddleware> _logger;

    public SqlErrorMiddleware(
        RequestDelegate next,
        ILogger<SqlErrorMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (SqlException ex) when (
            ex.Number >= 50000 && ex.Number <= 51099)
        {
            _logger.LogWarning(
                "Error de negocio SQL {Codigo}",
                ex.Number);

            await Responder(
                context,
                StatusCodes.Status409Conflict,
                ex.Message);
        }
        catch (SqlException ex) when (
            ex.Number is 2627 or 2601 or 547)
        {
            _logger.LogWarning(
                "Error de integridad SQL {Codigo}",
                ex.Number);

            await Responder(
                context,
                StatusCodes.Status409Conflict,
                MensajeIntegridad(ex));
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error inesperado durante la solicitud.");

            await Responder(
                context,
                StatusCodes.Status500InternalServerError,
                "Ocurrió un error inesperado.");
        }
    }

    // SQL Server menciona el nombre de la restricción o del índice en su mensaje:
    // con él se explica qué dato está repetido, sin mostrar el mensaje crudo al usuario
    private static readonly (string Restriccion, string Mensaje)[] Repetidos =
    {
        ("UX_Cliente_Nit", "Ya existe un cliente con ese NIT."),
        ("UX_Usuario_Email", "Ya existe un usuario con ese correo."),
        ("UQ_Usuario_Username", "Ya existe un usuario con ese nombre de usuario."),
        ("UQ_Equipo_NumeroSerie", "Ya existe un equipo con ese número de serie."),
        ("UQ_Repuesto_Codigo", "Ya existe un repuesto con ese código."),
        ("UQ_Bodega_Codigo", "Ya existe una bodega con ese código."),
        ("UQ_Proveedor_Nit", "Ya existe un proveedor con ese NIT."),
        ("UQ_Compra_ProveedorDocumento", "Ya existe una compra de ese proveedor con ese número de documento."),
        ("UQ_CategoriaRepuesto_Nombre", "Ya existe una categoría con ese nombre."),
        ("UQ_TipoEquipo_Nombre", "Ya existe un tipo de equipo con ese nombre."),
        ("UQ_Marca_Nombre", "Ya existe una marca con ese nombre."),
        ("UQ_Factura_Orden", "La orden ya tiene una factura."),
        ("UQ_Entrega_Orden", "La orden ya fue entregada."),
        ("UQ_Diagnostico_Orden", "La orden ya tiene un diagnóstico."),
        ("UQ_Reparacion_Diagnostico", "El diagnóstico ya tiene una reparación."),
    };

    private static string MensajeIntegridad(SqlException ex)
    {
        if (ex.Number is 2627 or 2601)
        {
            foreach (var (restriccion, mensaje) in Repetidos)
            {
                if (ex.Message.Contains(restriccion, StringComparison.OrdinalIgnoreCase))
                    return mensaje;
            }

            return "Ya existe un registro con esos datos.";
        }

        // 547: todas las restricciones CHECK del modelo se llaman CK_*; las demás son llaves foráneas
        return ex.Message.Contains("CK_", StringComparison.OrdinalIgnoreCase)
            ? "Algún dato no cumple las reglas del sistema (valor fuera de rango o no permitido)."
            : "El registro hace referencia a un dato que no existe o que está en uso.";
    }

    private static async Task Responder(
        HttpContext context,
        int status,
        string mensaje)
    {
        if (context.Response.HasStarted)
        {
            throw new InvalidOperationException(
                "No es posible cambiar una respuesta ya iniciada.");
        }

        context.Response.Clear();
        context.Response.StatusCode = status;

        await context.Response.WriteAsJsonAsync(
            new { error = mensaje });
    }
}
