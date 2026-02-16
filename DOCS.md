# Documentation Index

Complete documentation for the Smart Tourism System project.

## Core Documentation

### [README.md](./README.md)
Project overview, architecture, features, and quick start guide.
- Quick start for frontend and backend
- System architecture overview
- Core features
- API endpoints summary
- Development structure

### [SETUP.md](./SETUP.md)
Step-by-step setup instructions for getting the project running locally.
- Prerequisites and installations
- Backend setup (Python, Django, Supabase)
- Frontend setup (Flutter)
- Environment configuration
- Troubleshooting guide
- Helpful commands

### [API.md](./API.md)
Complete REST API endpoint documentation.
- Authentication endpoints
- Plans CRUD operations
- Routes discovery
- History inputs (templates)
- Query parameters and filtering
- Error responses
- Rate limiting info

### [ARCHITECTURE.md](./ARCHITECTURE.md)
System design and technical architecture.
- Three-tier architecture diagram
- Frontend state management (Provider)
- Backend app structure
- Database models and relationships
- Data flow diagrams
- External integrations
- Security model
- Scalability considerations
- Performance metrics

### [DEVELOPMENT.md](./DEVELOPMENT.md)
Development workflow and code guidelines.
- Backend setup and Django commands
- Creating models, views, serializers
- Frontend setup and Flutter commands
- State management with Provider
- API integration patterns
- Testing procedures
- Code quality tools (lint, format)
- Common development tasks
- Branch strategy and commits
- Troubleshooting

### [DEPLOYMENT.md](./DEPLOYMENT.md)
Production deployment and operations guide.
- Production checklist
- Docker containerization
- Cloud deployment (AWS, GCP, Heroku)
- Environment variables for production
- Database backups and recovery
- Monitoring and logging
- Performance optimization
- Security hardening
- SSL/TLS configuration
- Rollback procedures
- Version management

### [CONTRIBUTING.md](./CONTRIBUTING.md)
Guidelines for contributing to the project.
- Code of conduct
- Development workflow
- Code standards and style
- Testing requirements
- Documentation standards
- Pull request review process
- Performance guidelines
- Security checklist
- Release process

## Supporting Documentation

### [Backend Setup](./backend/README_SUPABASE.md)
Backend-specific configuration for Supabase integration.
- Environment variables
- Local development setup
- Django configuration
- JWT validation (advanced)

### [Frontend Setup](./frontend/README.md)
Frontend-specific configuration and development.
- Quick start
- Project structure
- State management
- Building for production
- Dependencies
- Configuration
- Troubleshooting

## Quick Links

**Getting Started:**
1. [Setup Guide](./SETUP.md) - Initial setup
2. [Development Guide](./DEVELOPMENT.md) - Start coding
3. [Architecture](./ARCHITECTURE.md) - Understand the system

**Working on Features:**
1. [API Documentation](./API.md) - API reference
2. [Contributing Guide](./CONTRIBUTING.md) - Code standards
3. [Development Guide](./DEVELOPMENT.md) - Development workflow

**Deploying:**
1. [Deployment Guide](./DEPLOYMENT.md) - Production setup
2. [Architecture](./ARCHITECTURE.md) - System design
3. [Backend Setup](./backend/README_SUPABASE.md) - Database config

## File Organization

```
CT-Project/
├── README.md                    ← Start here
├── SETUP.md                     ← Initial setup
├── API.md                       ← API reference
├── ARCHITECTURE.md              ← System design
├── DEVELOPMENT.md               ← Dev workflow
├── DEPLOYMENT.md                ← Production guide
├── CONTRIBUTING.md              ← Code guidelines
├── backend/
│   └── README_SUPABASE.md      ← Backend config
├── frontend/
│   └── README.md               ← Frontend config
└── scripts/
    ├── setup_local_env.ps1
    └── generate_env_js.ps1
```

## Documentation Standards

All documentation follows these principles:
- **Clear:** Written for team members with varying expertise
- **Complete:** All necessary information to complete tasks
- **Current:** Updated with code changes
- **Concise:** No unnecessary verbosity
- **Professional:** Polished for presentations

## Keeping Docs Updated

When making changes:
1. Update relevant `.md` files
2. Update API documentation if endpoints change
3. Update architecture if structure changes
4. Update SETUP.md if new dependencies added
5. Update CONTRIBUTING.md if standards change

## Markdown Tips

- Use ## for sections
- Use code blocks with language: ```python
- Use **bold** for emphasis
- Use links for cross-references
- Keep line length reasonable

## Questions?

Refer to the appropriate documentation:
- **How do I...?** → [Development Guide](./DEVELOPMENT.md)
- **What's the API?** → [API Documentation](./API.md)
- **How's it built?** → [Architecture](./ARCHITECTURE.md)
- **How do I deploy?** → [Deployment Guide](./DEPLOYMENT.md)
- **What are the rules?** → [Contributing Guide](./CONTRIBUTING.md)

## Version

Documentation last updated: **December 2025**

For specific code changes, see Git commit history.
