import React from 'react';
import PropTypes from 'prop-types';

import FilePanelGroup from './FilePanelGroup';
import FilePanelTable from './FilePanelTable';
import { isAudioVisualMember, isImageMember } from '../utils';
import * as styles from './FilePanel.module.css';

const normalizeLabel = (value) => {
  const label = (value || '').trim();
  return label.length > 0 ? label : 'Untitled File';
};

const byLabel = (a, b) => normalizeLabel(a?.label).localeCompare(normalizeLabel(b?.label));

const originalTypeLabel = (member) => {
  if (!member) return 'Other';
  if (isAudioVisualMember(member)) return 'Audio / Video';
  if (member.isPdf) return 'PDFs';
  if (isImageMember(member)) return 'Images';
  return 'Other';
};

const READING_MODE_GROUP_ID = '__reading_mode_pdf__';
const READING_MODE_FILENAME_PREFIX = 'reading_mode_pdf';
const REPRESENTATIVE_THUMBNAIL_FILENAME_FRAGMENT = 'representative_thumbnail';

const readingModeMember = (member) => {
  const label = (member?.label || '').toLowerCase();
  return label.startsWith(READING_MODE_FILENAME_PREFIX);
};

const representativeThumbnailMember = (member) => {
  const label = (member?.label || '').toLowerCase();
  return Boolean(member?.isRepresentativeThumbnail) || label.includes(REPRESENTATIVE_THUMBNAIL_FILENAME_FRAGMENT);
};

const hocrSiblingForPdf = (pdfMember, members) => {
  if (!pdfMember?.hocrUrl) return null;

  return members.find((member) => (
    member.id !== pdfMember.id
      && member.downloadUrl
      && member.downloadUrl === pdfMember.hocrUrl
  )) || null;
};

const FilePanelServiceTab = ({ members, originalMembers, onViewReadingMode }) => {
  if (members.length === 0) return <p>No service files are attached to this work.</p>;

  const representativeThumbnailMembers = members.filter((member) => representativeThumbnailMember(member));
  const nonRepresentativeMembers = members.filter((member) => !representativeThumbnailMember(member));
  const readingModePdfMember = nonRepresentativeMembers.find((member) => member.isReadingModePdf);
  const readingModeHocrMember = hocrSiblingForPdf(readingModePdfMember, nonRepresentativeMembers);
  const standaloneMemberIds = new Set([
    ...representativeThumbnailMembers.map((member) => member.id),
    readingModePdfMember?.id,
    readingModeHocrMember?.id,
  ].filter(Boolean));

  const groupedCandidates = members.filter((member) => !standaloneMemberIds.has(member.id));
  const readingModeFilenameMembers = groupedCandidates.filter((member) => readingModeMember(member)).sort(byLabel);
  const nonReadingModeGroupedCandidates = groupedCandidates.filter((member) => !readingModeMember(member));

  const originalById = new Map(
    originalMembers.map((member) => [String(member.id), member]),
  );

  const linkedBySourceId = new Map();
  const unlinkedMembers = [];

  nonReadingModeGroupedCandidates.forEach((member) => {
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
    .sort((a, b) => (
      a.sourceLabel.localeCompare(b.sourceLabel) || a.typeLabel.localeCompare(b.typeLabel)
    ));

  const readingModeMembers = [
    readingModePdfMember,
    readingModeHocrMember,
    ...readingModeFilenameMembers,
  ].filter(Boolean);

  const uniqueReadingModeMembers = Array.from(
    new Map(readingModeMembers.map((member) => [member.id, member])).values(),
  ).sort(byLabel);

  const workLevelGroups = [
    representativeThumbnailMembers.length > 0 && {
      sourceId: 'representative-thumbnail',
      sourceLabel: 'Representative Thumbnail',
      members: representativeThumbnailMembers.sort(byLabel),
    },
    uniqueReadingModeMembers.length > 0 && {
      sourceId: READING_MODE_GROUP_ID,
      sourceLabel: 'Reading Mode PDF',
      members: uniqueReadingModeMembers,
    },
  ].filter(Boolean);
  const sortedUnlinkedMembers = [...unlinkedMembers].sort(byLabel);
  const filesetLevelCount = sourceGroups.reduce((sum, group) => sum + group.members.length, 0) + sortedUnlinkedMembers.length;
  const workLevelCount = workLevelGroups.reduce((sum, group) => sum + group.members.length, 0);

  return (
    <>
      {workLevelGroups.length > 0 && (
        <FilePanelGroup label="Work Level Service Files" count={workLevelCount} defaultOpen={false}>
          {workLevelGroups.map((sourceGroup) => (
            <FilePanelGroup
              key={sourceGroup.sourceId}
              label={sourceGroup.sourceLabel}
              count={sourceGroup.members.length}
              defaultOpen={sourceGroup.sourceId === READING_MODE_GROUP_ID ? true : false}
            >
              {sourceGroup.sourceId === READING_MODE_GROUP_ID && onViewReadingMode && (
                <div className={styles.groupInlineAction}>
                  <button
                    type="button"
                    className={`btn btn-sm btn-default ${styles.readingModeButton}`}
                    onClick={onViewReadingMode}
                  >
                    View in reading mode
                  </button>
                </div>
              )}
              <FilePanelTable showViewColumn={false} members={sourceGroup.members} />
            </FilePanelGroup>
          ))}
        </FilePanelGroup>
      )}
      {filesetLevelCount > 0 && (
        <FilePanelGroup label="Fileset Level Service Files" count={filesetLevelCount} defaultOpen={false}>
          {sourceGroups.map((sourceGroup) => (
            <FilePanelGroup
              key={sourceGroup.sourceId}
              label={sourceGroup.sourceLabel}
              count={sourceGroup.members.length}
              defaultOpen={false}
            >
              <FilePanelTable showViewColumn={false} members={sourceGroup.members} />
            </FilePanelGroup>
          ))}
          {sortedUnlinkedMembers.length > 0 && (
            <FilePanelGroup label="Unlinked Service Files" count={sortedUnlinkedMembers.length} defaultOpen={false}>
              <FilePanelTable showViewColumn={false} members={sortedUnlinkedMembers} />
            </FilePanelGroup>
          )}
        </FilePanelGroup>
      )}
    </>
  );
};

FilePanelServiceTab.propTypes = {
  members: PropTypes.arrayOf(PropTypes.object).isRequired,
  originalMembers: PropTypes.arrayOf(PropTypes.object),
  onViewReadingMode: PropTypes.func,
};

FilePanelServiceTab.defaultProps = {
  originalMembers: [],
  onViewReadingMode: undefined,
};

export default FilePanelServiceTab;