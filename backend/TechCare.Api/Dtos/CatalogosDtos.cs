namespace TechCare.Api.Dtos;

public sealed class GuardarCategoriaDto
{
    public string? Nombre { get; set; }
}

public sealed class GuardarTipoEquipoDto
{
    public string? Nombre { get; set; }
}

public sealed class GuardarMarcaDto
{
    public string? Nombre { get; set; }
}

public sealed class GuardarProveedorDto
{
    public string? Nit { get; set; }
    public string? Nombre { get; set; }
    public string? Contacto { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? Direccion { get; set; }
    public string? Estado { get; set; }
}

public sealed class GuardarBodegaDto
{
    public string? Codigo { get; set; }
    public string? Nombre { get; set; }
    public string? Ubicacion { get; set; }
    public string? Estado { get; set; }
}

public sealed class GuardarRepuestoDto
{
    public string? Codigo { get; set; }
    public string? Nombre { get; set; }
    public string? Descripcion { get; set; }
    public int? IdCategoria { get; set; }
    public decimal? PrecioCompraRef { get; set; }
    public decimal? PrecioVenta { get; set; }
    public string? Estado { get; set; }
}
