import React, { Suspense } from 'react';

export const EMPTY_IMAGE_FOCUS = { canvasId: '', token: 0 };

export const getMemberPdfUrl = (member) => member?.pdfUrl || member?.downloadUrl || null;

export const isPdfMember = (member) => Boolean(member?.isPdf && getMemberPdfUrl(member));

export const toRampSelection = (member) => (
  member?.canvasId != null
    ? { startCanvasId: String(member.canvasId), startCanvasTime: 0 }
    : null
);

export const createViewerRenderers = ({ Ramp, PdfViewer, Clover, viewerShellClassName, imageViewerClassName }) => {
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
    <div className={`work-show-image-viewer ${imageViewerClassName}`}>
      <Clover
        manifestUrl={viewer.manifestUrl}
        focusCanvasId={imageFocus.canvasId}
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
          <Ramp manifestUrl={viewer.manifestUrl} transcriptFiles={viewer.transcriptFiles || []} />
        </div>
      );
    }

    if (viewer.defaultViewer === 'images' && viewer.manifestUrl) {
      return renderImageViewer(viewer, EMPTY_IMAGE_FOCUS);
    }

    if (viewer.defaultViewer === 'pdf' && defaultPdf?.fileUrl) {
      return renderPdfViewer(defaultPdf);
    }

    if (defaultPdf?.fileUrl) return renderPdfViewer(defaultPdf);
    if (viewer.manifestUrl) return renderImageViewer(viewer, EMPTY_IMAGE_FOCUS);

    return <div className="work-show-no-viewer">No viewer available.</div>;
  };

  const renderActiveViewer = ({ viewer, activeMode, selectedPdf, selectedRamp, defaultPdf, imageFocus }) => {
    const effectivePdf = selectedPdf?.fileUrl ? selectedPdf : defaultPdf;

    if (activeMode === 'ramp') {
      return (
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
      return renderPdfViewer(effectivePdf);
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