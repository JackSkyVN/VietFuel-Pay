# VietFuel-Pay (Smart Refuel System)

VietFuel-Pay is a comprehensive full-stack automated gas station payment and management system. It aims to deliver a seamless, secure, and futuristic refueling experience by integrating edge AI license plate recognition with a feature-rich mobile payment application.

## Key Features

- **Automated Refueling (ALPR):** Edge-based Automatic License Plate Recognition using YOLOv8-OBB and PaddleOCR for seamless vehicle identification and IoT trigger integration.
- **Modern Mobile App:** A Flutter application adhering to Clean Architecture and Riverpod state management, styled with a premium "Viettel Red" design language.
- **Offline QR Payments:** Dynamic, pulsating offline QR codes allowing users to transact securely even without an active internet connection.
- **Station Navigation:** Built-in station locator with OpenStreetMap integration, OSRM route previews, and deep linking to external navigation apps.
- **Secure Backend Engine:** A FastAPI/PostgreSQL architecture handling authentication, transaction history, geofencing, robust payment processing, and Alembic database migrations.

## Technology Stack

**Frontend (Mobile)**
- Flutter & Dart
- Clean Architecture
- Riverpod (State Management)
- OpenStreetMap & routing integrations

**Backend & AI**
- FastAPI (Python)
- PostgreSQL & Alembic
- YOLOv8-OBB & PaddleOCR (CUDA-accelerated)

## Project Structure

- `lib/` - Contains the Flutter application source code (Features: Dashboard, Offline QR, Map Navigation, Auth).
- `backend/` - Contains the FastAPI backend API logic, automated pipeline scripting (ALPR), and database schemas.

## Developer Setup

### Frontend
1. Ensure Flutter is installed.
2. Run `flutter pub get` in the root directory.
3. Run `flutter run` to launch the mobile application.

### Backend
1. Navigate to the `backend/` directory.
2. Create and activate a Python virtual environment.
3. Install dependencies: `pip install -r requirements.txt`.
4. Run the API server via Uvicorn: `uvicorn app.main:app --reload` (ensure CUDA is configured if running the ALPR pipeline locally).
