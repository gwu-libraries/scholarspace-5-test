import React, { Suspense, lazy, useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import { memberViewerType } from './file-panel/grouping';
import * as styles from './WorkShow.module.css';
import {
  createViewerRenderers,
  EMPTY_IMAGE_FOCUS,
  getMemberPdfUrl,
  isPdfMember,
  toRampSelection,
} from './viewers/rendering';
import { CollapsibleSection, WorkShowHeader, WorkShowMetadata } from './shared';
import DeepSearch from './deep-search/DeepSearch';

const loadRamp = () => import(
  /* webpackChunkName: "viewer-ramp" */
  './viewers/ramp/Ramp'
);
const loadPdfJs = () => import(
  /* webpackChunkName: "viewer-pdfjs" */
  './viewers/pdfjs/PdfJs'
);
const loadClover = () => import(
  /* webpackChunkName: "viewer-clover" */
  './viewers/clover/Clover'
);

const Ramp = lazy(loadRamp);
const PdfJs = lazy(loadPdfJs);
const Clover = lazy(loadClover);
const FilePanelTabs = lazy(() => import('./file-panel/FilePanelTabs'));

const viewerRenderers = createViewerRenderers({
  Ramp,
  PdfJs,
  Clover,
  viewerShellClassName: styles.viewerShell,
  imageViewerClassName: styles.imageViewer,
});

const LARGE_IMAGE_VIEWER_DEFER_THRESHOLD = 100;
const LARGE_FILE_PANEL_DEFER_THRESHOLD = 100;

const shouldDeferViewerLoad = ({ viewer, originalMembers }) => {
  const memberCount = Array.isArray(originalMembers) ? originalMembers.length : 0;
  if (memberCount <= LARGE_IMAGE_VIEWER_DEFER_THRESHOLD) return false;

  if (viewer.type === 'clover') return true;
  if (viewer.type === 'pdf_or_images' && viewer.defaultViewer === 'images') return true;

  return false;
};

const shouldDeferFilePanelLoad = ({ originalMembers }) => {
  const memberCount = Array.isArray(originalMembers) ? originalMembers.length : 0;
  return memberCount > LARGE_FILE_PANEL_DEFER_THRESHOLD;
};

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

const imageFocusFromLocation = () => {
  if (typeof window === 'undefined') return EMPTY_IMAGE_FOCUS;

  const params = new URLSearchParams(window.location.search);
  if (params.get('viewer') !== 'images') return EMPTY_IMAGE_FOCUS;

  const canvasId = params.get('canvas_id') || '';
  if (!canvasId) return EMPTY_IMAGE_FOCUS;

  return {
    canvasId,
    region: params.get('xywh') || '',
    wordRegion: params.get('word_xywh') || '',
    token: 1,
  };
};

const rampSelectionFromLocation = () => {
  if (typeof window === 'undefined') return null;

  const params = new URLSearchParams(window.location.search);
  if (params.get('viewer') !== 'ramp') return null;

  const startCanvasId = params.get('canvas_id') || '';
  if (!startCanvasId) return null;

  const startCanvasTime = Number.parseFloat(params.get('t') || '0');
  return {
    startCanvasId,
    startCanvasTime: Number.isFinite(startCanvasTime) ? startCanvasTime : 0,
  };
};

const pdfSelectionFromLocation = (originalMembers) => {
  if (typeof window === 'undefined') return null;

  const params = new URLSearchParams(window.location.search);
  if (params.get('viewer') !== 'pdf') return null;

  const pdfFileSetId = params.get('pdf_file_id') || '';
  const member = originalMembers.find((candidate) => String(candidate.id) === pdfFileSetId);
  const fileUrl = member ? getMemberPdfUrl(member) : null;
  if (!fileUrl) return null;

  return {
    fileUrl,
    hocrUrl: member?.hocrUrl || null,
    searchQuery: params.get('search') || '',
    initialPageIndex: Number.isInteger(Number(params.get('page'))) ? Number(params.get('page')) - 1 : null,
  };
};

ViewerSection.propTypes = {
  viewer: PropTypes.shape({
    type: PropTypes.string.isRequired,
    manifestUrl: PropTypes.string,
    rampManifestUrl: PropTypes.string,
    cloverManifestUrl: PropTypes.string,
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
    region: PropTypes.string,
    token: PropTypes.number.isRequired,
  }).isRequired,
};

const WorkShow = ({
  id,
  title,
  metadata = [],
  viewer,
  originalMembers,
  serviceMembers,
  canViewServiceFiles,
  readingModePdf = null,
  deepSearch,
}) => {
  const headerMetadataNames = ['description_tesim', 'abstract_tesim'];
  const headerMetadata = metadata.filter((field) => headerMetadataNames.includes(field.name));
  const panelMetadata = metadata.filter((field) => !headerMetadataNames.includes(field.name));
  const descriptions = headerMetadata
    .filter((field) => field.name === 'description_tesim')
    .flatMap((field) => field.values || [])
    .filter(Boolean);
  const abstracts = headerMetadata
    .filter((field) => field.name === 'abstract_tesim')
    .flatMap((field) => field.values || [])
    .filter(Boolean);
  const creators = metadata
    .filter((field) => field.name === 'creator_tesim' || field.name === 'creator_sim')
    .flatMap((field) => field.values || [])
    .filter(Boolean);
  const affiliation = metadata
    .find((field) => field.name === 'gw_affiliation')?.values?.join(', ');
  const firstPdfMember = originalMembers.find(isPdfMember);
  const hasViewerActionMembers = originalMembers.some((member) => Boolean(memberViewerType(member)));
  const defaultPdf = {
    fileUrl: viewer.pdfUrl || firstPdfMember?.pdfUrl || firstPdfMember?.downloadUrl || null,
    hocrUrl: viewer.hocrUrl || firstPdfMember?.hocrUrl || null,
  };
  const initialImageFocus = imageFocusFromLocation();
  const initialRampSelection = rampSelectionFromLocation();
  const initialPdfSelection = pdfSelectionFromLocation(originalMembers);
  const [activeMode, setActiveMode] = useState(initialPdfSelection ? 'pdf' : (initialRampSelection ? 'ramp' : (initialImageFocus.canvasId ? 'images' : 'default')));
  const [selectedPdf, setSelectedPdf] = useState(initialPdfSelection);
  const [selectedRamp, setSelectedRamp] = useState(initialRampSelection);
  const [imageFocus, setImageFocus] = useState(initialImageFocus);
  const [viewerEnabled, setViewerEnabled] = useState(() => Boolean(initialImageFocus.canvasId) || !shouldDeferViewerLoad({ viewer, originalMembers }));
  const [filePanelEnabled, setFilePanelEnabled] = useState(() => !shouldDeferFilePanelLoad({ originalMembers }));
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const activatePdfMode = (fileUrl, hocrUrl = null) => {
    if (!fileUrl) return;
    setActiveMode('pdf');
    setSelectedPdf({ fileUrl, hocrUrl });
  };

  useEffect(() => {
    const nextImageFocus = imageFocusFromLocation();
    const nextRampSelection = rampSelectionFromLocation();
    const nextPdfSelection = pdfSelectionFromLocation(originalMembers);
    setActiveMode(nextPdfSelection ? 'pdf' : (nextRampSelection ? 'ramp' : (nextImageFocus.canvasId ? 'images' : 'default')));
    setSelectedPdf(nextPdfSelection);
    setSelectedRamp(nextRampSelection);
    setImageFocus(nextImageFocus);
    setViewerEnabled(Boolean(nextImageFocus.canvasId) || !shouldDeferViewerLoad({ viewer, originalMembers }));
    setFilePanelEnabled(!shouldDeferFilePanelLoad({ originalMembers }));
  }, [id]);

  useEffect(() => {
    if (filePanelEnabled) return undefined;

    const enableFilePanels = () => setFilePanelEnabled(true);

    if (typeof window.requestIdleCallback === 'function') {
      const idleId = window.requestIdleCallback(enableFilePanels, { timeout: 1000 });
      return () => window.cancelIdleCallback(idleId);
    }

    const timerId = window.setTimeout(enableFilePanels, 0);
    return () => window.clearTimeout(timerId);
  }, [filePanelEnabled]);

  const onViewMember = (member, region = '', wordRegion = '') => {
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
        region,
        wordRegion,
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

  const normalizeCanvasId = (canvasId) => String(canvasId || '').replace(/^\/canvas\//, '');

  const currentFileId = (() => {
    if (activeMode === 'pdf' && selectedPdf?.fileUrl) {
      return originalMembers.find((member) => getMemberPdfUrl(member) === selectedPdf.fileUrl)?.id?.toString();
    }
    if (activeMode === 'ramp' && selectedRamp?.startCanvasId) {
      const selectedCanvasId = normalizeCanvasId(selectedRamp.startCanvasId);
      return originalMembers.find((member) => normalizeCanvasId(member.canvasId) === selectedCanvasId)?.id?.toString();
    }
    if (activeMode === 'images' && imageFocus.canvasId) {
      const selectedCanvasId = normalizeCanvasId(imageFocus.canvasId);
      return originalMembers.find((member) => normalizeCanvasId(member.canvasId) === selectedCanvasId)?.id?.toString();
    }
    return firstPdfMember?.id?.toString() || originalMembers[0]?.id?.toString();
  })();

  const onViewSearchResult = (result) => {
    if (!result?.href) return false;

    const resultUrl = new URL(result.href, window.location.origin);
    const fileSetId = result.fileSetId || resultUrl.searchParams.get('pdf_file_id') ||
      resultUrl.searchParams.get('canvas_id')?.replace(/^\/canvas\//, '');
    const member = originalMembers.find((candidate) => String(candidate.id) === fileSetId);
    if (!member) return false;

    const viewerType = memberViewerType(member);
    if (!viewerType) return false;

    if (viewerType === 'ramp') {
      const selection = toRampSelection(member);
      if (!selection) return false;

      setActiveMode('ramp');
      setSelectedRamp({
        ...selection,
        startCanvasTime: Number.isFinite(Number(result.startTime)) ? Number(result.startTime) : 0,
      });
      return true;
    }

    if (viewerType === 'pdf') {
      setActiveMode('pdf');
      setSelectedPdf({
        fileUrl: getMemberPdfUrl(member),
        hocrUrl: member?.hocrUrl || null,
        initialPageIndex: Number.isInteger(Number(result.page)) ? Number(result.page) - 1 : null,
        searchQuery: result.search || '',
      });
      return true;
    }

    onViewMember(member, result.region || '', result.wordRegion || '');
    return true;
  };

  return (
    <div className={styles.root}>
      <WorkShowHeader
        title={title}
        creators={creators}
        affiliation={affiliation}
        descriptions={descriptions}
        abstracts={abstracts}
      />
      <div className={styles.toolsToggleRow}>
        <button
          type="button"
          className="btn btn-default btn-sm"
          aria-expanded={sidebarOpen}
          aria-controls="work-show-tools"
          onClick={() => setSidebarOpen((open) => !open)}
        >
          {sidebarOpen ? 'Hide search and information' : 'Show search and metadata'}
        </button>
      </div>

      <div className={`${styles.content} ${sidebarOpen ? '' : styles.contentCollapsed}`}>
        <section className={styles.viewerColumn} aria-label="File viewer">
          {viewerEnabled ? (
            <ViewerSection
              viewer={viewer}
              activeMode={activeMode}
              selectedPdf={selectedPdf}
              selectedRamp={selectedRamp}
              defaultPdf={defaultPdf}
              imageFocus={imageFocus}
            />
          ) : (
            <div className={styles.viewerShell}>
              <button
                type="button"
                className="btn btn-primary btn-sm"
                onClick={() => setViewerEnabled(true)}
              >
                Load Viewer
              </button>
            </div>
          )}
        </section>

        <aside id="work-show-tools" className={styles.sidebar} aria-label="Work tools" hidden={!sidebarOpen}>
          <DeepSearch {...deepSearch} currentFileId={currentFileId} onViewResult={onViewSearchResult} />

          <WorkShowMetadata metadata={panelMetadata} />

          <section className={`${styles.sidebarSection} ${styles.filePanel}`}>
            <Suspense fallback={<p>Loading files...</p>}>
              {filePanelEnabled ? (
                <CollapsibleSection title="Files">
                  <FilePanelTabs
                    originalMembers={originalMembers}
                    serviceMembers={serviceMembers}
                    canViewServiceFiles={canViewServiceFiles}
                    onViewMember={hasViewerActionMembers ? onViewMember : undefined}
                    onViewReadingMode={readingModePdf?.fileUrl ? onViewReadingMode : undefined}
                  />
                </CollapsibleSection>
              ) : (
                <p>File lists are loading in the background.</p>
              )}
            </Suspense>
          </section>
        </aside>
      </div>
    </div>
  );
};

WorkShow.propTypes = {
  id:           PropTypes.string.isRequired,
  title:        PropTypes.string.isRequired,
  metadata: PropTypes.arrayOf(PropTypes.shape({
    name: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    values: PropTypes.arrayOf(PropTypes.string).isRequired,
  })),
  viewer:       PropTypes.object.isRequired,
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
  readingModePdf: PropTypes.shape({
    fileUrl: PropTypes.string,
    hocrUrl: PropTypes.string,
  }),
  deepSearch: PropTypes.shape({
    query: PropTypes.string,
    imageResults: PropTypes.arrayOf(PropTypes.object),
    pdfResults: PropTypes.arrayOf(PropTypes.object),
    avResults: PropTypes.arrayOf(PropTypes.object),
  }),
};

export default WorkShow;