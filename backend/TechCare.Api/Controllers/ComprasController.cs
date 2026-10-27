using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/compras")]
[Authorize]
public sealed class ComprasController : ControllerBase
{
    private static readonly string[] Estados =
        ["PENDIENTE", "RECIBIDA", "ANULADA"];

    private readonly InventarioRepository _repo;

    public ComprasController(InventarioRepository repo)
    {
        _repo = repo;
    }

    [HttpGet]
    [Authorize(Policy = "REPORTE_VER")]
    public async Task<IActionResult> Listar(
        [FromQuery] string? estado,
        [FromQuery] int? idProveedor)
    {
        if (estado is not null && !Estados.Contains(estado))
        {
            return BadRequest(new
            {
                error = "El estado debe ser PENDIENTE, RECIBIDA o ANULADA."
            });
        }

        return Ok(await _repo.ComprasAsync(estado, idProveedor));
    }

    [HttpPost]
    [Authorize(Policy = "COMPRA_REGISTRAR")]
    public async Task<IActionResult> Crear(CrearCompraDto dto)
    {
        if (dto.IdProveedor <= 0 ||
            dto.IdBodegaDestino <= 0 ||
            string.IsNullOrWhiteSpace(dto.NumeroDocumento) ||
            dto.NumeroDocumento.Length > 30 ||
            (dto.Observaciones?.Length ?? 0) > 300)
        {
            return BadRequest(new
            {
                error = "Revise el proveedor, la bodega, el número de documento y las observaciones."
            });
        }

        if (dto.Lineas is null || dto.Lineas.Count == 0)
        {
            return BadRequest(new
            {
                error = "La compra debe tener al menos una línea."
            });
        }

        if (dto.Lineas.Any(l =>
                l.IdRepuesto <= 0 ||
                l.Cantidad <= 0 ||
                l.CostoUnitario < 0))
        {
            return BadRequest(new
            {
                error = "Cada línea necesita un repuesto, una cantidad mayor que cero y un costo no negativo."
            });
        }

        if (dto.Lineas
                .GroupBy(l => l.IdRepuesto)
                .Any(g => g.Count() > 1))
        {
            return BadRequest(new
            {
                error = "Un repuesto solo puede aparecer una vez en la compra."
            });
        }

        var resultado = await _repo.CrearCompraAsync(
            dto,
            User.IdUsuario());

        return Ok(resultado);
    }

    [HttpPost("{id:int}/recepcion")]
    [Authorize(Policy = "COMPRA_RECIBIR")]
    public async Task<IActionResult> Recibir(int id)
    {
        if (id <= 0)
        {
            return BadRequest(new
            {
                error = "El identificador de la compra no es válido."
            });
        }

        var resultado = await _repo.RecibirCompraAsync(
            id,
            User.IdUsuario());

        return Ok(resultado);
    }
}
