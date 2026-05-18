import React, { useState } from 'react';
import PropTypes from 'prop-types';
import OriginalTab from './OriginalTab';
import ServiceTab from './ServiceTab';

const WorkItemsTabs = ({ originalMembers, serviceMembers, canViewServiceFiles, onPlayCanvas, onSelectPdf, onSelectImage, onViewReadingMode }) => {
  const [activeTab, setActiveTab] = useState('original');

  return (
    <div>
      <div role="tablist" className="nav nav-tabs">
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === 'original'}
          className={`nav-link ${activeTab === 'original' ? 'active' : ''}`}
          onClick={() => setActiveTab('original')}
        >
          Original Files ({originalMembers.length})
        </button>
        {canViewServiceFiles && (
          <button
            type="button"
            role="tab"
            aria-selected={activeTab === 'service'}
            className={`nav-link ${activeTab === 'service' ? 'active' : ''}`}
            onClick={() => setActiveTab('service')}
          >
            Service Files ({serviceMembers.length})
          </button>
        )}
      </div>
      <iframe name="work-show-download" title="work-show-download" style={{ display: 'none' }} />
      {activeTab === 'original' && <OriginalTab members={originalMembers} onPlayCanvas={onPlayCanvas} onSelectPdf={onSelectPdf} onSelectImage={onSelectImage} onViewReadingMode={onViewReadingMode} />}
      {activeTab === 'service' && canViewServiceFiles && <ServiceTab members={serviceMembers} />}
    </div>
  );
};

WorkItemsTabs.propTypes = {
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
  onPlayCanvas: PropTypes.func,
  onSelectPdf: PropTypes.func,
  onSelectImage: PropTypes.func,
  onViewReadingMode: PropTypes.func,
};

WorkItemsTabs.defaultProps = {
  onPlayCanvas: undefined,
  onSelectPdf: undefined,
  onSelectImage: undefined,
  onViewReadingMode: undefined,
};

export default WorkItemsTabs;