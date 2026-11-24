using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class ZonesRoutesManagement : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Zones",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Sector = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    City = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Zones", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Zones_Depots_DepotId",
                        column: x => x.DepotId,
                        principalTable: "Depots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Zones_DepotId",
                table: "Zones",
                column: "DepotId");

            migrationBuilder.CreateIndex(
                name: "IX_Zones_Sector_City_DepotId",
                table: "Zones",
                columns: new[] { "Sector", "City", "DepotId" });

            migrationBuilder.AddColumn<Guid>(
                name: "ZoneId",
                table: "DeliveryRoutes",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RouteSortOrder",
                table: "Customers",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Backfill one zone per distinct Sector/City/Depot from existing routes (no fabricated rows).
            migrationBuilder.Sql("""
                INSERT INTO Zones (Id, Name, Sector, City, DepotId, IsActive, CreatedAt)
                SELECT NEWID(),
                       CASE
                         WHEN CHARINDEX(N'–', MIN(r.Name)) > 0
                           THEN LTRIM(RTRIM(LEFT(MIN(r.Name), CHARINDEX(N'–', MIN(r.Name)) - 1)))
                         WHEN CHARINDEX(N'-', MIN(r.Name)) > 0
                           THEN LTRIM(RTRIM(LEFT(MIN(r.Name), CHARINDEX(N'-', MIN(r.Name)) - 1)))
                         ELSE CONCAT(MIN(r.Sector), N' ', MIN(r.City))
                       END,
                       r.Sector,
                       r.City,
                       r.DepotId,
                       1,
                       SYSUTCDATETIME()
                FROM DeliveryRoutes r
                GROUP BY r.Sector, r.City, r.DepotId;

                UPDATE r
                SET r.ZoneId = z.Id
                FROM DeliveryRoutes r
                INNER JOIN Zones z
                  ON z.Sector = r.Sector AND z.City = r.City AND z.DepotId = r.DepotId;
                """);

            migrationBuilder.Sql("""
                ;WITH Ordered AS (
                    SELECT c.Id,
                           ROW_NUMBER() OVER (
                               PARTITION BY c.RouteId
                               ORDER BY ISNULL(s.Sequence, 2147483647), c.BusinessName, c.Code
                           ) AS SortOrder
                    FROM Customers c
                    OUTER APPLY (
                        SELECT TOP (1) rs.Sequence
                        FROM RouteStops rs
                        WHERE rs.CustomerId = c.Id
                        ORDER BY rs.ServiceDate DESC, rs.Sequence
                    ) s
                    WHERE c.IsDeleted = 0
                )
                UPDATE c
                SET c.RouteSortOrder = o.SortOrder
                FROM Customers c
                INNER JOIN Ordered o ON o.Id = c.Id;
                """);

            migrationBuilder.AlterColumn<Guid>(
                name: "ZoneId",
                table: "DeliveryRoutes",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.DropIndex(
                name: "IX_Customers_RouteId",
                table: "Customers");

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryRoutes_ZoneId",
                table: "DeliveryRoutes",
                column: "ZoneId");

            migrationBuilder.CreateIndex(
                name: "IX_Customers_RouteId_RouteSortOrder",
                table: "Customers",
                columns: new[] { "RouteId", "RouteSortOrder" });

            migrationBuilder.AddForeignKey(
                name: "FK_DeliveryRoutes_Zones_ZoneId",
                table: "DeliveryRoutes",
                column: "ZoneId",
                principalTable: "Zones",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DeliveryRoutes_Zones_ZoneId",
                table: "DeliveryRoutes");

            migrationBuilder.DropTable(
                name: "Zones");

            migrationBuilder.DropIndex(
                name: "IX_DeliveryRoutes_ZoneId",
                table: "DeliveryRoutes");

            migrationBuilder.DropIndex(
                name: "IX_Customers_RouteId_RouteSortOrder",
                table: "Customers");

            migrationBuilder.DropColumn(
                name: "ZoneId",
                table: "DeliveryRoutes");

            migrationBuilder.DropColumn(
                name: "RouteSortOrder",
                table: "Customers");

            migrationBuilder.CreateIndex(
                name: "IX_Customers_RouteId",
                table: "Customers",
                column: "RouteId");
        }
    }
}
