import React from 'react';
import PropTypes from 'prop-types';

import * as styles from './FilePanel.module.css';

const FilePanelRow = ({ member, onViewMember, showViewColumn }) => {
  const hasInlineAction = Boolean(onViewMember);
  const rowThumbnailUrl = member.rowThumbnailUrl || member.thumbnailUrl || (member.isImage ? member.downloadUrl : null);

  return (
    <tr>
      {showViewColumn && (
        <td className={styles.cellView}>
          {hasInlineAction ? (
            <button
              type="button"
              className={`btn btn-xs btn-default ${styles.viewButton}`}
              onClick={(event) => {
                event.preventDefault();
                event.stopPropagation();

                onViewMember(member);
              }}
              title={`View ${member.label}`}
              aria-label={`View ${member.label}`}
            >
              <span className="glyphicon glyphicon-eye-open" aria-hidden="true" />
              {' '}
              View
            </button>
          ) : (
            <a href={member.showUrl} className={`btn btn-xs btn-default ${styles.viewButton}`}>View</a>
          )}
        </td>
      )}
      <td className={styles.cellThumbnail}>
        {rowThumbnailUrl ? (
          <img
            src={rowThumbnailUrl}
            alt=""
            className={styles.rowThumbnail}
            width="48"
            height="48"
            style={{ width: '48px', height: '48px' }}
            loading="lazy"
            decoding="async"
          />
        ) : null}
      </td>
      <td className={styles.cellTitle}>
        <a href={member.showUrl}>{member.label}</a>
      </td>
      <td className={styles.cellDate}>{member.dateUploaded}</td>
      <td className={styles.cellDownload}>
        <a href={member.downloadUrl} data-turbo="false" data-turbolinks="false" download={member.label}>Download</a>
        {member.editUrl && <>{' '}<a href={member.editUrl}>Edit</a></>}
      </td>
    </tr>
  );
};

FilePanelRow.propTypes = {
  member: PropTypes.shape({
    id: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    dateUploaded: PropTypes.string,
    isAv: PropTypes.bool,
    isPdf: PropTypes.bool,
    isImage: PropTypes.bool,
    canvasId: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    pdfUrl: PropTypes.string,
    hocrUrl: PropTypes.string,
    isRepresentativeThumbnail: PropTypes.bool,
    rowThumbnailUrl: PropTypes.string,
    thumbnailUrl: PropTypes.string.isRequired,
    showUrl: PropTypes.string.isRequired,
    downloadUrl: PropTypes.string.isRequired,
    editUrl: PropTypes.string,
  }).isRequired,
  onViewMember: PropTypes.func,
  showViewColumn: PropTypes.bool,
};

FilePanelRow.defaultProps = {
  onViewMember: undefined,
  showViewColumn: true,
};

export default FilePanelRow;