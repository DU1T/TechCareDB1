
namespace TechCare.Api.Dtos;

public sealed class GuardarEquipoDto
{
    public int? IdCliente { get; set; }
    public int? IdTipoEquipo { get; set; }
    public int? IdMarca { get; set; }
    public string? Modelo { get; set; }
    public string? NumeroSerie { get; set; }
    public string? Descripcion { get; set; }
    public string? Estado { get; set; }
}
