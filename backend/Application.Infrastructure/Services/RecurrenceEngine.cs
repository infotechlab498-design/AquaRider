namespace RouteLedger.Infrastructure.Services;

public sealed record RecurrenceInput(
    string Frequency,
    int Interval,
    int WeekdayMask,
    IReadOnlyList<int> MonthDays,
    IReadOnlyList<DateOnly> CustomDates,
    DateOnly Start,
    DateOnly? End,
    IReadOnlyList<DateOnly> Blocked);

/// <summary>
/// Dates a master schedule produces. A month day that the month does not contain is skipped.
/// </summary>
public static class RecurrenceEngine
{
    public const int HorizonDays = 45;

    public static IReadOnlyList<DateOnly> Dates(RecurrenceInput input, DateOnly from, DateOnly to)
    {
        if (to < from) return [];
        var start = input.Start > from ? input.Start : from;
        var end = input.End is DateOnly until && until < to ? until : to;
        if (end < start) return [];
        var blocked = input.Blocked.ToHashSet();
        var dates = new List<DateOnly>();
        for (var day = start; day <= end; day = day.AddDays(1))
        {
            if (blocked.Contains(day) || !Matches(input, day)) continue;
            dates.Add(day);
        }

        return dates;
    }

    public static bool Matches(RecurrenceInput input, DateOnly day)
    {
        if (day < input.Start || (input.End is DateOnly end && day > end)) return false;
        return input.Frequency switch
        {
            "Weekly" => Weekly(input, day),
            "Monthly" => input.MonthDays.Contains(day.Day),
            "Custom" => input.CustomDates.Contains(day),
            _ => false
        };
    }

    private static bool Weekly(RecurrenceInput input, DateOnly day)
    {
        var bit = 1 << (int)day.DayOfWeek;
        if ((input.WeekdayMask & bit) == 0) return false;
        var interval = input.Interval < 1 ? 1 : input.Interval;
        var weeks = (day.DayNumber - input.Start.DayNumber) / 7;
        return weeks % interval == 0;
    }
}
