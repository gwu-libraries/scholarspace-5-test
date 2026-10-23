import React, { Suspense } from 'react';

export const EMPTY_IMAGE_FOCUS = { canvasId: '', region: '', token: 0 };

export const getMemberPdfUrl = (member) => member?.pdfUrl || member?.downloadUrl || null;

export const isPdfMember = (member) => Boolean(member?.isPdf && getMemberPdfUrl(member));

export const toRampSelection = (member) => (
  member?.canvasId != null
    ? { startCanvasId: String(member.canvasId), startCanvasTime: 0 }
    : null
);

export const createViewerRenderers = ({ Ramp, PdfJs, Clover, viewerShellClassName, imageViewerClassName }) => {
  const rampManifestUrl = (viewer) => viewer.rampManifestUrl || viewer.manifestUrl;

  const renderPdfJs = (pdf) => (
    <div className="work-show-pdfjs">
      <PdfJs
        fileUrl={pdf.fileUrl}
        initialPageIndex={pdf.initialPageIndex}
        searchQuery={pdf.searchQuery}
      />
    </div>
  );

  const renderImageViewer = (viewer, imageFocus) => (
    <div className={`work-show-image-viewer ${imageViewerClassName}`}>
      <Clover
        manifestUrl={viewer.manifestUrl}
        focusCanvasId={imageFocus.canvasId}
        focusRegion={imageFocus.region}
        focusWordRegion={imageFocus.wordRegion}
        focusToken={imageFocus.token}
      />
    </div>
  );

  const renderInViewerShell = (node) => (
    <div className={viewerShellClassName}>
      <Suspense fallback={<p>Loading viewer...</p>}>
        {node}
      </Suspense>
    </div>
  );

  const renderDefaultViewer = (viewer, defaultPdf) => {
    if (viewer.type === 'ramp') {
      return (
        <div className="work-show-ramp-viewer">
          <Ramp manifestUrl={rampManifestUrl(viewer)} transcriptFiles={viewer.transcriptFiles || []} />
        </div>
      );
    }

    if (viewer.defaultViewer === 'images' && viewer.manifestUrl) {
      return renderImageViewer(viewer, EMPTY_IMAGE_FOCUS);
    }

    if (viewer.defaultViewer === 'pdf' && defaultPdf?.fileUrl) {
      return renderPdfJs(defaultPdf);
    }

    if (defaultPdf?.fileUrl) return renderPdfJs(defaultPdf);
    if (viewer.manifestUrl) return renderImageViewer(viewer, EMPTY_IMAGE_FOCUS);

    return <div className="work-show-no-viewer">No viewer available.</div>;
  };

  const renderActiveViewer = ({ viewer, activeMode, selectedPdf, selectedRamp, defaultPdf, imageFocus }) => {
    const effectivePdf = selectedPdf?.fileUrl ? selectedPdf : defaultPdf;

    if (activeMode === 'ramp') {
      return (
        <div className="work-show-ramp-viewer">
          <Ramp
            key={`${selectedRamp?.startCanvasId || 'default'}-${selectedRamp?.startCanvasTime || 0}`}
            manifestUrl={rampManifestUrl(viewer)}
            startCanvasId={selectedRamp?.startCanvasId}
            startCanvasTime={selectedRamp?.startCanvasTime}
            transcriptFiles={viewer.transcriptFiles || []}
          />
        </div>
      );
    }

    if (activeMode === 'pdf' && effectivePdf?.fileUrl) {
      return renderPdfJs(effectivePdf);
    }

    if (activeMode === 'images' && viewer.manifestUrl) {
      return renderImageViewer(viewer, imageFocus);
    }

    return renderDefaultViewer(viewer, defaultPdf);
  };

  return {
    renderActiveViewer,
    renderInViewerShell,
  };
};
