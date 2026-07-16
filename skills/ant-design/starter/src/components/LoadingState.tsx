/**
 * LoadingState Component
 * 
 * Standardized loading states for pages and sections.
 */

import React from 'react';
import { Spin, Skeleton, Empty, type SpinProps } from 'antd';
import { LoadingOutlined } from '@ant-design/icons';

export interface LoadingStateProps {
  /** Loading state type */
  type?: 'spinner' | 'skeleton' | 'empty';
  /** Loading message */
  tip?: string;
  /** Size of the spinner */
  size?: SpinProps['size'];
  /** Whether content is loading */
  loading?: boolean;
  /** Children to render when not loading */
  children?: React.ReactNode;
  /** Full screen overlay */
  fullscreen?: boolean;
  /** Number of skeleton rows (for skeleton type) */
  skeletonRows?: number;
  /** Empty state description */
  emptyDescription?: string;
  /** Delay in ms before showing loading state */
  delay?: number;
  /** Custom style */
  style?: React.CSSProperties;
  /** Additional className */
  className?: string;
}

export const LoadingState: React.FC<LoadingStateProps> = ({
  type = 'spinner',
  tip,
  size = 'default',
  loading = true,
  children,
  fullscreen = false,
  skeletonRows = 5,
  emptyDescription = 'Nenhum dado encontrado',
  delay = 0,
  style,
  className,
}) => {
  const [showLoading, setShowLoading] = React.useState(delay === 0);

  React.useEffect(() => {
    if (delay > 0) {
      const timer = setTimeout(() => setShowLoading(true), delay);
      return () => clearTimeout(timer);
    }
  }, [delay]);

  if (!loading) {
    return <>{children}</>;
  }

  if (!showLoading) {
    return <>{children}</>;
  }

  if (type === 'skeleton') {
    return (
      <div className={className} style={style}>
        <Skeleton 
          active 
          paragraph={{ rows: skeletonRows }}
          title={{ width: '40%' }}
        />
      </div>
    );
  }

  if (type === 'empty') {
    return (
      <div className={className} style={style}>
        <Empty description={emptyDescription} />
      </div>
    );
  }

  // Spinner (default)
  const spinIcon = <LoadingOutlined spin style={{ fontSize: fullscreen ? 48 : 24 }} />;

  if (fullscreen) {
    return (
      <div
        className={className}
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'rgba(255, 255, 255, 0.8)',
          zIndex: 1000,
          ...style,
        }}
      >
        <Spin indicator={spinIcon} tip={tip} size="large" />
      </div>
    );
  }

  return (
    <div 
      className={className}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: 200,
        ...style,
      }}
    >
      <Spin indicator={spinIcon} tip={tip} size={size} />
    </div>
  );
};

export default LoadingState;
