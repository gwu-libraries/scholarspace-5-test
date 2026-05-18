import React from 'react';
import PropTypes from 'prop-types';

import { isImageMember } from './file_grouping';

const MemberRow = ({ member, onPlayCanvas, onSelectPdf, onSelectImage }) => {
  const memberIsImage = isImageMember(member);
  const hasInlineAction = (member.isAv && onPlayCanvas) || (member.isPdf && onSelectPdf) || (memberIsImage && onSelectImage);
  const actionLabel = member.isPdf || memberIsImage ? 'View' : 'Play';
  const iconClass = member.isPdf ? 'glyphicon-file' : (memberIsImage ? 'glyphicon-picture' : 'glyphicon-play');

  return (
    <tr>
      <td>
        {hasInlineAction ? (
          <>
            <button
              type="button"
              className="btn btn-xs btn-default"
              style={{ marginRight: '8px' }}
              onClick={() => {
                if (member.isAv && onPlayCanvas) onPlayCanvas(member.id);
                if (member.isPdf && onSelectPdf) onSelectPdf(member);
                if (memberIsImage && onSelectImage) onSelectImage(member);
              }}
              title={`${actionLabel} ${member.label}`}
              aria-label={`${actionLabel} ${member.label}`}
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
        {hasInlineAction && (
          <>
            <a href={member.showUrl} style={{ marginRight: '8px' }}>View file set</a>
          </>
        )}
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
    pdfUrl: PropTypes.string,
    hocrUrl: PropTypes.string,
    isRepresentativeThumbnail: PropTypes.bool,
    showUrl: PropTypes.string.isRequired,
    downloadUrl: PropTypes.string.isRequired,
    editUrl: PropTypes.string,
  }).isRequired,
  onPlayCanvas: PropTypes.func,
  onSelectPdf: PropTypes.func,
  onSelectImage: PropTypes.func,
};

MemberRow.defaultProps = {
  onPlayCanvas: undefined,
  onSelectPdf: undefined,
  onSelectImage: undefined,
};

export default MemberRow;
