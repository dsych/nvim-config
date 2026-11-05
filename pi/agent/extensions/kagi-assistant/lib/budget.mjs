/**
 * Per-conversation spend cap in USD, fed by server-reported turn costs.
 */
export const DEFAULT_BUDGET_USD = 3;

export function formatUsd(v) {
  const n = Number(v) || 0;
  return `$${n < 0.01 && n > 0 ? n.toFixed(4) : n.toFixed(2)}`;
}

function validLimit(v) {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : DEFAULT_BUDGET_USD;
}

export class KagiBudget {
  constructor(limitUsd = DEFAULT_BUDGET_USD) {
    this.limitUsd = validLimit(limitUsd);
    this.spentUsd = 0;
    this.warned80 = false;
    this.warnedCap = false;
  }

  get limit() {
    return this.limitUsd;
  }

  /** Checked before a request is sent: "blocked" means nothing is sent. */
  gate() {
    return this.spentUsd >= this.limitUsd ? "blocked" : "ok";
  }

  #sync() {
    this.warned80 = this.spentUsd >= this.limitUsd * 0.8;
    this.warnedCap = this.spentUsd >= this.limitUsd;
  }

  /** Add a turn's cost; returns notifications to show (each threshold once). */
  record(costUsd) {
    const messages = [];
    this.spentUsd += Math.max(0, Number(costUsd) || 0);
    if (!this.warned80 && this.spentUsd >= this.limitUsd * 0.8 && this.spentUsd < this.limitUsd) {
      this.warned80 = true;
      messages.push({
        level: "warning",
        text: `Kagi Assistant: ${formatUsd(this.spentUsd)} of the ${formatUsd(this.limitUsd)} conversation cap spent.`,
      });
    }
    if (!this.warnedCap && this.spentUsd >= this.limitUsd) {
      this.warned80 = true;
      this.warnedCap = true;
      messages.push({
        level: "error",
        text: `Kagi Assistant: conversation cap reached (${formatUsd(this.spentUsd)} of ${formatUsd(this.limitUsd)}). Raise it with /kagi-budget <usd>.`,
      });
    }
    return messages;
  }

  /** Resume a session that already spent `spentUsd` (warnings already shown). */
  seed(spentUsd) {
    this.spentUsd = Math.max(0, Number(spentUsd) || 0);
    this.#sync();
  }

  setLimit(limitUsd) {
    this.limitUsd = validLimit(limitUsd);
    this.#sync();
  }
}
