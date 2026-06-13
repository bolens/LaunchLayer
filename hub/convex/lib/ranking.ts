/** Shared ranking for hub config recommendations. */
export type RankedConfigRow = {
  similarity: number;
  published_at: number;
  downloads: number;
};

/** Similarity first, then newest publish, then downloads. */
export function compareRankedConfigRows(
  a: RankedConfigRow,
  b: RankedConfigRow,
): number {
  if (b.similarity !== a.similarity) {
    return b.similarity - a.similarity;
  }
  if (b.published_at !== a.published_at) {
    return b.published_at - a.published_at;
  }
  return b.downloads - a.downloads;
}

export function rankConfigRecommendations<T extends RankedConfigRow>(
  rows: Iterable<T>,
  limit = 10,
): T[] {
  return [...rows]
    .filter((row) => row.similarity > 0)
    .sort(compareRankedConfigRows)
    .slice(0, limit);
}
