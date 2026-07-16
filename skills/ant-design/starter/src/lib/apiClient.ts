/**
 * API Client Wrapper
 * 
 * A minimal typed fetch wrapper with:
 * - baseUrl from environment
 * - Request/response helpers
 * - Typed errors
 */

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api';

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public data?: unknown
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

type RequestConfig = RequestInit & {
  params?: Record<string, string | number | boolean | undefined>;
};

function buildUrl(path: string, params?: Record<string, string | number | boolean | undefined>): string {
  const url = new URL(path.startsWith('http') ? path : `${API_BASE_URL}${path}`, window.location.origin);
  
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.set(key, String(value));
      }
    });
  }
  
  return url.toString().replace(window.location.origin, '');
}

async function request<T>(path: string, config: RequestConfig = {}): Promise<T> {
  const { params, ...fetchConfig } = config;
  const url = buildUrl(path, params);
  
  const response = await fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...fetchConfig.headers,
    },
    ...fetchConfig,
  });

  // Handle non-JSON responses (e.g., 204 No Content)
  if (response.status === 204) {
    return undefined as T;
  }

  let data: unknown;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  if (!response.ok) {
    throw new ApiError(
      (data as { message?: string })?.message || `HTTP ${response.status}`,
      response.status,
      data
    );
  }

  return data as T;
}

// Convenience methods
export const apiClient = {
  get: <T>(path: string, config?: RequestConfig) => 
    request<T>(path, { ...config, method: 'GET' }),
  
  post: <T>(path: string, body: unknown, config?: RequestConfig) => 
    request<T>(path, { 
      ...config, 
      method: 'POST', 
      body: JSON.stringify(body) 
    }),
  
  put: <T>(path: string, body: unknown, config?: RequestConfig) => 
    request<T>(path, { 
      ...config, 
      method: 'PUT', 
      body: JSON.stringify(body) 
    }),
  
  patch: <T>(path: string, body: unknown, config?: RequestConfig) => 
    request<T>(path, { 
      ...config, 
      method: 'PATCH', 
      body: JSON.stringify(body) 
    }),
  
  delete: <T>(path: string, config?: RequestConfig) => 
    request<T>(path, { ...config, method: 'DELETE' }),
};

export default apiClient;
