using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AEDemo
{
    class Program
    {
        static void Main(string[] args)
        {
            string connectionString = "Data Source=localhost; Initial Catalog=AEDemo; Integrated Security=true; Column Encryption Setting=enabled";
            SqlConnection connection = new SqlConnection(connectionString);
            connection.Open();

            if (args.Length != 3)
            {
                Console.WriteLine("Please enter a numeric and two string arguments.");
                return;
            }
            int id = Int32.Parse(args[0]);

            {
                using (SqlCommand cmd = connection.CreateCommand())
                {
                    cmd.CommandText = @"INSERT INTO dbo.Table1 (id, SecretDeterministic, SecretRandomized)" +
                        " VALUES (@id, @SecretDeterministic, @SecretRandomized);";

                    SqlParameter paramid= cmd.CreateParameter();
                    paramid.ParameterName = @"@id";
                    paramid.DbType = DbType.Int32;
                    paramid.Direction = ParameterDirection.Input;
                    paramid.Value = id;
                    cmd.Parameters.Add(paramid);

                    SqlParameter paramSecretDeterministic = cmd.CreateParameter();
                    paramSecretDeterministic.ParameterName = @"@SecretDeterministic";
                    paramSecretDeterministic.DbType = DbType.String;
                    paramSecretDeterministic.Direction = ParameterDirection.Input;
                    paramSecretDeterministic.Value = args[1];
                    paramSecretDeterministic.Size = 10;
                    cmd.Parameters.Add(paramSecretDeterministic);

                    SqlParameter paramSecretRandomized = cmd.CreateParameter();
                    paramSecretRandomized.ParameterName = @"@SecretRandomized";
                    paramSecretRandomized.DbType = DbType.String;
                    paramSecretRandomized.Direction = ParameterDirection.Input;
                    paramSecretRandomized.Value = args[2];
                    paramSecretRandomized.Size = 10;
                    cmd.Parameters.Add(paramSecretRandomized);

                    cmd.ExecuteNonQuery();
                }
            }
            connection.Close();
            Console.WriteLine("Row inserted successfully");
        }
    }
}
