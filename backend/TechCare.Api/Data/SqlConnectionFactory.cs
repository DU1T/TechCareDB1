
using Microsoft.Data.SqlClient;

namespace TechCare.Api.Data;

public sealed class SqlConnectionFactory
{
    // Azure SQL serverless se pausa sin uso: la primera conexión falla con 40613
    // mientras despierta. Se reintenta solo al ABRIR la conexión (nunca se
    // re-ejecuta un SP), hasta 5 veces con espera creciente (~30 s en total).
    private static readonly SqlRetryLogicBaseProvider Reintentos =
        SqlConfigurableRetryFactory.CreateExponentialRetryProvider(new SqlRetryLogicOption
        {
            NumberOfTries = 5,
            DeltaTime = TimeSpan.FromSeconds(2),
            MaxTimeInterval = TimeSpan.FromSeconds(20)
        });

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

        return new SqlConnection(connectionString)
        {
            RetryLogicProvider = Reintentos
        };
    }
}
