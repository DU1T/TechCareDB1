
using Microsoft.Data.SqlClient;

namespace TechCare.Api.Data;

public sealed class SqlConnectionFactory
{
    private readonly IConfiguration _configuration;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public SqlConnection Create()
    {
        string connectionString =
            _configuration.GetConnectionString("TechCare")
            ?? throw new InvalidOperationException(
                "No se configuró la conexión a TechCare.");

        return new SqlConnection(connectionString);
    }
}
