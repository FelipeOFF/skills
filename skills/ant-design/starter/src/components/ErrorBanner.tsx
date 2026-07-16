/**
 * ErrorBanner Component
 * 
 * Reusable error display with retry action.
 */

import React from 'react';
import { Alert, Button, Space } from 'antd';
import { ReloadOutlined, CloseCircleOutlined } from '@ant-design/icons';

export interface ErrorBannerProps {
  /** Error message to display */
  message?: string;
  /** Detailed error description */
  description?: string;
  /** Callback to retry the failed operation */
  onRetry?: () => void;
  /** Callback to dismiss the error */
  onDismiss?: () => void;
  /** Banner type */
  type?: 'error' | 'warning' | 'info';
  /** Show as banner (full width) or alert */
  banner?: boolean;
  /** Additional className */
  className?: string;
  /** Custom style */
  style?: React.CSSProperties;
}

export const ErrorBanner: React.FC<ErrorBannerProps> = ({
  message = 'Ocorreu um erro',
  description,
  onRetry,
  onDismiss,
  type = 'error',
  banner = false,
  className,
  style,
}) => {
  const action = (
    <Space>
      {onRetry && (
        <Button 
          icon={<ReloadOutlined />}
          onClick={onRetry}
          size="small"
        >
          Tentar novamente
        </Button>
      )}
      {onDismiss && (
        <Button
          icon={<CloseCircleOutlined />}
          onClick={onDismiss}
          size="small"
          type="text"
        >
          Fechar
        </Button>
      )}
    </Space>
  );

  return (
    <Alert
      type={type}
      message={message}
      description={description}
      action={action}
      banner={banner}
      closable={false}
      className={className}
      style={{
        marginBottom: 16,
        ...style,
      }}
      showIcon
    />
  );
};

export default ErrorBanner;
