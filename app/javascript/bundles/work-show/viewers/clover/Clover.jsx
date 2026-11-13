import React, { useEffect } from 'react';
import PropTypes from 'prop-types';
import CloverViewer from '@samvera/clover-iiif/viewer';
import * as styles from './Clover.module.css';

const FocusRegionControl = ({ region, wordRegion, useViewerState }) => {
  const { openSeadragonViewer } = useViewerState();

  useEffect(() => {
    if (!openSeadragonViewer || !region) return undefined;

    const parseRegion = (value) => {
      const coordinates = value.split(',').map(Number);
      return coordinates.length === 4 && coordinates.every((coordinate) => Number.isFinite(coordinate))
        ? coordinates
        : null;
    };
    const contextCoordinates = parseRegion(region);
    const wordCoordinates = wordRegion ? parseRegion(wordRegion) : null;
    if (!contextCoordinates) return undefined;

    let highlightElement;
    const fitRegion = () => {
      const image = openSeadragonViewer.world?.getItemAt(0);
      if (!image) return false;

      const [x, y, width, height] = contextCoordinates;
      const viewportRegion = image.imageToViewportRectangle(x, y, width, height);
      viewportRegion.x -= viewportRegion.width * 0.2;
      viewportRegion.y -= viewportRegion.height * 0.2;
      viewportRegion.width *= 1.4;
      viewportRegion.height *= 1.4;
      openSeadragonViewer.viewport.fitBounds(viewportRegion, false);
      if (wordCoordinates && !highlightElement) {
        const [wordX, wordY, wordWidth, wordHeight] = wordCoordinates;
        highlightElement = document.createElement('div');
        highlightElement.className = styles.ocrHighlight;
        openSeadragonViewer.addOverlay({
          element: highlightElement,
          location: image.imageToViewportRectangle(wordX, wordY, wordWidth, wordHeight),
        });
      }
      return true;
    };

    const stopAt = Date.now() + 10000;
    const intervalId = window.setInterval(() => {
      if (Date.now() >= stopAt) window.clearInterval(intervalId);
      else fitRegion();
    }, 100);

    return () => window.clearInterval(intervalId);
  }, [openSeadragonViewer, region, wordRegion]);

  return null;
};

const contentStateForCanvas = (manifestUrl, canvasId, region) => ({
  '@context': 'http://iiif.io/api/presentation/3/context.json',
  id: `${manifestUrl}#${encodeURIComponent(canvasId)}`,
  type: 'Annotation',
  motivation: ['contentState'],
  body: [
    {
      id: canvasId,
      type: 'Image',
    },
  ],
  target: region ? {
    id: `${canvasId}#xywh=${region}`,
    type: 'Canvas',
    partOf: [
      {
        id: manifestUrl,
        type: 'Manifest',
      },
    ],
  } : {
    id: canvasId,
    type: 'Canvas',
    partOf: [
      {
        id: manifestUrl,
        type: 'Manifest',
      },
    ],
  },
});

const Clover = ({ manifestUrl, focusCanvasId = '', focusRegion = '', focusWordRegion = '', focusToken = 0 }) => {
  const iiifContent = focusCanvasId
    ? contentStateForCanvas(manifestUrl, focusCanvasId, focusRegion)
    : manifestUrl;

  const viewerKey = `${manifestUrl}__${focusCanvasId || 'default'}__${focusToken}`;

  return (
    <div className={styles.viewer}>
      <CloverViewer
        key={viewerKey}
        iiifContent={iiifContent}
        plugins={focusRegion ? [
          {
            id: 'search-region-focus',
            imageViewer: {
              controls: {
                component: FocusRegionControl,
                componentProps: { region: focusRegion, wordRegion: focusWordRegion },
              },
            },
          },
        ] : []}
        options={{
          showTitle: false,
          showIIIFBadge: false,
          informationPanel: {
            open: false,
            renderToggle: false,
            renderAbout: false,
            renderSupplementing: false,
            renderAnnotation: false,
            renderContents: false,
            renderContentSearch: false,
            renderCanvasSummary: false,
          },
        }}
      />
    </div>
  );
};

Clover.propTypes = {
  manifestUrl: PropTypes.string.isRequired,
  focusCanvasId: PropTypes.string,
  focusRegion: PropTypes.string,
  focusWordRegion: PropTypes.string,
  focusToken: PropTypes.number,
};

export default Clover;
