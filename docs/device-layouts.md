# Device layout inventory

Extracted from Apple's installed CoreSimulator `capabilities.plist` profiles. Includes the iPhone 16 family and later / Air, plus all installed iPad profiles compatible with iPadOS 26. RAM variants have identical geometry and are represented once. SDK profiles may include models newer than the launch baseline.

**These are physical display dimensions, not hard-coded application layouts.** GridZero uses the current window's safe-area size at runtime, including rotation, Display Zoom, and iPad window resizing. Safe-area insets vary by OS and window state.

| Model | Portrait points | Native pixels | Scale | Minimum OS |
|---|---:|---:|---:|---|
| iPad mini (6th generation) | 744 × 1133 | 1488 × 2266 | 2.0× | 15.0.0 |
| iPad mini (A17 Pro) | 744 × 1133 | 1488 × 2266 | 2.0× | 18.1.0 |
| iPad mini (5th generation) | 768 × 1024 | 1536.0 × 2048 | 2.0× | 12.2.0 |
| iPad (8th generation) | 810 × 1080 | 1620 × 2160 | 2.0× | 13.0.0 |
| iPad (9th generation) | 810 × 1080 | 1620 × 2160 | 2.0× | 15.0.0 |
| iPad (10th generation) | 820 × 1180 | 1640 × 2360 | 2.0× | 16.1.0 |
| iPad (A16) | 820 × 1180 | 1640 × 2360 | 2.0× | 18.3.0 |
| iPad Air (4th generation) | 820 × 1180 | 1640 × 2360 | 2.0× | 12.2.0 |
| iPad Air (5th generation) | 820 × 1180 | 1640 × 2360 | 2.0× | 15.4.0 |
| iPad Air 11-inch (M2) | 820 × 1180 | 1640 × 2360 | 2.0× | 17.4.0 |
| iPad Air 11-inch (M3) | 820 × 1180 | 1640 × 2360 | 2.0× | 18.3.0 |
| iPad Air 11-inch (M4) | 820 × 1180 | 1640 × 2360 | 2.0× | 26.3.0 |
| iPad Air (3rd generation) | 834 × 1112 | 1668 × 2224 | 2.0× | 12.2.0 |
| iPad Pro (11-inch) (1st generation) | 834 × 1194 | 1668 × 2388 | 2.0× | 12.0.0 |
| iPad Pro (11-inch) (2nd generation) | 834 × 1194 | 1668 × 2388 | 2.0× | 13.4.0 |
| iPad Pro (11-inch) (3rd generation) | 834 × 1194 | 1668 × 2388 | 2.0× | 14.5.0 |
| iPad Pro (11-inch) (4th generation) | 834 × 1194 | 1668 × 2388 | 2.0× | 16.1.0 |
| iPad Pro 11-inch (M4) | 834 × 1210 | 1668 × 2420 | 2.0× | 17.4.0 |
| iPad Pro 11-inch (M5) | 834 × 1210 | 1668 × 2420 | 2.0× | 26.0.0 |
| iPad Air 13-inch (M2) | 1024 × 1366 | 2048 × 2732 | 2.0× | 17.4.0 |
| iPad Air 13-inch (M3) | 1024 × 1366 | 2048 × 2732 | 2.0× | 18.3.0 |
| iPad Air 13-inch (M4) | 1024 × 1366 | 2048 × 2732 | 2.0× | 26.3.0 |
| iPad Pro (12.9-inch) (3rd generation) | 1024 × 1366 | 2048 × 2732 | 2.0× | 12.0.0 |
| iPad Pro (12.9-inch) (4th generation) | 1024 × 1366 | 2048 × 2732 | 2.0× | 13.4.0 |
| iPad Pro (12.9-inch) (5th generation) | 1024 × 1366 | 2048 × 2732 | 2.0× | 14.5.0 |
| iPad Pro (12.9-inch) (6th generation) | 1024 × 1366 | 2048 × 2732 | 2.0× | 16.1.0 |
| iPad Pro 13-inch (M4) | 1032 × 1376 | 2064 × 2752 | 2.0× | 17.4.0 |
| iPad Pro 13-inch (M5) | 1032 × 1376 | 2064 × 2752 | 2.0× | 26.0.0 |
| iPhone 16e | 390 × 844 | 1170 × 2532 | 3.0× | 18.3.0 |
| iPhone 17e | 390 × 844 | 1170 × 2532 | 3.0× | 26.3.0 |
| iPhone 16 | 393 × 852 | 1179 × 2556 | 3.0× | 18.0.0 |
| iPhone 16 Pro | 402 × 874 | 1206 × 2622 | 3.0× | 18.0.0 |
| iPhone 17 | 402 × 874 | 1206 × 2622 | 3.0× | 26.0.0 |
| iPhone 17 Pro | 402 × 874 | 1206 × 2622 | 3.0× | 26.0.0 |
| iPhone 18 Pro | 402 × 874 | 1206 × 2622 | 3.0× | 27.0.0 |
| iPhone Air | 420 × 912 | 1260 × 2736 | 3.0× | 26.0.0 |
| iPhone 16 Plus | 430 × 932 | 1290 × 2796 | 3.0× | 18.0.0 |
| iPhone 16 Pro Max | 440 × 956 | 1320 × 2868 | 3.0× | 18.0.0 |
| iPhone 17 Pro Max | 440 × 956 | 1320 × 2868 | 3.0× | 26.0.0 |
| iPhone 18 Pro Max | 440 × 956 | 1320 × 2868 | 3.0× | 27.0.0 |

40 model profiles, 15 distinct family/display geometries.

## Layout behavior

- Phone portrait: edge-to-edge square grid, staggered keypad below.
- Tablet portrait / tall windows: centered square grid, capped at 720 points; keypad capped at 480 points.
- Landscape / sufficiently wide short windows: square grid on the left, staggered keypad on the right.
- Narrow or short windows: tighter spacing first; the grid scales down only when needed to preserve all controls.
- Key touch targets remain at least 44 × 44 points in the tested window range. No gameplay scrolling.

The inventory feeds geometry tests for every model in both orientations with conservative safe-area budgets. Additional tests sweep resizable windows and Display Zoom sizes. See `layout-verification.md` for actual simulator checks; mathematical coverage and simulator execution are recorded separately.
