using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class OrderNotes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "CustomerOrders",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ShowOnManifest",
                table: "CustomerOrders",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Notes",
                table: "CustomerOrders");

            migrationBuilder.DropColumn(
                name: "ShowOnManifest",
                table: "CustomerOrders");
        }
    }
}
