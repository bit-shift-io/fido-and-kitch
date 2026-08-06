/**
 * XML & Token Guard Plugin for OpenCode
 * Intercepts <unk> token loops and malformed XML during thinking/streaming.
 */
export default async function XmlSpamGuard(ctx) {
  const client = ctx?.client || ctx;

  function notify(title, message, variant = "error") {
    if (client?.tui?.showToast) {
      try {
        client.tui.showToast({
          body: { title, message, variant },
        });
        return;
      } catch {}
    }

    if (process.platform === "linux") {
      const sanitizedTitle = title.replace(/"/g, '\\"');
      const sanitizedMsg = message.replace(/"/g, '\\"');

      import("node:child_process").then(({ exec }) => {
        exec(
          `notify-send -u critical "${sanitizedTitle}" "${sanitizedMsg}"`,
          () => {}
        );
      });
    }
  }

  function isSpam(rawPayload) {
    if (!rawPayload || rawPayload.length < 5) return false;

    // 1. Detect 3 or more <unk> tokens anywhere in the event payload
    const unkMatches = rawPayload.match(/<unk>/gi);
    if (unkMatches && unkMatches.length >= 3) return true;

    // 2. Detect consecutive or whitespace-separated <unk> tokens
    if (/(?:<unk>\s*){3,}/i.test(rawPayload)) return true;

    // 3. Structural tag spam loops (e.g., repeating <tool_call> or <thinking>)
    if (
      /(<\/?(?:tool_call|invoke|thinking|function_call|code_block|artifact)[^>]*>[\s\n]*){3,}/i.test(
        rawPayload
      )
    ) {
      return true;
    }

    // 4. Generic repeating XML tag loops
    if (/(<([a-zA-Z_0-9-]+)[^>]*>.*?<\/\2>[\s\n]*){4,}/is.test(rawPayload)) {
      return true;
    }

    return false;
  }

  return {
    async config(cfg) {
      return cfg;
    },

    async event(evt) {
      if (!evt) return;

      // Inspect the raw payload to capture thinking text and delta chunks
      let rawPayload = "";
      try {
        rawPayload = JSON.stringify(evt);
      } catch {
        return;
      }

      if (isSpam(rawPayload)) {
        notify(
          "Guard Intercept",
          "Detected <unk> token loop. Aborting session...",
          "error"
        );

        // Extract session ID across various possible event structures
        const sessionID =
          evt?.properties?.sessionID ||
          evt?.sessionID ||
          evt?.properties?.message?.sessionID ||
          evt?.message?.sessionID ||
          evt?.properties?.part?.sessionID ||
          evt?.properties?.id ||
          evt?.id;

        try {
          if (client?.session?.abort && sessionID) {
            await client.session.abort({ path: { id: sessionID } });
          } else if (client?.session?.abort) {
            await client.session.abort();
          } else if (evt?.session?.abort) {
            await evt.session.abort();
          }
        } catch (err) {
          notify("Guard Error", `Failed to abort: ${err.message}`, "error");
        }
      }
    },

    async dispose() {},
  };
}
