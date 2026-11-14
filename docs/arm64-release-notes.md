Portable, self-contained Lenovo Legion Toolkit for Windows 11 on ARM64, built from the corresponding upstream stable release with the Yoga Slim 7x fork changes.

1. Download the `-win-arm64.zip` asset and extract the complete archive.
2. Open `Lenovo Legion Toolkit.exe` in the extracted folder.

The Yoga Slim 7x (14Q8X9, machine type 83ED) has limited hardware support. The Toolkit cannot change its Qualcomm firmware charging threshold from Windows. A limit already applied by the firmware continues to be enforced by the laptop.

This build runs without UIAccess, packaged LampArray identity, or the x64 PawnIO driver. Features that depend on those components may be unavailable.

[Upstream releases](https://github.com/LenovoLegionToolkit-Team/LenovoLegionToolkit/releases) · [ARM64 source and battery notes](https://github.com/emmarrem/LenovoLegionToolkit/blob/arm64/docs/yoga-slim-7x.md)
