import React from 'react';
import PropTypes from 'prop-types';

import MemberRow from './MemberRow';

const MemberTable = ({ members, onViewMember }) => (
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
        <MemberRow
          key={member.id}
          member={member}
          onViewMember={onViewMember}
        />
      ))}
    </tbody>
  </table>
);

MemberTable.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onViewMember: PropTypes.func,
};

MemberTable.defaultProps = {
  onViewMember: undefined,
};

export default MemberTable;
