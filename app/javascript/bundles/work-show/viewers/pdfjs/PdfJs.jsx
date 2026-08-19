import PropTypes from 'prop-types';
import React from 'react';
import * as styles from './PdfJs.module.css';

const PDFJS_VIEWER_PATH = '/pdfjs/web/viewer.html';

const pdfjsViewerUrl = (fileUrl, initialPageIndex) => {
  const params = new URLSearchParams({ file: fileUrl });
  const pageFragment = Number.isInteger(initialPageIndex) && initialPageIndex >= 0
    ? `#page=${initialPageIndex + 1}`
    : '';

  return `${PDFJS_VIEWER_PATH}?${params.toString()}${pageFragment}`;
};

const PdfJs = ({
  fileUrl,
  initialPageIndex,
}) => {
  if (!fileUrl) {
    return <div className={styles.status}>No PDF available.</div>;
  }

  const viewerUrl = pdfjsViewerUrl(fileUrl, initialPageIndex);

  return (
    <div className={styles.wrapper}>
      <iframe
        className={styles.frame}
        title="PDF viewer"
        src={viewerUrl}
        loading="lazy"
      />
    </div>
  );
};

PdfJs.propTypes = {
  fileUrl: PropTypes.string.isRequired,
  initialPageIndex: PropTypes.number,
};

PdfJs.defaultProps = {
  initialPageIndex: null,
};

export default PdfJs;