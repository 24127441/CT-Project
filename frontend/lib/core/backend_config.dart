// Backend API configuration
// This file contains the backend API URL for all API calls

/// Backend API URL
/// For local development: http://localhost:8000
/// For production: update with your production backend URL
const String backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);

/// Get the full API URL for an endpoint
String getApiUrl(String endpoint) {
  // Remove leading slash if present
  final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  return '$backendUrl/api/$path';
}
