import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import WorkItemsTabs from './WorkItemsTabs';

const loadPdfViewer = () => import(
  /* webpackChunkName: "viewer-pdf" */
  '../viewers/pdf_viewer/PdfViewer'
);
const PdfViewer = lazy(loadPdfViewer);

const viewerShellStyle = {
  width: '100vw',
  maxWidth: '2200px',
  marginLeft: 'calc(50% - 50vw)',
  paddingLeft: '12px',
  paddingRight: '12px',
};

const pdfPickerStyle = {
  display: 'flex',
  flexWrap: 'wrap',
  gap: '8px',
  marginBottom: '12px',
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
  const pdfMembers = originalMembers.filter((member) => member.isPdf && member.pdfUrl);
  const [showWorkItemsTabs, setShowWorkItemsTabs] = useState(false);
  const [activePdf, setActivePdf] = useState(null);

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

  const onSelectPdf = (member) => {
    const fileUrl = member?.pdfUrl || member?.downloadUrl;

    if (fileUrl) {
      setActivePdf({
        fileUrl,
        hocrUrl: member.hocrUrl || null,
        jumpToPageIndex: null,
        focusRegion: null,
        focusToken: 0,
      });
    }
  };

  const onViewReadingMode = () => {
    if (!viewer.pdfUrl) return;

    setActivePdf({
      fileUrl: viewer.pdfUrl,
      hocrUrl: viewer.hocrUrl || null,
      jumpToPageIndex: null,
      focusRegion: null,
      focusToken: 0,
    });
  };

  return (
    <div>
      <h1>Title: {title}</h1>

      {pdfMembers.length > 1 && (
        <div style={pdfPickerStyle} role="group" aria-label="PDF selector">
          {pdfMembers.map((member, index) => {
            const isActive = activePdf?.fileUrl ? activePdf.fileUrl === member.pdfUrl : viewer.pdfUrl === member.pdfUrl;

            return (
              <button
                key={member.id}
                type="button"
                className={`btn btn-default ${isActive ? 'active' : ''}`}
                onClick={() => onSelectPdf(member)}
              >
                PDF {index + 1}: {member.label}
              </button>
            );
          })}
        </div>
      )}

      <div style={viewerShellStyle}>
        <Suspense fallback={<p>Loading viewer...</p>}>
          <div className="work-show-pdf-viewer">
            <PdfViewer
              fileUrl={activePdf?.fileUrl || viewer.pdfUrl}
              hocrUrl={activePdf?.hocrUrl || viewer.hocrUrl}
                initialPageIndex={activePdf?.jumpToPageIndex ?? null}
                focusRegion={activePdf?.focusRegion || null}
                focusToken={activePdf?.focusToken || 0}
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
        <WorkItemsTabs
          originalMembers={originalMembers}
          serviceMembers={serviceMembers}
          canViewServiceFiles={canViewServiceFiles}
          onViewMember={onSelectPdf}
          onViewReadingMode={viewer.pdfUrl ? onViewReadingMode : undefined}
        />
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
    hasImages: PropTypes.bool,
  }).isRequired,
  originalMembers: PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers: PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
};

WorkShowPdfOnly.defaultProps = {
  descriptions: [],
};

export default WorkShowPdfOnly;