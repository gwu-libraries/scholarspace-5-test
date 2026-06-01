import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import { memberViewerType } from './utils';
import * as styles from './WorkShow.module.css';
import {
  createViewerRenderers,
  EMPTY_IMAGE_FOCUS,
  getMemberPdfUrl,
  isPdfMember,
  toRampSelection,
} from './utils/viewer-rendering';

const loadRamp = () => import(
  /* webpackChunkName: "viewer-ramp" */
  './viewers/ramp/Ramp'
);
const loadPdfViewer = () => import(
  /* webpackChunkName: "viewer-pdf" */
  './viewers/pdf-viewer/PdfViewer'
);
const loadClover = () => import(
  /* webpackChunkName: "viewer-clover" */
  './viewers/clover/Clover'
);

const Ramp = lazy(loadRamp);
const PdfViewer = lazy(loadPdfViewer);
const Clover = lazy(loadClover);
const FilePanelTabs = lazy(() => import('./file-panel/FilePanelTabs'));

const viewerRenderers = createViewerRenderers({
  Ramp,
  PdfViewer,
  Clover,
  viewerShellClassName: styles.viewerShell,
  imageViewerClassName: styles.imageViewer,
});

const ViewerSection = ({
  viewer,
  activeMode,
  selectedPdf,
  selectedRamp,
  defaultPdf,
  imageFocus,
}) => {
  const activeViewerNode = viewerRenderers.renderActiveViewer({
    viewer,
    activeMode,
    selectedPdf,
    selectedRamp,
    defaultPdf,
    imageFocus,
  });

  return viewerRenderers.renderInViewerShell(activeViewerNode);
};

ViewerSection.propTypes = {
  viewer: PropTypes.shape({
    type: PropTypes.string.isRequired,
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
  const readingModePdfMember = serviceMembers.find((m) => m.isJoinedImagesPdf && isPdfMember(m));
  const firstPdfMember = readingModePdfMember || originalMembers.find(isPdfMember);
  const hasViewerActionMembers = originalMembers.some((member) => Boolean(memberViewerType(member)));
  const defaultPdf = {
    fileUrl: firstPdfMember?.pdfUrl || firstPdfMember?.downloadUrl || viewer.pdfUrl || null,
    hocrUrl: firstPdfMember?.hocrUrl || viewer.hocrUrl || null,
  };
  const readingModePdf = {
    fileUrl: (readingModePdfMember?.pdfUrl || readingModePdfMember?.downloadUrl) || null,
    hocrUrl: readingModePdfMember?.hocrUrl || null,
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

    switch (type) {
    case 'pdf':
      activatePdfMode(getMemberPdfUrl(member), member?.hocrUrl || null);
      return;
    case 'ramp':
      setActiveMode('ramp');
      setSelectedRamp(toRampSelection(member));
      return;
    case 'images': {
      const supportsInlineImageViewer = Boolean(viewer.manifestUrl);

      if (!supportsInlineImageViewer) {
        if (member?.showUrl) window.location.assign(member.showUrl);
        return;
      }

      setActiveMode('images');
      setImageFocus((previous) => ({
        canvasId: member?.canvasId ? String(member.canvasId) : '',
        token: previous.token + 1,
      }));
      return;
    }
    default:
      return;
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
        <FilePanelTabs
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