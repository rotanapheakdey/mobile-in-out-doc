# SENIOR FULL-STACK ARCHITECTURE: Document Management System (DMS)
## Laravel 11 + Filament + Vue.js SPA + Flutter Mobile

---

## 1. UX ENHANCEMENT SUITE (DMS-SPECIFIC)

### 1.1 Global Hotkey Search (Ctrl+K Fuzzy)
**Mechanism:**
- Keystroke listener on all pages (Vue + Flutter)
- Query: `/api/search/fuzzy?q={query}&filters={role_based}` returns top 20 documents/users
- Debounce 300ms client-side before API call
- Local IndexedDB caching (Web) / Hive (Mobile) for instant repeat searches
- Results grouped: Recent → By Role → By Department

**Implementation:**
```
Web: Cmd+K/Ctrl+K → Open <SearchModal> → Dispatch vuex action
Mobile: Long-press volume down → TriggerSearch() → Riverpod state
Backend: Index full-text columns (control_no, title, uploader.name)
```

---

### 1.2 Resilient Chunked File Uploads (TUS Protocol)
**Mechanism:**
- Client splits files into 5MB chunks before upload
- Resume capability: Store chunk hashes in localStorage/Hive
- Parallel chunk upload (3 concurrent) with exponential backoff
- Server validates hash integrity on completion
- Mobile fallback: Single chunk if network degraded

**Backend Endpoint:**
```php
POST /api/documents/upload/init → Returns uploadId + chunk size
PATCH /api/documents/upload/{uploadId}/{chunkIndex} → Upload chunk
POST /api/documents/upload/{uploadId}/complete → Finalize
```

**Client Implementation:**
- Vue: `vue-tus` package or custom Axios interceptor
- Flutter: Implement `package:dio` with custom retry logic + chunk hashing (SHA-256)

---

### 1.3 Contextual File Ingestion
**Web - Drag & Drop:**
- Zones on Dashboard + Document Detail screens
- Multi-file drop with batch upload progress
- Inline preview (PDF thumbnail via canvas)

**Mobile - Share Sheet Integration:**
- Hook native share sheet → Auto-populate form
- File picker with camera capture (iOS/Android native)
- Post-upload: Auto-route to correct workflow phase based on user role

---

### 1.4 Optimistic UI States
**Pattern:**
- Action buttons disabled → Dispatch action → Local state update (IMMEDIATE) → Show confirmation
- Rollback on 422/403 error with inline toast
- Example: "Mark as signed" → Button shows checkmark instantly → API call async

**Vue Store:**
```
mutations: updateDocumentOptimistic(state, {id, newStatus})
actions: signDocument → commit optimistic → api.post() → if err rollback
```

**Flutter Riverpod:**
```
ref.read(documentProvider(id)).copyWith(status: newStatus)
state.documents = state.documents.map((d) => d.id == id ? updated : d)
```

---

## 2. MONOLITHIC/SPA HYBRID CONFIGURATION (Laravel + Vue)

### 2.1 Vite Configuration
**Create `vite.config.js` (root):**
```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'public/spa',
    emptyOutDir: true,
  },
})
```

**Create `frontend/package.json` (or root):**
```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.4.0",
    "axios": "^1.6.0",
    "pinia": "^2.1.0",
    "vue-router": "^4.2.0"
  }
}
```

### 2.2 Laravel Routing Gateway
**`routes/web.php`:**
```php
Route::fallback(function () {
    return file_exists(base_path('public/spa/index.html'))
        ? response()->file(base_path('public/spa/index.html'))
        : abort(404);
});
```

**`public/index.php` modification:**
```php
// Serve spa assets first, then fallback to Laravel
if ($uri === '/' || (
    !file_exists(__DIR__.'/'.$uri) && 
    !file_exists(__DIR__.'/../'.$uri) &&
    !str_starts_with($uri, '/api')
)) {
    return require __DIR__.'/spa/index.html';
}
```

**Alternative (Reverse Proxy):**
```nginx
# nginx.conf
location / {
    if (!-e $request_filename) {
        rewrite ^(.*)$ /spa/index.html last;
    }
}

location /api {
    proxy_pass http://localhost:8000;
}
```

### 2.3 Build Pipeline
**`package.json` (root scripts):**
```json
{
  "scripts": {
    "build": "npm run build:frontend && npm run build:backend",
    "build:frontend": "cd frontend && npm run build",
    "build:backend": "composer install --no-dev && php artisan optimize",
    "dev": "concurrently 'npm run dev:api' 'npm run dev:web'",
    "dev:api": "php artisan serve --port=8000",
    "dev:web": "cd frontend && npm run dev -- --port=5173"
  }
}
```

---

## 3. BACKEND LOOPHOLE & API SECURITY AUDIT

### 3.1 CRITICAL VULNERABILITIES FOUND

| Issue | Location | Fix |
|-------|----------|-----|
| **IDOR on File Access** | `downloadFile($id)` | No ownership verification; any user can download any doc |
| **Mass Assignment** | `Document::create()` → `$guarded = []` | Exposes all attrs to direct binding |
| **N+1 Queries** | `urgentFeed()` + `searchArchive()` | Missing `.with()` eager loading |
| **Weak CSRF** | No CSRF on `/api/*` routes | Implicit trust on Bearer tokens only |
| **File Path Disclosure** | `file_path` returned in JSON | Leaks internal storage structure |
| **Access Control Bypass** | `searchArchive()` role checks rely on user input | Missing policy authorization layer |

---

### 3.2 Dual-Auth Isolation Strategy

**Architecture:**
```
├─ SPA (Vue) → Sanctum Cookie Auth (Stateful)
│  └─ Session stored in DB
│  └─ CSRF token required
│
└─ Mobile (Flutter) → Bearer Token Auth (Stateless)
   └─ Personal Access Token (PAT)
   └─ No cookie required
```

**Implementation:**

`config/sanctum.php` - Update stateful domains:
```php
'stateful' => explode(',', env(
    'SANCTUM_STATEFUL_DOMAINS',
    'localhost,localhost:3000,127.0.0.1,127.0.0.1:8000'
)),
```

`routes/api.php` - Separate middleware groups:
```php
// SPA Routes (Cookie-based, CSRF required)
Route::middleware(['web', 'csrf'])->group(function () {
    Route::post('/login', [AuthController::class, 'loginWeb']);
    Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
});

// Mobile Routes (Bearer Token, Stateless)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/documents', [DocumentController::class, 'store']);
    // All mobile endpoints
});
```

`bootstrap/app.php` - Middleware config:
```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->api(prepend: [
        \Illuminate\Http\Middleware\HandleCors::class,
    ]);
})
```

---

### 3.3 IDOR Prevention (File Access)

**Vulnerable Code (Current):**
```php
public function downloadFile($id) {
    $document = Document::findOrFail($id); // ← No user check
    // ...
}
```

**Fixed Implementation:**
```php
public function downloadFile($id) {
    $user = Auth::user();
    $document = Document::findOrFail($id);
    
    // Auth policy check
    if (!$this->canViewDocument($user, $document)) {
        abort(403, 'Unauthorized');
    }
    
    // ...
}

private function canViewDocument($user, $document) {
    if ($user->role === 'dg' || $user->role === 'file_dept') {
        return true;
    }
    
    return $document->assigned_department_id === $user->department_id &&
           in_array($document->status, ['dg_directed', 'pending_vdg_approval', 'completed_archive']);
}
```

**Better: Use Laravel Policies**
```php
php artisan make:policy DocumentPolicy
```

`app/Policies/DocumentPolicy.php`:
```php
public function view(User $user, Document $document) {
    return match ($user->role) {
        'dg', 'file_dept' => true,
        default => $document->assigned_department_id === $user->department_id,
    };
}

public function download(User $user, Document $document) {
    return $this->view($user, $document);
}
```

**Controller:**
```php
public function downloadFile($id) {
    $document = Document::findOrFail($id);
    $this->authorize('download', $document);
    // ... stream file
}
```

---

### 3.4 Mass-Assignment Fix

**Current (Vulnerable):**
```php
class Document extends Model {
    protected $guarded = []; // ← All fields writable
}
```

**Fixed:**
```php
class Document extends Model {
    protected $fillable = [
        'control_no', 'title', 'file_path', 'file_dept_comment', 
        'status', 'assigned_department_id', 'uploaded_by_user_id'
    ];
    
    protected $hidden = ['file_path']; // ← Don't expose storage path
}
```

**Controller Update:**
```php
$document->update([
    'assigned_department_id' => $request->validated()['assigned_department_id'],
    'status' => 'pending_dispatch',
    // Explicitly set, never trust request wholesale
]);
```

---

### 3.5 N+1 Query Optimization

**Before (N+1 Problem):**
```php
public function urgentFeed() {
    $documents = $query->oldest()->get(); // ← 1 query
    // In JSON serialization, each document loads uploader & department (+N queries)
}
```

**After (Eager Loading):**
```php
public function urgentFeed() {
    $documents = $query
        ->with(['uploader:id,name', 'department:id,name', 'auditLogs:id,action,created_at'])
        ->oldest()
        ->paginate(50);
    
    return response()->json([
        'data' => $documents->items(),
        'pagination' => [
            'total' => $documents->total(),
            'per_page' => $documents->perPage(),
        ]
    ]);
}
```

**Add Pagination Globally:**
```php
public function searchArchive(Request $request) {
    $documents = $query
        ->with(['uploader:id,name', 'department:id,name'])
        ->orderBy('updated_at', 'desc')
        ->paginate(25); // Limit results
    
    return response()->json($documents);
}
```

---

### 3.6 Mobile Payload Pruning

**Strategy:** Return minimal data for mobile; optional full expansion via `?expand=` param

`app/Http/Resources/DocumentResource.php`:
```php
class DocumentResource extends JsonResource {
    public function toArray($request) {
        $base = [
            'id' => $this->id,
            'control_no' => $this->control_no,
            'title' => $this->title,
            'status' => $this->status,
            'updated_at' => $this->updated_at,
        ];
        
        if ($request->query('expand') === 'full') {
            $base['uploader'] = $this->whenLoaded('uploader', fn() => [
                'id' => $this->uploader->id,
                'name' => $this->uploader->name,
            ]);
        }
        
        return $base;
    }
}
```

**Controller:**
```php
return DocumentResource::collection($documents);
```

---

### 3.7 Rate Limiting & Abuse Prevention

`app/Http/Kernel.php` or `bootstrap/app.php`:
```php
Route::middleware(['throttle:60,1'])->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
});

Route::middleware(['throttle:api', 'auth:sanctum'])->group(function () {
    // Standard API endpoints
});
```

`.env`:
```
API_RATE_LIMIT=60
API_RATE_WINDOW=1 // minute
```

---

### 3.8 Logging & Audit Trail Enhancements

**Add Detailed Logging:**
```php
class DocumentController {
    public function store(Request $request) {
        try {
            // ... validation & creation
            Log::info('Document uploaded', [
                'user_id' => $user->id,
                'file_size' => $request->file('file')->getSize(),
                'ip' => $request->ip(),
            ]);
        } catch (Exception $e) {
            Log::error('Upload failed', ['error' => $e->getMessage()]);
        }
    }
}
```

---

## 4. FLUTTER MOBILE ARCHITECTURE & LEAN CODE BASELINE

### 4.1 Feature-First Clean Architecture

```
flutter_app/
├── lib/
│   ├── core/
│   │   ├── api/              # Base HTTP client
│   │   ├── cache/            # Hive adapters
│   │   ├── constants/        # URLs, keys
│   │   └── error/            # Exception handling
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   ├── auth_remote_ds.dart
│   │   │   │   │   └── auth_local_ds.dart
│   │   │   │   ├── models/       # Serializable
│   │   │   │   └── repositories/
│   │   │   ├── domain/
│   │   │   │   ├── entities/     # Business logic
│   │   │   │   ├── repositories/ # Abstractions
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       ├── widgets/
│   │   │       └── providers/    # Riverpod
│   │   │
│   │   ├── documents/           # Same structure as auth
│   │   ├── search/
│   │   ├── offline/
│   │   └── notifications/
│   │
│   └── main.dart
```

---

### 4.2 State Management: Riverpod (Justification)
**Why Riverpod over BLoC:** Riverpod's provider-based approach eliminates boilerplate, enables automatic dependency injection, supports family modifiers for parameterized data, and integrates seamlessly with async/await patterns; BLoC requires explicit stream management overhead.

### 4.3 Base Dio API Client

`lib/core/api/dio_client.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  late Dio _dio;
  static const baseUrl = 'http://your-api.com/api';
  static const tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage();

  DioClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    // Auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _handleTokenRefresh();
          return handler.resolve(
            await _retry(error.requestOptions),
          );
        }
        return handler.next(error);
      },
    ));

    // Logging interceptor
    _dio.interceptors.add(LoggingInterceptor());
  }

  Future<Response> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<Response> uploadFile(
    String path,
    String filePath, {
    Map<String, dynamic>? fields,
  }) async {
    try {
      final file = await MultipartFile.fromFile(filePath);
      final formData = FormData.fromMap({
        ...?fields,
        'file': file,
      });
      return await _dio.post(path, data: formData);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<void> _handleTokenRefresh() async {
    // Token refresh logic (if backend supports)
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  void _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        // Handle timeout
        break;
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 403) {
          // Access denied
        }
        break;
      default:
        // Generic error
    }
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🔵 [${options.method}] ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('🟢 [${response.statusCode}] ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('🔴 [${err.response?.statusCode}] ${err.requestOptions.path}');
    handler.next(err);
  }
}
```

---

### 4.4 Riverpod Auth Provider

`lib/features/auth/presentation/providers/auth_provider.dart`:
```dart
import 'package:riverpod/riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';

final dioClientProvider = Provider((ref) => DioClient());

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
    remoteDatasource: AuthRemoteDatasource(ref.watch(dioClientProvider)),
    localDatasource: AuthLocalDatasource(),
  );
});

final loginUsecaseProvider = Provider((ref) {
  return LoginUsecase(ref.watch(authRepositoryProvider));
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.watch(loginUsecaseProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final LoginUsecase _loginUsecase;

  AuthNotifier(this._loginUsecase) : super(const AsyncValue.data(null));

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _loginUsecase(email, password);
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.data(null);
    // Clear storage
  }
}
```

---

### 4.5 Document Repository & Datasource

`lib/features/documents/data/datasources/document_remote_ds.dart`:
```dart
class DocumentRemoteDatasource {
  final DioClient _dioClient;

  DocumentRemoteDatasource(this._dioClient);

  Future<List<DocumentModel>> getUrgentFeed() async {
    final response = await _dioClient.get('/documents/urgent');
    final List docs = response.data['documents'] ?? [];
    return docs.map((d) => DocumentModel.fromJson(d)).toList();
  }

  Future<DocumentModel> uploadDocument(
    String title,
    String filePath,
    String comment,
  ) async {
    final response = await _dioClient.uploadFile(
      '/documents',
      filePath,
      fields: {'title': title, 'comment': comment},
    );
    return DocumentModel.fromJson(response.data['document']);
  }

  Future<DocumentModel> signDocument(int id, String action) async {
    final endpoint = {
          'vdg': '/documents/$id/vdg-sign',
          'dg': '/documents/$id/dg-sign',
        }[action] ??
        '';
    final response = await _dioClient.post(endpoint);
    return DocumentModel.fromJson(response.data['document']);
  }
}
```

---

### 4.6 Offline Sync Caching (Hive)

`lib/core/cache/hive_adapter.dart`:
```dart
import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class DocumentHiveModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String controlNo;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String status;

  @HiveField(4)
  final DateTime updatedAt;

  DocumentHiveModel({
    required this.id,
    required this.controlNo,
    required this.title,
    required this.status,
    required this.updatedAt,
  });
}

class HiveCacheService {
  static const boxName = 'documents';

  static Future<void> init() async {
    Hive.registerAdapter(DocumentHiveModelAdapter());
    await Hive.openBox<DocumentHiveModel>(boxName);
  }

  static Future<void> saveDocuments(List<DocumentHiveModel> docs) async {
    final box = Hive.box<DocumentHiveModel>(boxName);
    await box.clear();
    await box.addAll(docs);
  }

  static List<DocumentHiveModel> getDocuments() {
    final box = Hive.box<DocumentHiveModel>(boxName);
    return box.values.toList();
  }

  static Future<void> clear() async {
    final box = Hive.box<DocumentHiveModel>(boxName);
    await box.clear();
  }
}
```

---

### 4.7 Error Handling

`lib/core/error/app_exception.dart`:
```dart
abstract class AppException implements Exception {
  final String message;
  AppException(this.message);
}

class ServerException extends AppException {
  final int statusCode;
  ServerException(super.message, this.statusCode);
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class CacheException extends AppException {
  CacheException(super.message);
}

extension ExceptionHandler on Exception {
  String getReadableMessage() {
    if (this is ServerException) {
      return (this as ServerException).message;
    }
    if (this is NetworkException) {
      return 'Network error. Check your connection.';
    }
    return 'An unexpected error occurred.';
  }
}
```

---

## 5. COHESIVE DEVELOPMENT ROADMAP

### Phase 1: Vite Configuration & Laravel API Gateway (1-2 days)

**Deliverables:**
- [ ] `vite.config.js` with proxy to Laravel backend
- [ ] `routes/web.php` fallback for SPA routing
- [ ] Nginx/Apache reverse proxy config (if needed)
- [ ] Build pipeline working (`npm run build`)
- [ ] Dev environment with HMR enabled

**Tasks:**
1. Create `/frontend` folder with Vue.js scaffolding
2. Install Vite + Vue plugin
3. Update Laravel `web.php` to serve SPA
4. Configure `.env` for API base URL
5. Test: `npm run dev` opens SPA, `/api` proxies to Laravel

---

### Phase 2: Core Backend Upgrades (2-3 days)

**Deliverables:**
- [ ] Dual-auth isolation (Sanctum + Bearer tokens)
- [ ] Document policies implemented + IDOR fixes
- [ ] Eager loading on all queries (N+1 fixed)
- [ ] Mass-assignment protection on models
- [ ] Chunked file upload endpoints
- [ ] Rate limiting + logging

**Tasks:**
1. Create `DocumentPolicy.php` with authorization logic
2. Update `DocumentController` to use `$this->authorize()`
3. Add `.with()` eager loading to all queries
4. Implement `/api/documents/upload/init` + `/complete` endpoints
5. Add role-based middleware separation in `api.php`
6. Update `.env` with rate limit config
7. Test with Postman: upload chunked file, verify IDOR prevention

---

### Phase 3: Vue.js SPA Scaffolding (3-4 days)

**Deliverables:**
- [ ] Pinia store for auth + document state
- [ ] Login/Dashboard/Document Detail pages
- [ ] Axios instance with interceptors (401 handling)
- [ ] Ctrl+K search modal
- [ ] Drag-and-drop file upload with progress
- [ ] Optimistic UI state updates
- [ ] Role-based UI routing

**Tasks:**
1. Install Pinia + Vue Router + Axios
2. Create store modules: `auth.ts`, `documents.ts`
3. Implement login form + token storage (localStorage for SPA)
4. Build Dashboard component with urgent feed
5. Implement Document Detail page with workflow actions
6. Add SearchModal with debounced API call
7. Create file upload zone with TUS protocol
8. Add error interceptor for 401 → redirect login
9. Test: Full workflow login → upload → sign → archive

---

### Phase 4: Flutter Mobile Setup & Network Layer (3-4 days)

**Deliverables:**
- [ ] Flutter project scaffolding (clean arch)
- [ ] Dio API client with auth interceptor
- [ ] Riverpod auth + document providers
- [ ] Hive offline caching
- [ ] Login screen + Dashboard
- [ ] File upload with chunking
- [ ] Error handling + retry logic
- [ ] APK buildable

**Tasks:**
1. Run `flutter create dms_mobile`
2. Add dependencies: `dio`, `riverpod`, `hive`, `flutter_secure_storage`
3. Implement `DioClient` with token refresh
4. Create auth & document Riverpod providers
5. Build login screen (TextFormField + button)
6. Implement Document page with ListView
7. Add file picker + upload logic
8. Cache documents locally with Hive
9. Test on Android emulator + iOS simulator

---

### Parallel Development Tasks (Phases 2-4)

**UI/UX Designer:**
- Mockups for Dashboard (urgent feed), Document Detail, Upload Modal
- Color scheme + typography system

**DevOps:**
- Docker setup for Laravel + MySQL
- CI/CD pipeline (GitHub Actions for tests + builds)

**QA:**
- Integration tests for 7-phase workflow
- Load testing with chunked uploads
- Mobile testing on real devices

---

## 6. DEPLOYMENT CHECKLIST

**Pre-Production:**
- [ ] `.env` production values set (APP_DEBUG=false, secure CORS)
- [ ] Database backups automated
- [ ] Rate limiting tuned
- [ ] Logging to external service (e.g., Sentry)
- [ ] HTTPS enforced (SSL cert)
- [ ] CORS whitelist configured
- [ ] API documentation generated (Swagger)
- [ ] Load balancing if needed

**Security Verification:**
- [ ] OWASP Top 10 audit completed
- [ ] Penetration testing on file endpoints
- [ ] Token expiration tested
- [ ] CSRF protection verified
- [ ] Secrets not in version control

**Performance:**
- [ ] Database query optimization (Blackfire profiling)
- [ ] Vue.js bundle size < 100KB
- [ ] Mobile app build size < 50MB
- [ ] API response time < 200ms p50

---

## 7. MONITORING & OBSERVABILITY

**Backend:**
```php
// config/logging.php - Send errors to Sentry
'sentry' => [
    'driver' => 'sentry',
    'dsn' => env('SENTRY_LARAVEL_DSN'),
],
```

**Frontend (Vue):**
```javascript
// main.ts
import * as Sentry from "@sentry/vue";
Sentry.init({ dsn: import.meta.env.VITE_SENTRY_DSN });
```

**Mobile (Flutter):**
```dart
// main.dart
await Sentry.init(
  (options) => options.dsn = 'https://your-sentry-dsn',
  appRunner: () => runApp(const MyApp()),
);
```

---

## 8. TECHNICAL DEBT BACKLOG (Post-MVP)

- [ ] Move `/api` behind API gateway (Kong/AWS API Gateway)
- [ ] Implement WebSocket for real-time notifications (document status updates)
- [ ] GraphQL layer for flexible frontend queries
- [ ] E2E encryption for sensitive documents
- [ ] Admin dashboard in Filament for user/department management
- [ ] Document versioning (store history)
- [ ] Webhook integrations (external systems)
- [ ] Mobile app PWA fallback

