import React from 'react';
import PropTypes from 'prop-types';

import FilePanelGroup from './FilePanelGroup';
import FilePanelTable from './FilePanelTable';
import { groupServiceMembers, isRepresentativeThumbnail } from '../utils';

const hocrSiblingForPdf = (pdfMember, members) => {
  if (!pdfMember?.hocrUrl) return null;

  return members.find((member) => (
    member.id !== pdfMember.id
      && member.downloadUrl
      && member.downloadUrl === pdfMember.hocrUrl
  )) || null;
};

const FilePanelServiceTab = ({ members, originalMembers }) => {
  if (members.length === 0) return <p>No service files are attached to this work.</p>;

  const sortedByLabel = (items) => [...items].sort((a, b) => {
    const aLabel = (a?.label || '').toString();
    const bLabel = (b?.label || '').toString();
    return aLabel.localeCompare(bLabel);
  });

  const representativeThumbnailMembers = members.filter(isRepresentativeThumbnail);
  const nonRepresentativeMembers = members.filter((member) => !isRepresentativeThumbnail(member));
  const readingModePdfMember = nonRepresentativeMembers.find((member) => member.isReadingModePdf);
  const readingModeHocrMember = hocrSiblingForPdf(readingModePdfMember, nonRepresentativeMembers);
  const readingModeMemberIds = new Set(
    [readingModePdfMember?.id, readingModeHocrMember?.id].filter(Boolean),
  );
  const remainingServiceMembers = nonRepresentativeMembers
    .filter((member) => !readingModeMemberIds.has(member.id));
  const ungroupedMembers = sortedByLabel(remainingServiceMembers.filter((member) => {
    const sourceId = (member?.sourceFileSetId || '').toString().trim();
    return sourceId.length === 0;
  }));
  const groupedServiceMembers = remainingServiceMembers.filter((member) => {
    const sourceId = (member?.sourceFileSetId || '').toString().trim();
    return sourceId.length > 0;
  });
  const groups = groupServiceMembers(groupedServiceMembers, originalMembers);

  return (
    <>
      {ungroupedMembers.length > 0 && (
        <FilePanelTable members={ungroupedMembers} />
      )}
      {representativeThumbnailMembers.length > 0 && (
        <FilePanelGroup label="Representative Thumbnail" count={representativeThumbnailMembers.length}>
          <FilePanelTable members={representativeThumbnailMembers} />
        </FilePanelGroup>
      )}
      {readingModePdfMember && (
        <FilePanelGroup
          label="Reading Mode PDF"
          count={readingModeHocrMember ? 2 : 1}
        >
          <FilePanelTable members={readingModeHocrMember ? [readingModePdfMember, readingModeHocrMember] : [readingModePdfMember]} />
        </FilePanelGroup>
      )}
      {groups.map((group) => (
        <FilePanelGroup key={group.label} label={group.label} count={group.members.length}>
          <FilePanelTable members={group.members} />
        </FilePanelGroup>
      ))}
    </>
  );
};

FilePanelServiceTab.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  originalMembers: PropTypes.arrayOf(PropTypes.object),
};

FilePanelServiceTab.defaultProps = {
  originalMembers: [],
};

export default FilePanelServiceTab;
