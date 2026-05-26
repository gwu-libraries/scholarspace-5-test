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

// why all this and not just pdfjs? 
// mostly to support HOCR overlays, which require page dimensions and word bounding boxes that are easier to manage here than in with pdfjs directly.
// with pdfjs, when the hocr for the document is updated, we need to run through
// the whole process of generating another pdf with embedded hocr and reindexing it. 
// This solution just lets us update the hocr file and have the viewer pick up the changes immediately, without needing to reprocess the pdf or reindex anything.

const PdfViewer = ({
  fileUrl,
  hocrUrl,
  initialPageIndex,
  focusRegion,
  focusToken,
  enableTextLayer,
  enableAnnotationLayer,
}) => {
  const [numPages, setNumPages] = useState(0);
  const [renderedPages, setRenderedPages] = useState(1);
  const [pageWidth, setPageWidth] = useState(0);
  const [hocrPages, setHocrPages] = useState([]);
  const [activeFocus, setActiveFocus] = useState(null);
  const pagesRef = useRef(null);
  const pageNodeRefs = useRef({});

  const parseBbox = (titleValue) => {
    if (!titleValue) return null;

    const match = titleValue.match(/\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/i);
    if (!match) return null;

    return [
      Number.parseInt(match[1], 10),
      Number.parseInt(match[2], 10),
      Number.parseInt(match[3], 10),
      Number.parseInt(match[4], 10),
    ];
  };

  const buildHocrOverlayData = (hocrText) => {
    if (!hocrText) return [];

    const parser = new DOMParser();
    const documentNode = parser.parseFromString(hocrText, 'text/html');
    const pageNodes = Array.from(documentNode.querySelectorAll('div.ocr_page'));

    return pageNodes.map((pageNode) => {
      const pageBbox = parseBbox(pageNode.getAttribute('title'));
      if (!pageBbox) return { words: [] };

      const [x1, y1, x2, y2] = pageBbox;
      const pageWidthPx = x2 - x1;
      const pageHeightPx = y2 - y1;
      if (pageWidthPx <= 0 || pageHeightPx <= 0) return { words: [] };

      const wordNodes = Array.from(pageNode.querySelectorAll('span.ocrx_word, span.ocr_word'));
      const words = wordNodes
        .map((wordNode) => {
          const text = wordNode.textContent?.replace(/\s+/g, ' ').trim();
          const wordBbox = parseBbox(wordNode.getAttribute('title'));
          if (!text || !wordBbox) return null;

          const [wx1, wy1, wx2, wy2] = wordBbox;
          const widthPx = wx2 - wx1;
          const heightPx = wy2 - wy1;
          if (widthPx <= 0 || heightPx <= 0) return null;

          return {
            text,
            leftPx: wx1 - x1,
            topPx: wy1 - y1,
            widthPx,
            heightPx,
            leftPct: ((wx1 - x1) / pageWidthPx) * 100,
            topPct: ((wy1 - y1) / pageHeightPx) * 100,
            widthPct: (widthPx / pageWidthPx) * 100,
            heightPct: (heightPx / pageHeightPx) * 100,
          };
        })
        .filter(Boolean);

      return {
        sourceWidthPx: pageWidthPx,
        sourceHeightPx: pageHeightPx,
        words,
      };
    });
  };

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
    setRenderedPages(Math.min(1, nextNumPages));
  };

  useEffect(() => {
    if (numPages <= 1) return undefined;

    let nextPage = 1;
    let timerId;

    const renderNextPage = () => {
      nextPage += 1;
      setRenderedPages(nextPage);

      if (nextPage < numPages) {
        timerId = setTimeout(renderNextPage, 0);
      }
    };

    timerId = setTimeout(renderNextPage, 0);

    return () => {
      if (timerId) clearTimeout(timerId);
    };
  }, [numPages]);

  useEffect(() => {
    let cancelled = false;

    const loadHocr = async () => {
      if (!hocrUrl) {
        setHocrPages([]);
        return;
      }

      try {
        const response = await fetch(hocrUrl, { credentials: 'same-origin' });
        if (!response.ok) throw new Error(`HOCR fetch failed: ${response.status}`);

        const text = await response.text();
        const pages = buildHocrOverlayData(text);
        if (!cancelled) setHocrPages(pages);
      } catch (_error) {
        if (!cancelled) setHocrPages([]);
      }
    };

    loadHocr();

    return () => {
      cancelled = true;
    };
  }, [hocrUrl]);

  useEffect(() => {
    if (!Number.isInteger(initialPageIndex) || initialPageIndex < 0) return;
    if (renderedPages <= initialPageIndex) return;

    const pageNode = pageNodeRefs.current[initialPageIndex + 1];
    if (pageNode && typeof pageNode.scrollIntoView === 'function') {
      pageNode.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [initialPageIndex, renderedPages, focusToken]);

  useEffect(() => {
    if (!Number.isInteger(initialPageIndex) || !focusRegion) {
      setActiveFocus(null);
      return;
    }

    const match = focusRegion.match(/^(\d+),(\d+),(\d+),(\d+)$/);
    if (!match) {
      setActiveFocus(null);
      return;
    }

    setActiveFocus({
      pageIndex: initialPageIndex,
      x: Number.parseInt(match[1], 10),
      y: Number.parseInt(match[2], 10),
      width: Number.parseInt(match[3], 10),
      height: Number.parseInt(match[4], 10),
    });
  }, [initialPageIndex, focusRegion, focusToken]);

  if (!fileUrl) {
    return <div className={styles.status}>No PDF available.</div>;
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.panel}>
        <div className={styles.documentShell}>
          <div ref={pagesRef} className={styles.pages}>
            <Document file={fileUrl} onLoadSuccess={onDocumentLoadSuccess} loading="Loading PDF...">
              {Array.from(new Array(Math.min(numPages, renderedPages)), (_el, index) => (
                  <div
                    key={`page_${index + 1}`}
                    className={styles.pageFrame}
                    ref={(node) => {
                      pageNodeRefs.current[index + 1] = node;
                    }}
                  >
                  <Page
                    pageNumber={index + 1}
                    renderTextLayer={enableTextLayer}
                    renderAnnotationLayer={enableAnnotationLayer}
                    className={styles.page}
                    width={pageWidth || undefined}
                  />
                  {hocrPages[index]?.words?.length > 0 && (
                    <div className={styles.hocrOverlay}>
                        {activeFocus && activeFocus.pageIndex === index && hocrPages[index]?.sourceWidthPx > 0 && hocrPages[index]?.sourceHeightPx > 0 && (
                          <span
                            style={{
                              position: 'absolute',
                              left: `${(activeFocus.x / hocrPages[index].sourceWidthPx) * 100}%`,
                              top: `${(activeFocus.y / hocrPages[index].sourceHeightPx) * 100}%`,
                              width: `${(activeFocus.width / hocrPages[index].sourceWidthPx) * 100}%`,
                              height: `${(activeFocus.height / hocrPages[index].sourceHeightPx) * 100}%`,
                              border: '2px solid #f39c12',
                              backgroundColor: 'rgba(243, 156, 18, 0.18)',
                              boxSizing: 'border-box',
                              pointerEvents: 'none',
                              zIndex: 2,
                            }}
                          />
                        )}
                      {hocrPages[index].words.map((word, wordIndex) => (
                        (() => {
                          const sourceWidthPx = hocrPages[index]?.sourceWidthPx;
                          const scale = sourceWidthPx && pageWidth ? pageWidth / sourceWidthPx : null;

                          return (
                        <span
                          // eslint-disable-next-line react/no-array-index-key
                          key={`hocr_${index + 1}_${wordIndex}`}
                          className={styles.hocrWord}
                          style={{
                            left: scale ? `${word.leftPx * scale}px` : `${word.leftPct}%`,
                            top: scale ? `${word.topPx * scale}px` : `${word.topPct}%`,
                            width: scale ? `${word.widthPx * scale}px` : `${word.widthPct}%`,
                            height: scale ? `${word.heightPx * scale}px` : `${word.heightPct}%`,
                            fontSize: scale
                              ? `${Math.max(word.heightPx * scale, 6)}px`
                              : `${Math.max(word.heightPct, 0.6)}%`,
                          }}
                        >
                          {word.text}
                        </span>
                          );
                        })()
                      ))}
                    </div>
                  )}
                </div>
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
  hocrUrl: PropTypes.string,
  initialPageIndex: PropTypes.number,
  focusRegion: PropTypes.string,
  focusToken: PropTypes.number,
  enableTextLayer: PropTypes.bool,
  enableAnnotationLayer: PropTypes.bool,
};

PdfViewer.defaultProps = {
  hocrUrl: null,
  initialPageIndex: null,
  focusRegion: null,
  focusToken: 0,
  enableTextLayer: false,
  enableAnnotationLayer: false,
};

export default PdfViewer;