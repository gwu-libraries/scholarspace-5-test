import React from 'react';
import PropTypes from 'prop-types';
import CloverViewer from '@samvera/clover-iiif/viewer';
import * as styles from './Clover.module.css';

const Clover = ({ manifestUrl, focusCanvasId, focusToken }) => {
  const iiifContent = focusCanvasId
    ? {
      '@context': 'http://iiif.io/api/presentation/3/context.json',
      id: `${manifestUrl}/state/${encodeURIComponent(focusCanvasId)}`,
      type: 'Annotation',
      motivation: ['contentState'],
      target: {
        type: 'SpecificResource',
        source: {
          id: focusCanvasId,
          type: 'Canvas',
          partOf: [{ id: manifestUrl, type: 'Manifest' }],
        },
      },
      body: [],
    }
    : manifestUrl;

  const viewerKey = `${manifestUrl}__${focusCanvasId || 'default'}__${focusToken}`;

  return (
    <div className={styles.viewer}>
      <CloverViewer
        key={viewerKey}
        iiifContent={iiifContent}
        options={{
          showTitle: false,
          showIIIFBadge: false,
          informationPanel: {
            open: true,
            renderToggle: true,
            renderAbout: true,
            renderSupplementing: false,
            renderAnnotation: false,
            renderContentSearch: true,
            defaultTab: 'manifest-content-search',
          },
        }}
      />
    </div>
  );
};

Clover.propTypes = {
  manifestUrl: PropTypes.string.isRequired,
  focusCanvasId: PropTypes.string,
  focusToken: PropTypes.number,
};

Clover.defaultProps = {
  focusCanvasId: '',
  focusToken: 0,
};

export default Clover;
