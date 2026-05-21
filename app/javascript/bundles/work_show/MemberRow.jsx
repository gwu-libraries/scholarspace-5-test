import React from 'react';
import PropTypes from 'prop-types';

import { memberViewerType } from './file_grouping';

const ICON_CLASS_BY_VIEWER = {
  ramp: 'glyphicon-play',
  pdf: 'glyphicon-file',
  images: 'glyphicon-picture',
};

const MemberRow = ({ member, onViewMember }) => {
  const viewerType = memberViewerType(member);
  const hasInlineAction = Boolean(viewerType && onViewMember);
  const iconClass = ICON_CLASS_BY_VIEWER[viewerType] || 'glyphicon-eye-open';

  return (
    <tr>
      <td>
        {hasInlineAction ? (
          <>
            <button
              type="button"
              className="btn btn-xs btn-default"
              style={{ marginRight: '8px' }}
              onClick={(event) => {
                event.preventDefault();
                event.stopPropagation();

                onViewMember(member);
              }}
              title={`View ${member.label}`}
              aria-label={`View ${member.label}`}
            >
              <span className={`glyphicon ${iconClass}`} aria-hidden="true" />
            </button>
            {member.label}
          </>
        ) : (
          <a href={member.showUrl}>{member.label}</a>
        )}
      </td>
      <td>{member.dateUploaded}</td>
      <td>
        <a href={member.downloadUrl} data-turbo="false" data-turbolinks="false" target="work-show-download" download={member.label}>Download</a>
        {member.editUrl && <>{' '}<a href={member.editUrl}>Edit</a></>}
      </td>
    </tr>
  );
};

MemberRow.propTypes = {
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
    showUrl: PropTypes.string.isRequired,
    downloadUrl: PropTypes.string.isRequired,
    editUrl: PropTypes.string,
  }).isRequired,
  onViewMember: PropTypes.func,
};

MemberRow.defaultProps = {
  onViewMember: undefined,
};

export default MemberRow;
