import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * /rename [name] — rename the currently open session.
 *
 *  - `/rename <name>` sets the session display name directly.
 *  - `/rename` with no argument prompts for a new name (current name shown as placeholder).
 *
 * Uses pi.setSessionName(), the same mechanism as the built-in /name, so the name is
 * persisted to the session file and shown in /resume.
 */

export default function (pi: ExtensionAPI) {
  pi.registerCommand("rename", {
    description: "Rename the current session (/rename <name>, or prompt if omitted)",
    handler: async (args, ctx) => {
      const current = pi.getSessionName();
      let name = args.trim();

      if (!name) {
        if (!ctx.hasUI) {
          ctx.ui.notify("Usage: /rename <name>", "info");
          return;
        }
        const input = await ctx.ui.input("Rename session", current ?? "New session name");
        name = (input ?? "").trim();
        if (!name) {
          ctx.ui.notify("Rename cancelled", "info");
          return;
        }
      }

      if (name === current) {
        ctx.ui.notify(`Session already named: ${name}`, "info");
        return;
      }

      pi.setSessionName(name);
      ctx.ui.notify(current ? `Renamed session: ${current} → ${name}` : `Session named: ${name}`, "info");
    },
  });
}
