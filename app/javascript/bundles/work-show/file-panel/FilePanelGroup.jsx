import React, { useState } from 'react';
import PropTypes from 'prop-types';
import * as styles from './FilePanel.module.css';

const FilePanelGroup = ({ label, count, children, defaultOpen, headerActions }) => {
  const [open, setOpen] = useState(defaultOpen !== false);
  const toggleLabel = `${open ? '\u25BE' : '\u25B8'}${label} (${count})`;

  return (
    <div className={styles.groupRoot}>
      <div className={styles.groupHeader}>
        <button
          type="button"
          onClick={() => setOpen((value) => !value)}
          className={`btn btn-default btn-xs ${styles.groupToggle}`}
          aria-expanded={open}
        >
          {toggleLabel}
        </button>
        {headerActions && <div className={styles.groupHeaderActions}>{headerActions}</div>}
      </div>
      {open && <div className={styles.groupChildren}>{children}</div>}
    </div>
  );
};

FilePanelGroup.propTypes = {
  label: PropTypes.string.isRequired,
  count: PropTypes.number.isRequired,
  children: PropTypes.node.isRequired,
  defaultOpen: PropTypes.bool,
  headerActions: PropTypes.node,
};

FilePanelGroup.defaultProps = {
  defaultOpen: true,
  headerActions: null,
};

export default FilePanelGroup;