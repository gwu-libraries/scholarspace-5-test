import PropTypes from 'prop-types';
import React, { useEffect, useRef, useState } from 'react';
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
  const playerContainerRef = useRef(null);
  const [mounted, setMounted] = useState(true);
  const transcripts = mapTranscriptFilesToRampTranscripts(transcriptFiles);
  const hasTranscripts = transcripts.length > 0;
  const playerProps = startCanvasId
    ? { manifestUrl, startCanvasId }
    : { manifestUrl };

  useEffect(() => {
    const handleBeforeVisit = () => setMounted(false);
    document.addEventListener('turbo:before-visit', handleBeforeVisit);
    return () => {
      document.removeEventListener('turbo:before-visit', handleBeforeVisit);
    };
  }, []);

  useEffect(() => {
    if (!Number.isFinite(startCanvasTime) || startCanvasTime <= 0) return undefined;

    const playerContainer = playerContainerRef.current;
    if (!playerContainer) return undefined;

    let mediaElement;
    let sought = false;
    const resetSeek = () => { sought = false; };
    const seekToResult = () => {
      const nextMediaElement = playerContainer.querySelector('video, audio');
      if (!nextMediaElement) return;

      if (mediaElement !== nextMediaElement) {
        mediaElement?.removeEventListener('canplay', seekToResult);
        mediaElement?.removeEventListener('emptied', resetSeek);
        mediaElement = nextMediaElement;
        sought = false;
        mediaElement.addEventListener('canplay', seekToResult);
        mediaElement.addEventListener('emptied', resetSeek);
      }

      if (sought || mediaElement.readyState < 2) return;

      sought = true;
      mediaElement.currentTime = startCanvasTime;
    };

    const observer = new MutationObserver(seekToResult);
    observer.observe(playerContainer, {
      childList: true,
      subtree: true,
    });
    seekToResult();

    return () => {
      observer.disconnect();
      mediaElement?.removeEventListener('canplay', seekToResult);
      mediaElement?.removeEventListener('emptied', resetSeek);
    };
  }, [startCanvasId, startCanvasTime]);

  if (!mounted) return null;

  return (
    <div ref={playerContainerRef}>
      <IIIFPlayer {...playerProps}>
        <div className={`panel panel-default ${styles.viewer}`}>
          <div className={`panel-body ${styles.panelBody}`}>
            <div className={`row ${styles.layoutRow}`}>
              <div className={`col-sm-12 ${styles.layoutCol} ${styles.playerCol}`}>
                <MediaPlayer playerID={playerID} enableFileDownload={false} />
              </div>

              {hasTranscripts && (
                <div className={`col-sm-12 ${styles.layoutCol} ${styles.transcriptCol}`}>
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
    </div>
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