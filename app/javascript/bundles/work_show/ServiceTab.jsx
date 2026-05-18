import React from 'react';
import PropTypes from 'prop-types';

import CollapsibleGroup from './CollapsibleGroup';
import MemberTable from './MemberTable';
import { groupServiceMembers, isRepresentativeThumbnail } from './file_grouping';

const ServiceTab = ({ members }) => {
  if (members.length === 0) return <p>No service files are attached to this work.</p>;

  const representativeThumbnailMembers = members.filter(isRepresentativeThumbnail);
  const nonRepresentativeMembers = members.filter((member) => !isRepresentativeThumbnail(member));
  const groups = groupServiceMembers(nonRepresentativeMembers);

  return (
    <>
      {representativeThumbnailMembers.length > 0 && (
        <CollapsibleGroup label="Representative Thumbnail" count={representativeThumbnailMembers.length}>
          <MemberTable members={representativeThumbnailMembers} />
        </CollapsibleGroup>
      )}
      {groups.map((group) => (
        <CollapsibleGroup key={group.label} label={group.label} count={group.members.length}>
          <MemberTable members={group.members} />
        </CollapsibleGroup>
      ))}
    </>
  );
};

ServiceTab.propTypes = { members: PropTypes.arrayOf(PropTypes.object).isRequired };

export default ServiceTab;
