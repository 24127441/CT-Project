# Setup Guide

Complete setup instructions for the Smart Tourism System.

## Prerequisites

- **Git** - Version control
- **Python 3.9+** - Backend runtime
- **Flutter 3.x** - Frontend SDK
- **Node.js 16+** - (Optional, for frontend web tooling)
- **PostgreSQL** - (Or use Supabase)
- **Supabase Account** - Free tier available
- **Text Editor** - VS Code recommended

## Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/CT-Project.git
cd CT-Project
```

## Step 2: Backend Setup

### Install Dependencies

```bash
cd backend
python -m venv venv

# On Windows
venv\Scripts\activate

# On macOS/Linux
source venv/bin/activate

pip install -r requirements.txt
```

### Configure Environment

Create `backend/.env`:

```bash
cp .env.example .env
```

Edit `.env` with your Supabase credentials:

```env
SECRET_KEY=your-secret-key-here

# Database (from Supabase)
DATABASE_URL=postgresql://postgres:password@db.host:5432/postgres

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_KEY=your-anon-key

# API
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
```

### Initialize Database

```bash
python manage.py migrate

# Create admin user (optional)
python manage.py createsuperuser
```

### Test Backend

```bash
python manage.py runserver
```

Visit `http://localhost:8000/admin` to verify it's running.

## Step 3: Frontend Setup

### Install Dependencies

```bash
cd frontend
flutter pub get
```

### Configure Environment

Create `frontend/.env`:

```bash
cp .env.example .env
```

Edit with your settings:

```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your-anon-key
API_BASE_URL=http://localhost:8000
GEMINI_API_KEY=your-gemini-key
```

### Test Frontend

```bash
flutter run
```

Or for web:

```bash
flutter run -d chrome
```

## Step 4: Configure Supabase

### Create Project
1. Sign up at [supabase.com](https://supabase.com)
2. Create new project
3. Copy project URL and anon key
4. Paste into both `.env` files

### Create Tables

Run migrations or execute SQL in Supabase SQL editor:

```sql
-- Users (managed by Supabase Auth)

-- User Profiles
CREATE TABLE public.user_profiles (
  id uuid NOT NULL REFERENCES auth.users(id),
  email text,
  created_at timestamp,
  PRIMARY KEY (id)
);

-- Plans
CREATE TABLE public.plans (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  name text NOT NULL,
  location text NOT NULL,
  start_date date,
  end_date date,
  difficulty_level text,
  group_size integer,
  accommodation text,
  dangers_snapshot jsonb,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now()
);

-- Routes
CREATE TABLE public.routes (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  location text NOT NULL,
  difficulty text,
  elevation_gain integer,
  distance_km float,
  duration_days integer,
  accommodation text,
  description text,
  gallery text[],
  ai_note text,
  estimated_cost integer,
  created_at timestamp DEFAULT now()
);

-- Equipment
CREATE TABLE public.equipment (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  category text,
  weight_kg float,
  estimated_cost integer,
  created_at timestamp DEFAULT now()
);

-- History Inputs (Templates)
CREATE TABLE public.history_inputs (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  name text NOT NULL,
  location text,
  difficulty_level text,
  group_size integer,
  accommodation text,
  personal_interest text,
  created_at timestamp DEFAULT now()
);
```

### Set Row Level Security

```sql
-- Plans: Users can only see their own plans
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own plans"
  ON public.plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own plans"
  ON public.plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own plans"
  ON public.plans FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own plans"
  ON public.plans FOR DELETE
  USING (auth.uid() = user_id);
```

## Step 5: Get API Keys

### Supabase
- URL: Project Settings → API
- Key: Copy "anon" key (public)

### Gemini
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create new API key
3. Paste into `.env`

### Open-Meteo (Weather)
- No API key needed (free public API)

## Step 6: Verify Setup

### Backend
```bash
cd backend
python manage.py test
python manage.py runserver
# Check http://localhost:8000/api/routes/
```

### Frontend
```bash
cd frontend
flutter analyze  # Should be 0 errors
flutter test
flutter run
```

## Step 7: Optional - Generate Environment Variables

For web deployment:

```powershell
cd frontend
.\scripts\generate_env_js.ps1 -UseDotenv
# Creates env.js for web/index.html
```

## Troubleshooting

### Backend won't start
```bash
# Check Python version
python --version  # Should be 3.9+

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall

# Check database connection
python manage.py dbshell
```

### Flutter won't run
```bash
# Check Flutter setup
flutter doctor

# Clean cache
flutter clean
flutter pub get

# Try again
flutter run -v
```

### Database connection error
- Verify `DATABASE_URL` in `.env`
- Check Supabase credentials
- Ensure project is not paused
- Try direct connection: `psql <DATABASE_URL>`

### API returns 401 (Unauthorized)
- Verify Supabase JWT token is valid
- Check `SUPABASE_KEY` in `.env`
- Check Authorization header format

### Gemini API errors
- Verify API key is valid
- Check Google Cloud project has API enabled
- Check quota limits

## Next Steps

1. Read [Development Guide](./DEVELOPMENT.md)
2. Review [API Documentation](./API.md)
3. Check [Architecture](./ARCHITECTURE.md)
4. See [Contributing Guidelines](./CONTRIBUTING.md)

## Helpful Commands

```bash
# Backend
python manage.py runserver              # Start dev server
python manage.py migrate               # Apply migrations
python manage.py makemigrations        # Create migrations
python manage.py test                  # Run tests
python manage.py shell                 # Interactive shell

# Frontend
flutter run                            # Run on device
flutter run -d chrome                  # Run on web
flutter test                           # Run tests
flutter analyze                        # Check code
flutter format lib/                    # Format code
flutter pub upgrade                    # Update dependencies
```

## Getting Help

- **Documentation:** See [README.md](./README.md)
- **Issues:** Check GitHub issues
- **Team:** Ask in Slack or email
- **Docs:** See other `.md` files in root

## Now You're Ready!

Start with the [Development Guide](./DEVELOPMENT.md) to begin working on the project.
