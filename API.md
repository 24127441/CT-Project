# API Documentation

## Base Information

**Base URL:** `http://localhost:8000/api/` (development)  
**Base URL (Production):** `https://api.yourdomain.com/api/`  
**API Version:** v1  
**Authentication:** Bearer Token (JWT)  
**Rate Limit:** 1000 requests/hour  
**Response Format:** JSON  

---

## Authentication

### Obtain Authentication Token

All protected endpoints require a `Authorization: Bearer {token}` header.

**Headers:**
```
Content-Type: application/json
```

**Example:**
```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  https://api.yourdomain.com/api/plans/
```

---

## Response Format

### Success Response (2xx)

```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Sample Response"
  },
  "message": "Operation completed successfully"
}
```

### List Response (Paginated)

```json
---

## Plans API

### List All Plans

Get paginated list of user's plans with pagination support.

**Endpoint:** `GET /plans/`  
**Authentication:** Required  
**Rate Limit:** 100 requests/minute

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| page | integer | Page number (default: 1) |
| page_size | integer | Items per page (default: 20, max: 100) |
| search | string | Search by name (case-insensitive) |
| ordering | string | Order by field: `name`, `-created_at`, `-updated_at` |

**Request:**

```bash
curl -X GET "https://api.yourdomain.com/api/plans/?page=1&page_size=20" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Hanoi City Tour",
      "destination": "Hanoi",
      "start_date": "2025-03-15",
      "end_date": "2025-03-18",
      "group_size": 4,
      "personal_interest": "cultural",
      "status": "draft",
      "created_at": "2025-02-01T10:30:00Z",
      "updated_at": "2025-02-10T15:45:00Z"
    }
  ],
  "pagination": {
    "total": 12,
    "page": 1,
    "page_size": 20,
    "total_pages": 1
  }
}
```

---

### Create Plan

Create a new trip plan.

**Endpoint:** `POST /plans/`  
**Authentication:** Required  

**Request Body:**

```json
{
  "name": "Sapa Mountain Trek",
  "destination": "Sapa",
  "start_date": "2025-04-20",
  "end_date": "2025-04-23",
  "group_size": 4,
  "personal_interest": "adventure"
}
```

**Request Example:**

```bash
curl -X POST "https://api.yourdomain.com/api/plans/" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sapa Mountain Trek",
    "destination": "Sapa",
    "start_date": "2025-04-20",
    "end_date": "2025-04-23",
    "group_size": 4
  }'
```

**Response (201 Created):**

```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Sapa Mountain Trek",
    "destination": "Sapa",
    "start_date": "2025-04-20",
    "end_date": "2025-04-23",
    "group_size": 4,
    "status": "draft",
    "created_at": "2025-02-15T12:00:00Z"
  }
}
```

---

### Get Plan Details

Get complete details for a specific plan.

**Endpoint:** `GET /plans/{id}/`  
**Authentication:** Required  

**Request:**

```bash
curl -X GET "https://api.yourdomain.com/api/plans/3/" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Sapa Mountain Trek",
    "destination": "Sapa",
    "start_date": "2025-04-20",
    "end_date": "2025-04-23",
    "group_size": 4,
    "personal_interest": "adventure",
    "routes": [
      {
        "id": 15,
        "name": "Fansipan Peak Trail",
        "difficulty": "hard"
      }
    ],
    "dangers_snapshot": {
      "high_temp": true,
      "heavy_rain": false,
      "strong_wind": false
    },
    "equipment_list": [
      { "id": 1, "name": "Hiking Boots" }
    ]
  }
}
```

---

### Update Plan

Update plan details.

**Endpoint:** `PUT /plans/{id}/`  
**Authentication:** Required  

**Request:**

```bash
curl -X PUT "https://api.yourdomain.com/api/plans/3/" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"group_size": 5}'
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 3,
    "group_size": 5,
    "updated_at": "2025-02-15T13:00:00Z"
  }
}
```

---

### Delete Plan

Delete a plan.

**Endpoint:** `DELETE /plans/{id}/`  
**Authentication:** Required  

**Request:**

```bash
curl -X DELETE "https://api.yourdomain.com/api/plans/3/" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:** `204 No Content`

---

## Routes API

### List Routes

Discover available routes with advanced filtering.

**Endpoint:** `GET /routes/`  
**Authentication:** Optional  

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| location | string | Filter by location |
| difficulty | string | easy, moderate, hard, extreme |
| accommodation | string | camping, guesthouse, hotel |
| duration_max | integer | Maximum days |

**Request Example:**

```bash
curl -X GET "https://api.yourdomain.com/api/routes/?location=Sapa&difficulty=moderate" \
  -H "Content-Type: application/json"
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 15,
      "name": "Fansipan Peak Trail",
      "location": "Sapa",
      "difficulty": "hard",
      "duration_days": 3,
      "distance_km": 12.5,
      "elevation_gain_m": 1800,
      "accommodation_types": ["camping"],
      "estimated_cost_usd": 450,
      "average_rating": 4.7
    }
  ]
}
```

---

### Get Route Details

Get comprehensive information about a specific route.

**Endpoint:** `GET /routes/{id}/`  
**Authentication:** Optional  

**Request:**

```bash
curl -X GET "https://api.yourdomain.com/api/routes/15/"
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 15,
    "name": "Fansipan Peak Trail",
    "location": "Sapa",
    "difficulty": "hard",
    "duration_days": 3,
    "distance_km": 12.5,
    "elevation_gain_m": 1800,
    "equipment_list": [
      {
        "id": 1,
        "name": "Hiking Boots",
        "category": "footwear",
        "weight_g": 600
      }
    ],
    "ai_note": "Popular peak bagging route...",
    "elevation_profile": [
      { "distance_km": 0, "elevation_m": 1600 },
      { "distance_km": 12.5, "elevation_m": 3143 }
    ]
  }
}
```

---

## Equipment API

### List Equipment

Get all available equipment items.

**Endpoint:** `GET /equipment/`  
**Authentication:** Optional  

**Request:**

```bash
curl -X GET "https://api.yourdomain.com/api/equipment/?category=footwear"
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Hiking Boots",
      "category": "footwear",
      "weight_g": 600,
      "estimated_cost_usd": 120
    }
  ]
}
```

---

## Templates API

### List Templates

Get user's saved trip templates.

**Endpoint:** `GET /templates/`  
**Authentication:** Required  

**Request:**

```bash
curl -X GET "https://api.yourdomain.com/api/templates/" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Summer Adventure Template",
      "personal_interest": "adventure",
      "default_duration": 5,
      "default_group_size": 4
    }
  ]
}
```

---

### Create Template

Save trip configuration as a template.

**Endpoint:** `POST /templates/`  
**Authentication:** Required  

**Request:**

```bash
curl -X POST "https://api.yourdomain.com/api/templates/" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Summer Adventure",
    "personal_interest": "adventure",
    "default_duration": 5
  }'
```

**Response (201 Created):**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Summer Adventure Template",
    "created_at": "2025-02-15T12:00:00Z"
  }
}
```

---

## Error Codes

| Code | Status | Description |
|------|--------|-------------|
| VALIDATION_ERROR | 400 | Invalid request data |
| AUTHENTICATION_REQUIRED | 401 | Missing/invalid token |
| PERMISSION_DENIED | 403 | No access to resource |
| NOT_FOUND | 404 | Resource doesn't exist |
| RATE_LIMIT_EXCEEDED | 429 | Too many requests |
| SERVER_ERROR | 500 | Internal server error |

---

## Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": {
      "email": ["Email is required"]
    }
  }
}
```

---

## Python SDK Example

```python
import requests

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# Create plan
response = requests.post(
    "https://api.yourdomain.com/api/plans/",
    json={
        "name": "Sapa Trek",
        "destination": "Sapa",
        "start_date": "2025-04-20",
        "end_date": "2025-04-23",
        "group_size": 4
    },
    headers=headers
)
print(response.json())
```

---

## Dart/Flutter SDK Example

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

final headers = {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
};

final response = await http.post(
  Uri.parse('https://api.yourdomain.com/api/plans/'),
  headers: headers,
  body: jsonEncode({
    'name': 'Sapa Trek',
    'destination': 'Sapa',
    'start_date': '2025-04-20',
    'end_date': '2025-04-23',
    'group_size': 4,
  }),
);
```

---

## Rate Limiting

API uses token bucket rate limiting.

**Headers Returned:**
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 978
X-RateLimit-Reset: 1645367400
```

---

## Support

**Issues:** support@yourdomain.com  
**Documentation:** https://docs.yourdomain.com

For real-time plan updates, subscribe to Supabase changes:
```javascript
const channel = supabase
  .channel('plans')
  .on('postgres_changes', 
    { event: '*', schema: 'public', table: 'plans' },
    (payload) => console.log(payload)
  )
  .subscribe()
```

---

## API Versioning

Current version: **v1**  
No breaking changes planned. All endpoints are stable for production use.

For future updates: endpoints will include `/v2/` prefix.

---

## Support

- **Issues:** GitHub Issues
- **Documentation:** See API examples above
- **Email:** api-support@smarttourism.com
