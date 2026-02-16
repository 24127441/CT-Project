# Frontend - Flutter

Cross-platform mobile and web application for smart travel planning.

## Quick Start

### 1. Setup
```bash
cd frontend
flutter pub get
```

### 2. Environment
Copy and fill your environment file:
```bash
cp .env.example .env
```

### 3. Run

**Mobile (iOS/Android):**
```bash
flutter run
```

**Web:**
```bash
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart                 App entry point
├── screens/                  Pages and dialogs
│   ├── auth/                Authentication screens
│   ├── trip_dashboard.dart   Main dashboard
│   └── tripinfo*.dart       Trip creation steps
├── providers/               State management
│   ├── auth_provider.dart
│   ├── trip_provider.dart
│   └── route_provider.dart
├── services/                Business logic
│   ├── api_service.dart
│   ├── supabase_db_service.dart
│   ├── auth_service.dart
│   └── plan_service.dart
├── models/                  Data classes
│   ├── plan.dart
│   ├── route.dart
│   └── equipment.dart
├── widgets/                 Reusable components
└── utils/                   Helpers and constants
```

## Development

### Code Quality
```bash
# Check for issues
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test
```

All code must pass `flutter analyze` with 0 errors.

### State Management

Uses **Provider** for reactive state:

```dart
final tripProvider = Provider.of<TripProvider>(context, listen: false);
tripProvider.updateTripName('New Name');
```

### API Integration

Use `SupabaseDbService`:

```dart
final db = SupabaseDbService();
final routes = await db.getSuggestedRoutes(
  location: 'Sa Pa',
  difficulty: 'hard',
);
```

## Building for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

## Key Features

- **Trip Planning:** Create and manage trips with filters
- **Route Discovery:** AI-powered route recommendations
- **Safety Alerts:** Automated weather and hazard detection
- **Equipment Checklist:** Curated lists by route type
- **Route Visualization:** Interactive maps with elevation profiles
- **Templates:** Save and reuse trip configurations

## Dependencies

- **flutter_dotenv** - Environment variables
- **provider** - State management
- **supabase_flutter** - Database and auth
- **http** - HTTP client
- **maplibre_gl** - Map visualization
- **flutter_map** - Alternative map
- **fl_chart** - Charts and graphs
- **intl** - Internationalization
- **url_launcher** - External links

## Configuration

### Supabase
Set in `.env`:
```
SUPABASE_URL=your-supabase-url
SUPABASE_KEY=your-anon-key
```

### API
```
API_BASE_URL=http://localhost:8000
```

### Gemini
```
GEMINI_API_KEY=your-api-key
```

## Troubleshooting

**Won't run?**
```bash
flutter clean
flutter pub get
flutter run
```

**Hot reload not working?**
```bash
flutter run --no-fast-start
```

**Build issues?**
```bash
flutter pub upgrade
flutter pub get
```

## Resources

- [Flutter Docs](https://flutter.dev)
- [Provider Package](https://pub.dev/packages/provider)
- [Supabase Flutter](https://supabase.com/docs/reference/flutter)
