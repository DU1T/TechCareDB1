namespace TechCare.Api.Dtos;

public sealed class RegistrarPagoDto
{
    public int? IdMetodoPago { get; set; }

    public decimal? Monto { get; set; }

    public string? Referencia { get; set; }
}