// ~/.config/opencode/plugins/network-watchdog.js
import { exec } from "node:child_process";

export const NetworkWatchdogPlugin = async ({ client }) => {
  let isOnline = true;
  let wasOffline = false;
  let activeSessionID = null;

  const PING_INTERVAL_MS = 5000;

  // Visual notification that doesn't enter LLM chat context
  function notifyUser(title, message, variant = "info") {
    // 1. Try OpenCode's native TUI Toast (UI overlay only, excluded from LLM history)
    if (client.tui?.showToast) {
      try {
        client.tui.showToast({
          body: { title, message, variant },
        });
        return;
      } catch {
        // Fall back to OS notification if TUI toast fails
      }
    }

    // 2. Desktop OS notification fallback (dunst / mako / libnotify)
    const urgency = variant === "error" || variant === "warning" ? "critical" : "normal";
    const sanitizedTitle = title.replace(/"/g, '\\"');
    const sanitizedMsg = message.replace(/"/g, '\\"');

    const cmd =
      process.platform === "linux"
        ? `notify-send -u ${urgency} "${sanitizedTitle}" "${sanitizedMsg}"`
        : process.platform === "darwin"
        ? `osascript -e 'display notification "${sanitizedMsg}" with title "${sanitizedTitle}"'`
        : null;

    if (cmd) {
      exec(cmd, () => {});
    }
  }

  async function checkNetwork() {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2000);

      const res = await fetch("https://1.1.1.1", {
        method: "HEAD",
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      return res.ok;
    } catch {
      return false;
    }
  }

  const timer = setInterval(async () => {
    const reachable = await checkNetwork();

    if (!reachable) {
      if (isOnline) {
        notifyUser(
          "Network Watchdog",
          "Connection dropped. Waiting...",
          "warning"
        );
      }
      isOnline = false;
      wasOffline = true;
    } else {
      isOnline = true;

      if (wasOffline && activeSessionID) {
        notifyUser(
          "Network Watchdog",
          "Internet restored! Resuming session...",
          "info"
        );
        wasOffline = false;

        try {
          // 1. Abort active hung request
          if (client.session.abort) {
            await client.session.abort({ path: { id: activeSessionID } });
          } else if (client.session.cancel) {
            await client.session.cancel({ path: { id: activeSessionID } });
          }

          // 2. Small buffer for session state to reset to idle
          await new Promise((resolve) => setTimeout(resolve, 500));

          // 3. Dispatch "continue" prompt quietly
          if (client.session.prompt) {
            await client.session.prompt({
              path: { id: activeSessionID },
              body: { parts: [{ type: "text", text: "continue" }] },
            });
          } else {
            await client.session.command({
              path: { id: activeSessionID },
              body: { command: "continue" },
            });
          }
        } catch (err) {
          notifyUser("Watchdog Error", err.message, "error");
          if (client.app?.log) {
            client.app.log({
              level: "error",
              message: `Watchdog failed: ${err.message}`,
            });
          }
        }
      }
    }
  }, PING_INTERVAL_MS);

  return {
    event: async ({ event }) => {
      const sessionID =
        event.properties?.sessionID ||
        event.properties?.id ||
        event.payload?.sessionID;

      if (sessionID) {
        activeSessionID = sessionID;
      }
    },

    cleanup: () => {
      clearInterval(timer);
    },
  };
};

export default NetworkWatchdogPlugin;
