# CalorieTracker

A comprehensive iOS calorie and nutrition tracking app with AI-powered features, HealthKit integration, and beautiful Liquid Glass UI design.

**Made by mpcode**

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

### Smart Features
- **Portion Size Support** - Products can have portion sizes (e.g., "4 x 115g portions")
- **Flexible Amount Entry** - Enter food by grams or portions with +/- buttons
- **Over-Limit Warnings** - Visual indicators when nutrients exceed recommended limits
- **Salt/Sodium Conversion** - Automatic conversion (Salt g = Sodium mg / 400)

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

| Dashboard | Vitamins | History |
|-----------|----------|---------|
| Calorie ring with macros | AI-analysed vitamins & minerals | 14-day calorie chart |

| Add Food | Scan Label | Settings |
|----------|------------|----------|
| AI quick add & search | Camera nutrition scanning | Profile & AI config |

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
│   └── AILogEntry.swift              # AI estimation log entries
│
├── Services/
│   ├── AIServiceProtocol.swift       # Unified AI service protocol
│   ├── ClaudeAPIService.swift        # Anthropic Claude integration
│   ├── GeminiAPIService.swift        # Google Gemini integration
│   ├── OpenAIService.swift           # OpenAI ChatGPT integration
│   ├── HealthKitManager.swift        # Apple Health integration
│   └── BarcodeScannerService.swift   # AVFoundation barcode scanning
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
│   ├── ProductListView.swift         # Saved products list
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
- **API Keys**: Stored locally in UserDefaults on your device
- **Data Storage**: All nutrition data stored locally using SwiftData
- **Network**: Only AI API calls are made (to your chosen provider)
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
