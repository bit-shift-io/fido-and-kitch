// ~/.config/opencode/plugins/network-watchdog.js
import { exec } from "node:child_process";

export const NetworkWatchdogPlugin = async ({ client }) => {
  let isOnline = true;
  let wasOffline = false;
  let activeSessionID = null;

  const PING_INTERVAL_MS = 5000;

  function notifyUser(title, message, variant = "info") {
    if (client.tui?.showToast) {
      try {
        client.tui.showToast({
          body: { title, message, variant },
        });
        return;
      } catch {
        // Fallback to desktop notification
      }
    }

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

  // Helper to wait until session state is clear to accept new prompts
  async function waitForSessionIdle(sessionId, maxAttempts = 10) {
    for (let i = 0; i < maxAttempts; i++) {
      try {
        if (client.session?.get) {
          const res = await client.session.get({ path: { id: sessionId } });
          const status = res.data?.status || res.status;
          // If status isn't active/busy, it's ready
          if (status !== "busy" && status !== "running") return true;
        }
      } catch {
        // Ignore check errors and fallback to delay
      }
      await new Promise((r) => setTimeout(r, 500));
    }
    return true;
  }

  async function handleReconnection() {
    // Attempt to resolve active session ID dynamically if missing
    let targetSession = activeSessionID;

    if (!targetSession && client.session?.list) {
      try {
        const sessions = await client.session.list();
        const active = sessions.data?.find((s) => s.status === "busy" || s.active);
        if (active) targetSession = active.id;
      } catch {
        // Fallback
      }
    }

    if (!targetSession) {
      notifyUser("Network Watchdog", "Reconnected, but no active session found.", "warning");
      wasOffline = false;
      return;
    }

    notifyUser("Network Watchdog", "Internet restored! Resuming session...", "info");

    try {
      // 1. Force interrupt/abort on the active session
      if (client.session?.abort) {
        await client.session.abort({ path: { id: targetSession } }).catch(() => {});
      } else if (client.session?.cancel) {
        await client.session.cancel({ path: { id: targetSession } }).catch(() => {});
      }

      // 2. Poll until session transitions out of busy state (up to 5 seconds)
      await waitForSessionIdle(targetSession);

      // 3. Dispatch prompt
      if (client.session?.prompt) {
        await client.session.prompt({
          path: { id: targetSession },
          body: { parts: [{ type: "text", text: "continue" }] },
        });
      } else if (client.session?.command) {
        await client.session.command({
          path: { id: targetSession },
          body: { command: "continue" },
        });
      }

      // Successfully processed recovery
      wasOffline = false;
    } catch (err) {
      notifyUser("Watchdog Error", `Recovery failed: ${err.message}`, "error");
      if (client.app?.log) {
        client.app.log({
          level: "error",
          message: `Watchdog recovery failed: ${err.message}`,
        });
      }
      // Leave wasOffline = true so the next ping loop can retry if needed
    }
  }

  const timer = setInterval(async () => {
    const reachable = await checkNetwork();

    if (!reachable) {
      if (isOnline) {
        notifyUser("Network Watchdog", "Connection dropped. Waiting...", "warning");
      }
      isOnline = false;
      wasOffline = true;
    } else {
      isOnline = true;
      if (wasOffline) {
        await handleReconnection();
      }
    }
  }, PING_INTERVAL_MS);

  return {
    event: async ({ event }) => {
      // Extract session ID from all known event structures
      const extractedID =
        event.properties?.sessionID ||
        event.properties?.id ||
        event.payload?.sessionID ||
        event.sessionID ||
        (event.type === "session.created" ? event.properties?.id : null);

      if (extractedID) {
        activeSessionID = extractedID;
      }
    },

    cleanup: () => {
      clearInterval(timer);
    },
  };
};

export default NetworkWatchdogPlugin;
