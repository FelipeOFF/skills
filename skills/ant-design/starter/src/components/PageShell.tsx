/**
 * PageShell Component
 * 
 * Standard page layout with breadcrumbs placeholder and content area.
 * Uses Ant Design Layout components.
 */

import React from 'react';
import { Layout, Breadcrumb, Typography, Space } from 'antd';
import type { BreadcrumbProps } from 'antd';

const { Content } = Layout;
const { Title } = Typography;

export interface PageShellProps {
  /** Page title displayed in the header */
  title: string;
  /** Optional breadcrumb items */
  breadcrumbs?: { label: string; path?: string }[];
  /** Actions displayed in the header (e.g., buttons) */
  actions?: React.ReactNode;
  /** Page content */
  children: React.ReactNode;
  /** Additional className for the content area */
  className?: string;
  /** Custom styles for content area */
  contentStyle?: React.CSSProperties;
}

export const PageShell: React.FC<PageShellProps> = ({
  title,
  breadcrumbs,
  actions,
  children,
  className,
  contentStyle,
}) => {
  const breadcrumbItems: BreadcrumbProps['items'] = breadcrumbs?.map((item, index) => ({
    key: index,
    title: item.path ? (
      <a href={item.path}>{item.label}</a>
    ) : (
      item.label
    ),
  }));

  return (
    <Layout style={{ minHeight: '100%', background: 'transparent' }}>
      {breadcrumbItems && breadcrumbItems.length > 0 && (
        <Breadcrumb style={{ marginBottom: 16 }} items={breadcrumbItems} />
      )}
      
      <Space direction="vertical" style={{ width: '100%', marginBottom: 24 }} size="middle">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <Title level={2} style={{ margin: 0 }}>{title}</Title>
          {actions && <div>{actions}</div>}
        </div>
      </Space>

      <Content 
        className={className}
        style={{
          background: '#fff',
          padding: 24,
          borderRadius: 8,
          ...contentStyle,
        }}
      >
        {children}
      </Content>
    </Layout>
  );
};

export default PageShell;
