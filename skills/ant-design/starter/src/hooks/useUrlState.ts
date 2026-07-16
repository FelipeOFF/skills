/**
 * React Hooks for URL State
 * 
 * Declarative bindings for urlState utilities.
 */

import { useCallback, useEffect, useState } from 'react';
import {
  parseUrlParams,
  setUrlParams,
  updateUrlParams,
  removeUrlParams,
  parseTableParams,
  setTableParams,
  type TableParams,
  type UrlParams,
} from '../lib/urlState';

/**
 * Hook to sync state with URL query params
 */
export function useUrlState<T extends UrlParams>(
  defaults?: Partial<T>
): [
  T,
  {
    set: (params: T) => void;
    update: (params: Partial<T>) => void;
    remove: (keys: Array<keyof T>) => void;
    reset: () => void;
  }
] {
  const [state, setState] = useState<T>(() => parseUrlParams(defaults));

  // Sync with URL changes (e.g., back button)
  useEffect(() => {
    const handlePopState = () => {
      setState(parseUrlParams(defaults));
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, [defaults]);

  const set = useCallback((params: T) => {
    setState(params);
    setUrlParams(params);
  }, []);

  const update = useCallback((params: Partial<T>) => {
    const next = { ...state, ...params };
    setState(next as T);
    updateUrlParams(params);
  }, [state]);

  const remove = useCallback((keys: Array<keyof T>) => {
    const next = { ...state };
    keys.forEach(key => delete next[key]);
    setState(next as T);
    removeUrlParams(keys as string[]);
  }, [state]);

  const reset = useCallback(() => {
    const next = defaults as T;
    setState(next);
    setUrlParams(next ?? {});
  }, [defaults]);

  return [state, { set, update, remove, reset }];
}

/**
 * Hook optimized for table/list pagination and filtering
 */
export function useTableUrlState(
  defaults?: Partial<TableParams>
): [
  TableParams,
  {
    setPage: (page: number) => void;
    setPageSize: (size: number) => void;
    setSearch: (search: string) => void;
    setSort: (field: string, order: 'asc' | 'desc') => void;
    setFilter: (key: string, value: unknown) => void;
    reset: () => void;
  }
] {
  const [state, setState] = useState<TableParams>(() => 
    parseTableParams(defaults)
  );

  useEffect(() => {
    const handlePopState = () => {
      setState(parseTableParams(defaults));
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, [defaults]);

  const setAndSync = useCallback((params: TableParams) => {
    setState(params);
    setTableParams(params);
  }, []);

  const setPage = useCallback((page: number) => {
    setAndSync({ ...state, page });
  }, [state, setAndSync]);

  const setPageSize = useCallback((pageSize: number) => {
    setAndSync({ ...state, page: 1, pageSize });
  }, [state, setAndSync]);

  const setSearch = useCallback((search: string) => {
    setAndSync({ ...state, page: 1, search: search || undefined });
  }, [state, setAndSync]);

  const setSort = useCallback((sortField: string, sortOrder: 'asc' | 'desc') => {
    setAndSync({ ...state, sortField, sortOrder });
  }, [state, setAndSync]);

  const setFilter = useCallback((key: string, value: unknown) => {
    setAndSync({ 
      ...state, 
      page: 1, 
      [key]: value === '' ? undefined : value 
    });
  }, [state, setAndSync]);

  const reset = useCallback(() => {
    const next = { page: 1, pageSize: 10, ...defaults };
    setState(next);
    setTableParams(next);
  }, [defaults]);

  return [state, { setPage, setPageSize, setSearch, setSort, setFilter, reset }];
}
