import PropTypes from 'prop-types';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  IIIFPlayer,
  MediaPlayer,
  Transcript,
  SupplementalFiles,
  MetadataDisplay,
} from "@samvera/ramp";


const Ramp = ({ manifestUrl, transcriptFiles = [] }) => {
  const [transcriptCollapsed, setTranscriptCollapsed] = useState(false);
  const [playerHeight, setPlayerHeight] = useState(null);
  const playerContainerRef = useRef(null);
  const [isNarrowViewport, setIsNarrowViewport] = useState(() => {
    if (typeof window === 'undefined') return false;
    return window.innerWidth < 1200;
  });
  const hasTranscripts = transcriptFiles.length > 0;
  const transcripts = useMemo(() => {
    if (!hasTranscripts) return [];

    return [{
      canvasId: 0,
      items: transcriptFiles.map((file) => {
        return {
          title: file.label,
          filename: file.label,
          url: file.url,
        };
      }),
    }];
  }, [hasTranscripts, transcriptFiles]);

  useEffect(() => {
    const onResize = () => setIsNarrowViewport(window.innerWidth < 1200);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  useEffect(() => {
    const playerEl = playerContainerRef.current;
    if (!playerEl) return undefined;

    const updateHeight = () => {
      const next = Math.round(playerEl.getBoundingClientRect().height);
      if (next > 0) setPlayerHeight(next);
    };

    updateHeight();

    if (typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', updateHeight);
      return () => window.removeEventListener('resize', updateHeight);
    }

    const observer = new ResizeObserver(updateHeight);
    observer.observe(playerEl);
    return () => observer.disconnect();
  }, [isNarrowViewport, transcriptCollapsed]);

  return (
    <IIIFPlayer manifestUrl={manifestUrl}>
      <div
        style={{
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          minHeight: 0,
          border: '1px solid #d9d9d9',
          borderRadius: '4px',
          padding: '0.75rem',
        }}
      >
        {/* Top section: player left, transcript right (collapsible) */}
        <div
          style={{
            display: 'flex',
            gap: '1rem',
            alignItems: 'stretch',
            minHeight: 0,
            flexDirection: isNarrowViewport ? 'column' : 'row',
            position: 'relative',
          }}
        >
          {hasTranscripts && (
            <button
              type="button"
              onClick={() => setTranscriptCollapsed((collapsed) => !collapsed)}
              style={{
                position: 'absolute',
                right: '0.25rem',
                top: '0.25rem',
                zIndex: 2,
                padding: '0.25rem 0.5rem',
                border: '1px solid #ccc',
                background: '#fff',
                cursor: 'pointer',
              }}
            >
              {transcriptCollapsed ? 'Show Transcript' : 'Hide Transcript'}
            </button>
          )}

          <div
            ref={playerContainerRef}
            style={{ flex: hasTranscripts && !transcriptCollapsed && !isNarrowViewport ? '0 0 78%' : '1 1 100%', minWidth: 0 }}
          >
            <MediaPlayer enableFileDownload={false} />
          </div>

          {hasTranscripts && !transcriptCollapsed && (
            <div
              style={{
                flex: isNarrowViewport ? '1 1 auto' : '1 1 22%',
                overflow: 'hidden',
                height: playerHeight ? `${playerHeight}px` : 'auto',
                maxHeight: playerHeight ? `${playerHeight}px` : 'none',
                minHeight: 0,
                fontSize: '0.92rem',
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              <div className="ramp-transcript-shell" style={{ height: '100%', minHeight: 0 }}>
                <Transcript manifestUrl={manifestUrl} transcripts={transcripts} />
              </div>
            </div>
          )}
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
    }),
  ),
};

export default Ramp;
