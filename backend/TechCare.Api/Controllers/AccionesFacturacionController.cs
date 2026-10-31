
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize]
public sealed class AccionesFacturacionController : ControllerBase
{
    private readonly FacturacionRepository _repo;

    public AccionesFacturacionController(
        FacturacionRepository repo)
    {
        _repo = repo;
    }

    // POST /api/ordenes/{id}/factura
    [HttpPost("ordenes/{id:int}/factura")]
    [Authorize(Policy = "FACTURA_EMITIR")]
    public async Task<IActionResult> Facturar(
        int id,
        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)]
        FacturarOrdenDto? dto)
    {
        if (id <= 0)
        {
            return BadRequest(new
            {
                error = "El identificador de la orden debe ser mayor que cero."
            });
        }

        dto ??= new FacturarOrdenDto();

        var nit = Limpiar(dto.NitFacturacion);
        var nombre = Limpiar(dto.NombreFacturacion);
        var direccion = Limpiar(dto.DireccionFacturacion);

        if (nit?.Length > 15 ||
            nombre?.Length > 150 ||
            direccion?.Length > 250)
        {
            return BadRequest(new
            {
                error = "Los datos de facturacion superan la longitud permitida."
            });
        }

        if (nombre is not null && !Validacion.NombreValido(nombre))
        {
            return BadRequest(new
            {
                error = "El nombre de facturación " + Validacion.MensajeNombre
            });
        }

        if (nit is not null && !Validacion.NitValido(nit))
        {
            return BadRequest(new
            {
                error = "El NIT de facturación debe ser CF o números con su dígito verificador (por ejemplo 1234567-8)."
            });
        }

        var resultado = await _repo.FacturarOrdenAsync(
            id,
            User.IdUsuario(),
            nit,
            nombre,
            direccion);

        return Ok(resultado);
    }

    // POST /api/pagos/{id}/anulacion
    [HttpPost("pagos/{id:int}/anulacion")]
    [Authorize(Policy = "PAGO_REGISTRAR")]
    public async Task<IActionResult> AnularPago(
        int id,
        [FromBody] AnularPagoDto dto)
    {
        if (id <= 0 ||
            string.IsNullOrWhiteSpace(dto.Motivo) ||
            dto.Motivo.Length > 250)
        {
            return BadRequest(new
            {
                error = "Indique un pago valido y un motivo de anulacion de hasta 250 caracteres."
            });
        }

        var resultado = await _repo.AnularPagoAsync(
            id,
            User.IdUsuario(),
            dto.Motivo.Trim());

        return Ok(resultado);
    }

    // POST /api/ordenes/{id}/entrega
    [HttpPost("ordenes/{id:int}/entrega")]
    [Authorize(Policy = "ENTREGA_REGISTRAR")]
    public async Task<IActionResult> Entregar(
        int id,
        [FromBody] EntregarOrdenDto dto)
    {
        if (id <= 0 ||
            string.IsNullOrWhiteSpace(dto.NombreRecibe) ||
            dto.NombreRecibe.Length > 120 ||
            (dto.DocumentoRecibe?.Length ?? 0) > 20 ||
            (dto.Observaciones?.Length ?? 0) > 300)
        {
            return BadRequest(new
            {
                error = "Revise la orden, el nombre de quien recibe y los datos de entrega."
            });
        }

        if (!Validacion.NombreValido(dto.NombreRecibe))
        {
            return BadRequest(new
            {
                error = "El nombre de quien recibe " + Validacion.MensajeNombre
            });
        }

        if (!Validacion.DpiValido(dto.DocumentoRecibe))
        {
            return BadRequest(new
            {
                error = "El DPI de quien recibe debe tener 13 dígitos."
            });
        }

        var resultado = await _repo.EntregarOrdenAsync(
            id,
            User.IdUsuario(),
            dto.NombreRecibe.Trim(),
            Limpiar(dto.DocumentoRecibe),
            Limpiar(dto.Observaciones));

        return Ok(resultado);
    }

    private static string? Limpiar(string? valor)
        => string.IsNullOrWhiteSpace(valor)
            ? null
            : valor.Trim();
}
