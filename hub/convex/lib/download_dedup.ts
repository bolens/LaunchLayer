export function resolveDownloadIncrement(
  currentDownloads: number,
  alreadyRecorded: boolean,
): { shouldIncrement: boolean; nextDownloads: number } {
  if (alreadyRecorded) {
    return { shouldIncrement: false, nextDownloads: currentDownloads };
  }
  return { shouldIncrement: true, nextDownloads: currentDownloads + 1 };
}
