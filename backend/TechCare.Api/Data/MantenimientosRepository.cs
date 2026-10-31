using System.Data;
using Dapper;
using TechCare.Api.Dtos;

namespace TechCare.Api.Data;

public sealed class MantenimientosRepository
{
    private readonly SqlConnectionFactory _db;
    public MantenimientosRepository(SqlConnectionFactory db) => _db = db;

    private async Task<object?> EjecutarAsync(string sql, object parametros, bool crear)
    {
        await using var cn = _db.Create();
        if (crear)
        {
            int id = await cn.ExecuteScalarAsync<int>(sql, parametros);
            return new { id };
        }
        int filas = await cn.ExecuteAsync(sql, parametros);
        return filas == 0 ? null : new { actualizado = true };
    }

    public Task<object?> CrearCategoriaAsync(GuardarCategoriaDto d) => EjecutarAsync(
        "INSERT INTO dbo.CategoriaRepuesto(nombre) OUTPUT INSERTED.idCategoria VALUES (@Nombre);",
        d, true);
    public Task<object?> EditarCategoriaAsync(int id, GuardarCategoriaDto d) => EjecutarAsync(
        "UPDATE dbo.CategoriaRepuesto SET nombre=@Nombre WHERE idCategoria=@id;",
        new { id, d.Nombre }, false);

    public Task<object?> CrearTipoAsync(GuardarTipoEquipoDto d) => EjecutarAsync(
        "INSERT INTO dbo.TipoEquipo(nombre) OUTPUT INSERTED.idTipoEquipo VALUES (@Nombre);",
        d, true);
    public Task<object?> EditarTipoAsync(int id, GuardarTipoEquipoDto d) => EjecutarAsync(
        "UPDATE dbo.TipoEquipo SET nombre=@Nombre WHERE idTipoEquipo=@id;",
        new { id, d.Nombre }, false);

    public Task<object?> CrearMarcaAsync(GuardarMarcaDto d) => EjecutarAsync(
        "INSERT INTO dbo.Marca(nombre) OUTPUT INSERTED.idMarca VALUES (@Nombre);",
        d, true);
    public Task<object?> EditarMarcaAsync(int id, GuardarMarcaDto d) => EjecutarAsync(
        "UPDATE dbo.Marca SET nombre=@Nombre WHERE idMarca=@id;",
        new { id, d.Nombre }, false);

    public Task<object?> CrearProveedorAsync(GuardarProveedorDto d) => EjecutarAsync(
        """
        INSERT INTO dbo.Proveedor(nit,nombre,contacto,telefono,email,direccion,estado)
        OUTPUT INSERTED.idProveedor
        VALUES(@Nit,@Nombre,@Contacto,@Telefono,@Email,@Direccion,@Estado);
        """, d, true);
    public Task<object?> EditarProveedorAsync(int id, GuardarProveedorDto d) => EjecutarAsync(
        """
        UPDATE dbo.Proveedor SET nit=@Nit,nombre=@Nombre,contacto=@Contacto,
        telefono=@Telefono,email=@Email,direccion=@Direccion,estado=@Estado
        WHERE idProveedor=@id;
        """, new { id, d.Nit,d.Nombre,d.Contacto,d.Telefono,d.Email,d.Direccion,d.Estado }, false);

    public Task<object?> CrearBodegaAsync(GuardarBodegaDto d) => EjecutarAsync(
        """
        INSERT INTO dbo.Bodega(codigo,nombre,ubicacion,estado)
        OUTPUT INSERTED.idBodega VALUES(@Codigo,@Nombre,@Ubicacion,@Estado);
        """, d, true);
    public Task<object?> EditarBodegaAsync(int id, GuardarBodegaDto d) => EjecutarAsync(
        """
        UPDATE dbo.Bodega SET codigo=@Codigo,nombre=@Nombre,
        ubicacion=@Ubicacion,estado=@Estado WHERE idBodega=@id;
        """, new { id, d.Codigo,d.Nombre,d.Ubicacion,d.Estado }, false);

    public Task<object?> CrearRepuestoAsync(GuardarRepuestoDto d) => EjecutarAsync(
        """
        INSERT INTO dbo.Repuesto(codigo,nombre,descripcion,idCategoria,precioCompraRef,precioVenta,estado)
        OUTPUT INSERTED.idRepuesto
        VALUES(@Codigo,@Nombre,@Descripcion,@IdCategoria,@PrecioCompraRef,@PrecioVenta,@Estado);
        """, d, true);

    // Importante: el trigger de auditoría lee SESSION_CONTEXT en esta MISMA conexión.
    // Actualización de precio por UPDATE normal; nunca modifica Inventario.existencia.
    public async Task<object?> EditarRepuestoAsync(int id, GuardarRepuestoDto d, int idUsuario)
    {
        await using var cn = _db.Create();
        await cn.OpenAsync();
        try
        {
            await cn.ExecuteAsync("dbo.sp_EstablecerContexto",
                new { idUsuario }, commandType: CommandType.StoredProcedure);
            int filas = await cn.ExecuteAsync(
                """
                UPDATE dbo.Repuesto SET codigo=@Codigo,nombre=@Nombre,
                descripcion=@Descripcion,idCategoria=@IdCategoria,
                precioCompraRef=@PrecioCompraRef,precioVenta=@PrecioVenta,estado=@Estado
                WHERE idRepuesto=@id;
                """,
                new { id,d.Codigo,d.Nombre,d.Descripcion,d.IdCategoria,d.PrecioCompraRef,d.PrecioVenta,d.Estado });
            return filas == 0 ? null : new { actualizado = true };
        }
        finally
        {
            await cn.ExecuteAsync("dbo.sp_EstablecerContexto",
                new { idUsuario = (int?)null }, commandType: CommandType.StoredProcedure);
        }
    }
}
