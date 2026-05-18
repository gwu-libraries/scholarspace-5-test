import React from 'react';
import PropTypes from 'prop-types';

import CollapsibleGroup from './CollapsibleGroup';
import MemberTable from './MemberTable';
import { groupOriginalMembers } from './file_grouping';

const OriginalTab = ({ members, onPlayCanvas, onSelectPdf, onSelectImage, onViewReadingMode }) => {
  if (members.length === 0) return <p>No original files are attached to this work.</p>;

  const groups = groupOriginalMembers(members);

  return (
    <>
      {groups.map((group) => (
        <CollapsibleGroup
          key={group.label}
          label={group.label}
          count={group.members.length}
          headerActions={group.label === 'Images' && onViewReadingMode ? (
            <button
              type="button"
              className="btn btn-xs btn-default"
              onClick={onViewReadingMode}
            >
              View in reading mode
            </button>
          ) : null}
        >
          <MemberTable
            members={group.members}
            onPlayCanvas={onPlayCanvas}
            onSelectPdf={onSelectPdf}
            onSelectImage={onSelectImage}
          />
        </CollapsibleGroup>
      ))}
    </>
  );
};

OriginalTab.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onPlayCanvas: PropTypes.func,
  onSelectPdf: PropTypes.func,
  onSelectImage: PropTypes.func,
  onViewReadingMode: PropTypes.func,
};

OriginalTab.defaultProps = {
  onPlayCanvas: undefined,
  onSelectPdf: undefined,
  onSelectImage: undefined,
  onViewReadingMode: undefined,
};

export default OriginalTab;
