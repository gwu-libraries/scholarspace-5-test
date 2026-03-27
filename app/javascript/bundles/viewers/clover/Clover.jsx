import React from 'react';
import PropTypes from 'prop-types';
import Viewer from '@samvera/clover-iiif/viewer';
import * as styles from './Clover.module.css';

import 'swiper/css';
import 'swiper/css/navigation';
import 'swiper/css/pagination';

const customTheme = {
  colors: {
    primary: '#033C5A',
    primaryMuted: '#0190DB',
    primaryAlt: '#AA9868',
    accent: '#FFC72C',
    accentMuted: '#A75523',
    accentAlt: '#B71C1C',
    secondary: '#FFFFFF',
    secondaryMuted: '#ECEFF1',
    secondaryAlt: '#CFD8DC',
  },
  fonts: {
    sans: "'Helvetica Neue', sans-serif",
    display: 'Optima, Georgia, Arial, sans-serif',
  },
};

const Clover = ({ manifestUrl }) => {
  return (
    <div className={styles.wrapper}>
      <article className={styles.viewer}>
        <Viewer iiifContent={manifestUrl} customTheme={customTheme} />
      </article>
    </div>
  );
};

Clover.propTypes = {
  manifestUrl: PropTypes.string.isRequired,
};

export default Clover;