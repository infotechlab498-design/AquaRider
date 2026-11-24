namespace RouteLedger.Infrastructure.Services;

internal static class GeoMath
{
    private const double EarthRadiusMeters = 6371000;

    public static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
            + Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2))
            * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 2 * EarthRadiusMeters * Math.Asin(Math.Min(1, Math.Sqrt(a)));
    }

    public static double BearingDegrees(double lat1, double lon1, double lat2, double lon2)
    {
        var y = Math.Sin(ToRad(lon2 - lon1)) * Math.Cos(ToRad(lat2));
        var x = Math.Cos(ToRad(lat1)) * Math.Sin(ToRad(lat2))
            - Math.Sin(ToRad(lat1)) * Math.Cos(ToRad(lat2)) * Math.Cos(ToRad(lon2 - lon1));
        var bearing = ToDeg(Math.Atan2(y, x));
        return (bearing + 360) % 360;
    }

    public static double HeadingDeltaDegrees(double a, double b)
    {
        var delta = Math.Abs(a - b) % 360;
        return delta > 180 ? 360 - delta : delta;
    }

    public static double DistanceToPolylineMeters(
        double lat,
        double lon,
        IReadOnlyList<(double Lat, double Lon)> polyline)
    {
        if (polyline.Count == 0)
        {
            return double.PositiveInfinity;
        }

        if (polyline.Count == 1)
        {
            return DistanceMeters(lat, lon, polyline[0].Lat, polyline[0].Lon);
        }

        var min = double.PositiveInfinity;
        for (var i = 0; i < polyline.Count - 1; i++)
        {
            min = Math.Min(min, DistanceToSegmentMeters(lat, lon, polyline[i], polyline[i + 1]));
        }

        return min;
    }

    private static double DistanceToSegmentMeters(
        double lat,
        double lon,
        (double Lat, double Lon) a,
        (double Lat, double Lon) b)
    {
        var ab = DistanceMeters(a.Lat, a.Lon, b.Lat, b.Lon);
        if (ab < 1)
        {
            return DistanceMeters(lat, lon, a.Lat, a.Lon);
        }

        var ap = DistanceMeters(a.Lat, a.Lon, lat, lon);
        var bp = DistanceMeters(b.Lat, b.Lon, lat, lon);
        var t = ((ap * ap) + (ab * ab) - (bp * bp)) / (2 * ab * ab);
        if (t <= 0)
        {
            return ap;
        }

        if (t >= 1)
        {
            return bp;
        }

        var bearing = BearingDegrees(a.Lat, a.Lon, b.Lat, b.Lon);
        var projLat = a.Lat + ((b.Lat - a.Lat) * t);
        var projLon = a.Lon + ((b.Lon - a.Lon) * t);
        _ = bearing;
        return DistanceMeters(lat, lon, projLat, projLon);
    }

    private static double ToRad(double degrees) => degrees * Math.PI / 180;
    private static double ToDeg(double radians) => radians * 180 / Math.PI;
}
