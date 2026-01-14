# API Integration Notes

## Login API
- **Endpoint**: `https://kiosk.cropsync.in/api/login_api.php`
- **Method**: POST
- **Content-Type**: application/json
- **Request Body**: `{"user_id": "123456"}`

### Success Response:
```json
{
  "success": true,
  "message": "Login successful.",
  "user": {
    "user_id": "123456",
    "name": "Laxma Reddy",
    "phone_number": "9182867605",
    "district": "WNP",
    "village": "PRP",
    "mandal": null,
    "region": "Wanaparthy",
    "client_code": "WNP001",
    "card_uid": "3660588835",
    "profile_image_url": "https://kiosk.cropsync.in/profile_images/123456_1768133872.jpg"
  }
}
```

### Error Response:
```json
{
  "success": false,
  "message": "User ID is required."
}
```

## Migration Plan:
1. Remove Supabase SDK dependency
2. Create API service class for HTTP calls
3. Create User model class
4. Create AuthService for session management using SharedPreferences
5. Update login_screen.dart to use new API
6. Update home_screen.dart to use local user data
7. Update profile_screen.dart to use local user data
