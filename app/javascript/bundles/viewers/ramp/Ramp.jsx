import PropTypes from 'prop-types';
import React, { useEffect, useState } from 'react';
import {
  IIIFPlayer,
  MediaPlayer,
  Transcript
} from '@samvera/ramp';


const Ramp = ({ manifestUrl, transcriptFiles = [] }) => {
  const [transcriptCollapsed, setTranscriptCollapsed] = useState(false);
  const [mounted, setMounted] = useState(true);
  const hasTranscripts = transcriptFiles.length > 0;

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
          {hasTranscripts && (
            <button
              type="button"
              onClick={() => setTranscriptCollapsed((collapsed) => !collapsed)}
              className="btn btn-default btn-sm"
            >
              {transcriptCollapsed ? 'Show Transcript' : 'Hide Transcript'}
            </button>
          )}

          <div className="row">
            <div className={hasTranscripts && !transcriptCollapsed ? 'col-sm-9' : 'col-sm-12'}>
              <MediaPlayer enableFileDownload={false} />
            </div>

            {hasTranscripts && !transcriptCollapsed && (
              <div className="col-sm-3">
                <div className="ramp-transcript-shell">
                <Transcript manifestUrl={manifestUrl} />
              </div>
              </div>
            )}
          </div>
        </div>
      </div>
      <style>
        {`
          .ramp-transcript-shell .ramp--transcript_nav {
            height: 100%;
            display: flex;
            flex-direction: column;
            min-height: 0;
          }

          .ramp-transcript-shell .transcript_content {
            flex: 1 1 auto;
            min-height: 0;
            overflow-y: auto;
          }
        `}
      </style>
    </IIIFPlayer>
  );
};

Ramp.propTypes = {
  manifestUrl: PropTypes.string.isRequired,
  transcriptFiles: PropTypes.arrayOf(
    PropTypes.shape({
      id: PropTypes.oneOfType([PropTypes.string, PropTypes.number]).isRequired,
      label: PropTypes.string.isRequired,
      url: PropTypes.string.isRequired,
      format: PropTypes.string,
    }),
  ),
};

export default Ramp;