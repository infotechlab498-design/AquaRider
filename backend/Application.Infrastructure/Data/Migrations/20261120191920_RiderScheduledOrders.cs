using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RiderScheduledOrders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Origin",
                table: "CustomerOrders",
                type: "nvarchar(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "Hq");

            migrationBuilder.Sql(
                """
                UPDATE o
                SET Origin = 'Rider'
                FROM CustomerOrders o
                WHERE EXISTS (
                    SELECT 1
                    FROM OrderLifecycleEvents e
                    WHERE e.OrderId = o.Id
                      AND e.EventCode = 'OrderCreated'
                      AND e.ActorUserId = o.RiderId
                      AND e.ActorUserId <> '')
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Origin",
                table: "CustomerOrders");
        }
    }
}
