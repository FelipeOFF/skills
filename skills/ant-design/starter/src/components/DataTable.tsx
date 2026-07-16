/**
 * DataTable Component
 * 
 * Ant Design Table wrapper with sensible defaults for data-heavy UIs.
 * Presets for pagination, sorting, and row selection.
 */

import React from 'react';
import { Table, type TableProps } from 'antd';
import type { TablePaginationConfig } from 'antd/es/table';

export interface DataTableProps<T> extends Omit<TableProps<T>, 'pagination'> {
  /** Current loading state */
  loading?: boolean;
  /** Total record count for pagination */
  total?: number;
  /** Current page */
  page?: number;
  /** Page size */
  pageSize?: number;
  /** Callback when pagination/sorter changes */
  onChange?: (pagination: TablePaginationConfig, filters: unknown, sorter: unknown) => void;
  /** Enable row selection */
  selectable?: boolean;
  /** Selected row keys (controlled) */
  selectedKeys?: React.Key[];
  /** Callback when selection changes */
  onSelectionChange?: (keys: React.Key[], rows: T[]) => void;
  /** Unique row key (default: 'id') */
  rowKey?: string | ((record: T) => React.Key);
  /** Disable pagination */
  disablePagination?: boolean;
}

export function DataTable<T extends object>({
  loading,
  total,
  page = 1,
  pageSize = 10,
  onChange,
  selectable,
  selectedKeys,
  onSelectionChange,
  rowKey = 'id',
  disablePagination,
  columns,
  dataSource,
  ...tableProps
}: DataTableProps<T>) {
  const pagination: false | TablePaginationConfig = disablePagination
    ? false
    : {
        current: page,
        pageSize,
        total,
        showSizeChanger: true,
        showQuickJumper: true,
        showTotal: (t: number, range: [number, number]) => 
          `${range[0]}-${range[1]} de ${t} itens`,
        pageSizeOptions: [10, 20, 50, 100],
      };

  const rowSelection = selectable
    ? {
        type: 'checkbox' as const,
        selectedRowKeys: selectedKeys,
        onChange: onSelectionChange,
      }
    : undefined;

  return (
    <Table<T>
      rowKey={rowKey}
      columns={columns}
      dataSource={dataSource}
      loading={loading}
      pagination={pagination}
      rowSelection={rowSelection}
      onChange={onChange}
      scroll={{ x: 'max-content' }}
      {...tableProps}
    />
  );
}

export default DataTable;
