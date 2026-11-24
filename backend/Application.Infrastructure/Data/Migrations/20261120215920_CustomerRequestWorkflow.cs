using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class CustomerRequestWorkflow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DeliveryArea",
                table: "RecurringSchedules",
                type: "nvarchar(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryCity",
                table: "RecurringSchedules",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryStreet",
                table: "RecurringSchedules",
                type: "nvarchar(240)",
                maxLength: 240,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RequestId",
                table: "CustomerNotifications",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AdminRequestNotices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RequestId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Body = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    ReadAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminRequestNotices", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerNotifications_RequestId",
                table: "CustomerNotifications",
                column: "RequestId");

            migrationBuilder.CreateIndex(
                name: "IX_AdminRequestNotices_CreatedAt",
                table: "AdminRequestNotices",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_AdminRequestNotices_RequestId",
                table: "AdminRequestNotices",
                column: "RequestId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AdminRequestNotices");

            migrationBuilder.DropIndex(
                name: "IX_CustomerNotifications_RequestId",
                table: "CustomerNotifications");

            migrationBuilder.DropColumn(
                name: "DeliveryArea",
                table: "RecurringSchedules");

            migrationBuilder.DropColumn(
                name: "DeliveryCity",
                table: "RecurringSchedules");

            migrationBuilder.DropColumn(
                name: "DeliveryStreet",
                table: "RecurringSchedules");

            migrationBuilder.DropColumn(
                name: "RequestId",
                table: "CustomerNotifications");
        }
    }
}
