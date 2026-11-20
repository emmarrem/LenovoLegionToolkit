# Windows ARM64 support for the Yoga Slim 7x

Download the latest [Windows ARM64 release](https://github.com/emmarrem/LenovoLegionToolkit/releases/latest), extract the ZIP, and open `Lenovo Legion Toolkit.exe`. The ZIP includes the ARM64 .NET Desktop Runtime.

Machine type 83ED (Yoga Slim 7 14Q8X9) passes the Toolkit compatibility check. Available functions depend on the Windows interfaces and drivers on the device. The portable build runs without UIAccess, LampArray package identity, and PawnIO.

## 80% firmware charging limit

The Snapdragon Yoga uses the Qualcomm battery manager. [Qualcomm's Linux battery driver](https://github.com/torvalds/linux/blob/master/drivers/power/supply/qcom_battmgr.c) implements the charge threshold. Lenovo [documents the missing Vantage control on Windows on ARM](https://support.lenovo.com/en/en/solutions/ht516682-windows-on-arm-faq). The Windows Toolkit currently has no supported way to read or write this firmware threshold.

If Windows already shows Smart charging and holds at 80%, you can leave the current firmware setting in place. For a machine that still needs the limit applied, the [Ubuntu Concept workaround](https://www.reddit.com/r/Lenovo/comments/1wtcx03/yoga_slim_7x_80_charging_limit_solved/) uses Ubuntu's battery settings to select the 80% charging limit before restarting into Windows. Use an [Ubuntu Concept Snapdragon X ISO](https://people.canonical.com/~platform/images/ubuntu-concept/) and its live session if the image and firmware support it.

## Build and release

Run `pwsh -File ./build-arm64.ps1 -Version 2.36.0.0` with a .NET 9 SDK and Git installed. The script builds the ARM64 LibreHardwareMonitor dependency from its pinned source revision and checks the PE machine type of the app host, runtime, and monitoring library.

The [ARM64 release workflow](https://github.com/emmarrem/LenovoLegionToolkit/actions/workflows/arm64-release.yml) checks the latest upstream stable release every six hours. It starts from the last successfully released integration and applies newer upstream source plus subsequent changes to the `arm64` branch. Each release tag includes `arm64-source.json` recording the upstream and ARM64 branch commits used for the build. Source preparation has regression checks covering consecutive upstream releases, subsequent ARM64 fixes, and preservation of the fork workflow. Dependencies are refreshed before compilation to resolve the APIs required by current upstream source.

If an upstream change needs a new ARM64 compatibility fix, the workflow reports the conflicting files. Update the `arm64` branch and rerun the workflow. GitHub can [disable inactive scheduled workflows](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows) in public repositories after 60 days.
