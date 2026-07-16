/**
 * FormSubmitBar Component
 * 
 * Standard action bar for forms with primary submit and cancel buttons.
 */

import React from 'react';
import { Space, Button } from 'antd';
import { SaveOutlined, CloseOutlined } from '@ant-design/icons';

export interface FormSubmitBarProps {
  /** Submit button text */
  submitText?: string;
  /** Cancel button text */
  cancelText?: string;
  /** Submit button loading state */
  loading?: boolean;
  /** Submit button disabled state */
  submitDisabled?: boolean;
  /** Callback when submit is clicked */
  onSubmit?: () => void;
  /** Callback when cancel is clicked */
  onCancel?: () => void;
  /** Align buttons to the right */
  align?: 'left' | 'center' | 'right';
  /** Additional buttons to display */
  extra?: React.ReactNode;
  /** Show cancel button */
  showCancel?: boolean;
}

export const FormSubmitBar: React.FC<FormSubmitBarProps> = ({
  submitText = 'Salvar',
  cancelText = 'Cancelar',
  loading = false,
  submitDisabled = false,
  onSubmit,
  onCancel,
  align = 'right',
  extra,
  showCancel = true,
}) => {
  const justifyContent = 
    align === 'right' ? 'flex-end' : 
    align === 'center' ? 'center' : 'flex-start';

  return (
    <div 
      style={{ 
        display: 'flex', 
        justifyContent,
        alignItems: 'center',
        gap: 12,
        paddingTop: 24,
        borderTop: '1px solid #f0f0f0',
        marginTop: 24,
      }}
    >
      {extra && <div style={{ marginRight: 'auto' }}>{extra}</div>}
      
      <Space>
        {showCancel && (
          <Button 
            onClick={onCancel}
            icon={<CloseOutlined />}
            disabled={loading}
          >
            {cancelText}
          </Button>
        )}
        <Button
          type="primary"
          onClick={onSubmit}
          loading={loading}
          disabled={submitDisabled}
          icon={<SaveOutlined />}
        >
          {submitText}
        </Button>
      </Space>
    </div>
  );
};

export default FormSubmitBar;
