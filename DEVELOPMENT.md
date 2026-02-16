# Development Guide

## Project Setup

### Prerequisites
- Python 3.9+
- Flutter 3.x
- Git
- VS Code or Android Studio

### Clone & Initial Setup

```bash
git clone <repo-url>
cd CT-Project
./scripts/setup_local_env.ps1
```

## Backend Development

### Start the Backend

```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
copy .env.example .env
# Edit .env with your Supabase credentials

# Run migrations
python manage.py migrate

# Create superuser (optional)
python manage.py createsuperuser

# Start server
python manage.py runserver
```

Server runs at `http://localhost:8000`

### Django Admin Interface
Access at `http://localhost:8000/admin` with superuser credentials.

### Creating Models

1. Create model in `apps/models.py`
2. Create migration: `python manage.py makemigrations`
3. Apply migration: `python manage.py migrate`
4. Create serializer in `apps/serializers.py`
5. Create viewset in `apps/views.py`
6. Register in `apps/urls.py`

### Useful Commands

```bash
# Run tests
python manage.py test

# Create superuser
python manage.py createsuperuser

# Database shell
python manage.py shell

# Check migrations
python manage.py showmigrations

# Reset database
python manage.py flush
```

## Frontend Development

### Start the Frontend

```bash
cd frontend

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run on Chrome web
flutter run -d chrome

# Run on specific device
flutter run -d <device-id>
```

### Code Structure

**Screens:** Complete pages with UI and logic
- `tripinfo*.dart` - Multi-step trip creation
- `trip_dashboard.dart` - Main dashboard with tabs
- `auth/*` - Authentication pages

**Providers:** State management using Provider pattern
- `TripProvider` - Trip creation state
- `AuthProvider` - Authentication state
- `RouteProvider` - Route discovery state

**Services:** Business logic and API calls
- `api_service.dart` - HTTP client
- `supabase_db_service.dart` - Database operations
- `plan_service.dart` - Trip logic
- `auth_service.dart` - Authentication

**Models:** Data classes
- `plan.dart` - Trip/Plan model
- `route.dart` - Route model
- `equipment.dart` - Equipment model

### Creating a New Screen

1. Create file in `lib/screens/`
2. Extend `StatefulWidget` or `StatelessWidget`
3. Use `Consumer` to access providers
4. Add to navigation in `main.dart`

Example:
```dart
class MyNewScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: Text('My Screen')),
          body: Center(child: Text('Hello')),
        );
      },
    );
  }
}
```

### Using Providers

Consume provider state:
```dart
final tripProvider = Provider.of<TripProvider>(context, listen: false);
tripProvider.updateTripName('New Name');
```

Watch for changes:
```dart
final tripProvider = Provider.of<TripProvider>(context, listen: true);
```

### Making API Calls

Use `supabase_db_service.dart`:
```dart
final db = SupabaseDbService();
final routes = await db.getSuggestedRoutes(
  location: 'Sa Pa',
  difficulty: 'hard',
);
```

### Testing

Run all tests:
```bash
flutter test
```

Run specific test file:
```bash
flutter test test/screens/trip_dashboard_test.dart
```

Debug test:
```bash
flutter test -v --dart-define=TEST_MODE=true
```

### Code Quality

Check for issues:
```bash
flutter analyze
```

Format code:
```bash
flutter format lib/
```

All code should pass `flutter analyze` with 0 errors.

## Common Tasks

### Add a New API Endpoint

**Backend:**
1. Create view in `app/views.py`
2. Create serializer in `app/serializers.py`
3. Register in `app/urls.py`
4. Test with `curl` or Postman

**Frontend:**
1. Add method to `supabase_db_service.dart`
2. Call from provider or screen
3. Handle errors gracefully

### Add State to Provider

```dart
class TripProvider extends ChangeNotifier {
  String _myField = '';
  
  String get myField => _myField;
  
  void updateField(String value) {
    _myField = value;
    notifyListeners();
  }
}
```

### Debug the App

**Flutter:**
```bash
# Enable debug logging
flutter run -v

# Debug on device
flutter run --debug

# Use DevTools
flutter pub global run devtools
flutter run --dart-devtools-uri=http://localhost:9100
```

**Backend:**
```bash
# Enable debug in settings.py
DEBUG = True

# Use Django shell
python manage.py shell
>>> from plan.models import Plan
>>> plans = Plan.objects.all()
```

## Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - Feature branches
- `fix/*` - Bug fix branches
- `chore/*` - Maintenance branches

### Making Changes

1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and commit: `git commit -m "feat: add new feature"`
3. Push: `git push origin feature/my-feature`
4. Create pull request on GitHub
5. Get review and merge to `develop`
6. After testing, merge `develop` to `main`

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Code style (no logic changes)
- `refactor` - Code refactoring
- `test` - Test updates
- `chore` - Build/dependencies

Example:
```
feat(trip): add weather-based danger detection

Implemented automatic weather analysis for trips
using Open-Meteo API. Detects high temperatures,
heavy precipitation, and strong winds.

Closes #123
```

## Performance Optimization

### Frontend
- Use `const` constructors where possible
- Minimize rebuilds with Provider `listen: false`
- Cache images and routes
- Use `ListView.builder` for long lists

### Backend
- Use `select_related()` and `prefetch_related()`
- Add database indexes for frequently filtered fields
- Cache serializer output
- Use pagination for large result sets

## Troubleshooting

### Flutter Won't Run
```bash
flutter clean
flutter pub get
flutter run
```

### Backend Migrations Fail
```bash
python manage.py makemigrations
python manage.py migrate --fake-initial
```

### API Returns 401
- Check Supabase JWT token validity
- Verify `Authorization` header format
- Check `.env` credentials

### Hot Reload Not Working
```bash
flutter run --no-fast-start
```

## Resources

- [Flutter Docs](https://flutter.dev/docs)
- [Django Docs](https://docs.djangoproject.com)
- [Provider Package](https://pub.dev/packages/provider)
- [Supabase Docs](https://supabase.com/docs)
