// ~/.config/opencode/plugins/network-watchdog.js

export const NetworkWatchdogPlugin = async ({ client }) => {
  let isOnline = true;
  let wasOffline = false;
  let activeSessionID = null;

  // Check connectivity every 5 seconds
  const PING_INTERVAL_MS = 5000;

  async function checkNetwork() {
    try {
      // Fast HEAD fetch to Cloudflare/Google DNS
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

  // Background watchdog loop
  const timer = setInterval(async () => {
    const reachable = await checkNetwork();

    if (!reachable) {
      if (isOnline) {
        console.warn("\n[Watchdog] Network drop detected! Waiting for connection...");
      }
      isOnline = false;
      wasOffline = true;
    } else {
      isOnline = true;

      // Transitioned back from Offline -> Online
      if (wasOffline && activeSessionID) {
        console.log("\n[Watchdog] Internet restored! Sending auto-continue signal...");
        wasOffline = false;

        try {
          // Instruct OpenCode session to execute /continue
          await client.session.command({
            path: { id: activeSessionID },
            body: { command: "continue" },
          });
        } catch (err) {
          console.error("[Watchdog] Failed to execute auto-continue:", err.message);
        }
      }
    }
  }, PING_INTERVAL_MS);

  return {
    // Listen to session events to track the current active session
    event: async ({ event }) => {
      if (event.type === "session.created" || event.type === "session.updated") {
        if (event.properties?.sessionID) {
          activeSessionID = event.properties.sessionID;
        }
      }
    },

    // Cleanup timer if plugin reloads or OpenCode shuts down
    cleanup: () => {
      clearInterval(timer);
    },
  };
};

export default NetworkWatchdogPlugin;
