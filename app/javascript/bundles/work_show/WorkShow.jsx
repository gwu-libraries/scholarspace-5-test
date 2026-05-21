import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import { memberViewerType } from './file_grouping';

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
  width: '100%',
  minHeight: '600px',
};

const EMPTY_IMAGE_FOCUS = { canvasId: '', token: 0 };

const renderPdfViewer = (pdf) => (
  <div className="work-show-pdf-viewer">
    <PdfViewer
      fileUrl={pdf.fileUrl}
      hocrUrl={pdf.hocrUrl}
      enableTextLayer
      enableAnnotationLayer={false}
    />
  </div>
);

const renderImageViewer = (viewer, imageFocus) => (
  <div className="work-show-image-viewer" style={cloverContainerStyle}>
    <Clover
      manifestUrl={viewer.manifestUrl}
      focusCanvasId={imageFocus.canvasId}
      focusToken={imageFocus.token}
    />
  </div>
);

const ViewerSection = ({
  viewer,
  activeMode,
  selectedPdf,
  selectedRamp,
  defaultPdf,
  imageFocus,
}) => {
  const effectivePdf = selectedPdf?.fileUrl ? selectedPdf : defaultPdf;
  const renderInShell = (node) => (
    <div style={viewerShellStyle}>
      <Suspense fallback={<p>Loading viewer...</p>}>
        {node}
      </Suspense>
    </div>
  );

  if (activeMode === 'ramp') {
    return renderInShell(
      <div className="work-show-ramp-viewer">
        <Ramp
          key={selectedRamp?.startCanvasId}
          manifestUrl={viewer.manifestUrl}
          startCanvasId={selectedRamp?.startCanvasId}
          startCanvasTime={selectedRamp?.startCanvasTime}
          transcriptFiles={viewer.transcriptFiles || []}
        />
      </div>
    );
  }

  if (activeMode === 'pdf' && effectivePdf?.fileUrl) {
    return renderInShell(renderPdfViewer(effectivePdf));
  }

  if (activeMode === 'images' && (viewer.type === 'pdf_or_images' || viewer.type === 'clover')) {
    return renderInShell(renderImageViewer(viewer, imageFocus));
  }

  let defaultViewerNode = null;

  if (viewer.type === 'ramp') {
    defaultViewerNode = (
      <div className="work-show-ramp-viewer">
        <Ramp manifestUrl={viewer.manifestUrl} transcriptFiles={viewer.transcriptFiles || []} />
      </div>
    );
  } else if (viewer.type === 'pdf_or_images') {
    defaultViewerNode = renderImageViewer(viewer, EMPTY_IMAGE_FOCUS);
  } else if (defaultPdf?.fileUrl) {
    defaultViewerNode = renderPdfViewer(defaultPdf);
  } else {
    defaultViewerNode = renderImageViewer(viewer, EMPTY_IMAGE_FOCUS);
  }

  return renderInShell(defaultViewerNode);
};

ViewerSection.propTypes = {
  viewer: PropTypes.shape({
    type: PropTypes.oneOf(['ramp', 'pdf_or_images', 'clover']).isRequired,
    manifestUrl: PropTypes.string,
    transcriptFiles: PropTypes.arrayOf(PropTypes.object),
  }).isRequired,
  activeMode: PropTypes.oneOf(['default', 'ramp', 'pdf', 'images']).isRequired,
  selectedPdf: PropTypes.shape({
    fileUrl: PropTypes.string,
    hocrUrl: PropTypes.string,
  }),
  selectedRamp: PropTypes.shape({
    startCanvasId: PropTypes.string,
    startCanvasTime: PropTypes.number,
  }),
  defaultPdf: PropTypes.shape({
    fileUrl: PropTypes.string,
    hocrUrl: PropTypes.string,
  }),
  imageFocus: PropTypes.shape({
    canvasId: PropTypes.string,
    token: PropTypes.number.isRequired,
  }).isRequired,
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
  const firstPdfMember = originalMembers.find((member) => member.isPdf && (member.pdfUrl || member.downloadUrl));
  const hasViewerActionMembers = originalMembers.some((member) => Boolean(memberViewerType(member)));
  const defaultPdf = {
    fileUrl: firstPdfMember?.pdfUrl || firstPdfMember?.downloadUrl || viewer.pdfUrl || null,
    hocrUrl: firstPdfMember?.hocrUrl || viewer.hocrUrl || null,
  };
  const readingModePdf = {
    fileUrl: viewer.pdfUrl || defaultPdf.fileUrl,
    hocrUrl: viewer.hocrUrl || defaultPdf.hocrUrl,
  };
  const [activeMode, setActiveMode] = useState('default');
  const [selectedPdf, setSelectedPdf] = useState(null);
  const [selectedRamp, setSelectedRamp] = useState(null);
  const [imageFocus, setImageFocus] = useState(EMPTY_IMAGE_FOCUS);

  const activatePdfMode = (fileUrl, hocrUrl = null) => {
    if (!fileUrl) return;
    setActiveMode('pdf');
    setSelectedPdf({ fileUrl, hocrUrl });
  };

  useEffect(() => {
    setActiveMode('default');
    setSelectedPdf(null);
    setSelectedRamp(null);
    setImageFocus(EMPTY_IMAGE_FOCUS);
  }, [id]);

  const onViewMember = (member) => {
    const type = memberViewerType(member);

    if (type === 'pdf') {
      activatePdfMode(member?.pdfUrl || member?.downloadUrl, member?.hocrUrl || null);
      return;
    }

    if (type === 'ramp') {
      setActiveMode('ramp');
      setSelectedRamp(member?.canvasId != null ? { startCanvasId: String(member.canvasId), startCanvasTime: 0 } : null);
      return;
    }

    if (type === 'images') {
      const supportsInlineImageViewer = viewer.type === 'pdf_or_images' || viewer.type === 'clover';

      if (!supportsInlineImageViewer) {
        if (member?.showUrl) window.location.assign(member.showUrl);
        return;
      }

      setActiveMode('images');
      setImageFocus((previous) => ({
        canvasId: member?.canvasId || '',
        token: previous.token + 1,
      }));
    }
  };

  const onViewReadingMode = () => {
    activatePdfMode(readingModePdf.fileUrl, readingModePdf.hocrUrl || null);
  };

  return (
    <div>
      <h1>Title: {title}</h1>

      <ViewerSection
        viewer={viewer}
        activeMode={activeMode}
        selectedPdf={selectedPdf}
        selectedRamp={selectedRamp}
        defaultPdf={defaultPdf}
        imageFocus={imageFocus}
      />

      {safeDescriptions.map((desc, i) => (
        // eslint-disable-next-line react/no-danger
        <p key={i}>
          Description: <span dangerouslySetInnerHTML={{ __html: desc }} />
        </p>
      ))}

      <Suspense fallback={<p>Loading files...</p>}>
        <WorkItemsTabs
          originalMembers={originalMembers}
          serviceMembers={serviceMembers}
          canViewServiceFiles={canViewServiceFiles}
          onViewMember={hasViewerActionMembers ? onViewMember : undefined}
          onViewReadingMode={readingModePdf.fileUrl ? onViewReadingMode : undefined}
        />
      </Suspense>
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