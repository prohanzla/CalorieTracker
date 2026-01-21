# CalorieTracker

A comprehensive iOS calorie and nutrition tracking app with AI-powered features, HealthKit integration, and beautiful Liquid Glass UI design.

**Made by mpcode**

> ⚠️ **BETA SOFTWARE - WORK IN PROGRESS**
>
> This app is currently under active development and testing. Features may be incomplete, unstable, or change without notice. You may encounter bugs, crashes, or unexpected behaviour. Use at your own risk and please report any issues you find.

[![iOS](https://img.shields.io/badge/iOS-26.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-6.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-Native-green.svg)](https://developer.apple.com/documentation/swiftdata)

---

## Features

### Core Tracking
- **Daily Calorie Dashboard** - Beautiful animated progress ring showing daily intake vs goal
- **Comprehensive Macro Tracking** - Protein, Carbohydrates, Fat, Sugar, Fibre, and Salt
- **Calorie History Graph** - Interactive chart showing your progress over the last 14 days
- **History View** - Calendar-based view of past daily logs with full nutrition breakdowns

### AI-Powered Features
- **Multi-AI Provider Support** - Choose between Claude (Anthropic), Gemini (Google), or ChatGPT (OpenAI)
- **AI Nutrition Label Scanning** - Take a photo of any nutrition label and AI extracts all values per 100g
- **Natural Language Food Input** - Simply type "I had a large pizza" and AI estimates nutrition
- **AI Vitamin & Mineral Analysis** - Get estimated vitamin/mineral intake from your daily foods
- **AI Food Templates** - Save AI-generated foods for quick re-logging

### Scanning & Input
- **Barcode Scanning** - Quickly add products using AVFoundation barcode recognition
- **Image Cropping** - Crop nutrition label photos for better AI accuracy
- **Manual Entry** - Full manual product entry with all nutrition fields
- **Quick Add** - Add recent products and AI foods with one tap

### Health Integration
- **Apple HealthKit** - Sync with Apple Health for steps and active calories
- **Activity-Adjusted Goals** - Daily calorie target increases based on activity
- **Automatic Data Refresh** - HealthKit data syncs on app launch

### Data & Backup
- **iCloud Sync** - Automatic CloudKit sync keeps your data safe across devices
- **Manual Backup Export** - Export all data (products, logs, photos) to JSON file
- **Backup Import** - Restore data from backup with duplicate detection
- **Product Notes** - Add personal notes to any product

### Smart Features
- **Portion Size Support** - Products can have portion sizes (e.g., "4 x 115g portions")
- **Flexible Amount Entry** - Enter food by grams or portions with +/- buttons
- **Over-Limit Warnings** - Visual indicators when nutrients exceed recommended limits
- **Salt/Sodium Conversion** - Automatic conversion (Salt g = Sodium mg / 400)
- **Date Navigation** - View and edit food entries for previous days
- **Fullscreen Photo Viewer** - Tap product photos to view fullscreen with pinch-to-zoom

### User Experience
- **Swipeable Dashboard** - Three pages: Calories, Vitamins & Minerals, History Graph
- **Liquid Glass UI** - Beautiful iOS 26 glass effect design with fallback for older versions
- **Animated Backgrounds** - Dynamic gradient backgrounds
- **Dark Mode Support** - Full dark mode compatibility

### Settings & Customisation
- **Personalised Targets** - Set your own calorie and macro goals
- **BMR Calculator** - Calculate recommended calories using Mifflin-St Jeor equation
- **User Profile** - Store age, gender, height, weight for accurate calculations
- **Metric/Imperial Units** - Choose your preferred measurement system
- **AI Billing Links** - Quick access to check your AI provider billing/usage

---

## Screenshots

<p align="center">
  <img src="Screenshots/dashboard.png" width="250" alt="Dashboard">
  <img src="Screenshots/vitamins.png" width="250" alt="Vitamins">
  <img src="Screenshots/history.png" width="250" alt="History">
</p>

<p align="center">
  <img src="Screenshots/add-food.png" width="250" alt="Add Food">
  <img src="Screenshots/products.png" width="250" alt="Products">
  <img src="Screenshots/settings.png" width="250" alt="Settings">
</p>

| Screen | Description |
|--------|-------------|
| **Dashboard** | Main calorie ring with daily progress and macros breakdown |
| **Vitamins** | AI-analysed vitamins & minerals from your daily food intake |
| **History** | Interactive 14-day calorie history chart |
| **Add Food** | AI quick add, recent products, and food search |
| **Products** | Your saved products database |
| **Settings** | Profile, daily targets, HealthKit, and AI configuration |

---

## Requirements

- **iOS 26.0+** (Liquid Glass UI)
- **Xcode 26.0+**
- **iPhone 11 or later** (A13 Bionic chip minimum)
- **AI API Key** (at least one of: Claude, Gemini, or OpenAI)

---

## Setup

### 1. Clone the Repository
```bash
git clone https://github.com/mp-c0de/CalorieTracker.git
cd CalorieTracker
```

### 2. Open in Xcode
```
File → Open → Select CalorieTracker.xcodeproj
```

### 3. Configure Signing
- Select your development team in **Signing & Capabilities**
- Ensure the following capabilities are enabled:
  - HealthKit
  - Camera
  - iCloud (with CloudKit)
  - Push Notifications
  - Background Modes (Remote notifications)

### 4. Get an AI API Key

Choose at least one AI provider:

| Provider | Get API Key | Cost |
|----------|-------------|------|
| **Claude** | [console.anthropic.com](https://console.anthropic.com/) | Pay-as-you-go |
| **Gemini** | [aistudio.google.com](https://aistudio.google.com/app/apikey) | Free tier available |
| **OpenAI** | [platform.openai.com](https://platform.openai.com/api-keys) | Pay-as-you-go |

### 5. Build and Run
- Connect your iPhone
- Press `Cmd + R` to build and run

### 6. Configure in App
- Go to **Settings** tab
- Tap **AI Features** to add your API key
- Optionally connect **Apple Health**

---

## Project Structure

```
CalorieTracker/
├── CalorieTrackerApp.swift           # App entry point with SwiftData container
├── CalorieTracker.entitlements       # HealthKit permissions
│
├── Models/
│   ├── Product.swift                 # Product with full nutrition data
│   ├── FoodEntry.swift               # Individual food consumption entries
│   ├── DailyLog.swift                # Daily tracking with AI vitamin data
│   ├── AIFoodTemplate.swift          # Persistent AI food templates
│   ├── AILogEntry.swift              # AI estimation log entries
│   ├── Supplement.swift              # Supplement/vitamin pill model
│   ├── SupplementEntry.swift         # Daily supplement intake entries
│   └── NutrientDefinitions.swift     # Centralised vitamin/mineral definitions
│
├── Services/
│   ├── AIServiceProtocol.swift       # Unified AI service protocol
│   ├── ClaudeAPIService.swift        # Anthropic Claude integration
│   ├── GeminiAPIService.swift        # Google Gemini integration
│   ├── OpenAIService.swift           # OpenAI ChatGPT integration
│   ├── HealthKitManager.swift        # Apple Health integration
│   ├── BarcodeScannerService.swift   # AVFoundation barcode scanning
│   ├── DataBackupManager.swift       # Export/import backup functionality
│   └── SelectedDateManager.swift     # Shared date state for navigation
│
├── Views/
│   ├── ContentView.swift             # Main tab navigation
│   ├── DashboardView.swift           # Swipeable dashboard (ring, vitamins, history)
│   ├── AddFoodView.swift             # Food entry with AI input & quick add
│   ├── AddProductToLogSheet.swift    # Log product with amount selection
│   ├── HistoryView.swift             # Calendar-based history browser
│   ├── AILogView.swift               # AI estimation log view
│   ├── AISettingsView.swift          # AI provider configuration
│   ├── BarcodeScannerView.swift      # Camera barcode scanner
│   ├── NutritionCameraView.swift     # Nutrition label camera
│   ├── ImageCropperView.swift        # Photo cropping tool
│   ├── ManualEntryView.swift         # Manual product entry form
│   ├── ProductListView.swift         # Saved products list with edit support
│   ├── SupplementListView.swift      # Supplements list and management
│   ├── AddSupplementView.swift       # Add new supplements with presets
│   └── SettingsView.swift            # App settings, profile, billing links
│
└── Utils/
    └── AppBackground.swift           # Animated gradient backgrounds
```

---

## Technologies

| Technology | Purpose |
|------------|---------|
| **SwiftUI 6.0** | Modern declarative UI with Liquid Glass effects |
| **SwiftData** | Native Swift persistence framework |
| **Swift Charts** | Interactive calorie history graphs |
| **AVFoundation** | Camera and barcode scanning |
| **HealthKit** | Apple Health integration |
| **Claude API** | AI nutrition parsing (Anthropic) |
| **Gemini API** | AI nutrition parsing (Google) |
| **OpenAI API** | AI nutrition parsing (ChatGPT) |

---

## Daily Recommended Values

The app uses these reference values:

| Nutrient | Male | Female | Unit |
|----------|------|--------|------|
| Calories | Calculated via BMR | Calculated via BMR | kcal |
| Protein | 56 | 46 | g |
| Carbohydrates | 300 | 225 | g |
| Fat | 78 | 65 | g |
| Sugar (max) | 36 | 25 | g |
| Fibre | 38 | 25 | g |
| Salt (max) | 6 | 6 | g |

Vitamin and mineral targets follow NHS/EU reference intakes.

---

## Privacy

- **Camera**: Required for barcode and nutrition label scanning
- **HealthKit**: Optional - for steps and active calories (read-only)
- **iCloud**: Optional - automatic sync via CloudKit for backup across devices
- **API Keys**: Stored locally in UserDefaults on your device
- **Data Storage**: All nutrition data stored locally using SwiftData (with optional iCloud sync)
- **Network**: Only AI API calls and iCloud sync (if enabled)
- **No Analytics**: No tracking or analytics are collected

---

## Licence

**Copyright (c) 2024-2025 mpcode. All Rights Reserved.**

This software is proprietary and confidential. Unauthorised copying, modification, distribution, or use of this software, via any medium, is strictly prohibited without express written permission from the copyright holder.

For licensing enquiries, contact: mpcode@icloud.com

---

## Author

**mpcode**

- GitHub: [@mp-c0de](https://github.com/mp-c0de)
- LinkedIn: [mpc0de](https://www.linkedin.com/in/mpc0de/)

---

## Links

- [GitHub Repository](https://github.com/mp-c0de/CalorieTracker)
- [Claude API Documentation](https://docs.anthropic.com/)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [OpenAI API Documentation](https://platform.openai.com/docs)

---

## Changelog

### v1.3.0-beta.4 (January 2025) - HealthKit Profile Sync
- **HealthKit Profile Import** - Auto-fill profile from Apple Health
  - Imports height, weight, date of birth, and biological sex
  - One-tap "Sync" button in Settings after connecting HealthKit
  - Shows available data from Health before syncing
  - Auto-syncs on first HealthKit connection

### v1.3.0-beta.3 (January 2025) - Supplements & Product Editing
- **Supplements Tracking** - New supplements/vitamins pills tracking system
  - Add supplements with full vitamin/mineral data per serving
  - Log daily supplement intake with amount tracking
  - Quick presets for common supplements (Vitamin D3, B-Complex, Multivitamin, etc.)
  - Supports multiple dosage forms: tablet, capsule, softgel, gummy, liquid, powder
  - Supplements automatically add to daily vitamin/mineral totals
- **Edit Products** - Products can now be edited from the detail view (V15)
  - Edit name, brand, all nutrition values
  - Edit all vitamins and minerals
- **AI Logs in Toolbar** - Moved AI Logs from tab bar to top toolbar near calendar
- **Earned Calories Fix** - "All Active" mode now correctly combines daily activity + workouts
- **Vitamin Calculation Fix** - Fixed critical bug with vitamin/mineral calculation for piece units
- **Data Persistence** - Food entries now store nutrient data, persisting even if product is deleted
- **2 Decimal Precision** - Nutrition values now display with 2 decimal places

### v1.3.0-beta.1 (January 2025) - First Beta Release
- **Favorite Nutrients** - Mark vitamins/minerals as favourites with heart icons for quick tracking
- **Favorites Card** - Dedicated card below calorie ring showing your favourite nutrients with larger rings
- **Product Images in Dashboard** - Today's food entries now show product photos instead of emojis
- **Add to Today** - Quick add products directly from Products and Manual Products views
- **TipKit Integration** - Native iOS tooltips for first-time user guidance
- **Improved Scroll Performance** - Fixed Dashboard scroll bouncing/shaking issues
- **Simplified Tutorial System** - Replaced custom coach marks with native TipKit
- **UI Refinements** - Various layout and visual improvements throughout

### v1.2.0 (January 2025)
- Added Manual Products tab for products without barcodes
- Moved Settings to Dashboard toolbar (gear icon)
- Added view identifier badges for development/testing
- Fixed portion display - now shows "1 portion" instead of converting to grams
- Improved sugar tracking - separate Natural Sugar and Added Sugar fields
- Updated AI prompts to correctly classify sugar types from nutrition labels
- Added vitamin estimation AI logging
- Smooth tab bar animation when entering/exiting Settings
- Tutorial coach marks updated for new tab layout
- Various UI improvements and bug fixes

### v1.1.0 (January 2025)
- iCloud/CloudKit sync for automatic backup across devices
- Manual backup export/import with JSON (includes photos)
- Date navigation - view and log food for previous days
- Product notes - add personal notes to any product
- Fullscreen photo viewer with pinch-to-zoom
- Redesigned photo review screen with glass effects
- Chart tap detection improvements
- Various UI polish and bug fixes

### v1.0.0 (January 2025)
- Initial release
- Multi-AI provider support (Claude, Gemini, OpenAI)
- HealthKit integration
- Swipeable dashboard with calories, vitamins, and history
- Comprehensive macro tracking with salt/sodium conversion
- AI vitamin and mineral analysis
- Liquid Glass UI design for iOS 26
- Calendar-based history view
- AI food templates for quick re-logging
