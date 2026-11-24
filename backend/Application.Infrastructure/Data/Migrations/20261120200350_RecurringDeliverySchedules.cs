using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RouteLedger.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RecurringDeliverySchedules : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RecurringSchedules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ScheduleCode = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    CustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DefaultRiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Frequency = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Interval = table.Column<int>(type: "int", nullable: false),
                    WeekdayMask = table.Column<int>(type: "int", nullable: false),
                    StartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    EndDate = table.Column<DateOnly>(type: "date", nullable: true),
                    TimeWindow = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    TimeZoneId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    AutoPublish = table.Column<bool>(type: "bit", nullable: false),
                    PublicationTime = table.Column<TimeOnly>(type: "time", nullable: false),
                    AssignmentMode = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Instructions = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Version = table.Column<int>(type: "int", nullable: false),
                    CreatedBy = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecurringSchedules", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecurringSchedules_Customers_CustomerId",
                        column: x => x.CustomerId,
                        principalTable: "Customers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecurringSchedules_Depots_DepotId",
                        column: x => x.DepotId,
                        principalTable: "Depots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SchedulePublicationLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OccurrenceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    FailureReason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    Attempt = table.Column<int>(type: "int", nullable: false),
                    PublishedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SchedulePublicationLogs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "DeliveryOccurrences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ScheduleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DepotId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AssignedRiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    ServiceDate = table.Column<DateOnly>(type: "date", nullable: false),
                    TimeWindow = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Detached = table.Column<bool>(type: "bit", nullable: false),
                    OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    FailureReason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeliveryOccurrences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DeliveryOccurrences_RecurringSchedules_ScheduleId",
                        column: x => x.ScheduleId,
                        principalTable: "RecurringSchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RecurringScheduleCustomDates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ScheduleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ServiceDate = table.Column<DateOnly>(type: "date", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecurringScheduleCustomDates", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecurringScheduleCustomDates_RecurringSchedules_ScheduleId",
                        column: x => x.ScheduleId,
                        principalTable: "RecurringSchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RecurringScheduleLines",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ScheduleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    ExpectedEmpties = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecurringScheduleLines", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecurringScheduleLines_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecurringScheduleLines_RecurringSchedules_ScheduleId",
                        column: x => x.ScheduleId,
                        principalTable: "RecurringSchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RecurringScheduleMonthDays",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ScheduleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Day = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecurringScheduleMonthDays", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecurringScheduleMonthDays_RecurringSchedules_ScheduleId",
                        column: x => x.ScheduleId,
                        principalTable: "RecurringSchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ScheduleExceptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ScheduleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExceptionType = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    StartDate = table.Column<DateOnly>(type: "date", nullable: false),
                    EndDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    CreatedBy = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ScheduleExceptions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ScheduleExceptions_RecurringSchedules_ScheduleId",
                        column: x => x.ScheduleId,
                        principalTable: "RecurringSchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "OccurrenceAssignments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OccurrenceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    PreviousRiderId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    AssignedBy = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    AssignedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OccurrenceAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_OccurrenceAssignments_DeliveryOccurrences_OccurrenceId",
                        column: x => x.OccurrenceId,
                        principalTable: "DeliveryOccurrences",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryOccurrences_ScheduleId_ServiceDate",
                table: "DeliveryOccurrences",
                columns: new[] { "ScheduleId", "ServiceDate" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryOccurrences_ServiceDate_Status",
                table: "DeliveryOccurrences",
                columns: new[] { "ServiceDate", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_OccurrenceAssignments_OccurrenceId_AssignedAt",
                table: "OccurrenceAssignments",
                columns: new[] { "OccurrenceId", "AssignedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_RecurringScheduleCustomDates_ScheduleId_ServiceDate",
                table: "RecurringScheduleCustomDates",
                columns: new[] { "ScheduleId", "ServiceDate" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecurringScheduleLines_ProductId",
                table: "RecurringScheduleLines",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_RecurringScheduleLines_ScheduleId_ProductId",
                table: "RecurringScheduleLines",
                columns: new[] { "ScheduleId", "ProductId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecurringScheduleMonthDays_ScheduleId_Day",
                table: "RecurringScheduleMonthDays",
                columns: new[] { "ScheduleId", "Day" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecurringSchedules_CustomerId_Status",
                table: "RecurringSchedules",
                columns: new[] { "CustomerId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_RecurringSchedules_DepotId",
                table: "RecurringSchedules",
                column: "DepotId");

            migrationBuilder.CreateIndex(
                name: "IX_RecurringSchedules_ScheduleCode",
                table: "RecurringSchedules",
                column: "ScheduleCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ScheduleExceptions_ScheduleId_Status",
                table: "ScheduleExceptions",
                columns: new[] { "ScheduleId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_SchedulePublicationLogs_OccurrenceId",
                table: "SchedulePublicationLogs",
                column: "OccurrenceId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OccurrenceAssignments");

            migrationBuilder.DropTable(
                name: "RecurringScheduleCustomDates");

            migrationBuilder.DropTable(
                name: "RecurringScheduleLines");

            migrationBuilder.DropTable(
                name: "RecurringScheduleMonthDays");

            migrationBuilder.DropTable(
                name: "ScheduleExceptions");

            migrationBuilder.DropTable(
                name: "SchedulePublicationLogs");

            migrationBuilder.DropTable(
                name: "DeliveryOccurrences");

            migrationBuilder.DropTable(
                name: "RecurringSchedules");
        }
    }
}
