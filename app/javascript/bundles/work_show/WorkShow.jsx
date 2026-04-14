import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';

import ViewerToggle from '../viewers/viewer_toggle/ViewerToggle';
import WorkItemsTabs from './WorkItemsTabs';

const loadRamp = () => import('../viewers/ramp/Ramp');
const loadPdfViewer = () => import('../viewers/pdf_viewer/PdfViewer');
const loadClover = () => import('../viewers/clover/Clover');

const Ramp = lazy(loadRamp);
const PdfViewer = lazy(loadPdfViewer);
const Clover = lazy(loadClover);

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
  const [activeViewer, setActiveViewer] = useState(viewer.defaultViewer || 'pdf');

  useEffect(() => {
    if (viewer.type === 'pdf_or_images') loadPdfViewer();
  }, [viewer.type]);

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
            enableTextLayer={false}
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
      {viewer.type === 'pdf_or_images' && (
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

      <WorkItemsTabs
        originalMembers={originalMembers}
        serviceMembers={serviceMembers}
        canViewServiceFiles={canViewServiceFiles}
      />
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