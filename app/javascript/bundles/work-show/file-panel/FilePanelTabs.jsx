import React, { useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import FilePanelOriginalTab from './FilePanelOriginalTab';
import FilePanelServiceTab from './FilePanelServiceTab';

const ORIGINAL_TAB = 'original-files';
const SERVICE_TAB = 'service-files';

const FilePanelTabs = ({ originalMembers, serviceMembers, canViewServiceFiles, onViewMember, onViewReadingMode }) => {
  const [activeTab, setActiveTab] = useState(ORIGINAL_TAB);

  useEffect(() => {
    if (!canViewServiceFiles && activeTab !== ORIGINAL_TAB) {
      setActiveTab(ORIGINAL_TAB);
    }
  }, [canViewServiceFiles, activeTab]);

  const showServiceFiles = canViewServiceFiles && activeTab === SERVICE_TAB;

  return (
    <div>
      {canViewServiceFiles && (
        <div className="btn-group" role="tablist" aria-label="Work files tabs">
          <button
            type="button"
            role="tab"
            aria-selected={!showServiceFiles}
            className={`btn btn-sm ${showServiceFiles ? 'btn-default' : 'btn-primary'}`}
            onClick={() => setActiveTab(ORIGINAL_TAB)}
          >
            Original Files
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={showServiceFiles}
            className={`btn btn-sm ${showServiceFiles ? 'btn-primary' : 'btn-default'}`}
            onClick={() => setActiveTab(SERVICE_TAB)}
          >
            Service Files
          </button>
        </div>
      )}

      {showServiceFiles ? (
        <FilePanelServiceTab members={serviceMembers} originalMembers={originalMembers} />
      ) : (
        <FilePanelOriginalTab
          members={originalMembers}
          onViewMember={onViewMember}
          onViewReadingMode={onViewReadingMode}
        />
      )}
    </div>
  );
};

FilePanelTabs.propTypes = {
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
  onViewMember: PropTypes.func,
  onViewReadingMode: PropTypes.func,
};

FilePanelTabs.defaultProps = {
  onViewMember: undefined,
  onViewReadingMode: undefined,
};

export default FilePanelTabs;