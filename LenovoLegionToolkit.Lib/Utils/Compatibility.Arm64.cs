using System;
using System.Runtime.InteropServices;

namespace LenovoLegionToolkit.Lib.Utils;

public static partial class Compatibility
{
    public static bool IsYogaSlim7x(string vendor, string machineType) =>
        RuntimeInformation.OSArchitecture == Architecture.Arm64 &&
        vendor.Equals("LENOVO", StringComparison.OrdinalIgnoreCase) &&
        machineType.Equals("83ED", StringComparison.OrdinalIgnoreCase);
}
