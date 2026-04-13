import React, { useState } from 'react';
import PropTypes from 'prop-types';

const REPRESENTATIVE_THUMBNAIL_FILENAME = 'representative_thumbnail.jpg';

const FILE_GROUPS = [
  { label: 'hOCR Files',        test: (name) => name.endsWith('.hocr') },
  { label: 'PDF Derivatives',   test: (name) => name.endsWith('.pdf') },
  { label: 'Transcripts',       test: (name) => name.endsWith('.vtt') },
  { label: 'Thumbnails', test: (name) => ['.jpg','.jpeg','.png','.tif','.tiff','.gif','.webp'].includes(name.match(/\.[^.]+$/)?.[0] ?? '') },
  { label: 'Other',             test: () => true },
];

function groupServiceMembers(members) {
  const placed = new Set();
  return FILE_GROUPS.reduce((acc, group) => {
    const matched = members.filter((m) => !placed.has(m.id) && group.test(m.label.toLowerCase()));
    matched.forEach((m) => placed.add(m.id));
    if (matched.length > 0) acc.push({ label: group.label, members: matched });
    return acc;
  }, []);
}

function isRepresentativeThumbnail(member) {
  return member.label.toLowerCase() === REPRESENTATIVE_THUMBNAIL_FILENAME;
}

const MemberRow = ({ member }) => (
  <tr>
    <td><a href={member.showUrl}>{member.label}</a></td>
    <td>{member.dateUploaded}</td>
    <td>
      <a href={member.downloadUrl} data-turbo="false" data-turbolinks="false" target="work-show-download" download={member.label}>Download</a>
      {member.editUrl && <>{' '}<a href={member.editUrl}>Edit</a></>}
    </td>
  </tr>
);

MemberRow.propTypes = {
  member: PropTypes.shape({
    id: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    dateUploaded: PropTypes.string,
    showUrl: PropTypes.string.isRequired,
    downloadUrl: PropTypes.string.isRequired,
    editUrl: PropTypes.string,
  }).isRequired,
};

const MemberTable = ({ members }) => (
  <table className="table table-sm">
    <thead>
      <tr>
        <th>Title</th>
        <th>Date Uploaded</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {members.map((m) => <MemberRow key={m.id} member={m} />)}
    </tbody>
  </table>
);

MemberTable.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
};

const OriginalTab = ({ members }) => (
  members.length === 0
    ? <p>No original files are attached to this work.</p>
    : <MemberTable members={members} />
);

OriginalTab.propTypes = { members: PropTypes.arrayOf(PropTypes.object).isRequired };

const ServiceTab = ({ members }) => {
  if (members.length === 0) return <p>No service files are attached to this work.</p>;
  const representativeThumbnailMembers = members.filter(isRepresentativeThumbnail);
  const nonRepresentativeMembers = members.filter((member) => !isRepresentativeThumbnail(member));
  const groups = groupServiceMembers(nonRepresentativeMembers);

  return (
    <>
      {representativeThumbnailMembers.length > 0 && (
        <div>
          <h5>Representative Thumbnail ({representativeThumbnailMembers.length})</h5>
          <MemberTable members={representativeThumbnailMembers} />
        </div>
      )}
      {groups.map((group) => (
        <div key={group.label}>
          <h5>{group.label} ({group.members.length})</h5>
          <MemberTable members={group.members} />
        </div>
      ))}
    </>
  );
};

ServiceTab.propTypes = { members: PropTypes.arrayOf(PropTypes.object).isRequired };

const WorkItemsTabs = ({ originalMembers, serviceMembers, canViewServiceFiles }) => {
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
      {activeTab === 'original' && <OriginalTab members={originalMembers} />}
      {activeTab === 'service' && canViewServiceFiles && <ServiceTab members={serviceMembers} />}
    </div>
  );
};

WorkItemsTabs.propTypes = {
  originalMembers:    PropTypes.arrayOf(PropTypes.object).isRequired,
  serviceMembers:      PropTypes.arrayOf(PropTypes.object).isRequired,
  canViewServiceFiles: PropTypes.bool.isRequired,
};

export default WorkItemsTabs;