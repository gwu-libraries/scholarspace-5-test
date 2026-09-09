import React from 'react';
import PropTypes from 'prop-types';

import FilePanelTabs from './file-panel/FilePanelTabs';

const WorkShow = ({ title, descriptions, originalMembers, serviceMembers, canViewServiceFiles }) => {
  const safeDescriptions = descriptions || [];

  return (
    <div>
      <h1>Title: {title}</h1>

      {safeDescriptions.map((desc, i) => (
        <p key={i}>
          Description: <span dangerouslySetInnerHTML={{ __html: desc }} />
        </p>
      ))}

      <FilePanelTabs
        originalMembers={originalMembers}
        serviceMembers={serviceMembers}
        canViewServiceFiles={canViewServiceFiles}
      />
    </div>
  );
};

WorkShow.propTypes = {
  title:        PropTypes.string.isRequired,
  descriptions: PropTypes.arrayOf(PropTypes.string),
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
};

WorkShow.defaultProps = {
  descriptions: [],
};

export default WorkShow;