# CalorieTracker

iOS calorie tracking app with barcode scanning and AI-powered nutrition label recognition.

**Made by mpcode**

## Features

- **Barcode Scanning**: Quickly add products by scanning their barcode
- **AI Nutrition Label Scanning**: Take a photo of any nutrition label and let Claude AI extract all the nutritional information
- **Natural Language Food Input**: Simply type "I had one apple" and AI estimates the calories
- **Daily Tracking Dashboard**: Visual progress rings showing your daily calorie and macro intake
- **Product Database**: Build your personal database of frequently consumed products
- **Customisable Targets**: Set your own daily calorie and macro goals

## Requirements

- iOS 26.0+
- Xcode 26.0+
- iPhone 11 or later (A13 Bionic chip minimum)
- Claude API key (for AI features)

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/mp-c0de/CalorieTracker.git
   ```

2. Open in Xcode 26:
   - Open Xcode
   - File → Open → Select the `CalorieTracker` folder
   - Create a new iOS App project if needed and add the Swift files from `CalorieTracker/` folder

3. Configure signing:
   - Select your development team in Signing & Capabilities
   - Camera usage description will be auto-configured

4. Get a Claude API key:
   - Visit [console.anthropic.com](https://console.anthropic.com/)
   - Create an API key
   - Add it in the app's Settings tab

5. Build and run on your device

## Project Structure

```
CalorieTracker/
├── CalorieTrackerApp.swift      # App entry point with SwiftData container
├── Models/
│   ├── Product.swift            # Product model with full nutrition data
│   ├── FoodEntry.swift          # Individual food consumption entries
│   └── DailyLog.swift           # Daily tracking with targets
├── Services/
│   ├── ClaudeAPIService.swift   # Claude API integration
│   └── BarcodeScannerService.swift # AVFoundation barcode scanning
├── Views/
│   ├── ContentView.swift        # Main tab navigation
│   ├── DashboardView.swift      # Daily calorie dashboard
│   ├── AddFoodView.swift        # Food entry with AI input
│   ├── BarcodeScannerView.swift # Camera barcode scanner
│   ├── NutritionCameraView.swift # Nutrition label camera
│   ├── ManualEntryView.swift    # Manual product entry form
│   ├── ProductListView.swift    # Saved products list
│   └── SettingsView.swift       # App settings and API config
└── Utils/
```

## Technologies

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Native Swift persistence framework
- **AVFoundation** - Camera and barcode scanning
- **Claude API** - AI-powered nutrition parsing and food estimation

## Privacy

- Camera access is required for barcode and nutrition label scanning
- Your Claude API key is stored locally on your device
- No data is sent to external servers except Claude API calls for AI features
- All nutrition data is stored locally using SwiftData

## Licence

MIT Licence - feel free to use and modify as needed.

## Links

- [GitHub Repository](https://github.com/mp-c0de/CalorieTracker)
- [Claude API Documentation](https://docs.anthropic.com/)
