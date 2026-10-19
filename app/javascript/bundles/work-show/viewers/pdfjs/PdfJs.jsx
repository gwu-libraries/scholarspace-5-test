import PropTypes from 'prop-types';
import React from 'react';
import * as styles from './PdfJs.module.css';

const PDFJS_VIEWER_PATH = '/pdfjs/web/viewer.html';

const pdfjsViewerUrl = (fileUrl, initialPageIndex, searchQuery) => {
  const params = new URLSearchParams({ file: fileUrl });
  const fragment = new URLSearchParams();
  if (Number.isInteger(initialPageIndex) && initialPageIndex >= 0) {
    fragment.set('page', String(initialPageIndex + 1));
  }
  if (searchQuery) fragment.set('search', searchQuery);
  const pageFragment = fragment.toString() ? `#${fragment.toString()}` : '';

  return `${PDFJS_VIEWER_PATH}?${params.toString()}${pageFragment}`;
};

const PdfJs = ({
  fileUrl,
  initialPageIndex = null,
  searchQuery = '',
}) => {
  if (!fileUrl) {
    return <div className={styles.status}>No PDF available.</div>;
  }

  const viewerUrl = pdfjsViewerUrl(fileUrl, initialPageIndex, searchQuery);

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
  searchQuery: PropTypes.string,
};

export default PdfJs;