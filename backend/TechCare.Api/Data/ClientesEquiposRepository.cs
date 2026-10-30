using TechCare.Api.Dtos;
using Dapper;

namespace TechCare.Api.Data;

public sealed class ClientesEquiposRepository
{
    private readonly SqlConnectionFactory _db;

    public ClientesEquiposRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    public async Task<IEnumerable<dynamic>> ListarClientesAsync(
        string? buscar)
    {
        await using var cn = _db.Create();

        const string sql = """
            SELECT
                idCliente,
                tipoCliente,
                nit,
                nombre,
                telefono,
                email,
                direccion,
                estado,
                fechaRegistro
            FROM dbo.Cliente
            WHERE @buscar IS NULL
               OR nombre LIKE '%' + @buscar + '%'
               OR nit LIKE '%' + @buscar + '%'
            ORDER BY nombre, idCliente;
            """;

        return await cn.QueryAsync(sql, new { buscar });
    }

    public async Task<object?> DetalleClienteAsync(int id)
    {
        await using var cn = _db.Create();

        const string sql = """
            SELECT
                idCliente,
                tipoCliente,
                nit,
                nombre,
                telefono,
                email,
                direccion,
                estado,
                fechaRegistro
            FROM dbo.Cliente
            WHERE idCliente = @id;
            """;

        return await cn.QueryFirstOrDefaultAsync(
            sql, new { id });
    }

    public async Task<IEnumerable<dynamic>> ListarEquiposAsync(
        int? idCliente)
    {
        await using var cn = _db.Create();

        const string sql = """
            SELECT
                e.idEquipo,
                e.idCliente,
                c.nombre AS cliente,
                e.idTipoEquipo,
                te.nombre AS tipoEquipo,
                e.idMarca,
                m.nombre AS marca,
                e.modelo,
                e.numeroSerie,
                e.descripcion,
                e.estado,
                e.fechaRegistro
            FROM dbo.Equipo AS e
            INNER JOIN dbo.Cliente AS c
                ON c.idCliente = e.idCliente
            INNER JOIN dbo.TipoEquipo AS te
                ON te.idTipoEquipo = e.idTipoEquipo
            INNER JOIN dbo.Marca AS m
                ON m.idMarca = e.idMarca
            WHERE @idCliente IS NULL
               OR e.idCliente = @idCliente
            ORDER BY e.idEquipo DESC;
            """;

        return await cn.QueryAsync(sql, new { idCliente });
    }

    public async Task<object?> DetalleEquipoAsync(int id)
    {
        await using var cn = _db.Create();

        const string sql = """
            SELECT
                e.idEquipo,
                e.idCliente,
                c.nombre AS cliente,
                e.idTipoEquipo,
                te.nombre AS tipoEquipo,
                e.idMarca,
                m.nombre AS marca,
                e.modelo,
                e.numeroSerie,
                e.descripcion,
                e.estado,
                e.fechaRegistro
            FROM dbo.Equipo AS e
            INNER JOIN dbo.Cliente AS c
                ON c.idCliente = e.idCliente
            INNER JOIN dbo.TipoEquipo AS te
                ON te.idTipoEquipo = e.idTipoEquipo
            INNER JOIN dbo.Marca AS m
                ON m.idMarca = e.idMarca
            WHERE e.idEquipo = @id;
            """;

        return await cn.QueryFirstOrDefaultAsync(
            sql, new { id });
    }


    // Registrar cliente
    public async Task<object> CrearClienteAsync(
        GuardarClienteDto dto)
    {
        await using var cn = _db.Create();

        const string sql = """
            INSERT INTO dbo.Cliente
                (tipoCliente, nit, nombre, telefono,
                 email, direccion, estado)
            OUTPUT
                INSERTED.idCliente,
                INSERTED.tipoCliente,
                INSERTED.nit,
                INSERTED.nombre,
                INSERTED.estado
            VALUES
                (@tipoCliente, @nit, @nombre, @telefono,
                 @email, @direccion, @estado);
            """;

        return await cn.QuerySingleAsync(sql, new
        {
            tipoCliente = dto.TipoCliente,
            nit = dto.Nit,
            nombre = dto.Nombre,
            telefono = dto.Telefono,
            email = dto.Email,
            direccion = dto.Direccion,
            estado = dto.Estado ?? "ACTIVO"
        });
    }

    // Actualizar cliente existente
    public async Task<object?> ActualizarClienteAsync(
        int id,
        GuardarClienteDto dto)
    {
        await using var cn = _db.Create();

        const string sql = """
            UPDATE dbo.Cliente
            SET tipoCliente = @tipoCliente,
                nit = @nit,
                nombre = @nombre,
                telefono = @telefono,
                email = @email,
                direccion = @direccion,
                estado = COALESCE(@estado, estado)
            OUTPUT
                INSERTED.idCliente,
                INSERTED.tipoCliente,
                INSERTED.nit,
                INSERTED.nombre,
                INSERTED.estado
            WHERE idCliente = @id;
            """;

        return await cn.QuerySingleOrDefaultAsync(sql, new
        {
            id,
            tipoCliente = dto.TipoCliente,
            nit = dto.Nit,
            nombre = dto.Nombre,
            telefono = dto.Telefono,
            email = dto.Email,
            direccion = dto.Direccion,
            estado = dto.Estado
        });
    }

    // Registrar equipo
    public async Task<object> CrearEquipoAsync(
        GuardarEquipoDto dto)
    {
        await using var cn = _db.Create();

        const string sql = """
            INSERT INTO dbo.Equipo
                (idCliente, idTipoEquipo, idMarca,
                 modelo, numeroSerie, descripcion, estado)
            OUTPUT
                INSERTED.idEquipo,
                INSERTED.idCliente,
                INSERTED.numeroSerie,
                INSERTED.estado
            VALUES
                (@idCliente, @idTipoEquipo, @idMarca,
                 @modelo, @numeroSerie, @descripcion, @estado);
            """;

        return await cn.QuerySingleAsync(sql, new
        {
            idCliente = dto.IdCliente,
            idTipoEquipo = dto.IdTipoEquipo,
            idMarca = dto.IdMarca,
            modelo = dto.Modelo,
            numeroSerie = dto.NumeroSerie,
            descripcion = dto.Descripcion,
            estado = dto.Estado ?? "ACTIVO"
        });
    }

    // Actualizar equipo existente
    public async Task<object?> ActualizarEquipoAsync(
        int id,
        GuardarEquipoDto dto)
    {
        await using var cn = _db.Create();

        const string sql = """
            UPDATE dbo.Equipo
            SET idCliente = @idCliente,
                idTipoEquipo = @idTipoEquipo,
                idMarca = @idMarca,
                modelo = @modelo,
                numeroSerie = @numeroSerie,
                descripcion = @descripcion,
                estado = COALESCE(@estado, estado)
            OUTPUT
                INSERTED.idEquipo,
                INSERTED.idCliente,
                INSERTED.numeroSerie,
                INSERTED.estado
            WHERE idEquipo = @id;
            """;

        return await cn.QuerySingleOrDefaultAsync(sql, new
        {
            id,
            idCliente = dto.IdCliente,
            idTipoEquipo = dto.IdTipoEquipo,
            idMarca = dto.IdMarca,
            modelo = dto.Modelo,
            numeroSerie = dto.NumeroSerie,
            descripcion = dto.Descripcion,
            estado = dto.Estado
        });
    }

}
