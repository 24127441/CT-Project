# Contributing Guide

## Code of Conduct

Be respectful, collaborative, and professional. Treat all team members with courtesy.

## Getting Started

1. Fork or clone the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test thoroughly
5. Create a pull request

## Development Workflow

### 1. Before Starting

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-feature
```

### 2. Make Changes

Follow code style:
- **Python:** PEP 8 (use `black` for formatting)
- **Dart:** Dart style guide (use `dart format`)
- **Naming:** Clear, descriptive names

### 3. Test Your Changes

**Backend:**
```bash
python manage.py test
python manage.py makemigrations --check
flake8 .
```

**Frontend:**
```bash
flutter analyze
flutter test
```

All tests must pass before submitting PR.

### 4. Commit Changes

Use conventional commits:
```
feat(trip): add weather-based danger detection
fix(auth): resolve OTP verification issue
docs: update API documentation
refactor(routes): simplify route filtering logic
```

```bash
git add .
git commit -m "feat(trip): add weather-based danger detection"
git push origin feature/my-feature
```

### 5. Create Pull Request

- Link related issues
- Describe changes clearly
- Add screenshots if UI changes
- Request reviewers
- Wait for CI/CD to pass

## Code Standards

### Backend (Django)

**Models:**
```python
class Plan(models.Model):
    """Trip plan with routes and safety info."""
    
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=255, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
        ]
    
    def __str__(self):
        return self.name
```

**Views:**
```python
class PlanViewSet(viewsets.ModelViewSet):
    """CRUD operations for plans."""
    
    serializer_class = PlanSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Return plans for current user only."""
        return Plan.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        """Attach current user to new plan."""
        serializer.save(user=self.request.user)
```

**Serializers:**
```python
class PlanSerializer(serializers.ModelSerializer):
    """Serializer for Plan model."""
    
    class Meta:
        model = Plan
        fields = ['id', 'name', 'location', 'start_date', 'end_date']
        read_only_fields = ['id', 'created_at']
```

### Frontend (Flutter)

**Widgets:**
```dart
class TripCard extends StatelessWidget {
  final Plan plan;
  
  const TripCard({required this.plan});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(plan.name),
        subtitle: Text(plan.location),
      ),
    );
  }
}
```

**Providers:**
```dart
class TripProvider extends ChangeNotifier {
  Plan? _currentPlan;
  
  Plan? get currentPlan => _currentPlan;
  
  Future<void> loadPlan(int id) async {
    try {
      _currentPlan = await _db.getPlanById(id);
      notifyListeners();
    } catch (e) {
      AppLogger.e('TripProvider', 'Error loading plan: $e');
      rethrow;
    }
  }
}
```

**Services:**
```dart
class PlanService {
  final SupabaseDbService _db;
  
  Future<Plan> createPlan(PlanRequest request) async {
    try {
      final response = await _db.createPlan(request);
      return Plan.fromJson(response);
    } catch (e) {
      AppLogger.e('PlanService', 'Create failed: $e');
      rethrow;
    }
  }
}
```

## Testing Requirements

### Backend Tests

```python
from django.test import TestCase
from plan.models import Plan

class PlanTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user('test', 'test@test.com')
    
    def test_plan_creation(self):
        plan = Plan.objects.create(
            user=self.user,
            name='Test Trip',
            location='Hanoi'
        )
        self.assertEqual(plan.name, 'Test Trip')
    
    def test_plan_str(self):
        plan = Plan.objects.create(user=self.user, name='Trip')
        self.assertEqual(str(plan), 'Trip')
```

### Frontend Tests

```dart
void main() {
  group('TripProvider', () {
    test('loads plan successfully', () async {
      final provider = TripProvider();
      await provider.loadPlan(1);
      expect(provider.currentPlan, isNotNull);
    });
    
    test('handles error gracefully', () async {
      final provider = TripProvider();
      expect(() => provider.loadPlan(-1), throwsException);
    });
  });
}
```

## Documentation

### Docstrings (Python)
```python
def get_danger_level(temperature: float, wind_speed: float) -> str:
    """
    Assess danger level based on weather conditions.
    
    Args:
        temperature: Temperature in Celsius
        wind_speed: Wind speed in km/h
    
    Returns:
        Danger level: 'safe', 'caution', 'warning', 'danger'
    """
```

### Comments (Dart)
```dart
/// Calculates distance between two coordinates.
/// 
/// Uses Haversine formula for great-circle distance.
double calculateDistance(LatLng from, LatLng to) {
  // Implementation
}
```

## Review Process

Reviewers look for:
- ✅ Tests pass
- ✅ Code follows style guide
- ✅ No security issues
- ✅ Performance acceptable
- ✅ Documentation complete
- ✅ Descriptive commit messages

### For Reviewers

- Be constructive and helpful
- Suggest improvements, don't demand
- Approve after addressing concerns
- Run code locally if possible

## Common Issues

### Test Failures
```bash
# Backend
python manage.py test --keepdb

# Frontend
flutter test --coverage
```

### Merge Conflicts
```bash
git fetch origin
git rebase origin/develop
# Resolve conflicts in editor
git add .
git rebase --continue
```

### Slow Builds
```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Clear Django cache
python manage.py clear_cache
```

## Performance Guidelines

### Backend
- Query time: <100ms (p95)
- Database connections: <20
- Memory per request: <100MB

### Frontend
- Build size: <150MB (release)
- Startup time: <3s
- 60 FPS rendering

## Security Checklist

- [ ] No secrets in code
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (use ORM)
- [ ] XSS prevention (sanitize output)
- [ ] CSRF tokens on forms
- [ ] Password requirements enforced
- [ ] Rate limiting on auth endpoints

## Release Process

1. Update version in `pubspec.yaml` and `settings.py`
2. Update `CHANGELOG.md`
3. Create PR to `main`
4. Get approval
5. Merge and tag: `git tag -a v1.0.0`
6. Push tag: `git push origin v1.0.0`
7. Create GitHub release notes
8. Deploy to production

## Questions?

- Open issue on GitHub
- Discuss in team meetings
- Ask in Slack channel
- Email team lead

## Thank You!

We appreciate your contributions to making this project better.
