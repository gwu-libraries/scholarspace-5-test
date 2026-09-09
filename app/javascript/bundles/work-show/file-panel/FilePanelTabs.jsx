import React, { useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import FilePanelOriginalTab from './FilePanelOriginalTab';
import FilePanelServiceTab from './FilePanelServiceTab';

const ORIGINAL_TAB = 'original-files';
const SERVICE_TAB = 'service-files';

function isThumbnailServiceMember(member) {
  const label = (member?.label || '').toLowerCase();
  return label.includes('_thumbnail.') || Boolean(member?.isRepresentativeThumbnail);
}

function isRepresentativeThumbnailServiceMember(member) {
  const label = (member?.label || '').toLowerCase();
  return Boolean(member?.isRepresentativeThumbnail) || label.includes('representative_thumbnail');
}

function thumbnailBySourceId(serviceMembers) {
  return serviceMembers.reduce((map, member) => {
    if (!isThumbnailServiceMember(member)) return map;
    if (isRepresentativeThumbnailServiceMember(member)) return map;

    const sourceId = (member?.sourceFileSetId || '').toString().trim();
    if (!sourceId) return map;

    if (!map.has(sourceId)) {
      map.set(sourceId, member.downloadUrl || member.thumbnailUrl || null);
    }

    return map;
  }, new Map());
}

function enrichMembersWithRowThumbnails(members, thumbMap) {
  return members.map((member) => {
    const sourceId = (member?.sourceFileSetId || '').toString().trim();
    const thumbKey = sourceId || member.id;

    return {
      ...member,
      rowThumbnailUrl: (
        thumbMap.get(thumbKey)
        || member.thumbnailUrl
        || (member.isImage ? member.downloadUrl : null)
      ),
    };
  });
}

function enrichServiceMembersWithRowThumbnails(members, thumbMap) {
  return members.map((member) => {
    const sourceId = (member?.sourceFileSetId || '').toString().trim();
    const thumbKey = sourceId || member.id;
    const isThumbnail = isThumbnailServiceMember(member);

    return {
      ...member,
      rowThumbnailUrl: isThumbnail ? (thumbMap.get(thumbKey) || member.thumbnailUrl || null) : null,
    };
  });
}

const FilePanelTabs = ({ originalMembers, serviceMembers, canViewServiceFiles, onViewMember, onViewReadingMode }) => {
  const [activeTab, setActiveTab] = useState(ORIGINAL_TAB);
  const thumbMap = thumbnailBySourceId(serviceMembers);
  const originalMembersWithThumbs = enrichMembersWithRowThumbnails(originalMembers, thumbMap);
  const serviceMembersWithThumbs = enrichServiceMembersWithRowThumbnails(serviceMembers, thumbMap);

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
        <FilePanelServiceTab
          members={serviceMembersWithThumbs}
          originalMembers={originalMembersWithThumbs}
          onViewReadingMode={onViewReadingMode}
        />
      ) : (
        <FilePanelOriginalTab
          members={originalMembersWithThumbs}
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