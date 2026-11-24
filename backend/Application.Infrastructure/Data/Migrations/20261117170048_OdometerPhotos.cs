using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class OdometerPhotos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "ClosingInspectionPhoto",
                table: "Shifts",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "ClosingOdometerPhoto",
                table: "Shifts",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "OpeningInspectionPhoto",
                table: "Shifts",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "OpeningOdometerPhoto",
                table: "Shifts",
                type: "varbinary(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ClosingInspectionPhoto",
                table: "Shifts");

            migrationBuilder.DropColumn(
                name: "ClosingOdometerPhoto",
                table: "Shifts");

            migrationBuilder.DropColumn(
                name: "OpeningInspectionPhoto",
                table: "Shifts");

            migrationBuilder.DropColumn(
                name: "OpeningOdometerPhoto",
                table: "Shifts");
        }
    }
}
