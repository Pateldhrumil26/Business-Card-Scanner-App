# Business Card Scanner & Contact Manager (CardScanner Pro)

A complete, production-ready full-stack mobile application that scans physical business cards using Google ML Kit Text Recognition, intelligently parses the contact information, allows review & editing, and synchronizes the verified contacts to a Node.js/Express and MongoDB backend CRM.

---

## 📁 Project Structure

The project strictly contains two main application directories:

```
Business Card Scanner App/
├── backend/                  # Node.js, Express & MongoDB REST API
└── frontend/                 # Flutter mobile application
```

---

## 🌟 Key Features

1. **Google ML Kit Text Recognition**: Real-time on-device optical character recognition (OCR) extracting raw text blocks from camera captures and gallery uploads.
2. **Intelligent Contact Parser**:
   - Person Name detection (Title casing heuristics, honorific prefixes `Dr.`, `Mr.`, `Ms.`, positioning relative to designations).
   - Designation detection (Chief Executive Officer, CTO, Managing Director, Manager, Engineer, Consultant, etc.).
   - Company name extraction (Pvt Ltd, LLC, Inc, Technologies, Solutions, plus non-generic domain parsing).
   - Phone & Alternative Phone parsing (Indian +91, 10-digit, and international formats).
   - Email and Website extraction.
   - GST Number detection (Standard 15-character Indian GST format: `\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}`).
   - Address, City, State, and Country parsing.
3. **Verification & Editing Flow**: Extracted fields are loaded into an editable review form highlighting uncertain or missing fields before saving.
4. **CRM Contact Management**:
   - Fast full-text and regex search by Name, Company, Phone, and Email.
   - Filter by Company chips.
   - Sort by Newest, Oldest, Name (A-Z), and Company (A-Z).
   - Direct Call (`tel:`), Email (`mailto:`), and Website (`https://`) actions.
   - Standard vCard 3.0 export and sharing via native share sheet.
5. **Dashboard Statistics**: Real-time metrics tracking Total Cards Scanned, Total Contacts, and Unique Companies.
6. **Authentication & Multi-Tenancy**: JWT authentication with bcrypt password hashing; all business cards and contacts are strictly scoped to the authenticated user.
7. **Dynamic Server Configuration**: Allows instant switching between Android Emulator (`http://10.0.2.2:5050/api`), Localhost (`http://127.0.0.1:5050/api`), and Physical Device LAN IP directly from the app's Profile settings.

---

## 🛠️ Technology Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.50+ / Dart 3.14+
- **Design System**: Material Design 3 (Navy Blue `#0F172A`, Clean Slate, Modern CRM UI)
- **OCR Engine**: `google_mlkit_text_recognition`
- **Camera & Media**: `camera`, `image_picker`
- **State Management**: `provider`
- **Networking**: `dio` with central interceptors, JWT attachment, and error mapping
- **Persistence**: `shared_preferences`
- **Device Integrations**: `url_launcher`, `share_plus`, `permission_handler`

### Backend (TypeScript & Node.js)
- **Language**: TypeScript (`ES2022`, strict typing)
- **Runtime & Framework**: Node.js v22+, Express.js
- **Cloud Storage**: AWS S3 (`@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`) - **Multer completely removed**
- **Database & ODM**: MongoDB, Mongoose
- **Security**: JWT (`jsonwebtoken`), `bcryptjs`, `helmet`, `cors`, `express-rate-limit`
- **Validation**: `express-validator`
- **Architecture**: Clean MVC (Controllers, Models, Routes, Services, Middlewares)

---

## 🚀 Getting Started

### Prerequisites
- Node.js (v18+) and npm installed
- MongoDB installed and running locally on port `27017` (or MongoDB Atlas connection URI)
- Flutter SDK (v3.20+) installed and added to PATH
- Android Studio / Android Emulator or physical Android device

---

### Step 1: Start the MongoDB Server
Ensure MongoDB is running locally:
```bash
# If running as local service or binary:
mongod --dbpath <path_to_data_dir> --port 27017
```

---

### Step 2: Configure & Run the Backend

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Inspect or configure `.env` (a ready `.env` is already created):
   ```env
   PORT=5050
   NODE_ENV=development
   MONGO_URI=mongodb://127.0.0.1:27017/business-card-scanner
   JWT_SECRET=business_card_scanner_super_secret_jwt_key_2026_dev_secure
   JWT_EXPIRES_IN=7d
   UPLOAD_DIR=uploads
   MAX_FILE_SIZE=10485760
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Run tests:
   ```bash
   npm test
   node tests/api.test.js
   ```

5. Start the backend server:
   ```bash
   npm start
   # Or for development with auto-reload:
   npm run dev
   ```
   The backend will be running at `http://localhost:5050` and accessible from Android Emulator at `http://10.0.2.2:5050`.

---

### Step 3: Run the Flutter Frontend

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Fetch packages:
   ```bash
   flutter pub get
   ```

3. Run static analyzer and unit tests:
   ```bash
   flutter analyze
   flutter test test/models_test.dart
   ```

4. Run the application:
   ```bash
   # On Android Emulator:
   flutter run

   # On specific connected device:
   flutter run -d <device_id>
   ```

5. **Connecting to the Backend**:
   - **Android Emulator**: The app defaults to `http://10.0.2.2:5050/api` which points directly to your host PC.
   - **Physical Device**: Go to Profile Tab -> Backend Server Configuration -> enter `http://<YOUR_COMPUTER_LAN_IP>:5050/api` (e.g. `http://192.168.1.10:5050/api`).

---

## 📡 REST API Documentation

### Authentication Endpoints
- `POST /api/auth/register` - Create account (`{ name, email, mobile, password }`)
- `POST /api/auth/login` - Authenticate (`{ email, password }`)
- `GET /api/auth/profile` - Get current user profile (Bearer token)
- `PUT /api/auth/profile` - Update user profile (`{ name, mobile }`)
- `POST /api/auth/change-password` - Change password (`{ currentPassword, newPassword }`)

### Business Card Endpoints
- `POST /api/cards/upload` - Upload image via `multipart/form-data` (Field: `image`)
- `POST /api/cards/extract` - Intelligently parse raw OCR text (`{ rawText, cardId? }`)
- `GET /api/cards` - List user's scanned cards (Query: `page`, `limit`)
- `GET /api/cards/:id` - Get card by ID
- `DELETE /api/cards/:id` - Delete card & remove file

### Contact Endpoints
- `POST /api/contacts` - Save verified contact
- `GET /api/contacts` - List contacts (Query: `search`, `company`, `sortBy`, `page`, `limit`)
- `GET /api/contacts/:id` - Get contact details
- `PUT /api/contacts/:id` - Update contact
- `DELETE /api/contacts/:id` - Delete contact
- `GET /api/contacts/:id/vcf` - Export contact as standard vCard 3.0 (`.vcf`)

### Dashboard Endpoints
- `GET /api/dashboard/stats` - Total cards, contacts, and companies count
- `GET /api/dashboard/recent-contacts` - Recent contacts and scanned cards

---

## 📄 License
This project is licensed under the MIT License.
