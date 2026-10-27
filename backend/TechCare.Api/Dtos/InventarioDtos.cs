namespace TechCare.Api.Dtos;

public record AjusteInventarioDto(
    int IdBodega,
    int IdRepuesto,
    int Cantidad,
    string Motivo);

public record LineaCompraDto(
    int IdRepuesto,
    int Cantidad,
    decimal CostoUnitario);

public record CrearCompraDto(
    int IdProveedor,
    int IdBodegaDestino,
    string NumeroDocumento,
    string? Observaciones,
    List<LineaCompraDto>? Lineas);
