/** Browser storage helpers that tolerate stale or corrupt saved data. */

/**
 * Reads a saved value. Objects are merged over the fallback so new fields get defaults;
 * anything whose shape doesn't match the fallback (array vs object) is ignored.
 */
export function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    const saved = JSON.parse(raw) as unknown;
    if (Array.isArray(fallback)) return (Array.isArray(saved) ? saved : fallback) as T;
    if (saved && typeof saved === "object" && !Array.isArray(saved)) return { ...fallback, ...(saved as object) } as T;
    return fallback;
  } catch {
    return fallback;
  }
}
