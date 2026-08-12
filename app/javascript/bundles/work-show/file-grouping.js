const ORIGINAL_FILE_GROUPS = [
  { label: "Audio / Video", test: (member) => isAvMember(member) },
  { label: "PDFs", test: (member) => member.isPdf },
  { label: "Images", test: (member) => isImageMember(member) },
  { label: "Other", test: () => true },
];

const IMAGE_EXTENSIONS = [
  ".jpg",
  ".jpeg",
  ".png",
  ".gif",
  ".tif",
  ".tiff",
  ".webp",
  ".jp2",
];
const AV_EXTENSIONS = [
  ".mp3",
  ".wav",
  ".m4a",
  ".aac",
  ".flac",
  ".ogg",
  ".oga",
  ".mp4",
  ".m4v",
  ".mov",
  ".avi",
  ".mkv",
  ".webm",
  ".mpeg",
  ".mpg",
];
const READING_MODE_GROUP_KEY = "__reading_mode__";
const READING_MODE_GROUP_LABEL = "Reading Mode";
const READING_MODE_FILENAMES = new Set([
  "reading_mode_pdf.pdf",
  "reading_mode_pdf_hocr.hocr",
]);

function isAvMember(member) {
  if (member.isAv) return true;
  const label = (member.label || "").toLowerCase();
  return AV_EXTENSIONS.some((ext) => label.endsWith(ext));
}

function isImageMember(member) {
  if (member.isImage) return true;
  const label = (member.label || "").toLowerCase();
  return IMAGE_EXTENSIONS.some((ext) => label.endsWith(ext));
}

function groupByRules(members, rules, getValue) {
  const placed = new Set();

  return rules.reduce((groups, rule) => {
    const matched = members.filter(
      (member) => !placed.has(member.id) && rule.test(getValue(member)),
    );
    matched.forEach((member) => placed.add(member.id));
    if (matched.length > 0)
      groups.push({ label: rule.label, members: matched });
    return groups;
  }, []);
}

function normalizeLabel(value) {
  const label = (value || "").trim();
  return label.length > 0 ? label : "Untitled File";
}

function sortedMembers(members) {
  return [...members].sort((a, b) =>
    normalizeLabel(a.label).localeCompare(normalizeLabel(b.label)),
  );
}

function groupServiceMembers(members, originalMembers = []) {
  const originalLabelById = new Map(
    originalMembers.map((member) => [
      String(member.id),
      normalizeLabel(member.label),
    ]),
  );

  const groupedBySourceId = new Map();

  members.forEach((member) => {
    const filename = normalizeLabel(member.label).toLowerCase();
    const sourceId = READING_MODE_FILENAMES.has(filename)
      ? READING_MODE_GROUP_KEY
      : (member.sourceFileSetId || "").toString().trim();

    if (!sourceId) return;

    if (!groupedBySourceId.has(sourceId)) groupedBySourceId.set(sourceId, []);
    groupedBySourceId.get(sourceId).push(member);
  });

  return Array.from(groupedBySourceId.entries())
    .map(([sourceId, sourceMembers]) => ({
      label:
        sourceId === READING_MODE_GROUP_KEY
          ? READING_MODE_GROUP_LABEL
          : originalLabelById.get(sourceId) || `Source File ${sourceId}`,
      members: sortedMembers(sourceMembers),
    }))
    .sort((a, b) => a.label.localeCompare(b.label));
}

function groupOriginalMembers(members) {
  return groupByRules(members, ORIGINAL_FILE_GROUPS, (member) => member);
}

function isRepresentativeThumbnail(member) {
  return Boolean(member.isRepresentativeThumbnail);
}

export {
  AV_EXTENSIONS,
  IMAGE_EXTENSIONS,
  ORIGINAL_FILE_GROUPS,
  groupOriginalMembers,
  groupServiceMembers,
  isAvMember,
  isImageMember,
  isRepresentativeThumbnail,
};
