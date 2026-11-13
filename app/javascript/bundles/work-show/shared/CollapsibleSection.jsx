import React from 'react';
import PropTypes from 'prop-types';
import * as styles from './CollapsibleSection.module.css';

const CollapsibleSection = ({ title, children }) => (
  <details className={styles.section} open>
    <summary className={styles.summary}>{title}</summary>
    <div className={styles.content}>{children}</div>
  </details>
);

CollapsibleSection.propTypes = {
  title: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired,
};

export default CollapsibleSection;
