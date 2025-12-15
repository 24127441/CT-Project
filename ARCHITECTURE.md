# System Architecture

## Overview

The Smart Tourism System is built on a modern three-tier architecture, separating concerns across presentation, application, and data layers. This design enables scalability, maintainability, and independent deployment of components.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│           CLIENT LAYER (Presentation)                      │
├─────────────────────────────────────────────────────────────┤
│  Flutter App (iOS/Android/Web)                              │
│  ├─ UI Components (Screens, Widgets)                        │
│  ├─ State Management (Provider)                             │
│  ├─ Service Layer (API, Database, Auth)                     │
│  └─ Utilities (Logging, Validation, Navigation)             │
└────────────┬──────────────────────────────────┬─────────────┘
             │                                  │
          REST API                        WebSocket
             │                                  │
┌────────────▼──────────────────────────────────▼─────────────┐
│         APPLICATION LAYER (Business Logic)                 │
├─────────────────────────────────────────────────────────────┤
│  Django REST Framework                                      │
│  ├─ Views/ViewSets (API Endpoints)                          │
│  ├─ Serializers (Data Validation & Transform)               │
│  ├─ Models (Domain Objects)                                 │
│  ├─ Managers & QuerySets (Database Access)                  │
│  └─ Services (Business Logic)                               │
│      ├─ RouteRecommendationService (Gemini AI)              │
│      ├─ DangerAssessmentService (Weather API)               │
│      ├─ AuthenticationService (Supabase)                    │
│      └─ EquipmentCalculationService                         │
└────────────┬──────────────────────────────────┬─────────────┘
             │                                  │
          SQL/ORM                        Real-time
             │                           Events
┌────────────▼──────────────────────────────────▼─────────────┐
│         DATA LAYER (Persistence & Storage)                 │
├─────────────────────────────────────────────────────────────┤
│  Supabase PostgreSQL                                        │
│  ├─ Plans Table (Trip Definitions)                          │
│  ├─ Routes Table (Predefined Paths)                         │
│  ├─ Equipment Table (Gear Catalog)                          │
│  ├─ HistoryInput Table (User Templates)                     │
│  ├─ Auth (User Management & JWT)                            │
│  └─ RLS Policies (Row-Level Security)                       │
└─────────────────────────────────────────────────────────────┘
             │
  ┌──────────┴──────────┬──────────────┬──────────────┐
  │                     │              │              │
  ▼                     ▼              ▼              ▼
Gemini API        Open-Meteo API   Nominatim API   Shopee API
(AI Recs)        (Weather Data)   (Geocoding)     (Shopping)
```

---

## Frontend Architecture (Flutter)

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── constants/           # App-wide constants
│   ├── theme/               # Color schemes, typography
│   └── error/               # Custom exceptions
├── features/                # Feature-specific modules
│   ├── auth/
│   │   ├── providers/       # State management
│   │   ├── screens/         # UI screens
│   │   └── services/        # Authentication logic
│   ├── trip/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── services/
│   ├── routes/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── services/
│   └── dashboard/
│       ├── providers/
│       ├── screens/
│       └── services/
├── models/                  # Data models
├── providers/               # Global state management
├── screens/                 # App-level screens
├── services/                # Global services
│   ├── api_service.dart    # REST API calls
│   ├── auth_service.dart   # Authentication
│   └── supabase_db_service.dart
├── utils/                   # Utilities
└── widgets/                 # Reusable components
```

### State Management Pattern (Provider)

```
┌─────────────────────────┐
│   Flutter Widgets       │
│   (UI Components)       │
└────────────┬────────────┘
             │ listen/watch
┌────────────▼─────────────────────┐
│  ChangeNotifier Providers         │
│  ├─ AuthProvider                  │
│  ├─ TripProvider                  │
│  ├─ RouteProvider                 │
│  └─ ThemeProvider                 │
└────────────┬─────────────────────┘
             │ notifyListeners()
┌────────────▼────────────────────────┐
│  Services (API, Database, Auth)     │
│  ├─ ApiService                      │
│  ├─ AuthService                     │
│  └─ SupabaseDbService               │
└────────────┬────────────────────────┘
             │
┌────────────▼─────────────────────────┐
│  External Services & APIs            │
│  ├─ REST Backend                     │
│  ├─ Supabase                         │
│  └─ External APIs                    │
└─────────────────────────────────────┘
```

---

## Backend Architecture (Django)

### Project Structure

```
backend/
├── manage.py
├── requirements.txt
├── trek_guide_project/      # Main project settings
│   ├── settings.py          # Django configuration
│   ├── urls.py              # Main URL router
│   ├── asgi.py              # Async server gateway
│   ├── wsgi.py              # WSGI server gateway
│   └── supabase_auth.py     # Custom auth backend
├── plan/                     # Trip planning app
│   ├── models.py            # Plan, DangerSnapshot
│   ├── views.py             # ViewSets for API
│   ├── serializers.py       # Data serialization
│   ├── urls.py              # App URL routing
│   └── migrations/          # Database migrations
├── routes/                   # Route management app
│   ├── models.py            # Route model
│   ├── views.py
│   └── serializers.py
├── safety/                   # Safety assessment
│   ├── models.py
│   └── services.py
└── users/                    # User management
    ├── models.py
    ├── serializers.py
    └── views.py
```

### API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/plans/` | List user plans |
| POST | `/api/plans/` | Create plan |
| GET | `/api/routes/` | Discover routes |
| GET | `/api/equipment/` | List equipment |
| GET | `/api/templates/` | List templates |

---

## Data Models

### Core Entities

**Plan** (Trip)
- `id` - UUID
- `user_id` - Supabase user reference
- `name` - Trip name
- `destination` - Location
- `start_date` / `end_date` - Trip duration
- `group_size` - Number of participants
- `personal_interest` - User preferences
- `dangers_snapshot` - Cached weather data
- `routes` - Related Route objects

**Route** (Path/Trail)
- `id` - UUID
- `name` - Route name
- `location` - Geographic location
- `difficulty` - ease, moderate, hard
- `duration_days` - Estimated length
- `distance_km` - Total distance
- `elevation_gain_m` - Vertical climb
- `accommodation_types` - Available lodging
- `estimated_cost_usd` - Budget estimate
- `ai_note` - AI-generated description
- `elevation_profile` - Terrain data

**Equipment**
- `id` - UUID
- `name` - Equipment name
- `category` - Type (footwear, shelter, etc)
- `weight_g` - Gear weight
- `estimated_cost_usd` - Price estimate
- `shopee_link` - Shopping link

**HistoryInput** (Template)
- `id` - UUID
- `user_id` - Supabase user reference
- `name` - Template name
- `personal_interest` - Saved preferences
- `default_duration` - Typical trip length
- `default_group_size` - Common party size

---

## Authentication Flow

Requests are authenticated using Supabase JWT tokens:

1. User signs up/in via Supabase
2. Frontend receives JWT access token
3. Token stored securely in device
4. Included in API requests: `Authorization: Bearer {token}`
5. Backend validates signature and extracts user_id
6. User can access protected resources

**Row-Level Security:** Supabase policies ensure users only see their own data.

---

## External API Integration

### Gemini API (Route Recommendations)
- Receives trip details and location
- Generates personalized route suggestions
- Results cached as Route.ai_note

### Open-Meteo API (Weather Data)
- Provides weather forecast for trip dates
- Identifies environmental hazards
- Stored in Plan.dangers_snapshot

### Nominatim (Geocoding)
- Converts location names to coordinates
- Enables accurate map display
- Free, no authentication required

---

## Scalability & Performance

### Database Optimization
- Strategic indexes on frequently filtered columns
- Query prefetching to avoid N+1 problems
- Connection pooling for efficiency

### Caching
- API responses cached for 5 minutes
- Route list cached to reduce database load
- Client-side caching in Flutter app

### Horizontal Scaling
- Multiple Django instances behind load balancer
- Supabase handles database replication
- CDN serves static files
- Async jobs via Celery for long operations

---

## Security

✅ HTTPS/TLS encryption  
✅ JWT token validation  
✅ Row-level security (RLS) in database  
✅ Input validation & sanitization  
✅ SQL injection prevention (ORM)  
✅ CORS restrictions  
✅ Rate limiting (1000 req/hour)  

---

## Technology Stack

- **Frontend:** Flutter, Provider, Supabase SDK
- **Backend:** Django, Django REST Framework
- **Database:** PostgreSQL (Supabase)
- **Authentication:** Supabase Auth + JWT
- **AI:** Google Gemini API
- **Weather:** Open-Meteo (free)
- **Maps:** MapLibre GL, Flutter Map
- **Hosting:** Supabase, Cloud Run/App Engine

This modern architecture ensures the application is maintainable, scalable, and ready for production deployment.


## Overview

The Smart Tourism System is built on a modern three-tier architecture:
- **Presentation Layer:** Flutter cross-platform frontend
- **Application Layer:** Django REST API backend
- **Data Layer:** Supabase PostgreSQL database with real-time capabilities

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  Flutter App (iOS, Android, Web)                             │
│  - Trip Planning Interface                                   │
│  - Route Discovery & Visualization                           │
│  - Real-time Weather & Danger Detection                      │
│  - Equipment Checklist                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                         HTTPS/REST
                              │
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  Django REST API                                             │
│  ├─ Authentication (Supabase JWT)                           │
│  ├─ Plans Service (CRUD operations)                         │
│  ├─ Routes Service (discovery & filtering)                  │
│  ├─ Equipment Management                                    │
│  ├─ Danger Detection & Assessment                           │
│  └─ AI Integration (Gemini)                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                      PostgreSQL API
                              │
┌─────────────────────────────────────────────────────────────┐
│                     DATA LAYER                               │
├─────────────────────────────────────────────────────────────┤
│  Supabase PostgreSQL                                         │
│  ├─ plans                                                    │
│  ├─ routes                                                   │
│  ├─ equipment                                                │
│  ├─ history_inputs (templates)                              │
│  ├─ auth.users (Supabase Auth)                             │
│  └─ user_profiles                                           │
└─────────────────────────────────────────────────────────────┘
```

## Frontend Architecture

### State Management
Uses **Provider** pattern for reactive state:

```
App
├─ AuthProvider (user session, authentication)
├─ TripProvider (trip creation, route selection)
├─ RouteProvider (route discovery, filtering)
└─ UI Screens (consume providers)
```

### Screen Structure

```
lib/screens/
├─ auth/
│  ├─ signup_screen.dart
│  ├─ login_screen.dart
│  └─ otp_verification_screen.dart
├─ trip_dashboard.dart (main dashboard with tabs)
├─ tripinfo*.dart (trip creation steps)
├─ trip_info_waiting_screen.dart (loading state)
└─ widgets/ (reusable components)
```

### Services

```
lib/services/
├─ api_service.dart (HTTP client with auth)
├─ supabase_db_service.dart (database operations)
├─ auth_service.dart (authentication)
├─ plan_service.dart (plan business logic)
├─ gemini_service.dart (AI recommendations)
└─ danger_labels.dart (danger display helpers)
```

## Backend Architecture

### Django Apps

```
backend/
├─ trek_guide_project/ (core settings & configuration)
├─ users/ (user profiles, authentication)
│  ├─ models.py (UserProfile)
│  ├─ views.py (profile endpoints)
│  └─ serializers.py
├─ plan/ (trip management)
│  ├─ models.py (Plan, HistoryInput)
│  ├─ views.py (CRUD endpoints)
│  └─ seed_routes.py (demo data)
├─ routes/ (route catalog)
│  ├─ models.py (Route, Equipment)
│  └─ views.py (discovery endpoints)
└─ safety/ (danger assessment)
   └─ models.py (Danger, DangerSnapshot)
```

### Key Models

**Plan**
```python
- id (PK)
- user_id (FK → users)
- name
- location
- start_date, end_date
- difficulty_level
- group_size
- accommodation
- routes (M2M)
- dangers_snapshot (JSON)
- created_at, updated_at
```

**Route**
```python
- id (PK)
- name
- location
- difficulty
- elevation_gain
- distance_km
- duration_days
- accommodation
- equipment (M2M)
- ai_note
- image_url
```

**Equipment**
```python
- id (PK)
- name
- category
- weight_kg
- estimated_cost
```

**HistoryInput (Template)**
```python
- id (PK)
- user_id (FK)
- name
- location
- difficulty_level
- group_size
- accommodation
- personal_interest
```

## Data Flow

### Trip Creation Flow
```
1. User fills trip details (TripProvider)
2. System fetches routes from API
3. Gemini AI generates recommendations
4. Backend creates Plan record
5. Dashboard loads plan with weather/dangers
6. Frontend detects weather anomalies
7. Danger snapshot stored in plan
8. User acknowledges dangers
9. Trip confirmed and saved
```

### Route Discovery Flow
```
1. User applies filters (difficulty, accommodation, location)
2. Frontend sends GET /routes/ request
3. Backend filters Route queryset
4. Returns matching routes with metadata
5. Frontend displays routes with images/details
```

### Danger Detection Flow
```
1. Trip dashboard loads plan
2. Extracts start_date, end_date, location
3. Geocodes location to coordinates
4. Fetches weather from Open-Meteo API
5. Analyzes: temperature, precipitation, wind
6. Applies hardcoded danger rules
7. Creates danger_snapshot JSON
8. Stores snapshot in plan.dangers_snapshot
9. Shows warning dialog to user
10. User checks danger acknowledgments
11. System stores ack state in SharedPreferences
```

## External Integrations

### Supabase
- **Auth:** JWT-based authentication
- **Database:** PostgreSQL with Row-Level Security (RLS)
- **Real-time:** Postgres changes subscribed by frontend

### Gemini AI
- **Endpoint:** Google's generative-ai library
- **Purpose:** Route recommendations based on trip parameters
- **Input:** Trip details (location, difficulty, duration, interests)
- **Output:** Natural language suggestions and route notes

### Open-Meteo API
- **Endpoint:** https://api.open-meteo.com/v1/forecast
- **Purpose:** Free weather forecasting
- **Params:** latitude, longitude, date range, weather metrics
- **Data:** temp max/min, precipitation, wind speed

### Nominatim (OpenStreetMap)
- **Endpoint:** https://nominatim.openstreetmap.org/search
- **Purpose:** Geocoding location strings to coordinates
- **Used by:** Danger detection weather lookup

## Security

### Authentication Flow
```
1. User registers with email/password (Supabase Auth)
2. OTP verification via email
3. On successful login, Supabase returns JWT token
4. Frontend stores token in session
5. All API requests include: Authorization: Bearer <token>
6. Backend validates JWT signature with Supabase public key
7. Extracts user_id from token claims
8. Filters data by user_id (Row-Level Security)
```

### Data Protection
- **In Transit:** HTTPS only
- **At Rest:** PostgreSQL encryption at Supabase
- **Secrets:** Environment variables in `.env` (never committed)
- **API Keys:** Public keys only in frontend (Supabase, Gemini API)

## Scalability Considerations

### Caching
- Route catalog cached in frontend (rarely changes)
- Plan data cached in Provider state
- Weather cached for 6-12 hours per location

### Database Indexing
- `plans.user_id` indexed for fast lookups
- `routes.location` indexed for filtering
- `history_inputs.user_id` indexed

### API Rate Limiting (Recommended)
- Implement Redis-based rate limiter
- 1000 req/hour per authenticated user
- 100 req/hour per IP (unauthenticated)

### Load Balancing (Production)
- Multiple Django instances behind load balancer
- Session management via stateless JWT
- Database connection pooling via PgBouncer

## Deployment Architecture

### Development
```
Local Machine
├─ Flutter dev server (hot reload)
├─ Django development server
└─ Supabase local emulator (optional)
```

### Production
```
Cloud Provider (AWS/GCP/Azure)
├─ Frontend: Static hosting (Vercel/Netlify for web)
├─ Backend: Container (Docker on K8s/App Engine)
├─ Database: Managed Postgres (Supabase/AWS RDS)
└─ CDN: CloudFront/Cloudflare for assets
```

## Performance Metrics

- **API Response Time:** <500ms (p95)
- **Frontend Load Time:** <3s (3G network)
- **Weather API Response:** <1s
- **Gemini AI Response:** <5s
- **Database Queries:** <100ms (p95)

## Monitoring & Logging

**Frontend:**
- AppLogger for structured logging
- Crash reporting via Sentry/Firebase
- Performance monitoring via Firebase Analytics

**Backend:**
- Django logging to console/file
- Database query logging for slow queries
- Error tracking via Sentry

**Infrastructure:**
- Uptime monitoring via Pingdom
- Log aggregation via CloudWatch/Stackdriver
