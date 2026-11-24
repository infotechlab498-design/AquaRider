using RouteLedger.Infrastructure.Services;

namespace RouteLedger.Tests;

public sealed class RecurrenceEngineTests
{
    [Fact]
    public void Weekly_keeps_monday_wednesday_and_friday()
    {
        var start = new DateOnly(2026, 6, 1);
        var dates = RecurrenceEngine.Dates(new RecurrenceInput(
            "Weekly",
            1,
            (1 << (int)DayOfWeek.Monday) | (1 << (int)DayOfWeek.Wednesday) | (1 << (int)DayOfWeek.Friday),
            [],
            [],
            start,
            new DateOnly(2026, 6, 14),
            []), start, new DateOnly(2026, 6, 14));

        Assert.Equal(
            [
                new DateOnly(2026, 6, 1),
                new DateOnly(2026, 6, 3),
                new DateOnly(2026, 6, 5),
                new DateOnly(2026, 6, 8),
                new DateOnly(2026, 6, 10),
                new DateOnly(2026, 6, 12)
            ],
            dates);
    }

    [Fact]
    public void Monthly_skips_the_31st_in_a_shorter_month()
    {
        var dates = RecurrenceEngine.Dates(new RecurrenceInput(
            "Monthly",
            1,
            0,
            [31],
            [],
            new DateOnly(2026, 1, 1),
            new DateOnly(2026, 4, 30),
            []), new DateOnly(2026, 1, 1), new DateOnly(2026, 4, 30));

        Assert.Equal([new DateOnly(2026, 1, 31), new DateOnly(2026, 3, 31)], dates);
    }

    [Fact]
    public void Leap_year_includes_february_29_only_when_that_day_exists()
    {
        var leap = RecurrenceEngine.Dates(new RecurrenceInput(
            "Monthly", 1, 0, [29], [], new DateOnly(2024, 2, 1), new DateOnly(2024, 2, 29), []),
            new DateOnly(2024, 2, 1), new DateOnly(2024, 2, 29));
        var common = RecurrenceEngine.Dates(new RecurrenceInput(
            "Monthly", 1, 0, [29], [], new DateOnly(2026, 2, 1), new DateOnly(2026, 2, 28), []),
            new DateOnly(2026, 2, 1), new DateOnly(2026, 2, 28));

        Assert.Equal([new DateOnly(2024, 2, 29)], leap);
        Assert.Empty(common);
    }

    [Fact]
    public void Pause_range_is_excluded()
    {
        var dates = RecurrenceEngine.Dates(new RecurrenceInput(
            "Weekly",
            1,
            1 << (int)DayOfWeek.Monday,
            [],
            [],
            new DateOnly(2026, 6, 1),
            new DateOnly(2026, 6, 30),
            [new DateOnly(2026, 6, 8), new DateOnly(2026, 6, 15)]),
            new DateOnly(2026, 6, 1),
            new DateOnly(2026, 6, 30));

        Assert.DoesNotContain(new DateOnly(2026, 6, 8), dates);
        Assert.DoesNotContain(new DateOnly(2026, 6, 15), dates);
        Assert.Contains(new DateOnly(2026, 6, 22), dates);
    }

    [Fact]
    public void Every_second_week_skips_the_in_between_week()
    {
        var dates = RecurrenceEngine.Dates(new RecurrenceInput(
            "Weekly",
            2,
            1 << (int)DayOfWeek.Monday,
            [],
            [],
            new DateOnly(2026, 6, 1),
            new DateOnly(2026, 6, 30),
            []), new DateOnly(2026, 6, 1), new DateOnly(2026, 6, 30));

        Assert.Equal([new DateOnly(2026, 6, 1), new DateOnly(2026, 6, 15), new DateOnly(2026, 6, 29)], dates);
    }
}
