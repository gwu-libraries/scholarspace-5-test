import React from 'react';
import PropTypes from 'prop-types';
import OriginalTab from './OriginalTab';
import ServiceTab from './ServiceTab';

const WorkItemsTabs = ({ originalMembers, serviceMembers, canViewServiceFiles, onViewMember, onViewReadingMode }) => (
  <div>
    <iframe name="work-show-download" title="work-show-download" style={{ display: 'none' }} />
    <OriginalTab members={originalMembers} onViewMember={onViewMember} onViewReadingMode={onViewReadingMode} />
    {canViewServiceFiles && <ServiceTab members={serviceMembers} />}
  </div>
);

WorkItemsTabs.propTypes = {
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
  onViewMember: PropTypes.func,
  onViewReadingMode: PropTypes.func,
};

WorkItemsTabs.defaultProps = {
  onViewMember: undefined,
  onViewReadingMode: undefined,
};

export default WorkItemsTabs;