import React, { Suspense, lazy, useState } from 'react';
import PropTypes from 'prop-types';

import ViewerToggle from '../viewers/viewer_toggle/ViewerToggle';
import WorkItemsTabs from './WorkItemsTabs';

const Ramp = lazy(() => import('../viewers/ramp/Ramp'));
const PdfViewer = lazy(() => import('../viewers/pdf_viewer/PdfViewer'));
const Clover = lazy(() => import('../viewers/clover/Clover'));

const ViewerSection = ({ viewer, presenterId }) => {
  const [activeViewer, setActiveViewer] = useState(viewer.defaultViewer || 'pdf');

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
          <div className="work-show-image-viewer">
            <Clover manifestUrl={viewer.manifestUrl} />
          </div>
        );
      }

      return (
        <div className="work-show-pdf-viewer">
          <PdfViewer fileUrl={viewer.pdfUrl} />
        </div>
      );
    }

    return <Clover manifestUrl={viewer.manifestUrl} />;
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
      <Suspense fallback={<p>Loading viewer...</p>}>
        {renderViewer()}
      </Suspense>
    </>
  );
};

ViewerSection.propTypes = {
  viewer: PropTypes.shape({
    type: PropTypes.oneOf(['ramp', 'pdf_or_images', 'clover']).isRequired,
    manifestUrl: PropTypes.string,
    pdfUrl:      PropTypes.string,
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