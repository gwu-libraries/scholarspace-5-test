const ORIGINAL_FILE_GROUPS = [
  { label: "Audio / Video", test: (member) => isAudioVisualMember(member) },
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
const AUDIO_VISUAL_EXTENSIONS = [
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

function isAudioVisualMember(member) {
  if (member.isAudioVisual) return true;
  const label = (member.label || "").toLowerCase();
  return AUDIO_VISUAL_EXTENSIONS.some((ext) => label.endsWith(ext));
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

function groupOriginalMembers(members) {
  return groupByRules(members, ORIGINAL_FILE_GROUPS, (member) => member);
}

export {
  groupOriginalMembers,
  isAudioVisualMember,
  isImageMember,
};
