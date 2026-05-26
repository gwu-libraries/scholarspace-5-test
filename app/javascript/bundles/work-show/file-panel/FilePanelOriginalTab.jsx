import React from 'react';
import PropTypes from 'prop-types';

import FilePanelGroup from './FilePanelGroup';
import FilePanelTable from './FilePanelTable';
import { groupOriginalMembers } from '../utils';
import * as styles from './FilePanel.module.css';

const FilePanelOriginalTab = ({ members, onViewMember, onViewReadingMode }) => {
  if (members.length === 0) return <p>No original files are attached to this work.</p>;

  const groups = groupOriginalMembers(members);

  return (
    <>
      {groups.map((group) => (
        <FilePanelGroup
          key={group.label}
          label={group.label}
          count={group.members.length}
        >
          {group.label === 'Images' && onViewReadingMode && (
            <div className={styles.groupInlineAction}>
              <button
                type="button"
                className="btn btn-default"
                onClick={onViewReadingMode}
              >
                View in reading mode
              </button>
            </div>
          )}
          <FilePanelTable
            members={group.members}
            onViewMember={onViewMember}
          />
        </FilePanelGroup>
      ))}
    </>
  );
};

FilePanelOriginalTab.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onViewMember: PropTypes.func,
  onViewReadingMode: PropTypes.func,
};

FilePanelOriginalTab.defaultProps = {
  onViewMember: undefined,
  onViewReadingMode: undefined,
};

export default FilePanelOriginalTab;
