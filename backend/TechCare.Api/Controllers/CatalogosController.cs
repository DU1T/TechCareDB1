// Listas de solo lectura para los filtros y formularios de inventario y compras
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize(Policy = "REPORTE_VER")]
public sealed class CatalogosController : ControllerBase
{
    private readonly InventarioRepository _repo;

    public CatalogosController(InventarioRepository repo)
    {
        _repo = repo;
    }

    [HttpGet("bodegas")]
    public async Task<IActionResult> Bodegas()
        => Ok(await _repo.BodegasAsync());

    [HttpGet("categorias")]
    public async Task<IActionResult> Categorias()
        => Ok(await _repo.CategoriasAsync());

    [HttpGet("proveedores")]
    public async Task<IActionResult> Proveedores()
        => Ok(await _repo.ProveedoresAsync());

    [HttpGet("repuestos")]
    public async Task<IActionResult> Repuestos([FromQuery] int? idCategoria)
        => Ok(await _repo.RepuestosAsync(idCategoria));
}
