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
                "La operación incumple una regla de integridad de los datos.");
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
