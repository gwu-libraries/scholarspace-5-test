import React from 'react';
import PropTypes from 'prop-types';

import FilePanelRow from './FilePanelRow';

const FilePanelTable = ({ members, onViewMember }) => (
  <table className="table table-sm">
    <thead>
      <tr>
        <th>Title</th>
        <th>Date Uploaded</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {members.map((member) => (
        <FilePanelRow
          key={member.id}
          member={member}
          onViewMember={onViewMember}
        />
      ))}
    </tbody>
  </table>
);

FilePanelTable.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onViewMember: PropTypes.func,
};

FilePanelTable.defaultProps = {
  onViewMember: undefined,
};

export default FilePanelTable;
