import PropTypes from 'prop-types';
import React, { useEffect, useRef, useState } from 'react';
import { Document, Page, pdfjs } from 'react-pdf';
import * as styles from './PdfViewer.module.css';

import 'react-pdf/dist/Page/AnnotationLayer.css';
import 'react-pdf/dist/Page/TextLayer.css';

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString();

const PdfViewer = ({ fileUrl }) => {
  const [numPages, setNumPages] = useState(0);
  const [pageWidth, setPageWidth] = useState(0);
  const pagesRef = useRef(null);

  useEffect(() => {
    const element = pagesRef.current;
    if (!element) return undefined;

    const updateWidth = () => {
      setPageWidth(element.clientWidth);
    };

    updateWidth();

    const resizeObserver = new ResizeObserver(() => {
      updateWidth();
    });

    resizeObserver.observe(element);

    return () => {
      resizeObserver.disconnect();
    };
  }, []);

  const onDocumentLoadSuccess = ({ numPages: nextNumPages }) => {
    setNumPages(nextNumPages);
  };

  if (!fileUrl) {
    return <div className={styles.status}>No PDF available.</div>;
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.panel}>
        <div className={styles.documentShell}>
          <div ref={pagesRef} className={styles.pages}>
            <Document file={fileUrl} onLoadSuccess={onDocumentLoadSuccess} loading="Loading PDF...">
              {Array.from(new Array(numPages), (_el, index) => (
                <Page
                  key={`page_${index + 1}`}
                  pageNumber={index + 1}
                  renderTextLayer
                  renderAnnotationLayer
                  className={styles.page}
                  width={pageWidth || undefined}
                />
              ))}
            </Document>
          </div>
        </div>
      </div>
    </div>
  );
};

PdfViewer.propTypes = {
  fileUrl: PropTypes.string.isRequired,
};

export default PdfViewer;