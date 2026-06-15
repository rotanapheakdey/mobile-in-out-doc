# TACTICAL IMPLEMENTATION: Quick Start Commands & Config

---

## PHASE 1: Setup & Build Infrastructure (DAY 1)

### Step 1.1: Initialize Frontend (Vue + Vite)
```bash
# Terminal 1: Frontend scaffolding
npm create vite@latest frontend -- --template vue
cd frontend
npm install
npm install -D @vitejs/plugin-vue
npm install axios pinia vue-router
npm install @vueuse/core lodash-es
```

### Step 1.2: Vite Config
`frontend/vite.config.js`:
```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': 'http://localhost:8000'
    }
  },
  build: {
    outDir: '../public/spa',
    emptyOutDir: true
  }
})
```

### Step 1.3: Laravel Bootstrap Update
`bootstrap/app.php` - Add fallback route:
```php
->withRouting(
    web: __DIR__.'/../routes/web.php',
    commands: __DIR__.'/../routes/console.php',
    health: '/up',
    then: function () {
        Route::fallback(function () {
            if (file_exists(base_path('public/spa/index.html'))) {
                return response()->file(base_path('public/spa/index.html'));
            }
            abort(404);
        });
    }
)
```

### Step 1.4: Test Build
```bash
cd frontend && npm run build
# Check: public/spa/index.html exists
php artisan serve
# Visit: http://localhost:8000 → should show SPA
```

---

## PHASE 2: Backend Security Hardening (DAY 1-2)

### Step 2.1: Create Document Policy
```bash
php artisan make:policy DocumentPolicy --model=Document
```

### Step 2.2: Register Policy (app/Providers/AuthServiceProvider.php)
```php
protected $policies = [
    Document::class => DocumentPolicy::class,
];
```

### Step 2.3: Update Models with $fillable

`app/Models/Document.php`:
```php
protected $fillable = [
    'uploaded_by_user_id', 'assigned_department_id', 'control_no',
    'title', 'file_path', 'file_dept_comment', 'status'
];

protected $hidden = ['file_path']; // Don't expose storage path
```

### Step 2.4: Fix N+1 Queries - DocumentController.php
Replace all queries with eager loading:
```php
// Before
$documents = Document::where('status', 'completed_archive')->get();

// After
$documents = Document::where('status', 'completed_archive')
    ->with(['uploader:id,name', 'department:id,name'])
    ->paginate(25);
```

### Step 2.5: Add Rate Limiting (routes/api.php)
```php
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
Route::middleware(['auth:sanctum', 'throttle:60,1'])->group(function () {
    // All protected endpoints
});
```

### Step 2.6: Run Tests
```bash
php artisan test
# Verify: All tests pass
```

---

## PHASE 3: Laravel API Gateway (DAY 2)

### Step 3.1: Create Dual-Auth Middleware (app/Http/Middleware/DualAuthMiddleware.php)
```php
<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class DualAuthMiddleware {
    public function handle(Request $request, Closure $next) {
        // Sanctum handles both session + bearer token
        // No additional logic needed if using auth:sanctum
        return $next($request);
    }
}
```

### Step 3.2: Configure Sanctum (config/sanctum.php)
```php
'stateful' => explode(',', env(
    'SANCTUM_STATEFUL_DOMAINS',
    'localhost,localhost:3000,127.0.0.1,127.0.0.1:8000'
)),

'guard' => ['web'],

'expiration' => null, // No token expiration (adjust as needed)
```

### Step 3.3: Create Chunked Upload Controller
```bash
php artisan make:controller Api/ChunkedUploadController
```

### Step 3.4: Add Upload Routes (routes/api.php)
```php
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/documents/upload/init', [ChunkedUploadController::class, 'initiate']);
    Route::post('/documents/upload/{uploadId}/{chunkIndex}', [ChunkedUploadController::class, 'uploadChunk']);
    Route::post('/documents/upload/{uploadId}/complete', [ChunkedUploadController::class, 'complete']);
});
```

### Step 3.5: Test with Postman
```
1. POST /api/login → Get token
2. POST /api/documents/upload/init → Get uploadId
3. PATCH /api/documents/upload/{uploadId}/0 → Upload chunk
4. POST /api/documents/upload/{uploadId}/complete → Finalize
```

---

## PHASE 3b: Vue.js Frontend Setup (DAY 2-3)

### Step 3b.1: Create Stores (frontend/src/stores/)
```bash
mkdir -p src/stores src/pages src/components src/api
```

`src/api/client.ts`:
```typescript
import axios from 'axios'

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || '/api',
})

client.interceptors.response.use(
  (res) => res,
  async (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('auth_token')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default client
```

### Step 3b.2: Auth Store (src/stores/auth.ts)
```typescript
import { defineStore } from 'pinia'
import client from '../api/client'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    token: localStorage.getItem('auth_token'),
  }),
  
  actions: {
    async login(email, password) {
      const { data } = await client.post('/login', { email, password })
      this.token = data.access_token
      this.user = data.user
      localStorage.setItem('auth_token', this.token)
      client.defaults.headers.common['Authorization'] = `Bearer ${this.token}`
    },
  },
})
```

### Step 3b.3: Document Store (src/stores/documents.ts)
```typescript
import { defineStore } from 'pinia'
import client from '../api/client'

export const useDocumentStore = defineStore('documents', {
  state: () => ({
    items: [],
    loading: false,
  }),
  
  actions: {
    async fetchUrgent() {
      this.loading = true
      const { data } = await client.get('/documents/urgent')
      this.items = data.data || data.documents
    },
  },
})
```

### Step 3b.4: Login Page (src/pages/Login.vue)
```vue
<template>
  <form @submit.prevent="handleLogin">
    <input v-model="email" type="email" placeholder="Email" />
    <input v-model="password" type="password" placeholder="Password" />
    <button :disabled="loading">{{ loading ? 'Loading...' : 'Login' }}</button>
  </form>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const email = ref('')
const password = ref('')
const loading = ref(false)
const router = useRouter()
const auth = useAuthStore()

async function handleLogin() {
  loading.value = true
  try {
    await auth.login(email.value, password.value)
    router.push('/dashboard')
  } finally {
    loading.value = false
  }
}
</script>
```

### Step 3b.5: Dashboard (src/pages/Dashboard.vue)
```vue
<template>
  <div>
    <h1>Urgent Documents</h1>
    <button @click="refresh">Refresh</button>
    <div v-if="docs.loading">Loading...</div>
    <ul v-else>
      <li v-for="doc in docs.items" :key="doc.id">
        <strong>{{ doc.title }}</strong>
        <span>{{ doc.status }}</span>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { useDocumentStore } from '../stores/documents'

const docs = useDocumentStore()

async function refresh() {
  await docs.fetchUrgent()
}

refresh()
</script>
```

### Step 3b.6: Build & Deploy
```bash
cd frontend && npm run build
cd ..
php artisan serve
# Visit http://localhost:8000
```

---

## PHASE 4: Flutter Mobile Setup (DAY 3-4)

### Step 4.1: Create Flutter Project
```bash
flutter create dms_mobile
cd dms_mobile
```

### Step 4.2: pubspec.yaml Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.3.0
  riverpod: ^2.4.0
  flutter_riverpod: ^2.4.0
  hive: ^2.2.0
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0
  image_picker: ^1.0.0
  permission_handler: ^11.4.0
```

### Step 4.3: Run Pubspec
```bash
flutter pub get
```

### Step 4.4: Create Dio Client (lib/core/network/dio_client.dart)
*[Use code from IMPLEMENTATION_CODE.md Section 4.3]*

### Step 4.5: Create Auth Provider (lib/features/auth/presentation/providers/)
*[Use code from IMPLEMENTATION_CODE.md Section 4.4]*

### Step 4.6: Create Login Screen
```bash
mkdir -p lib/features/auth/presentation/pages
touch lib/features/auth/presentation/pages/login_screen.dart
# [Use code from IMPLEMENTATION_CODE.md Section 4 - Flutter]
```

### Step 4.7: Build APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

---

## CRITICAL FIX: IDOR Vulnerability (IMMEDIATE)

### Fix in DocumentController.php
```php
// OLD (VULNERABLE)
public function downloadFile($id) {
    $document = Document::findOrFail($id);
    // No authorization check!
}

// NEW (FIXED)
public function downloadFile($id) {
    $document = Document::findOrFail($id);
    $this->authorize('download', $document); // ← Add this line
    return Storage::download($document->file_path);
}
```

### Deploy Fix
```bash
php artisan cache:clear
php artisan config:clear
php artisan serve
```

---

## Docker Setup (Optional)

### docker-compose.yml (root)
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      DB_CONNECTION: mysql
      DB_HOST: mysql
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: dms
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: secret
    ports:
      - "3306:3306"
```

### Dockerfile
```dockerfile
FROM php:8.3-cli
WORKDIR /app
COPY . .
RUN apt-get update && apt-get install -y \
    sqlite3 libsqlite3-dev
RUN curl -s https://getcomposer.org/installer | php
RUN php composer.phar install
EXPOSE 8000
CMD ["php", "artisan", "serve", "--host=0.0.0.0"]
```

### Run
```bash
docker-compose up -d
```

---

## Monitoring & Logs

### Tail Logs
```bash
# Frontend (Vue)
cd frontend && npm run dev

# Backend (Laravel)
php artisan pail

# Queue (if using)
php artisan queue:listen
```

### Test Document Flow End-to-End
```bash
# 1. Login as file_dept
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"file_dept@test.com","password":"password"}'

# 2. Upload document
curl -X POST http://localhost:8000/api/documents \
  -H "Authorization: Bearer {token}" \
  -F "title=Test Doc" \
  -F "file=@test.pdf"

# 3. Get urgent feed
curl -X GET http://localhost:8000/api/documents/urgent \
  -H "Authorization: Bearer {token}"
```

---

## Deployment Checklist

- [ ] `.env` production values set
- [ ] `APP_DEBUG=false`
- [ ] Database migrated & seeded
- [ ] Frontend built (`npm run build`)
- [ ] HTTPS certificate installed
- [ ] CORS origins configured
- [ ] Rate limits tuned
- [ ] Logging to Sentry enabled
- [ ] Backups automated
- [ ] SSL certificate renewed (cron job)

---

## Performance Optimization Checklist

- [ ] Database indexes on `status`, `assigned_department_id`
- [ ] Redis for session caching
- [ ] Vue.js code splitting (lazy routes)
- [ ] Flutter APK size < 50MB
- [ ] API response time < 200ms p50
- [ ] No N+1 queries (verified with debugbar)

