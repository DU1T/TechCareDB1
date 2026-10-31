
using Dapper;
using TechCare.Api.Dtos;

namespace TechCare.Api.Data;

public sealed class UsuariosRepository
{
    private readonly SqlConnectionFactory _db;

    public UsuariosRepository(SqlConnectionFactory db)
    {
        _db = db;
    }

    private sealed class UsuarioFila
    {
        public int IdUsuario { get; set; }
        public string Username { get; set; } = "";
        public string NombreCompleto { get; set; } = "";
        public string? Email { get; set; }
        public string? Telefono { get; set; }
        public string Estado { get; set; } = "";
        public DateTime FechaCreacion { get; set; }
    }

    private sealed class RolFila
    {
        public int IdUsuario { get; set; }
        public int IdRol { get; set; }
        public string Nombre { get; set; } = "";
    }

    public async Task<object[]> ListarAsync()
    {
        await using var cn = _db.Create();

        var usuarios = (await cn.QueryAsync<UsuarioFila>(
            """
            SELECT idUsuario, username, nombreCompleto,
                   email, telefono, estado, fechaCreacion
            FROM dbo.Usuario
            ORDER BY idUsuario;
            """)).ToList();

        var roles = (await cn.QueryAsync<RolFila>(
            """
            SELECT ur.idUsuario, r.idRol, r.nombre
            FROM dbo.UsuarioRol ur
            JOIN dbo.Rol r ON r.idRol = ur.idRol;
            """)).ToList();

        return usuarios.Select(u => (object)new
        {
            u.IdUsuario,
            u.Username,
            u.NombreCompleto,
            u.Email,
            u.Telefono,
            u.Estado,
            u.FechaCreacion,
            roles = roles
                .Where(r => r.IdUsuario == u.IdUsuario)
                .Select(r => new { r.IdRol, r.Nombre })
                .ToList()
        }).ToArray();
    }

    public async Task<object?> DetalleAsync(int id)
    {
        var usuarios = await ListarAsync();

        return usuarios.FirstOrDefault(u =>
            (int)u.GetType().GetProperty("IdUsuario")!
                .GetValue(u)! == id);
    }

    public async Task<IEnumerable<dynamic>> RolesAsync()
    {
        await using var cn = _db.Create();

        return await cn.QueryAsync(
            """
            SELECT idRol, nombre, descripcion
            FROM dbo.Rol
            ORDER BY idRol;
            """);
    }

    private static async Task ValidarRolesAsync(
        System.Data.Common.DbConnection cn,
        System.Data.Common.DbTransaction tx,
        List<int> ids)
    {
        var encontrados = await cn.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*)
            FROM dbo.Rol
            WHERE idRol IN @ids;
            """,
            new { ids },
            tx);

        if (encontrados != ids.Count)
            throw new ArgumentException(
                "Uno o varios roles no existen.");
    }

    public async Task<int> CrearAsync(
        CrearUsuarioDto dto,
        string passwordHash)
    {
        await using var cn = _db.Create();
        await cn.OpenAsync();
        await using var tx = await cn.BeginTransactionAsync();

        try
        {
            var roles = dto.IdRoles!.Distinct().ToList();

            await ValidarRolesAsync(cn, tx, roles);

            int id = await cn.QuerySingleAsync<int>(
                """
                INSERT INTO dbo.Usuario
                    (username, passwordHash, nombreCompleto,
                     email, telefono, estado)
                OUTPUT INSERTED.idUsuario
                VALUES
                    (@username, @passwordHash, @nombreCompleto,
                     @email, @telefono, 'ACTIVO');
                """,
                new
                {
                    username = dto.Username,
                    passwordHash,
                    nombreCompleto = dto.NombreCompleto,
                    email = dto.Email,
                    telefono = dto.Telefono
                },
                tx);

            foreach (int idRol in roles)
            {
                await cn.ExecuteAsync(
                    """
                    INSERT INTO dbo.UsuarioRol(idUsuario, idRol)
                    VALUES (@id, @idRol);
                    """,
                    new { id, idRol },
                    tx);
            }

            await tx.CommitAsync();
            return id;
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }

    public async Task<bool> ActualizarAsync(
        int id,
        ActualizarUsuarioDto dto,
        string? passwordHash)
    {
        await using var cn = _db.Create();
        await cn.OpenAsync();
        await using var tx = await cn.BeginTransactionAsync();

        try
        {
            var roles = dto.IdRoles!.Distinct().ToList();

            await ValidarRolesAsync(cn, tx, roles);

            int afectados = await cn.ExecuteAsync(
                """
                UPDATE dbo.Usuario
                SET username = @username,
                    nombreCompleto = @nombreCompleto,
                    email = @email,
                    telefono = @telefono,
                    estado = @estado,
                    passwordHash =
                        COALESCE(@passwordHash, passwordHash)
                WHERE idUsuario = @id;
                """,
                new
                {
                    id,
                    username = dto.Username,
                    nombreCompleto = dto.NombreCompleto,
                    email = dto.Email,
                    telefono = dto.Telefono,
                    estado = dto.Estado,
                    passwordHash
                },
                tx);

            if (afectados == 0)
            {
                await tx.RollbackAsync();
                return false;
            }

            await cn.ExecuteAsync(
                """
                DELETE FROM dbo.UsuarioRol
                WHERE idUsuario = @id;
                """,
                new { id },
                tx);

            foreach (int idRol in roles)
            {
                await cn.ExecuteAsync(
                    """
                    INSERT INTO dbo.UsuarioRol(idUsuario, idRol)
                    VALUES (@id, @idRol);
                    """,
                    new { id, idRol },
                    tx);
            }

            await tx.CommitAsync();
            return true;
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }
}
