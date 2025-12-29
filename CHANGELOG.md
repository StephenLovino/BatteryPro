# Changelog

## [1.2.0] - 2025-12-30

### Fixed
-   **Bypass Toggle**: Resolved an issue where disabling "Manual Bypass" would not properly re-enable charging.
-   **Charging Logic**: Updated `checkCharging()` to dynamically detect the correct SMC key (`CHTE`, `CH0B`, etc.) instead of relying on a hardcoded value.
-   **SMC Connection**: Fixed a resource leak in `SMCKit` where connections were repeatedly opened without being closed, leading to "failedToOpen" errors.
-   **Helper Tool**: Incremented helper version to force a reinstall, insuring all users get the latest SMC fixes.
