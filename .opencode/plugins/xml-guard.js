/**
 * XML Spam Guard Plugin for OpenCode
 */
export default async function XmlSpamGuard(ctx) {
  return {
    // Config hook
    async config(cfg) {
      return cfg;
    },

    // Event listener hook
    async event(evt) {
      const eventType = evt?.type || evt?.event?.type;
      if (eventType !== "message.updated") return;

      const message = evt?.properties?.message || evt?.message;
      if (!message || message.role !== "assistant" || !message.content) return;

      const xmlSpamPattern = /(<\/?(?:tool_call|invoke|thinking|function_call|code_block)[^>]*>){2,}/i;
      const rawXmlLoopPattern = /(<[a-zA-Z_0-9-]+>[^<]*<\/[a-zA-Z_0-9-]+>\s*){3,}/i;

      if (xmlSpamPattern.test(message.content) || rawXmlLoopPattern.test(message.content)) {
        console.warn("[XmlSpamGuard] Intercepted XML loop. Aborting session...");

        const session = evt?.session || ctx?.session;
        if (session && typeof session.abort === "function") {
          await session.abort();
        }
      }
    },

    // Dispose hook
    async dispose() {}
  };
}
