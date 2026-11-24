using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class DayCloseAndBasePricing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "SettlementVarianceThreshold",
                table: "BusinessProfiles",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "DayLocks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BusinessDate = table.Column<DateOnly>(type: "date", nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LockedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LockedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    AcknowledgementNote = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DayLocks", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SettlementAuditEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BusinessDate = table.Column<DateOnly>(type: "date", nullable: false),
                    SettlementSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    EventCode = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Detail = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    ActorUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RelatedEntityName = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                    RelatedEntityId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SettlementAuditEvents", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SettlementSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BusinessDate = table.Column<DateOnly>(type: "date", nullable: false),
                    RiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ShiftId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    RouteId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Status = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    RiderAnnotation = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    DraftVerifiedCash = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    DraftResolutionCategory = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    DraftRemarks = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    ResolutionCategory = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    ResolutionRemarks = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    ApprovedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    ApprovedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SettlementSessions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CashDeclarations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SettlementSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeclaredAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Source = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    SubmittedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SubmittedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CashDeclarations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CashDeclarations_SettlementSessions_SettlementSessionId",
                        column: x => x.SettlementSessionId,
                        principalTable: "SettlementSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PhysicalCashVerifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SettlementSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    VerifiedAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    BatchReference = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    VerifiedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    VerifiedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PhysicalCashVerifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PhysicalCashVerifications_SettlementSessions_SettlementSessionId",
                        column: x => x.SettlementSessionId,
                        principalTable: "SettlementSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CashDeclarations_SettlementSessionId",
                table: "CashDeclarations",
                column: "SettlementSessionId");

            migrationBuilder.CreateIndex(
                name: "IX_DayLocks_BusinessDate",
                table: "DayLocks",
                column: "BusinessDate",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PhysicalCashVerifications_SettlementSessionId",
                table: "PhysicalCashVerifications",
                column: "SettlementSessionId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementAuditEvents_BusinessDate_OccurredAtUtc",
                table: "SettlementAuditEvents",
                columns: new[] { "BusinessDate", "OccurredAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_SettlementAuditEvents_SettlementSessionId",
                table: "SettlementAuditEvents",
                column: "SettlementSessionId");

            migrationBuilder.CreateIndex(
                name: "IX_SettlementSessions_BusinessDate_RiderId",
                table: "SettlementSessions",
                columns: new[] { "BusinessDate", "RiderId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SettlementSessions_BusinessDate_Status",
                table: "SettlementSessions",
                columns: new[] { "BusinessDate", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CashDeclarations");

            migrationBuilder.DropTable(
                name: "DayLocks");

            migrationBuilder.DropTable(
                name: "PhysicalCashVerifications");

            migrationBuilder.DropTable(
                name: "SettlementAuditEvents");

            migrationBuilder.DropTable(
                name: "SettlementSessions");

            migrationBuilder.DropColumn(
                name: "SettlementVarianceThreshold",
                table: "BusinessProfiles");
        }
    }
}
