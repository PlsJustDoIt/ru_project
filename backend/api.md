# API Documentation

This document provides an overview of the API endpoints available in the `ru_project` backend.

## Base URL

The base URL for all API endpoints is:

```
http://localhost:5000/api
```

## Authentication Routes

### Register a New User

**Endpoint:** `/api/auth/register`

**Method:** `POST`

**Description:** Registers a new user.

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response:**
- `201 Created`: User registered successfully.
- `400 Bad Request`: Invalid input.

### Login

**Endpoint:** `/api/auth/login`

**Method:** `POST`

**Description:** Logs in an existing user.

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Response:**
- `200 OK`: Returns a JWT token.
- `401 Unauthorized`: Invalid credentials.

## User Routes

### Get User Profile

**Endpoint:** `/api/users/profile`

**Method:** `GET`

**Description:** Retrieves the profile of the authenticated user.

**Headers:**
```json
{
  "Authorization": "Bearer <token>"
}
```



**

Response:**
- `200 OK`: Returns the user profile.
- `401 Unauthorized`: Invalid or missing token.

### Update User Profile

**Endpoint:** `/api/users/profile`

**Method:** `PUT`

**Description:** Updates the profile of the authenticated user.

**Headers:**
```json
{
  "Authorization": "Bearer <token>"
}
```

**Request Body:**
```json
{
  "username": "string",
  "status": "string"
}
```

**Response:**
- `200 OK`: Profile updated successfully.
- `400 Bad Request`: Invalid input.
- `401 Unauthorized`: Invalid or missing token.

## RU Routes

### Get RU Data

**Endpoint:** `/api/ru`

**Method:** `GET`

**Description:** Retrieves RU data.

**Response:**
- `200 OK`: Returns the RU data.
- `500 Internal Server Error`: Server error.

### Add RU Data

**Endpoint:** `/api/ru`

**Method:** `POST`

**Description:** Adds new RU data.

**Request Body:**
```json
{
  "name": "string",
  "location": "string",
  "description": "string"
}
```

**Response:**
- `201 Created`: RU data added successfully.
- `400 Bad Request`: Invalid input.
- `500 Internal Server Error`: Server error.

### Update RU Data

**Endpoint:** `/api/ru/:id`

**Method:** `PUT`

**Description:** Updates existing RU data.

**Request Params:**
- `id`: The ID of the RU data to update.

**Request Body:**
```json
{
  "name": "string",
  "location": "string",
  "description": "string"
}
```

**Response:**
- `200 OK`: RU data updated successfully.
- `400 Bad Request`: Invalid input.
- `404 Not Found`: RU data not found.
- `500 Internal Server Error`: Server error.

### Delete RU Data

**Endpoint:** `/api/ru/:id`

**Method:** `DELETE`

**Description:** Deletes existing RU data.

**Request Params:**
- `id`: The ID of the RU data to delete.

**Response:**
- `200 OK`: RU data deleted successfully.
- `404 Not Found`: RU data not found.
- `500 Internal Server Error`: Server error.

## Error Handling

All endpoints may return the following error responses:

- `400 Bad Request`: The request was invalid or cannot be otherwise served.
- `401 Unauthorized`: Authentication is required and has failed or has not yet been provided.
- `403 Forbidden`: The request was valid, but the server is refusing action.
- `404 Not Found`: The requested resource could not be found.
- `500 Internal Server Error`: An error occurred on the server.

## Notes

- Ensure to replace `<token>` with the actual JWT token obtained from the login endpoint.
- All endpoints that require authentication must include the `Authorization` header with the Bearer token.

This documentation provides a basic overview of the available API endpoints. For more detailed information, refer to the source code or contact the development team.