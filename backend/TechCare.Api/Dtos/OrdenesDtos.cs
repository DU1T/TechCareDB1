namespace TechCare.Api.Dtos;

public record CrearOrdenDto(
    int IdEquipo,
    string ProblemaReportado,
    string Prioridad,
    DateOnly? FechaEstimada,
    string? Observaciones
);

public record RegistrarDiagnosticoDto(
    string Descripcion,
    decimal CostoManoObraEstimado
);

public record RegistrarAutorizacionDto(
    bool? Autorizado);

public record IniciarReparacionDto();

public record RegistrarActividadDto(
    string Descripcion,
    decimal Horas);

public record FinalizarReparacionDto(
    string DescripcionTrabajo,
    decimal CostoManoObra);