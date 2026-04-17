import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';

const loadPdfViewer = () => import(
  /* webpackChunkName: "viewer-pdf" */
  '../viewers/pdf_viewer/PdfViewer'
);
const PdfViewer = lazy(loadPdfViewer);
const WorkItemsTabs = lazy(() => import('./WorkItemsTabs'));

const viewerShellStyle = {
  width: '100vw',
  maxWidth: '2200px',
  marginLeft: 'calc(50% - 50vw)',
  paddingLeft: '12px',
  paddingRight: '12px',
};

const WorkShowPdfOnly = ({
  title,
  descriptions,
  viewer,
  originalMembers,
  serviceMembers,
  canViewServiceFiles,
}) => {
  const safeDescriptions = descriptions || [];
  const [showWorkItemsTabs, setShowWorkItemsTabs] = useState(false);

  useEffect(() => {
    let cancelled = false;

    const schedule = window.requestIdleCallback || ((cb) => setTimeout(cb, 0));
    const cancel = window.cancelIdleCallback || ((id) => clearTimeout(id));

    const handle = schedule(() => {
      if (!cancelled) setShowWorkItemsTabs(true);
    });

    return () => {
      cancelled = true;
      cancel(handle);
    };
  }, []);

  return (
    <div>
      <h1>Title: {title}</h1>

      <div style={viewerShellStyle}>
        <Suspense fallback={<p>Loading viewer...</p>}>
          <div className="work-show-pdf-viewer">
            <PdfViewer
              fileUrl={viewer.pdfUrl}
              hocrUrl={viewer.hocrUrl}
              enableTextLayer
              enableAnnotationLayer={false}
            />
          </div>
        </Suspense>
      </div>

      {safeDescriptions.map((desc, i) => (
        // eslint-disable-next-line react/no-danger
        <p key={i}>
          Description: <span dangerouslySetInnerHTML={{ __html: desc }} />
        </p>
      ))}

      {showWorkItemsTabs && (
        <Suspense fallback={<p>Loading files...</p>}>
          <WorkItemsTabs
            originalMembers={originalMembers}
            serviceMembers={serviceMembers}
            canViewServiceFiles={canViewServiceFiles}
          />
        </Suspense>
      )}
    </div>
  );
};

WorkShowPdfOnly.propTypes = {
  title: PropTypes.string.isRequired,
  descriptions: PropTypes.arrayOf(PropTypes.string),
  viewer: PropTypes.shape({
    type: PropTypes.oneOf(['pdf_or_images']).isRequired,
    pdfUrl: PropTypes.string,
    hocrUrl: PropTypes.string,
  }).isRequired,
  originalMembers: PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers: PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
};

WorkShowPdfOnly.defaultProps = {
  descriptions: [],
};

export default WorkShowPdfOnly;