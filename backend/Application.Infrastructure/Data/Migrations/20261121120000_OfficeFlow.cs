using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using RouteLedger.Infrastructure.Data;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20261121120000_OfficeFlow")]
    public partial class OfficeFlow : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(name: "CashStatus", table: "Collections", type: "nvarchar(32)", maxLength: 32, nullable: false, defaultValue: "CollectedByRider");
            migrationBuilder.AddColumn<Guid>(name: "HandoverId", table: "Collections", type: "uniqueidentifier", nullable: true);
            migrationBuilder.AddColumn<DateTime>(name: "CashReceivedAt", table: "Collections", type: "datetime2", nullable: true);
            migrationBuilder.AddColumn<string>(name: "CashReceivedByUserId", table: "Collections", type: "nvarchar(450)", maxLength: 450, nullable: true);
            migrationBuilder.AddColumn<Guid>(name: "CashReceivedDepotId", table: "Collections", type: "uniqueidentifier", nullable: true);
            migrationBuilder.CreateIndex(name: "IX_Collections_HandoverId", table: "Collections", column: "HandoverId");

            migrationBuilder.Sql("""
                UPDATE c
                SET CashStatus = 'CashReceived'
                FROM Collections c
                INNER JOIN DayLocks d ON d.BusinessDate = CONVERT(date, c.CreatedAt)
                """);

            migrationBuilder.AddColumn<string>(name: "SupportEmail", table: "BusinessProfiles", type: "nvarchar(180)", maxLength: 180, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>(name: "SupportPhone", table: "BusinessProfiles", type: "nvarchar(40)", maxLength: 40, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>(name: "SupportAddress", table: "BusinessProfiles", type: "nvarchar(300)", maxLength: 300, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>(name: "Website", table: "BusinessProfiles", type: "nvarchar(180)", maxLength: 180, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>(name: "ReceiptFooter", table: "BusinessProfiles", type: "nvarchar(300)", maxLength: 300, nullable: false, defaultValue: "");

            migrationBuilder.CreateTable(
                name: "CustomerLinkReviews",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeliveryCustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MatchBasis = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    RequestedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ReviewedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    Comment = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomerLinkReviews", x => x.Id);
                    table.ForeignKey("FK_CustomerLinkReviews_CustomerAccounts_CustomerAccountId", x => x.CustomerAccountId, "CustomerAccounts", "Id", onDelete: ReferentialAction.Restrict);
                });
            migrationBuilder.CreateIndex(name: "IX_CustomerLinkReviews_CustomerAccountId", table: "CustomerLinkReviews", column: "CustomerAccountId");
            migrationBuilder.CreateIndex(name: "IX_CustomerLinkReviews_DeliveryCustomerId", table: "CustomerLinkReviews", column: "DeliveryCustomerId");

            migrationBuilder.CreateTable(
                name: "CashHandovers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReferenceNumber = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    RiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BusinessDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ExpectedAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    ActualAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    SubmittedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    SubmittedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReceivedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    ReceivedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Note = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true)
                },
                constraints: table => table.PrimaryKey("PK_CashHandovers", x => x.Id));
            migrationBuilder.CreateIndex(name: "IX_CashHandovers_ReferenceNumber", table: "CashHandovers", column: "ReferenceNumber", unique: true);
            migrationBuilder.CreateIndex(name: "IX_CashHandovers_RiderId_BusinessDate", table: "CashHandovers", columns: new[] { "RiderId", "BusinessDate" });

            migrationBuilder.CreateTable(
                name: "PriceListAssignments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PriceListId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PriceListAssignments", x => x.Id);
                    table.ForeignKey("FK_PriceListAssignments_PriceLists_PriceListId", x => x.PriceListId, "PriceLists", "Id", onDelete: ReferentialAction.Cascade);
                    table.ForeignKey("FK_PriceListAssignments_Customers_CustomerId", x => x.CustomerId, "Customers", "Id", onDelete: ReferentialAction.Restrict);
                });
            migrationBuilder.CreateIndex(name: "IX_PriceListAssignments_CustomerId", table: "PriceListAssignments", column: "CustomerId", unique: true);
            migrationBuilder.CreateIndex(name: "IX_PriceListAssignments_PriceListId", table: "PriceListAssignments", column: "PriceListId");

            migrationBuilder.CreateTable(
                name: "WarehouseStocks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WarehouseStocks", x => x.Id);
                    table.ForeignKey("FK_WarehouseStocks_Depots_DepotId", x => x.DepotId, "Depots", "Id", onDelete: ReferentialAction.Restrict);
                    table.ForeignKey("FK_WarehouseStocks_Products_ProductId", x => x.ProductId, "Products", "Id", onDelete: ReferentialAction.Restrict);
                });
            migrationBuilder.CreateIndex(name: "IX_WarehouseStocks_DepotId_ProductId", table: "WarehouseStocks", columns: new[] { "DepotId", "ProductId" }, unique: true);

            migrationBuilder.CreateTable(
                name: "InventoryCountLines",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExpectedQuantity = table.Column<int>(type: "int", nullable: false),
                    CountedQuantity = table.Column<int>(type: "int", nullable: false),
                    Variance = table.Column<int>(type: "int", nullable: false),
                    CountedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    CountedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Note = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true)
                },
                constraints: table => table.PrimaryKey("PK_InventoryCountLines", x => x.Id));
            migrationBuilder.CreateIndex(name: "IX_InventoryCountLines_DepotId_ProductId", table: "InventoryCountLines", columns: new[] { "DepotId", "ProductId" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "InventoryCountLines");
            migrationBuilder.DropTable(name: "WarehouseStocks");
            migrationBuilder.DropTable(name: "PriceListAssignments");
            migrationBuilder.DropTable(name: "CashHandovers");
            migrationBuilder.DropTable(name: "CustomerLinkReviews");
            migrationBuilder.DropColumn(name: "ReceiptFooter", table: "BusinessProfiles");
            migrationBuilder.DropColumn(name: "Website", table: "BusinessProfiles");
            migrationBuilder.DropColumn(name: "SupportAddress", table: "BusinessProfiles");
            migrationBuilder.DropColumn(name: "SupportPhone", table: "BusinessProfiles");
            migrationBuilder.DropColumn(name: "SupportEmail", table: "BusinessProfiles");
            migrationBuilder.DropIndex(name: "IX_Collections_HandoverId", table: "Collections");
            migrationBuilder.DropColumn(name: "CashReceivedDepotId", table: "Collections");
            migrationBuilder.DropColumn(name: "CashReceivedByUserId", table: "Collections");
            migrationBuilder.DropColumn(name: "CashReceivedAt", table: "Collections");
            migrationBuilder.DropColumn(name: "HandoverId", table: "Collections");
            migrationBuilder.DropColumn(name: "CashStatus", table: "Collections");
        }
    }
}
