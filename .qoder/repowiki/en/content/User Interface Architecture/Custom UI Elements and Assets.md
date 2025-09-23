# Custom UI Elements and Assets

<cite>
**Referenced Files in This Document**   
- [AppIcon.appiconset/Contents.json](file://To Do List/Assets.xcassets/AppIcon.appiconset/Contents.json)
- [AppIcon_WHITE.appiconset/Contents.json](file://To Do List/Assets.xcassets/AppIcon_WHITE.appiconset/Contents.json)
- [Buttons/icon_close.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_close.imageset/Contents.json)
- [Buttons/icon_home.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_home.imageset/Contents.json)
- [Buttons/icon_menu.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_menu.imageset/Contents.json)
- [Buttons/icon_search.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_search.imageset/Contents.json)
- [HomeTopBar/cal_Icon.imageset/Contents.json](file://To Do List/Assets.xcassets/HomeTopBar/cal_Icon.imageset/Contents.json)
- [Material_Icons/material_add.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_add.imageset/Contents.json)
- [Material_Icons/material_add_White.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_add_White.imageset/Contents.json)
- [Material_Icons/material_close.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_close.imageset/Contents.json)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Asset Catalog Structure](#asset-catalog-structure)
3. [App Icon Variants](#app-icon-variants)
4. [Navigation Buttons](#navigation-buttons)
5. [Material Design Icons](#material-design-icons)
6. [Top Bar and Calendar Integration](#top-bar-and-calendar-integration)
7. [Theme and Resolution Support](#theme-and-resolution-support)
8. [Accessibility and Dynamic Type](#accessibility-and-dynamic-type)
9. [Best Practices for Asset Usage](#best-practices-for-asset-usage)
10. [Conclusion](#conclusion)

## Introduction
This document provides a comprehensive overview of the custom UI elements and asset catalog structure used in the Tasker application. It details the organization, purpose, and usage of key image assets, including app icons, navigation buttons, material design icons, and top bar components with calendar integration. The documentation also covers support for light and dark themes, dynamic resolution handling, accessibility considerations, and best practices for developers when working with these assets.

## Asset Catalog Structure
The `Assets.xcassets` catalog is organized into logical groups to streamline asset management and ensure consistency across the application. The primary directories include:
- **AppIcon.appiconset**: Contains app icon variants for different device types and scales.
- **AppIcon_WHITE.appiconset**: White-themed app icons for dark mode compatibility.
- **Buttons**: Houses navigation and action buttons such as home, menu, search, and close.
- **HomeTopBar**: Contains assets for the top navigation bar, including the calendar icon.
- **Material_Icons**: Stores material design icons used for task actions, with both black and white variants.
- **TableViewCell**: Includes icons for table view interactions, such as dismiss actions at 24pt and 28pt sizes.

This structure enables developers to quickly locate and reference assets while maintaining a clean and scalable design system.

**Section sources**
- [To Do List/Assets.xcassets](file://To Do List/Assets.xcassets)

## App Icon Variants
The Tasker application supports multiple app icon variants to ensure optimal display across different devices and themes. The `AppIcon.appiconset` and `AppIcon_WHITE.appiconset` directories contain icons for various iOS device idioms (iPhone, iPad) and scales (1x, 2x, 3x), including sizes such as 20x20, 29x29, 40x40, 60x60, 76x76, and 83.5x83.5 points. Both sets include a 1024x1024 marketing icon for the App Store.

The white variant (`AppIcon_WHITE.appiconset`) ensures visibility in dark mode environments, maintaining brand consistency across themes. Developers should ensure that any updates to the app icon are applied to both sets to support dynamic theme switching.

**Section sources**
- [AppIcon.appiconset/Contents.json](file://To Do List/Assets.xcassets/AppIcon.appiconset/Contents.json)
- [AppIcon_WHITE.appiconset/Contents.json](file://To Do List/Assets.xcassets/AppIcon_WHITE.appiconset/Contents.json)

## Navigation Buttons
The `Buttons` directory contains vector-based PDF assets for key navigation elements, ensuring crisp rendering at any resolution. These include:
- **icon_close**: Close button used for dismissing views.
- **icon_home**: Home button for returning to the main screen.
- **icon_menu**: Menu button for accessing side navigation.
- **icon_search**: Search button for initiating search functionality.

Each button is defined with universal idiom support and includes 2x and 3x scale variants. The use of PDF vectors allows for dynamic scaling without loss of quality, reducing the need for multiple raster assets.

**Section sources**
- [Buttons/icon_close.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_close.imageset/Contents.json)
- [Buttons/icon_home.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_home.imageset/Contents.json)
- [Buttons/icon_menu.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_menu.imageset/Contents.json)
- [Buttons/icon_search.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_search.imageset/Contents.json)

## Material Design Icons
The `Material_Icons` directory provides a collection of material design icons used for task-related actions. Key icons include:
- **material_add**: Black add icon for light themes.
- **material_add_White**: White add icon for dark themes.
- **material_close**: Black close icon for light themes.

These icons are available in 1x, 2x, and 3x resolutions, with filenames indicating their color and size (e.g., `twotone_add_black_36pt`). The inclusion of white variants ensures proper visibility in dark mode. Developers should use the appropriate variant based on the current theme to maintain visual consistency.

**Section sources**
- [Material_Icons/material_add.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_add.imageset/Contents.json)
- [Material_Icons/material_add_White.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_add_White.imageset/Contents.json)
- [Material_Icons/material_close.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_close.imageset/Contents.json)

## Top Bar and Calendar Integration
The `HomeTopBar` directory contains the `cal_Icon` asset, which represents the calendar integration in the top navigation bar. This icon is available in three resolutions (1x, 2x, 3x) as PNG files (`calendar-dates1x.png`, `calendar-dates@2x.png`, `calendar-dates@3x.png`), ensuring sharp display on all device scales. The icon is used to indicate date-based task filtering or calendar synchronization features.

**Section sources**
- [HomeTopBar/cal_Icon.imageset/Contents.json](file://To Do List/Assets.xcassets/HomeTopBar/cal_Icon.imageset/Contents.json)

## Theme and Resolution Support
The asset catalog is designed to support both light and dark themes through dedicated white variants for key icons. Assets such as app icons, material design icons, and navigation buttons include white versions to ensure visibility in dark mode. Raster assets are provided in 1x, 2x, and 3x resolutions to accommodate different device pixel densities, while vector PDFs are used for buttons to enable infinite scalability.

Developers should ensure that theme-aware code references the correct asset variant based on the user's selected interface style. For example, `material_add` should be used in light mode, while `material_add_White` should be used in dark mode.

**Section sources**
- [AppIcon.appiconset/Contents.json](file://To Do List/Assets.xcassets/AppIcon.appiconset/Contents.json)
- [AppIcon_WHITE.appiconset/Contents.json](file://To Do List/Assets.xcassets/AppIcon_WHITE.appiconset/Contents.json)
- [Material_Icons/material_add_White.imageset/Contents.json](file://To Do List/Assets.xcassets/Material_Icons/material_add_White.imageset/Contents.json)

## Accessibility and Dynamic Type
All image assets should be accompanied by appropriate accessibility labels to ensure usability for visually impaired users. For example, the `icon_close` button should have an accessibility label of "Close" and a hint describing its action. Developers must ensure that image-based controls are properly exposed to VoiceOver and other assistive technologies.

While the current assets are primarily iconographic, the use of vector PDFs in the `Buttons` directory supports dynamic type compatibility by allowing icons to scale appropriately with text size changes. Developers should test asset rendering under different dynamic type settings to ensure consistent layout and usability.

**Section sources**
- [Buttons/icon_close.imageset/Contents.json](file://To Do List/Assets.xcassets/Buttons/icon_close.imageset/Contents.json)

## Best Practices for Asset Usage
When adding or modifying assets, developers should follow these best practices:
1. **Use Vector Assets**: Prefer PDF vectors for icons and buttons to ensure resolution independence.
2. **Maintain Naming Conventions**: Follow existing naming patterns (e.g., `icon_`, `material_`, `_White`) for consistency.
3. **Support Both Themes**: Provide white variants for all icons used in dark mode.
4. **Include All Resolutions**: For raster assets, include 1x, 2x, and 3x versions to support all device scales.
5. **Reference Assets Correctly**: Use asset catalog names in code (e.g., `UIImage(named: "icon_close")`) rather than file paths.
6. **Test Across Devices**: Verify asset rendering on different screen sizes and resolutions.
7. **Update Both Icon Sets**: When updating the app icon, modify both `AppIcon.appiconset` and `AppIcon_WHITE.appiconset`.

By adhering to these guidelines, developers can maintain a consistent, high-quality user interface across all themes and devices.

**Section sources**
- [To Do List/Assets.xcassets](file://To Do List/Assets.xcassets)

## Conclusion
The Tasker application's asset catalog is thoughtfully organized to support a consistent, accessible, and visually appealing user interface across both light and dark themes. By leveraging vector graphics, providing theme-specific variants, and maintaining a logical directory structure, the design system ensures scalability and ease of maintenance. Developers should follow the outlined best practices when working with assets to preserve the application's visual integrity and user experience.