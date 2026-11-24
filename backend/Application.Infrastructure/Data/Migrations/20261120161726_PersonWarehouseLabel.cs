using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class PersonWarehouseLabel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "WarehousePersonUserId",
                table: "AspNetUsers",
                type: "nvarchar(450)",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ZoneId",
                table: "AspNetUsers",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUsers_WarehousePersonUserId",
                table: "AspNetUsers",
                column: "WarehousePersonUserId");

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUsers_ZoneId",
                table: "AspNetUsers",
                column: "ZoneId");

            migrationBuilder.AddForeignKey(
                name: "FK_AspNetUsers_AspNetUsers_WarehousePersonUserId",
                table: "AspNetUsers",
                column: "WarehousePersonUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_AspNetUsers_Zones_ZoneId",
                table: "AspNetUsers",
                column: "ZoneId",
                principalTable: "Zones",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_AspNetUsers_AspNetUsers_WarehousePersonUserId",
                table: "AspNetUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_AspNetUsers_Zones_ZoneId",
                table: "AspNetUsers");

            migrationBuilder.DropIndex(
                name: "IX_AspNetUsers_WarehousePersonUserId",
                table: "AspNetUsers");

            migrationBuilder.DropIndex(
                name: "IX_AspNetUsers_ZoneId",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "WarehousePersonUserId",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ZoneId",
                table: "AspNetUsers");
        }
    }
}
