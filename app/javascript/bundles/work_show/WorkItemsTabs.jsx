import React, { useState } from 'react';
import PropTypes from 'prop-types';

const FILE_GROUPS = [
  { label: 'hOCR Files',        test: (name) => name.endsWith('.hocr') },
  { label: 'PDF Derivatives',   test: (name) => name.endsWith('.pdf') },
  { label: 'Transcripts',       test: (name) => name.endsWith('.vtt') },
  { label: 'Image Derivatives', test: (name) => ['.jpg','.jpeg','.png','.tif','.tiff','.gif','.webp'].includes(name.match(/\.[^.]+$/)?.[0] ?? '') },
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

const MemberRow = ({ member }) => (
  <tr>
    <td><a href={member.downloadUrl}>{member.label}</a></td>
    <td>{member.dateUploaded}</td>
    <td>
      <a href={member.downloadUrl}>Download</a>
      {member.editUrl && <>{' '}<a href={member.editUrl}>Edit</a></>}
    </td>
  </tr>
);

MemberRow.propTypes = {
  member: PropTypes.shape({
    id: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    dateUploaded: PropTypes.string,
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
  const groups = groupServiceMembers(members);
  return (
    <>
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