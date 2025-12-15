# Deployment Guide

## Production Checklist

- [ ] All tests passing
- [ ] Code reviewed
- [ ] Secrets in environment variables (not code)
- [ ] Database backups configured
- [ ] Monitoring and logging set up
- [ ] Error tracking configured (Sentry)
- [ ] CDN configured for assets
- [ ] SSL/TLS certificates valid
- [ ] Rate limiting configured
- [ ] Database connection pooling enabled

## Backend Deployment

### Build Docker Image

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend .
EXPOSE 8000

CMD ["gunicorn", "trek_guide_project.wsgi", "--bind", "0.0.0.0:8000"]
```

Build and run:
```bash
docker build -t smart-tourism-api .
docker run -e DATABASE_URL=<url> -p 8000:8000 smart-tourism-api
```

### Deploy to Cloud

#### AWS Elastic Beanstalk
```bash
# Install EB CLI
pip install awsebcli

# Initialize
eb init -p python-3.11 smart-tourism

# Create environment
eb create production

# Deploy
eb deploy
```

#### Google App Engine
```bash
# app.yaml
runtime: python311
entrypoint: gunicorn -b :$PORT trek_guide_project.wsgi

env_variables:
  DATABASE_URL: <your-url>

# Deploy
gcloud app deploy
```

#### Heroku
```bash
# Create Procfile
web: gunicorn trek_guide_project.wsgi --log-file -

# Deploy
git push heroku main
```

### Environment Variables (Production)

```bash
SECRET_KEY=<strong-random-key>
DATABASE_URL=postgresql://...
SUPABASE_URL=<url>
SUPABASE_KEY=<key>
GEMINI_API_KEY=<key>
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
```

### Database Migrations

```bash
# On deployment, run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser
```

### Static Files

```bash
# Collect static files
python manage.py collectstatic --noinput

# Serve from CDN (S3, CloudFront)
AWS_STORAGE_BUCKET_NAME=smart-tourism-static
AWS_S3_CUSTOM_DOMAIN=cdn.yourdomain.com
```

## Frontend Deployment

### Web Build

```bash
cd frontend
flutter build web --release
```

Outputs to `build/web/`

#### Deploy to Netlify
```bash
# netlify.toml
[build]
  command = "flutter build web --release"
  publish = "build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

```bash
netlify deploy --prod
```

#### Deploy to Vercel
```bash
# vercel.json
{
  "buildCommand": "flutter build web --release",
  "outputDirectory": "build/web",
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}
```

```bash
vercel --prod
```

### Mobile Build

#### Android APK
```bash
flutter build apk --release
```

Output: `build/app/outputs/apk/release/app-release.apk`

Deploy to Google Play Store:
- Sign APK with release key
- Upload to Google Play Console
- Create release notes
- Roll out to production

#### iOS IPA
```bash
flutter build ios --release
```

Output: `build/ios/iphoneos/`

Deploy to App Store:
- Create app in App Store Connect
- Build and archive in Xcode
- Upload via Xcode or Transporter
- Create release notes
- Submit for review

### Environment Configuration

For web runtime variables:
```powershell
./scripts/generate_env_js.ps1 -Out "frontend/web/env.js"
```

Inject in `web/index.html`:
```html
<script src="env.js"></script>
```

## Database Backups

### Supabase Automated Backups
- Point-in-time recovery: 7 days
- Full backups: Daily
- Access via Supabase dashboard

### Manual Backup
```bash
pg_dump "postgresql://user:pass@host/db" > backup.sql
```

### Restore
```bash
psql "postgresql://user:pass@host/db" < backup.sql
```

## Monitoring

### Application Performance
- **Tool:** New Relic, DataDog, or Scout
- **Metrics:** Response time, error rate, throughput
- **Alert:** >1s response time, error rate >1%

### Uptime Monitoring
- **Tool:** Pingdom, Statuspage
- **Checks:** API health endpoint every 5 minutes
- **Alert:** Immediate downtime notification

### Error Tracking
- **Tool:** Sentry
- **Integration:** Both frontend and backend
- **Alert:** Critical errors in Slack

### Logs
- **Tool:** CloudWatch, Stackdriver, ELK
- **Retention:** 30 days
- **Search:** By user ID, error type, timestamp

## Performance Optimization

### Backend
```python
# settings.py
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
    }
}

# Use caching
from django.views.decorators.cache import cache_page

@cache_page(60 * 15)  # 15 minutes
def expensive_view(request):
    pass
```

### Frontend
- Enable code minification: `flutter build web --release`
- Use lazy loading for images
- Cache routes and plans locally
- Implement pagination for lists

### Database
- Add indexes on frequently filtered columns
- Use connection pooling (PgBouncer)
- Monitor slow queries
- Archive old data

## Security

### HTTPS/TLS
```nginx
# nginx config
server {
    listen 443 ssl;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
}
```

### CORS Configuration
```python
# settings.py
CORS_ALLOWED_ORIGINS = [
    "https://yourdomain.com",
    "https://www.yourdomain.com",
]
```

### Rate Limiting
```python
# settings.py with django-ratelimit
RATELIMIT_ENABLE = True
RATELIMIT_USE_CACHE = "default"
RATELIMIT_VIEW = "100/h"  # 100 requests per hour
```

### Security Headers
```python
# settings.py
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
X_FRAME_OPTIONS = 'DENY'
```

## Maintenance

### Regular Tasks
- **Daily:** Monitor error logs
- **Weekly:** Review performance metrics
- **Monthly:** Database optimization, security audit
- **Quarterly:** Dependency updates, security patches

### Disaster Recovery
- Backup: Daily automated via Supabase
- Recovery time objective (RTO): 4 hours
- Recovery point objective (RPO): 1 hour
- Test restores monthly

## Rollback Procedure

If deployment fails:

1. Check health: `curl https://api.yourdomain.com/health/`
2. View logs: `kubectl logs deployment/smart-tourism-api`
3. Rollback: `git revert <commit>` and redeploy
4. Or restore database from backup
5. Notify team in Slack
6. Post-mortem within 24 hours

## Version Management

Use semantic versioning: `MAJOR.MINOR.PATCH`

```
v1.0.0  - Initial release
v1.1.0  - New feature (weather detection)
v1.1.1  - Bug fix
v2.0.0  - Breaking changes
```

Tag releases:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Support & Documentation

- **API Docs:** `/api/docs/` (Swagger)
- **Status Page:** status.yourdomain.com
- **User Guide:** docs.yourdomain.com
- **Support Email:** support@yourdomain.com
