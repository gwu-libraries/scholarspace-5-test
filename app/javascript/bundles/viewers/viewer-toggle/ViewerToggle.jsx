import React, { useEffect, useState } from 'react';
import PropTypes from 'prop-types';

const ViewerToggle = ({
  pdfTargetId,
  imagesTargetId,
  defaultViewer,
  activeViewer,
  onViewerChange,
}) => {
  const [internalViewer, setInternalViewer] = useState(defaultViewer);
  const currentViewer = activeViewer || internalViewer;

  const setViewer = (viewer) => {
    if (!activeViewer) setInternalViewer(viewer);
    if (onViewerChange) onViewerChange(viewer);
  };

  useEffect(() => {
    if (onViewerChange) return;
    if (!pdfTargetId || !imagesTargetId) return;

    const pdf = document.getElementById(pdfTargetId);
    const images = document.getElementById(imagesTargetId);
    if (!pdf || !images) return;

    pdf.hidden = currentViewer !== 'pdf';
    images.hidden = currentViewer !== 'images';
  }, [currentViewer, imagesTargetId, onViewerChange, pdfTargetId]);

  return (
    <div className="btn-group" role="group" aria-label="Viewer toggle">
      <button
        type="button"
        onClick={() => setViewer('pdf')}
        aria-pressed={currentViewer === 'pdf'}
        className={`btn btn-default ${currentViewer === 'pdf' ? 'active' : ''}`}
      >
        PDF viewer
      </button>
      <button
        type="button"
        onClick={() => setViewer('images')}
        aria-pressed={currentViewer === 'images'}
        className={`btn btn-default ${currentViewer === 'images' ? 'active' : ''}`}
      >
        Image viewer
      </button>
    </div>
  );
};

ViewerToggle.propTypes = {
  defaultViewer: PropTypes.oneOf(['pdf', 'images']),
  activeViewer: PropTypes.oneOf(['pdf', 'images']),
  onViewerChange: PropTypes.func,
  imagesTargetId: PropTypes.string,
  pdfTargetId: PropTypes.string,
};

ViewerToggle.defaultProps = {
  defaultViewer: 'pdf',
  activeViewer: undefined,
  onViewerChange: undefined,
  imagesTargetId: undefined,
  pdfTargetId: undefined,
};

export default ViewerToggle;