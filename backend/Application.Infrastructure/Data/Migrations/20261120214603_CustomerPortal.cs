using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class CustomerPortal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "DeliveryCustomerId",
                table: "CustomerAccounts",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "CustomerAccounts",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "CustomerNotifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Body = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    ReadAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomerNotifications", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CustomerSavedAddresses",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Label = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    City = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Area = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Street = table.Column<string>(type: "nvarchar(180)", maxLength: 180, nullable: false),
                    HouseNumber = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Landmark = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: true),
                    Instructions = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    Latitude = table.Column<decimal>(type: "decimal(18,8)", precision: 18, scale: 8, nullable: true),
                    Longitude = table.Column<decimal>(type: "decimal(18,8)", precision: 18, scale: 8, nullable: true),
                    IsDefault = table.Column<bool>(type: "bit", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomerSavedAddresses", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CustomerSavedAddresses_CustomerAccounts_CustomerAccountId",
                        column: x => x.CustomerAccountId,
                        principalTable: "CustomerAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CustomerServiceRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    CustomerAccountId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeliveryCustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ScheduleId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Type = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    CurrentSummary = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    RequestedSummary = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Frequency = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    WeekdayMask = table.Column<int>(type: "int", nullable: true),
                    MonthDays = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                    TimeWindow = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    EffectiveDate = table.Column<DateOnly>(type: "date", nullable: true),
                    PauseStart = table.Column<DateOnly>(type: "date", nullable: true),
                    ResumeDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CurrentQuantity = table.Column<int>(type: "int", nullable: true),
                    RequestedQuantity = table.Column<int>(type: "int", nullable: true),
                    AddressLabel = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    City = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                    Area = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: true),
                    Street = table.Column<string>(type: "nvarchar(180)", maxLength: 180, nullable: true),
                    HouseNumber = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    Landmark = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: true),
                    Instructions = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    AffectedDates = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    AdminComment = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ReviewedBy = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomerServiceRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CustomerServiceRequests_CustomerAccounts_CustomerAccountId",
                        column: x => x.CustomerAccountId,
                        principalTable: "CustomerAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerAccounts_DeliveryCustomerId",
                table: "CustomerAccounts",
                column: "DeliveryCustomerId",
                unique: true,
                filter: "[DeliveryCustomerId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CustomerNotifications_CustomerAccountId_CreatedAt",
                table: "CustomerNotifications",
                columns: new[] { "CustomerAccountId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerSavedAddresses_CustomerAccountId",
                table: "CustomerSavedAddresses",
                column: "CustomerAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_CustomerServiceRequests_Code",
                table: "CustomerServiceRequests",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CustomerServiceRequests_CustomerAccountId_Status",
                table: "CustomerServiceRequests",
                columns: new[] { "CustomerAccountId", "Status" });

            migrationBuilder.AddForeignKey(
                name: "FK_CustomerAccounts_Customers_DeliveryCustomerId",
                table: "CustomerAccounts",
                column: "DeliveryCustomerId",
                principalTable: "Customers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CustomerAccounts_Customers_DeliveryCustomerId",
                table: "CustomerAccounts");

            migrationBuilder.DropTable(
                name: "CustomerNotifications");

            migrationBuilder.DropTable(
                name: "CustomerSavedAddresses");

            migrationBuilder.DropTable(
                name: "CustomerServiceRequests");

            migrationBuilder.DropIndex(
                name: "IX_CustomerAccounts_DeliveryCustomerId",
                table: "CustomerAccounts");

            migrationBuilder.DropColumn(
                name: "DeliveryCustomerId",
                table: "CustomerAccounts");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "CustomerAccounts");
        }
    }
}
