import PropTypes from 'prop-types';
import React, { useEffect, useRef, useState } from 'react';
import { Document, Page, pdfjs } from 'react-pdf';

import 'react-pdf/dist/Page/AnnotationLayer.css';
import 'react-pdf/dist/Page/TextLayer.css';
import * as styles from './PdfViewer.module.css';

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString();

const PdfViewer = ({ fileUrl }) => {
  const containerRef = useRef(null);
  const [containerWidth, setContainerWidth] = useState(0);
  const [numPages, setNumPages] = useState(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return undefined;

    const updateWidth = () => {
      const nextWidth = Math.floor(container.getBoundingClientRect().width);
      if (nextWidth > 0) setContainerWidth(nextWidth);
    };

    updateWidth();

    if (typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', updateWidth);
      return () => window.removeEventListener('resize', updateWidth);
    }

    const observer = new ResizeObserver(updateWidth);
    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  return (
    <div className={styles.wrapper}>
      <div ref={containerRef} className={styles.documentShell}>
        <Document
          file={fileUrl}
          loading={<div className={styles.status}>Loading PDF...</div>}
          error={<div className={styles.status}>Unable to load PDF.</div>}
          onLoadSuccess={({ numPages: nextNumPages }) => setNumPages(nextNumPages)}
        >
          {Array.from({ length: numPages || 0 }, (_, index) => (
            <div key={`page-${index + 1}`} className={styles.pageFrame}>
              <Page
                pageNumber={index + 1}
                renderAnnotationLayer
                renderTextLayer={false}
                width={containerWidth || undefined}
              />
            </div>
          ))}
        </Document>
      </div>
    </div>
  );
};

PdfViewer.propTypes = {
  fileUrl: PropTypes.string.isRequired,
};

export default PdfViewer;