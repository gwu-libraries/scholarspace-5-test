import React from 'react';
import PropTypes from 'prop-types';

import FilePanelRow from './FilePanelRow';
import * as styles from './FilePanel.module.css';

const FilePanelTable = ({ members, onViewMember, showViewColumn }) => (
  <table className={`table table-sm ${styles.fileTable}`}>
    <thead>
      <tr>
        {showViewColumn && <th>View</th>}
        <th>Thumbnail</th>
        <th>Title</th>
        <th>Date Uploaded</th>
        <th>Download</th>
      </tr>
    </thead>
    <tbody>
      {members.map((member) => (
        <FilePanelRow
          key={member.id}
          member={member}
          onViewMember={onViewMember}
          showViewColumn={showViewColumn}
        />
      ))}
    </tbody>
  </table>
);

FilePanelTable.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onViewMember: PropTypes.func,
  showViewColumn: PropTypes.bool,
};

FilePanelTable.defaultProps = {
  onViewMember: undefined,
  showViewColumn: true,
};

export default FilePanelTable;