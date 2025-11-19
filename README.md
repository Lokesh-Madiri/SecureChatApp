# Chat App Notification Server

This is a serverless function for handling push notifications in the chat application. It can be deployed to Vercel to send Firebase Cloud Messaging (FCM) notifications.

## Setup Instructions

### 1. Firebase Service Account Setup

1. Go to the Firebase Console
2. Navigate to Project Settings > Service Accounts
3. Click "Generate new private key"
4. Save the JSON file securely

### 2. Environment Variables for Vercel

Set the following environment variables in your Vercel project settings:

```
FIREBASE_TYPE=service_account
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=your-client-email@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=https://www.googleapis.com/robot/v1/metadata/x509/your-client-email%40your-project.iam.gserviceaccount.com
```

### 3. Deploy to Vercel

1. Install Vercel CLI:

   ```bash
   npm install -g vercel
   ```

2. Deploy the project:
   ```bash
   vercel --prod
   ```

### 4. Update Flutter App

Update your Flutter app to use the deployed Vercel URL by setting the environment variable:

```bash
flutter run --dart-define=NOTIFICATION_SERVER_URL=https://your-deployment-url.vercel.app
```

Or for production builds:

```bash
flutter build --dart-define=NOTIFICATION_SERVER_URL=https://your-deployment-url.vercel.app
```

## API Endpoint

POST `/api/send-notification`

### Request Body

```json
{
  "userId": "recipient-user-id",
  "title": "Notification Title",
  "body": "Notification Body",
  "data": {
    "key": "value"
  }
}
```

### Response

```json
{
  "success": true,
  "message": "Notification sent successfully",
  "response": "Firebase message ID"
}
```

## Local Development

1. Create a `.env.local` file with your Firebase service account credentials
2. Run the development server:
   ```bash
   vercel dev
   ```

## Error Handling

The server handles various error cases:

- Missing required fields
- User not found
- Invalid or expired FCM tokens
- Firebase messaging errors
