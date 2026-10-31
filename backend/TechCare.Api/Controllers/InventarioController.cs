using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api/inventario")]
[Authorize]
public sealed class InventarioController : ControllerBase
{
    private static readonly string[] EstadosStock =
        ["OK", "BAJO_MINIMO", "SIN_STOCK"];

    private readonly InventarioRepository _repo;

    public InventarioController(InventarioRepository repo)
    {
        _repo = repo;
    }

    [HttpGet]
    [Authorize(Policy = "REPORTE_VER")]
    public async Task<IActionResult> Listar(
        [FromQuery] int? idBodega,
        [FromQuery] int? idCategoria,
        [FromQuery] string? estadoStock)
    {
        if (estadoStock is not null &&
            !EstadosStock.Contains(estadoStock))
        {
            return BadRequest(new
            {
                error = "El estado de stock debe ser OK, BAJO_MINIMO o SIN_STOCK."
            });
        }

        return Ok(await _repo.InventarioAsync(
            idBodega,
            idCategoria,
            estadoStock));
    }

    [HttpGet("kardex")]
    [Authorize(Policy = "REPORTE_VER")]
    public async Task<IActionResult> Kardex(
        [FromQuery] int? idBodega,
        [FromQuery] int? idRepuesto,
        [FromQuery] DateOnly? fechaInicio,
        [FromQuery] DateOnly? fechaFin)
    {
        if (fechaInicio > fechaFin)
        {
            return BadRequest(new
            {
                error = "La fecha inicial no puede ser posterior a la fecha final."
            });
        }

        return Ok(await _repo.KardexAsync(
            idBodega,
            idRepuesto,
            fechaInicio,
            fechaFin));
    }

    [HttpPost("ajuste")]
    [Authorize(Policy = "CATALOGO_GESTIONAR")]
    public async Task<IActionResult> Ajuste(AjusteInventarioDto dto)
    {
        if (dto.IdBodega <= 0 ||
            dto.IdRepuesto <= 0 ||
            dto.Cantidad == 0 ||
            Math.Abs((long)dto.Cantidad) > Validacion.CantidadMaxima ||
            string.IsNullOrWhiteSpace(dto.Motivo) ||
            dto.Motivo.Length > 250)
        {
            return BadRequest(new
            {
                error = "Indique bodega, repuesto, una cantidad distinta de cero (hasta 10,000) y el motivo (máximo 250 caracteres)."
            });
        }

        var resultado = await _repo.AjusteAsync(
            dto,
            User.IdUsuario());

        return Ok(resultado);
    }
}
