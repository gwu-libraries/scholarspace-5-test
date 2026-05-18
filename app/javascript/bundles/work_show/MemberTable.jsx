import React from 'react';
import PropTypes from 'prop-types';

import MemberRow from './MemberRow';

const MemberTable = ({ members, onPlayCanvas, onSelectPdf, onSelectImage }) => (
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
          onPlayCanvas={onPlayCanvas}
          onSelectPdf={onSelectPdf}
          onSelectImage={onSelectImage}
        />
      ))}
    </tbody>
  </table>
);

MemberTable.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  onPlayCanvas: PropTypes.func,
  onSelectPdf: PropTypes.func,
  onSelectImage: PropTypes.func,
};

MemberTable.defaultProps = {
  onPlayCanvas: undefined,
  onSelectPdf: undefined,
  onSelectImage: undefined,
};

export default MemberTable;
