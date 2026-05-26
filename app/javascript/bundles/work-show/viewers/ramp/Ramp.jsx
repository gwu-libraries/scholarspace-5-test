import PropTypes from 'prop-types';
import React, { useEffect, useState } from 'react';
import * as styles from './Ramp.module.css';
import 'video.js/dist/video-js.css';
import '@samvera/ramp/dist/ramp.css';
import {
  IIIFPlayer,
  MediaPlayer,
  Transcript
} from '@samvera/ramp';

const mapTranscriptFilesToRampTranscripts = (transcriptFiles = []) => {
  if (!transcriptFiles.length) return [];

  const groupedByCanvas = transcriptFiles
    .filter((file) => file?.url)
    .reduce((acc, file) => {
      const parsedCanvasId = Number.parseInt(file?.canvasId, 10);
      const canvasId = Number.isInteger(parsedCanvasId) ? parsedCanvasId : 0;
      if (!acc[canvasId]) acc[canvasId] = [];
      acc[canvasId].push({
        title: file.label || 'Transcript',
        filename: file.label || 'Transcript',
        url: file.url,
        format: file.format || 'text/vtt',
      });
      return acc;
    }, {});

  return Object.entries(groupedByCanvas)
    .sort(([a], [b]) => Number(a) - Number(b))
    .map(([canvasId, items]) => ({ canvasId: Number(canvasId), items }));
};

const Ramp = ({
  manifestUrl,
  startCanvasId = undefined,
  startCanvasTime = 0,
  transcriptFiles = [],
}) => {
  const playerID = 'scholarspace-ramp-player';
  const [transcriptCollapsed, setTranscriptCollapsed] = useState(false);
  const [mounted, setMounted] = useState(true);
  const transcripts = mapTranscriptFilesToRampTranscripts(transcriptFiles);
  const playerProps = startCanvasId
    ? { manifestUrl, startCanvasId, startCanvasTime: Number.isFinite(startCanvasTime) ? startCanvasTime : 0 }
    : { manifestUrl };

  useEffect(() => {
    const handleBeforeVisit = () => setMounted(false);
    document.addEventListener('turbo:before-visit', handleBeforeVisit);
    return () => {
      document.removeEventListener('turbo:before-visit', handleBeforeVisit);
    };
  }, []);

  if (!mounted) return null;

  return (
    <IIIFPlayer {...playerProps}>
      <div className="panel panel-default">
        <div className="panel-body">
          <button
            type="button"
            onClick={() => setTranscriptCollapsed((collapsed) => !collapsed)}
            className="btn btn-default btn-sm"
          >
            {transcriptCollapsed ? 'Show Transcript' : 'Hide Transcript'}
          </button>

          <div className={`row ${styles.layoutRow}`}>
            <div className={!transcriptCollapsed ? `col-sm-9 ${styles.layoutCol}` : `col-sm-12 ${styles.layoutCol}`}>
              <MediaPlayer playerID={playerID} enableFileDownload={false} />
            </div>

            {!transcriptCollapsed && (
              <div className={`col-sm-3 ${styles.layoutCol} ${styles.transcriptCol}`}>
                <div className={styles.transcriptShell}>
                  <Transcript
                    playerID={playerID}
                    manifestUrl={manifestUrl}
                    transcripts={transcripts}
                  />
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </IIIFPlayer>
  );
};

Ramp.propTypes = {
  manifestUrl: PropTypes.string.isRequired,
  startCanvasId: PropTypes.string,
  startCanvasTime: PropTypes.number,
  transcriptFiles: PropTypes.arrayOf(
    PropTypes.shape({
      label: PropTypes.string,
      url: PropTypes.string,
      canvasId: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
      format: PropTypes.string,
    }),
  ),
};

export default Ramp;