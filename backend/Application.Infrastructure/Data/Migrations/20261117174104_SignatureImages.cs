using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class SignatureImages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "SignatureImage",
                table: "Sales",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SignatureNote",
                table: "Sales",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "SignatureImage",
                table: "Collections",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SignatureNote",
                table: "Collections",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SignatureImage",
                table: "Sales");

            migrationBuilder.DropColumn(
                name: "SignatureNote",
                table: "Sales");

            migrationBuilder.DropColumn(
                name: "SignatureImage",
                table: "Collections");

            migrationBuilder.DropColumn(
                name: "SignatureNote",
                table: "Collections");
        }
    }
}
