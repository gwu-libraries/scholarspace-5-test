import React, { useState } from 'react';
import PropTypes from 'prop-types';

const CollapsibleGroup = ({ label, count, children, defaultOpen, headerActions }) => {
  const [open, setOpen] = useState(defaultOpen !== false);

  return (
    <div style={{ marginBottom: '8px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <button
          type="button"
          onClick={() => setOpen((value) => !value)}
          style={{
            background: 'none',
            border: 'none',
            padding: '4px 0',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            fontWeight: 600,
            fontSize: '0.95rem',
          }}
          aria-expanded={open}
        >
          <span
            style={{
              display: 'inline-block',
              transition: 'transform 0.15s',
              transform: open ? 'rotate(90deg)' : 'rotate(0deg)',
              fontSize: '0.75rem',
            }}
            aria-hidden="true"
          >
            &#9654;
          </span>
          <span>{label} ({count})</span>
        </button>
        {headerActions && <div style={{ marginLeft: 'auto' }}>{headerActions}</div>}
      </div>
      {open && <div style={{ paddingLeft: '16px' }}>{children}</div>}
    </div>
  );
};

CollapsibleGroup.propTypes = {
  label: PropTypes.string.isRequired,
  count: PropTypes.number.isRequired,
  children: PropTypes.node.isRequired,
  defaultOpen: PropTypes.bool,
  headerActions: PropTypes.node,
};

CollapsibleGroup.defaultProps = {
  defaultOpen: true,
  headerActions: null,
};

export default CollapsibleGroup;
