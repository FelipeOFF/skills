# Starter — App Base Scaffold

A minimal, production-ready scaffold for React + Ant Design v5 applications.

## Quick Start

```bash
# Copy starter/ into your new project
cp -r starter/ my-new-app/
cd my-new-app

# Install dependencies
npm install

# Start development
npm run dev
```

## Environment Variables

Create `.env` file:

```env
VITE_API_BASE_URL=/api
```

## Project Structure

```
src/
├── lib/                    # Core utilities
│   ├── apiClient.ts        # Typed fetch wrapper
│   ├── urlState.ts         # URL query param helpers
│   └── index.ts            # Public exports
├── hooks/                  # React hooks
│   ├── useUrlState.ts      # URL state sync hooks
│   └── index.ts            # Public exports
├── components/             # Reusable UI components
│   ├── PageShell.tsx       # Layout + breadcrumbs
│   ├── DataTable.tsx       # Table wrapper with presets
│   ├── FormSubmitBar.tsx   # Form action bar
│   ├── ErrorBanner.tsx     # Error display
│   ├── LoadingState.tsx    # Loading states
│   └── index.ts            # Public exports
├── pages/                  # Page components
├── AppProviders.tsx        # Global provider wrapper
├── theme.ts               # Ant Design token config
└── main.tsx               # Entry point
```

## Features

### 1. API Client (`lib/apiClient.ts`)

A minimal typed fetch wrapper:

```typescript
import { apiClient, ApiError } from './lib';

// GET with query params
const users = await apiClient.get<User[]>('/users', {
  params: { page: 1, search: 'john' }
});

// POST with body
const newUser = await apiClient.post<User>('/users', { name: 'John' });

// Error handling
try {
  await apiClient.get('/users/999');
} catch (error) {
  if (error instanceof ApiError) {
    console.log(error.status);  // 404
    console.log(error.message); // "Not found"
  }
}
```

**Features:**
- Base URL from `VITE_API_BASE_URL` env
- Automatic JSON parsing
- Typed errors with `ApiError`
- Query param serialization
- Empty body handling (204 responses)

### 2. URL State Helpers (`lib/urlState.ts`)

Framework-agnostic utilities for URL query params:

```typescript
import {
  parseUrlParams,
  setUrlParams,
  updateUrlParams,
  removeUrlParams,
  parseTableParams,
} from './lib';

// Read current URL state
const params = parseUrlParams({ page: 1, search: '' });
console.log(params.page);   // 1 or from URL
console.log(params.search); // "" or from URL

// Update URL (adds history entry)
setUrlParams({ page: 2, search: 'hello' });

// Update specific params (preserves others)
updateUrlParams({ page: 3 });

// Remove params
removeUrlParams(['search', 'filter']);

// Table-specific helpers (with defaults)
const tableParams = parseTableParams();
// Returns: { page: 1, pageSize: 10, ... }
```

### 3. React Hooks (`hooks/useUrlState.ts`)

Declarative URL state bindings:

```typescript
import { useUrlState, useTableUrlState } from './hooks';

// Generic URL state
const [state, { set, update, remove, reset }] = useUrlState({
  tab: 'all',
  filter: '',
});

// Table-optimized URL state
const [params, { setPage, setPageSize, setSearch, setSort, setFilter, reset }] = 
  useTableUrlState({ page: 1, pageSize: 20 });
```

### 4. Reusable Components

#### PageShell

Standard page layout with breadcrumbs and title:

```typescript
import { PageShell } from './components';

<PageShell
  title="Users"
  breadcrumbs={[
    { label: 'Home', path: '/' },
    { label: 'Users' },
  ]}
  actions={<Button type="primary">New User</Button>}
>
  {/* Content */}
</PageShell>
```

#### DataTable

Ant Design Table wrapper with sensible defaults:

```typescript
import { DataTable } from './components';

<DataTable
  columns={columns}
  dataSource={data}
  loading={isLoading}
  total={100}
  page={page}
  pageSize={pageSize}
  onChange={handleTableChange}
  selectable
  selectedKeys={selectedKeys}
  onSelectionChange={setSelectedKeys}
/>
```

#### FormSubmitBar

Standard form action bar:

```typescript
import { FormSubmitBar } from './components';

<FormSubmitBar
  submitText="Save"
  cancelText="Cancel"
  loading={isSubmitting}
  onSubmit={handleSubmit}
  onCancel={handleCancel}
  align="right"
/>
```

#### ErrorBanner

Reusable error display with retry:

```typescript
import { ErrorBanner } from './components';

<ErrorBanner
  message="Failed to load users"
  description="Please check your connection"
  onRetry={refetch}
  onDismiss={() => setError(null)}
/>
```

#### LoadingState

Standardized loading states:

```typescript
import { LoadingState } from './components';

// Inline spinner
<LoadingState loading={isLoading} tip="Loading...">
  <DataTable ... />
</LoadingState>

// Skeleton placeholder
<LoadingState loading={isLoading} type="skeleton" skeletonRows={8} />

// Fullscreen overlay
<LoadingState loading={isLoading} fullscreen tip="Saving..." />
```

## TypeScript

All components and utilities are fully typed. Import types as needed:

```typescript
import type { 
  PageShellProps, 
  DataTableProps, 
  TableParams,
  ApiError 
} from './lib';
```

## Customization

### Theme Tokens

Edit `src/theme.ts` to customize Ant Design tokens:

```typescript
export const theme = {
  token: {
    colorPrimary: '#1890ff',
    borderRadius: 4,
    // ...
  },
};
```

### Extending API Client

Add interceptors or custom headers in `lib/apiClient.ts`:

```typescript
async function request<T>(path: string, config: RequestConfig = {}): Promise<T> {
  const token = localStorage.getItem('token');
  // ...
  headers: {
    ...fetchConfig.headers,
    ...(token && { Authorization: `Bearer ${token}` }),
  },
  // ...
}
```

## License

MIT
