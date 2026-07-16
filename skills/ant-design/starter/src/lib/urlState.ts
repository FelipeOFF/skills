/**
 * URL State Helpers
 * 
 * Framework-agnostic utilities for syncing state with URL query params.
 * Useful for search, pagination, and filters.
 */

export type UrlParams = Record<string, string | number | boolean | string[] | undefined>;

/**
 * Read query params from current URL
 */
export function getUrlParams(): URLSearchParams {
  return new URLSearchParams(window.location.search);
}

/**
 * Parse URL params into typed object
 */
export function parseUrlParams<T extends UrlParams>(
  defaults?: Partial<T>
): T {
  const params = getUrlParams();
  const result: Record<string, unknown> = { ...defaults };

  params.forEach((value, key) => {
    // Handle arrays (e.g., ?tags=a&tags=b)
    if (result[key] !== undefined) {
      const existing = result[key];
      if (Array.isArray(existing)) {
        result[key] = [...existing, value];
      } else {
        result[key] = [existing, value];
      }
    } else {
      // Type inference
      if (value === 'true') result[key] = true;
      else if (value === 'false') result[key] = false;
      else if (/^\d+$/.test(value)) result[key] = parseInt(value, 10);
      else result[key] = value;
    }
  });

  return result as T;
}

/**
 * Build query string from params object
 */
export function buildQueryString(params: UrlParams): string {
  const searchParams = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    
    if (Array.isArray(value)) {
      value.forEach(v => searchParams.append(key, String(v)));
    } else {
      searchParams.set(key, String(value));
    }
  });

  const qs = searchParams.toString();
  return qs ? `?${qs}` : '';
}

/**
 * Update URL params without page reload (uses history.pushState)
 */
export function setUrlParams(
  params: UrlParams,
  options?: { replace?: boolean; scroll?: boolean }
): void {
  const qs = buildQueryString(params);
  const url = `${window.location.pathname}${qs}${window.location.hash}`;

  if (options?.replace) {
    window.history.replaceState(null, '', url);
  } else {
    window.history.pushState(null, '', url);
  }

  if (!options?.scroll) {
    // Prevent scroll to top on URL change
    const scrollPos = window.scrollY;
    setTimeout(() => window.scrollTo(0, scrollPos), 0);
  }
}

/**
 * Update specific params while preserving others
 */
export function updateUrlParams(
  updates: UrlParams,
  options?: { replace?: boolean; scroll?: boolean }
): void {
  const current = parseUrlParams();
  setUrlParams({ ...current, ...updates }, options);
}

/**
 * Remove specific params from URL
 */
export function removeUrlParams(
  keys: string[],
  options?: { replace?: boolean; scroll?: boolean }
): void {
  const current = parseUrlParams();
  const next: UrlParams = { ...current };
  keys.forEach(key => delete next[key]);
  setUrlParams(next, options);
}

/**
 * Common preset for table pagination/filtering
 */
export interface TableParams {
  page?: number;
  pageSize?: number;
  search?: string;
  sortField?: string;
  sortOrder?: 'asc' | 'desc';
  [key: string]: unknown;
}

export function parseTableParams(defaults?: Partial<TableParams>): TableParams {
  return parseUrlParams<TableParams>({
    page: 1,
    pageSize: 10,
    ...defaults,
  });
}

export function setTableParams(
  params: TableParams,
  options?: { replace?: boolean }
): void {
  setUrlParams(params, { replace: true, ...options });
}
