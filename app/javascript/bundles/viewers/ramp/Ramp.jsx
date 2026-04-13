import PropTypes from 'prop-types';
import React, { useEffect, useState } from 'react';
import * as styles from './Ramp.module.css';
import {
  IIIFPlayer,
  MediaPlayer,
  Transcript
} from '@samvera/ramp';

const mapTranscriptFilesToRampTranscripts = (transcriptFiles = []) => {
  if (!transcriptFiles.length) return [];

  return [
    {
      // Ramp expects transcripts grouped by manifest canvas index.
      // Most single AV works use the first canvas.
      canvasId: 0,
      items: transcriptFiles
        .filter((file) => file?.url)
        .map((file) => ({ title: file.label || 'Transcript', url: file.url })),
    },
  ];
};

const Ramp = ({ manifestUrl, transcriptFiles }) => {
  const playerID = 'scholarspace-ramp-player';
  const [transcriptCollapsed, setTranscriptCollapsed] = useState(false);
  const [mounted, setMounted] = useState(true);
  const transcripts = mapTranscriptFilesToRampTranscripts(transcriptFiles);

  useEffect(() => {
    const handleBeforeVisit = () => setMounted(false);
    document.addEventListener('turbo:before-visit', handleBeforeVisit);
    return () => {
      document.removeEventListener('turbo:before-visit', handleBeforeVisit);
    };
  }, []);

  if (!mounted) return null;

  return (
    <IIIFPlayer manifestUrl={manifestUrl}>
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
                  <Transcript playerID={playerID} manifestUrl={manifestUrl} transcripts={transcripts} />
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
  transcriptFiles: PropTypes.arrayOf(
    PropTypes.shape({
      label: PropTypes.string,
      url: PropTypes.string,
    }),
  ),
};

Ramp.defaultProps = {
  transcriptFiles: [],
};

export default Ramp;