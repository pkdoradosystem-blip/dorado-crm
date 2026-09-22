DORADO CRM - API READY DYNAMIC ARCHITECTURE

FRONTEND
- Flutter frontend separate from backend
- Main menu comes from GET /api/v1/menus
- Submenus use the same reusable DynamicMenuPage
- Form schema comes from GET /api/v1/forms/{code}
- Common text/dropdown components are reusable
- ApiClient has GET/POST/PUT/DELETE
- Responsive max-width layout for mobile/desktop

BACKEND
- Separate FastAPI starter
- Menu API + form-schema API
- Lead CRUD starter
- API docs: http://localhost:8000/docs
- Current lead storage is memory-only for architecture testing

RUN BACKEND (Windows)
cd backend
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

FRONTEND
Use the supplied frontend/lib and pubspec.yaml in a NEW test Flutter project first.
Run flutter pub get.
Chrome/Windows: flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
Android emulator: --dart-define=API_BASE_URL=http://10.0.2.2:8000
Physical Android: use the PC LAN IP, e.g. http://192.168.1.10:8000

NEXT PRODUCTION PHASE
PostgreSQL + ORM, authentication, company/tenant, roles/permissions, persistent menu/form configuration, and all Dorado business modules.
