/**
 * Kagi catalog -> pi models, and pi thinking levels -> Kagi reasoning_effort.
 */
export const KAGI_PROVIDER_ID = "kagi";
export const KAGI_API_ID = "kagi-assistant";
export const PI_LEVELS = ["minimal", "low", "medium", "high", "xhigh", "max"];

/**
 * pi level -> Kagi effort. Levels the model does not offer are null, so pi hides
 * them and clamps requests to the nearest supported level. "off" maps to Kagi's
 * "none" when the model has it.
 */
export function buildThinkingLevelMap(options) {
  const opts = Array.isArray(options) ? options : [];
  const map = { off: opts.includes("none") ? "none" : null };
  for (const level of PI_LEVELS) map[level] = opts.includes(level) ? level : null;
  return map;
}

/** True when the model has at least one effort besides "none". */
export function hasEffortControl(options) {
  return Array.isArray(options) && options.some((o) => o !== "none");
}

/**
 * Map one /api/init catalog entry to a pi model, or null when the account cannot
 * use it. Kagi publishes no token rates: costs come from each turn's cost_usd.
 */
export function mapCatalogModel(m, { hasUnlimitedAccess = false } = {}) {
  if (!m || typeof m.id !== "string" || !m.id) return null;
  if (m.supported === false || m.retired === true) return null;
  if (m.access_level && m.access_level !== "standard" && !hasUnlimitedAccess) return null;
  const options = m.parameters?.reasoning_effort?.options;
  const reasoning = hasEffortControl(options);
  const model = {
    id: m.id,
    name: m.display_name || m.id,
    api: KAGI_API_ID,
    reasoning,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: Number(m.context_window) > 0 ? Number(m.context_window) : 128000,
    maxTokens: 32768,
  };
  if (reasoning) model.thinkingLevelMap = buildThinkingLevelMap(options);
  return model;
}

/** Usable models (deduplicated by id) plus per-model Kagi metadata. */
export function mapCatalog(init) {
  const hasUnlimitedAccess = Boolean(init?.has_unlimited_access);
  const models = [];
  const meta = new Map();
  for (const m of init?.models?.models ?? []) {
    const model = mapCatalogModel(m, { hasUnlimitedAccess });
    if (!model || meta.has(model.id)) continue;
    models.push(model);
    meta.set(model.id, { requiresSearch: Boolean(m.requires_search), thinkingLevelMap: model.thinkingLevelMap ?? null });
  }
  return { models, meta };
}

/**
 * Effort to send. `level` is pi's requested level (undefined means "off").
 * A reasoning model always gets an explicit effort so the server's default
 * (often the most expensive) never applies silently.
 */
export function resolveEffort(map, level) {
  if (!map) return undefined;
  if (level && map[level]) return map[level];
  if (!level && map.off) return map.off;
  for (const l of ["off", ...PI_LEVELS]) if (map[l]) return map[l];
  return undefined;
}
