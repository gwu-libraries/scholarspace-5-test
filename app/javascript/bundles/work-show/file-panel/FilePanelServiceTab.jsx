import React from 'react';
import PropTypes from 'prop-types';

import FilePanelGroup from './FilePanelGroup';
import FilePanelTable from './FilePanelTable';
import { isAvMember, isImageMember } from '../utils';

const normalizeLabel = (value) => {
  const label = (value || '').trim();
  return label.length > 0 ? label : 'Untitled File';
};

const byLabel = (a, b) => normalizeLabel(a?.label).localeCompare(normalizeLabel(b?.label));

const originalTypeLabel = (member) => {
  if (!member) return 'Other';
  if (isAvMember(member)) return 'Audio / Video';
  if (member.isPdf) return 'PDFs';
  if (isImageMember(member)) return 'Images';
  return 'Other';
};

const typeSortOrder = ['Audio / Video', 'PDFs', 'Images', 'Other'];
const READING_MODE_GROUP_ID = '__reading_mode_pdf__';

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

  const representativeThumbnailMembers = members.filter((member) => Boolean(member?.isRepresentativeThumbnail));
  const nonRepresentativeMembers = members.filter((member) => !member?.isRepresentativeThumbnail);
  const readingModePdfMember = nonRepresentativeMembers.find((member) => member.isReadingModePdf);
  const readingModeHocrMember = hocrSiblingForPdf(readingModePdfMember, nonRepresentativeMembers);
  const standaloneMemberIds = new Set([
    ...representativeThumbnailMembers.map((member) => member.id),
    readingModePdfMember?.id,
    readingModeHocrMember?.id,
  ].filter(Boolean));

  const groupedCandidates = members.filter((member) => !standaloneMemberIds.has(member.id));

  const originalById = new Map(
    originalMembers.map((member) => [String(member.id), member]),
  );

  const linkedBySourceId = new Map();
  const unlinkedMembers = [];

  groupedCandidates.forEach((member) => {
    const sourceId = (member?.sourceFileSetId || '').toString().trim();

    if (!sourceId || !originalById.has(sourceId)) {
      unlinkedMembers.push(member);
      return;
    }

    if (!linkedBySourceId.has(sourceId)) linkedBySourceId.set(sourceId, []);
    linkedBySourceId.get(sourceId).push(member);
  });

  const sourceGroups = Array.from(linkedBySourceId.entries())
    .map(([sourceId, serviceSiblings]) => {
      const original = originalById.get(sourceId);
      return {
        sourceId,
        sourceLabel: normalizeLabel(original?.label),
        typeLabel: originalTypeLabel(original),
        members: [...serviceSiblings].sort(byLabel),
      };
    })
    .sort((a, b) => a.sourceLabel.localeCompare(b.sourceLabel));

  const groupedByType = sourceGroups.reduce((map, group) => {
    if (!map.has(group.typeLabel)) map.set(group.typeLabel, []);
    map.get(group.typeLabel).push(group);
    return map;
  }, new Map());

  if (readingModePdfMember) {
    if (!groupedByType.has('Images')) groupedByType.set('Images', []);

    groupedByType.get('Images').unshift({
      sourceId: READING_MODE_GROUP_ID,
      sourceLabel: 'Reading Mode PDF',
      typeLabel: 'Images',
      members: readingModeHocrMember ? [readingModePdfMember, readingModeHocrMember] : [readingModePdfMember],
    });
  }

  const typeGroups = Array.from(groupedByType.entries())
    .map(([typeLabel, sourceFileGroups]) => ({
      typeLabel,
      sourceFileGroups,
      groupCount: sourceFileGroups.length,
    }))
    .sort((a, b) => typeSortOrder.indexOf(a.typeLabel) - typeSortOrder.indexOf(b.typeLabel));

  const sortedUnlinkedMembers = [...unlinkedMembers].sort(byLabel);

  return (
    <>
      {representativeThumbnailMembers.length > 0 && (
        <FilePanelGroup label="Representative Thumbnail" count={representativeThumbnailMembers.length} defaultOpen={false}>
          <FilePanelTable showViewColumn={false} members={representativeThumbnailMembers} />
        </FilePanelGroup>
      )}
      {typeGroups.map((typeGroup) => (
        <FilePanelGroup
          key={typeGroup.typeLabel}
          label={typeGroup.typeLabel}
          count={typeGroup.groupCount}
          defaultOpen={false}
        >
          {typeGroup.sourceFileGroups.map((sourceGroup) => (
            <FilePanelGroup
              key={sourceGroup.sourceId}
              label={sourceGroup.sourceLabel}
              count={sourceGroup.members.length}
              defaultOpen={sourceGroup.sourceId === READING_MODE_GROUP_ID ? true : false}
            >
              <FilePanelTable showViewColumn={false} members={sourceGroup.members} />
            </FilePanelGroup>
          ))}
        </FilePanelGroup>
      ))}
      {sortedUnlinkedMembers.length > 0 && (
        <FilePanelGroup label="Unlinked Service Files" count={sortedUnlinkedMembers.length} defaultOpen={false}>
          <FilePanelTable showViewColumn={false} members={sortedUnlinkedMembers} />
        </FilePanelGroup>
      )}
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
