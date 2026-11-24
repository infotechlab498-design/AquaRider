using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class LiveFleetTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RiderInAppNotifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RiderUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    AnomalyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Title = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Body = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    DeepLink = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    IdempotencyKey = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    IsRead = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RiderInAppNotifications", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TrackingSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RiderUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    ShiftId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RouteId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    VehicleId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    StartedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndReason = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrackingSessions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RiderLocationTelemetries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TrackingSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RiderUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Latitude = table.Column<double>(type: "float(18)", precision: 18, scale: 8, nullable: false),
                    Longitude = table.Column<double>(type: "float(18)", precision: 18, scale: 8, nullable: false),
                    AccuracyMeters = table.Column<double>(type: "float(18)", precision: 18, scale: 2, nullable: true),
                    SpeedMetersPerSecond = table.Column<double>(type: "float(18)", precision: 18, scale: 3, nullable: true),
                    HeadingDegrees = table.Column<double>(type: "float(18)", precision: 18, scale: 2, nullable: true),
                    DeviceTimestampUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ServerReceivedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    BatteryPercent = table.Column<int>(type: "int", nullable: true),
                    NetworkStatus = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    IsStale = table.Column<bool>(type: "bit", nullable: false),
                    Rejected = table.Column<bool>(type: "bit", nullable: false),
                    RejectReason = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RiderLocationTelemetries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RiderLocationTelemetries_TrackingSessions_TrackingSessionId",
                        column: x => x.TrackingSessionId,
                        principalTable: "TrackingSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RouteComplianceAnomalies",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AnomalyNumber = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    RiderUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    TrackingSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ShiftId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    RouteId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Category = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Severity = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    DetectedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastLatitude = table.Column<double>(type: "float(18)", precision: 18, scale: 8, nullable: true),
                    LastLongitude = table.Column<double>(type: "float(18)", precision: 18, scale: 8, nullable: true),
                    ExpectedWaypoint = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    ExpectedStopId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ActualHeadingDegrees = table.Column<double>(type: "float(18)", precision: 18, scale: 2, nullable: true),
                    ExpectedHeadingDegrees = table.Column<double>(type: "float(18)", precision: 18, scale: 2, nullable: true),
                    EvidenceJson = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    ResponseDueAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ResolvedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ResolutionNotes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RouteComplianceAnomalies", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RouteComplianceAnomalies_TrackingSessions_TrackingSessionId",
                        column: x => x.TrackingSessionId,
                        principalTable: "TrackingSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RiderAnomalyExplanations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AnomalyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RiderUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ExplanationText = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    SupportingNote = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    SubmittedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsCorrection = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RiderAnomalyExplanations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RiderAnomalyExplanations_RouteComplianceAnomalies_AnomalyId",
                        column: x => x.AnomalyId,
                        principalTable: "RouteComplianceAnomalies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RouteAnomalyStatusEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AnomalyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FromStatus = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    ToStatus = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    ActorUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RouteAnomalyStatusEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RouteAnomalyStatusEvents_RouteComplianceAnomalies_AnomalyId",
                        column: x => x.AnomalyId,
                        principalTable: "RouteComplianceAnomalies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RouteComplianceReviews",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AnomalyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AdminUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Action = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RouteComplianceReviews", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RouteComplianceReviews_RouteComplianceAnomalies_AnomalyId",
                        column: x => x.AnomalyId,
                        principalTable: "RouteComplianceAnomalies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RiderAnomalyExplanations_AnomalyId_SubmittedAtUtc",
                table: "RiderAnomalyExplanations",
                columns: new[] { "AnomalyId", "SubmittedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RiderInAppNotifications_IdempotencyKey",
                table: "RiderInAppNotifications",
                column: "IdempotencyKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RiderInAppNotifications_RiderUserId_CreatedAtUtc",
                table: "RiderInAppNotifications",
                columns: new[] { "RiderUserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RiderLocationTelemetries_RiderUserId_DeviceTimestampUtc",
                table: "RiderLocationTelemetries",
                columns: new[] { "RiderUserId", "DeviceTimestampUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RiderLocationTelemetries_TrackingSessionId_DeviceTimestampUtc",
                table: "RiderLocationTelemetries",
                columns: new[] { "TrackingSessionId", "DeviceTimestampUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RiderLocationTelemetries_TrackingSessionId_DeviceTimestampUtc_Latitude_Longitude",
                table: "RiderLocationTelemetries",
                columns: new[] { "TrackingSessionId", "DeviceTimestampUtc", "Latitude", "Longitude" },
                unique: true,
                filter: "[Rejected] = 0");

            migrationBuilder.CreateIndex(
                name: "IX_RouteAnomalyStatusEvents_AnomalyId_OccurredAtUtc",
                table: "RouteAnomalyStatusEvents",
                columns: new[] { "AnomalyId", "OccurredAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RouteComplianceAnomalies_AnomalyNumber",
                table: "RouteComplianceAnomalies",
                column: "AnomalyNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RouteComplianceAnomalies_RiderUserId_DetectedAtUtc",
                table: "RouteComplianceAnomalies",
                columns: new[] { "RiderUserId", "DetectedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RouteComplianceAnomalies_Status_DetectedAtUtc",
                table: "RouteComplianceAnomalies",
                columns: new[] { "Status", "DetectedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RouteComplianceAnomalies_TrackingSessionId",
                table: "RouteComplianceAnomalies",
                column: "TrackingSessionId");

            migrationBuilder.CreateIndex(
                name: "IX_RouteComplianceReviews_AnomalyId_OccurredAtUtc",
                table: "RouteComplianceReviews",
                columns: new[] { "AnomalyId", "OccurredAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_TrackingSessions_RiderUserId_Status",
                table: "TrackingSessions",
                columns: new[] { "RiderUserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_TrackingSessions_ShiftId",
                table: "TrackingSessions",
                column: "ShiftId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RiderAnomalyExplanations");

            migrationBuilder.DropTable(
                name: "RiderInAppNotifications");

            migrationBuilder.DropTable(
                name: "RiderLocationTelemetries");

            migrationBuilder.DropTable(
                name: "RouteAnomalyStatusEvents");

            migrationBuilder.DropTable(
                name: "RouteComplianceReviews");

            migrationBuilder.DropTable(
                name: "RouteComplianceAnomalies");

            migrationBuilder.DropTable(
                name: "TrackingSessions");
        }
    }
}
