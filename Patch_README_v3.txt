
GliderTracker Patch – 2025-07-04

Files in this zip replace or add to your existing Xcode project.

• PilotFetcher.swift
    – Adds fallback for legacy lat/lon fields
    – Queries only records newer than 15 min
    – Removes any sort descriptor on `position` (location fields cannot be sorted server‑side)

Installation
------------
1. Unzip the archive.
2. Drag `PilotFetcher.swift` into your Xcode project, replacing the existing file.
3. Clean build folder (⇧⌘K) and run on a device or simulator.

No other source files were changed. If you previously added server‑side sorting
on the `position` field elsewhere, remove it or switch to `timestamp`.
