using System.Data;
using Dapper;

namespace TechCare.Api.Data;

public sealed class ReportesRepository
{
    private readonly SqlConnectionFactory _db;

    public ReportesRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    // Reporte 1: Ordenes activas
    public async Task<IEnumerable<dynamic>> OrdenesActivasAsync(
        string? estado,
        string? prioridad,
        int? idTecnico)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_01_OrdenesActivas",
            new
            {
                estado,
                prioridad,
                idTecnico
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 2: Historial de cliente
    public async Task<IEnumerable<dynamic>> HistorialClienteAsync(
        int? idCliente,
        string? nit)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_02_HistorialCliente",
            new
            {
                idCliente,
                nit
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 3: Historial tecnico por numero de serie
    public async Task<IEnumerable<dynamic>> HistorialEquipoAsync(
        string numeroSerie)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_03_HistorialEquipo",
            new
            {
                numeroSerie
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 4: Productividad por tecnico
    public async Task<IEnumerable<dynamic>> ProductividadTecnicoAsync(
        int? idTecnico,
        DateTime? fechaInicio,
        DateTime? fechaFin)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_04_ProductividadTecnico",
            new
            {
                idTecnico,
                fechaInicio,
                fechaFin
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 5: Repuestos utilizados con costo y venta historicos
    public async Task<IEnumerable<dynamic>> RepuestosUtilizadosAsync(
        DateTime? fechaInicio,
        DateTime? fechaFin,
        int? idTecnico,
        int? idBodega)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_05_RepuestosUtilizados",
            new
            {
                fechaInicio,
                fechaFin,
                idTecnico,
                idBodega
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 6: Inventario actual por bodega y categoria
    public async Task<IEnumerable<dynamic>> InventarioAsync(
        int? idBodega,
        int? idCategoria)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_06_Inventario",
            new
            {
                idBodega,
                idCategoria
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 7: Repuestos en o bajo el stock minimo
    public async Task<IEnumerable<dynamic>> BajoMinimoAsync(
        int? idBodega)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_07_BajoMinimo",
            new
            {
                idBodega
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 8: Compras por proveedor con detalle
    public async Task<IEnumerable<dynamic>> ComprasProveedorAsync(
        int? idProveedor,
        DateTime? fechaInicio,
        DateTime? fechaFin,
        string? estado)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_08_ComprasProveedor",
            new
            {
                idProveedor,
                fechaInicio,
                fechaFin,
                estado
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 9: Kardex por bodega y repuesto
    public async Task<IEnumerable<dynamic>> KardexAsync(
        int? idBodega,
        int? idRepuesto,
        DateTime? fechaInicio,
        DateTime? fechaFin)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_09_Kardex",
            new
            {
                idBodega,
                idRepuesto,
                fechaInicio,
                fechaFin
            },
            commandType: CommandType.StoredProcedure);
    }


    // Reporte 10: facturas con saldo y pagos relacionados
    public async Task<object> FacturasSaldoAsync(
        bool incluirPagadas,
        int? idCliente,
        DateTime? fechaInicio,
        DateTime? fechaFin)
    {
        await using var cn = _db.Create();

        using var resultados = await cn.QueryMultipleAsync(
            "dbo.sp_Reporte_10_FacturasSaldo",
            new
            {
                soloConSaldo = !incluirPagadas,
                idCliente,
                fechaInicio,
                fechaFin
            },
            commandType: CommandType.StoredProcedure);

        var facturas = (await resultados.ReadAsync<dynamic>())
            .ToList();

        var pagos = (await resultados.ReadAsync<dynamic>())
            .ToList();

        return new
        {
            facturas,
            pagos
        };
    }

    // Reporte 11: ingresos agrupados por periodo
    public async Task<IEnumerable<dynamic>> IngresosPeriodoAsync(
        DateTime? fechaInicio,
        DateTime? fechaFin)
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            "dbo.sp_Reporte_11_IngresosPeriodo",
            new
            {
                fechaInicio,
                fechaFin
            },
            commandType: CommandType.StoredProcedure);
    }

    // Reporte 12: trazabilidad completa de una orden
    public async Task<object> TrazabilidadAsync(int idOrden)
    {
        await using var cn = _db.Create();

        using var resultados = await cn.QueryMultipleAsync(
            "dbo.sp_Reporte_12_Trazabilidad",
            new { idOrden },
            commandType: CommandType.StoredProcedure);

        var encabezado =
            await resultados.ReadFirstOrDefaultAsync<dynamic>();

        var repuestos =
            (await resultados.ReadAsync<dynamic>()).ToList();

        var movimientos =
            (await resultados.ReadAsync<dynamic>()).ToList();

        var pagos =
            (await resultados.ReadAsync<dynamic>()).ToList();

        var historial =
            (await resultados.ReadAsync<dynamic>()).ToList();

        return new
        {
            encabezado,
            repuestos,
            movimientos,
            pagos,
            historial
        };
    }




}