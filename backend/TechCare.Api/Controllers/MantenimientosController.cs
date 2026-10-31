using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Api.Data;
using TechCare.Api.Dtos;
using TechCare.Api.Middleware;

namespace TechCare.Api.Controllers;

[ApiController]
[Route("api")]
[Authorize(Policy = "CATALOGO_GESTIONAR")]
public sealed class MantenimientosController : ControllerBase
{
    private readonly MantenimientosRepository _repo;
    public MantenimientosController(MantenimientosRepository repo) => _repo = repo;

    private static string? Texto(string? valor, int max, string campo, bool obligatorio = true)
    {
        if (obligatorio && string.IsNullOrWhiteSpace(valor))
            return $"{campo} es obligatorio.";
        if (valor?.Length > max)
            return $"{campo} supera {max} caracteres.";
        return null;
    }
    private static string? Estado(string? estado, string activo, string inactivo)
        => estado == activo || estado == inactivo ? null : $"Estado debe ser {activo} o {inactivo}.";
    private static IActionResult Respuesta(object? resultado)
        => resultado is null
            ? new NotFoundObjectResult(new { error = "El registro no existe." })
            : new OkObjectResult(resultado);
    private static bool PrecioValido(decimal? precio)
        => precio.HasValue && precio >= 0 && precio <= 9999999999.99m;
    private static string? ValidarRepuesto(GuardarRepuestoDto d)
        => Texto(d.Codigo,30,"Codigo") ?? Texto(d.Nombre,120,"Nombre")
           ?? Texto(d.Descripcion,300,"Descripcion",false)
           ?? (d.IdCategoria.GetValueOrDefault() <= 0 ? "IdCategoria debe ser positivo." : null)
           ?? (!PrecioValido(d.PrecioCompraRef) || !PrecioValido(d.PrecioVenta) ? "Precios deben ser no negativos y de hasta 10 enteros y 2 decimales." : null)
           ?? (decimal.Round(d.PrecioCompraRef!.Value,2) != d.PrecioCompraRef || decimal.Round(d.PrecioVenta!.Value,2) != d.PrecioVenta ? "Precios aceptan hasta dos decimales." : null)
           ?? Estado(d.Estado,"ACTIVO","INACTIVO");
    private static string? ValidarProveedor(GuardarProveedorDto d)
        => Texto(d.Nit,15,"NIT") ?? Texto(d.Nombre,150,"Nombre")
           ?? Texto(d.Contacto,120,"Contacto",false) ?? Texto(d.Telefono,20,"Telefono",false)
           ?? Texto(d.Email,120,"Email",false) ?? Texto(d.Direccion,250,"Direccion",false)
           ?? Estado(d.Estado,"ACTIVO","INACTIVO");
    private static string? ValidarBodega(GuardarBodegaDto d)
        => Texto(d.Codigo,10,"Codigo") ?? Texto(d.Nombre,80,"Nombre")
           ?? Texto(d.Ubicacion,200,"Ubicacion",false)
           ?? Estado(d.Estado,"ACTIVA","INACTIVA");
    private static IActionResult Error(string mensaje) => new BadRequestObjectResult(new { error = mensaje });

    [HttpPost("categorias")]
    public async Task<IActionResult> CrearCategoria(GuardarCategoriaDto d)
    {
        var error = Texto(d.Nombre,60,"Nombre");
        if (error is not null) return Error(error);
        d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.CrearCategoriaAsync(d));
    }
    [HttpPut("categorias/{id:int}")]
    public async Task<IActionResult> EditarCategoria(int id, GuardarCategoriaDto d)
    {
        var error = Texto(d.Nombre,60,"Nombre");
        if (id <= 0 || error is not null) return Error(error ?? "ID invalido.");
        d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.EditarCategoriaAsync(id,d));
    }

    [HttpPost("tipos-equipo")]
    public async Task<IActionResult> CrearTipo(GuardarTipoEquipoDto d)
    {
        var error = Texto(d.Nombre,50,"Nombre");
        if (error is not null) return Error(error);
        d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.CrearTipoAsync(d));
    }
    [HttpPut("tipos-equipo/{id:int}")]
    public async Task<IActionResult> EditarTipo(int id, GuardarTipoEquipoDto d)
    {
        var error = Texto(d.Nombre,50,"Nombre");
        if (id <= 0 || error is not null) return Error(error ?? "ID invalido.");
        d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.EditarTipoAsync(id,d));
    }

    [HttpPost("marcas")]
    public async Task<IActionResult> CrearMarca(GuardarMarcaDto d)
    {
        var error = Texto(d.Nombre,50,"Nombre");
        if (error is not null) return Error(error);
        d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.CrearMarcaAsync(d));
    }
    [HttpPut("marcas/{id:int}")]
    public async Task<IActionResult> EditarMarca(int id, GuardarMarcaDto d)
    {
        var error = Texto(d.Nombre,50,"Nombre");
        if (id <= 0 || error is not null) return Error(error ?? "ID invalido.");
        d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.EditarMarcaAsync(id,d));
    }

    [HttpPost("proveedores")]
    public async Task<IActionResult> CrearProveedor(GuardarProveedorDto d)
    {
        d.Estado ??= "ACTIVO";
        var error = ValidarProveedor(d);
        if (error is not null) return Error(error);
        d.Nit = d.Nit!.Trim(); d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.CrearProveedorAsync(d));
    }
    [HttpPut("proveedores/{id:int}")]
    public async Task<IActionResult> EditarProveedor(int id, GuardarProveedorDto d)
    {
        var error = ValidarProveedor(d);
        if (id <= 0 || error is not null) return Error(error ?? "ID invalido.");
        d.Nit = d.Nit!.Trim(); d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.EditarProveedorAsync(id,d));
    }

    [HttpPost("bodegas")]
    public async Task<IActionResult> CrearBodega(GuardarBodegaDto d)
    {
        d.Estado ??= "ACTIVA";
        var error = ValidarBodega(d);
        if (error is not null) return Error(error);
        d.Codigo = d.Codigo!.Trim(); d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.CrearBodegaAsync(d));
    }
    [HttpPut("bodegas/{id:int}")]
    public async Task<IActionResult> EditarBodega(int id, GuardarBodegaDto d)
    {
        var error = ValidarBodega(d);
        if (id <= 0 || error is not null) return Error(error ?? "ID invalido.");
        d.Codigo = d.Codigo!.Trim(); d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.EditarBodegaAsync(id,d));
    }

    [HttpPost("repuestos")]
    public async Task<IActionResult> CrearRepuesto(GuardarRepuestoDto d)
    {
        d.Estado ??= "ACTIVO";
        var error = ValidarRepuesto(d);
        if (error is not null) return Error(error);
        d.Codigo = d.Codigo!.Trim(); d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.CrearRepuestoAsync(d));
    }
    [HttpPut("repuestos/{id:int}")]
    public async Task<IActionResult> EditarRepuesto(int id, GuardarRepuestoDto d)
    {
        var error = ValidarRepuesto(d);
        if (id <= 0 || error is not null) return Error(error ?? "ID invalido.");
        d.Codigo = d.Codigo!.Trim(); d.Nombre = d.Nombre!.Trim();
        return Respuesta(await _repo.EditarRepuestoAsync(id,d,User.IdUsuario()));
    }
}
