import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';

import ViewerToggle from '../viewers/viewer_toggle/ViewerToggle';

const loadRamp = () => import(
  /* webpackChunkName: "viewer-ramp" */
  '../viewers/ramp/Ramp'
);
const loadPdfViewer = () => import(
  /* webpackChunkName: "viewer-pdf" */
  '../viewers/pdf_viewer/PdfViewer'
);
const loadClover = () => import(
  /* webpackChunkName: "viewer-clover" */
  '../viewers/clover/Clover'
);

const Ramp = lazy(loadRamp);
const PdfViewer = lazy(loadPdfViewer);
const Clover = lazy(loadClover);
const WorkItemsTabs = lazy(() => import('./WorkItemsTabs'));

const viewerShellStyle = {
  width: '100vw',
  maxWidth: '2200px',
  marginLeft: 'calc(50% - 50vw)',
  paddingLeft: '12px',
  paddingRight: '12px',
};

const cloverContainerStyle = {
  height: '82vh',
  minHeight: '720px',
};

const ViewerSection = ({ viewer, presenterId }) => {
  const defaultViewer = viewer.hasImages ? (viewer.defaultViewer || 'pdf') : 'pdf';
  const [activeViewer, setActiveViewer] = useState(defaultViewer);

  const renderViewer = () => {
    if (viewer.type === 'ramp') {
      return (
        <div className="work-show-ramp-viewer">
          <Ramp manifestUrl={viewer.manifestUrl} transcriptFiles={viewer.transcriptFiles || []} />
        </div>
      );
    }

    if (viewer.type === 'pdf_or_images') {
      if (activeViewer === 'images') {
        return (
          <div className="work-show-image-viewer" style={cloverContainerStyle}>
            <Clover manifestUrl={viewer.manifestUrl} />
          </div>
        );
      }

      return (
        <div className="work-show-pdf-viewer">
          <PdfViewer
            fileUrl={viewer.pdfUrl}
            hocrUrl={viewer.hocrUrl}
            enableTextLayer
            enableAnnotationLayer={false}
          />
        </div>
      );
    }

    return (
      <div className="work-show-image-viewer" style={cloverContainerStyle}>
        <Clover manifestUrl={viewer.manifestUrl} />
      </div>
    );
  };

  return (
    <>
      {viewer.type === 'pdf_or_images' && viewer.hasImages && (
        <ViewerToggle
          defaultViewer={viewer.defaultViewer}
          activeViewer={activeViewer}
          onViewerChange={setActiveViewer}
        />
      )}
      <div style={viewerShellStyle}>
        <Suspense fallback={<p>Loading viewer...</p>}>
          {renderViewer()}
        </Suspense>
      </div>
    </>
  );
};

ViewerSection.propTypes = {
  viewer: PropTypes.shape({
    type: PropTypes.oneOf(['ramp', 'pdf_or_images', 'clover']).isRequired,
    manifestUrl: PropTypes.string,
    pdfUrl:      PropTypes.string,
    hocrUrl:     PropTypes.string,
    hasImages: PropTypes.bool,
    defaultViewer: PropTypes.oneOf(['pdf', 'images']),
    transcriptFiles: PropTypes.arrayOf(PropTypes.object),
  }).isRequired,
  presenterId: PropTypes.string.isRequired,
};

const WorkShow = ({
  id,
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

    const schedule =
      window.requestIdleCallback ||
      ((cb) => setTimeout(cb, 0));
    const cancel =
      window.cancelIdleCallback ||
      ((id) => clearTimeout(id));

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

      <ViewerSection viewer={viewer} presenterId={id} />

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

WorkShow.propTypes = {
  id:           PropTypes.string.isRequired,
  title:        PropTypes.string.isRequired,
  descriptions: PropTypes.arrayOf(PropTypes.string),
  viewer:       PropTypes.object.isRequired,
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
};

WorkShow.defaultProps = {
  descriptions: [],
};

export default WorkShow;