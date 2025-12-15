# CTT009 - Smart Tourism System

**Intelligent travel planning platform combining computational thinking with AI-driven route recommendations and real-time safety assessment.**

A full-stack application demonstrating advanced problem decomposition, pattern recognition, and practical AI integration for the tourism industry.

## Key Capabilities

🚀 **AI-Powered Route Discovery** - Smart recommendations based on preferences and constraints

⚠️ **Automated Danger Detection** - Real-time weather analysis and environmental risk assessment

🗺️ **Interactive Route Visualization** - Elevation profiles, distance metrics, and interactive maps

📋 **Equipment Planning** - Curated equipment lists tailored to route difficulty and type

💾 **Reusable Templates** - Save trip configurations for quick planning of similar journeys

## Quick Start

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

### Backend (Django)
```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Environment Setup
```powershell
.\scripts\setup_local_env.ps1
.\scripts\generate_env_js.ps1
```

## Architecture

**Frontend:** Flutter (iOS, Android, Web)
- Trip planning and management interface
- Interactive route maps with elevation profiles
- Real-time weather and danger detection
- Equipment checklist by route type
- User profile and trip history

**Backend:** Django REST API
- Route and trip CRUD operations
- User authentication via Supabase
- AI-powered route recommendations (Gemini)
- Danger assessment and storage
- History input (template) management

**Database:** Supabase Postgres
- Plans, routes, equipment, user profiles, danger snapshots

## Core Features

- **AI Route Discovery:** Smart recommendations based on user preferences and trip parameters
- **Safety Alerts:** Automated weather analysis with danger detection
- **Equipment Planning:** Curated equipment lists by route difficulty and type
- **Route Visualization:** Interactive maps with elevation and distance profiles
- **Template System:** Save and reuse trip configurations

## API Endpoints

### Authentication
- POST `/api/auth/register/` - User registration
- POST `/api/auth/login/` - User login
- POST `/api/auth/verify-otp/` - OTP verification

### Plans
- GET/POST `/api/plans/` - List and create plans
- GET/PUT/DELETE `/api/plans/{id}/` - Plan details and management

### Routes
- GET `/api/routes/` - Discover routes with filters
- GET `/api/routes/{id}/` - Route details

### Templates
- GET/POST `/api/history-inputs/` - User templates
- GET/PUT/DELETE `/api/history-inputs/{id}/` - Template management

## Development

### Project Structure
```
CT-Project/
├── backend/          Django REST API
│   ├── trek_guide_project/  Core settings
│   ├── plan/         Trip planning
│   ├── routes/       Route management
│   ├── users/        User management
│   └── safety/       Danger detection
├── frontend/         Flutter app
│   ├── lib/
│   │   ├── screens/  UI pages
│   │   ├── providers/ State management
│   │   ├── services/ API and business logic
│   │   ├── models/   Data models
│   │   └── widgets/  Reusable components
│   └── pubspec.yaml
└── scripts/          Setup and deployment helpers
```

### Key Technologies
- **Backend:** Django, Django REST Framework, Supabase, PostgreSQL
- **Frontend:** Flutter, Provider, Supabase SDK, Gemini API
- **External:** Open-Meteo (weather), MapLibre GL, FL Chart

### Testing

Run Flutter tests:
```bash
cd frontend
flutter test
```

Run Django tests:
```bash
cd backend
python manage.py test
```

## Deployment

See [Backend Setup](./backend/README_SUPABASE.md) and [Frontend Setup](./frontend/README.md) for deployment instructions.

---

CTT009 Computational Thinking Course | HCMUS - University of Science
