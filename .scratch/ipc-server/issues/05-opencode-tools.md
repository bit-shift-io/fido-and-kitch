Status: pending

# 05: OpenCode Tools — TypeScript Tool Definitions

## What to build
Create `.opencode/tools/fido-kitch-ipc.ts` with tool definitions:

```typescript
import { tool } from "@opencode-ai/plugin";
import { net } from "node:net";

const DEFAULT_PORT = parseInt(process.env.FIDO_KITCH_IPC_PORT || "8080", 10);
const HOST = "127.0.0.1";

async function sendCommand(cmd: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const client = net.createConnection({ host: HOST, port: DEFAULT_PORT }, () => {
      client.write(cmd + "\n");
    });

    let buffer = "";
    client.on("data", (data) => {
      buffer += data.toString();
      if (buffer.includes("\n")) {
        const line = buffer.trim();
        client.end();
        resolve(line);
      }
    });

    client.on("error", (err) => reject(new Error(`IPC connection failed: ${err.message}`)));
    client.on("timeout", () => reject(new Error("IPC timeout")));
    client.setTimeout(2000);
  });
}

function parseOK(response: string): string {
  if (response.startsWith("OK: ")) return response.slice(4);
  if (response.startsWith("STATE ")) return response.slice(6);
  throw new Error(`Unexpected response: ${response}`);
}

function parseError(response: string): never {
  if (response.startsWith("ERROR: ")) throw new Error(response.slice(7));
  throw new Error(`Unknown response: ${response}`);
}

export const resize_window = tool({
  description: "Resize the game window",
  args: {
    width: tool.schema.number().describe("Width in pixels"),
    height: tool.schema.number().describe("Height in pixels"),
  },
  async execute({ width, height }) {
    const response = await sendCommand(`RESIZE ${width} ${height}`);
    if (response.startsWith("OK: ")) return response.slice(4);
    parseError(response);
  },
});

export const move_player = tool({
  description: "Move a player by relative delta",
  args: {
    player: tool.schema.number().describe("Player index (1 or 2)"),
    dx: tool.schema.number().describe("Delta X"),
    dy: tool.schema.number().describe("Delta Y"),
  },
  async execute({ player, dx, dy }) {
    const response = await sendCommand(`MOVE_PLAYER ${player} ${dx} ${dy}`);
    return parseOK(response);
  },
});

export const get_game_state = tool({
  description: "Get full game state snapshot",
  args: {},
  async execute() {
    const response = await sendCommand("GET_STATE");
    const data = parseOK(response); // "p1x=X p1y=Y p2x=X p2y=Y w=W h=H map=NAME"
    const parts = data.split(" ");
    const state: Record<string, string> = {};
    for (const part of parts) {
      const [k, v] = part.split("=");
      state[k] = v;
    }
    return {
      player1: { x: parseInt(state.p1x), y: parseInt(state.p1y) },
      player2: { x: parseInt(state.p2x), y: parseInt(state.p2y) },
      window: { width: parseInt(state.w), height: parseInt(state.h) },
      map: state.map,
    };
  },
});

export const get_player_pos = tool({
  description: "Get single player position",
  args: {
    player: tool.schema.number().describe("Player index (1 or 2)"),
  },
  async execute({ player }) {
    const response = await sendCommand(`GET_PLAYER_POS ${player}`);
    return parseOK(response); // "Player N at X,Y"
  },
});

export const restart_level = tool({
  description: "Restart the current level",
  args: {},
  async execute() {
    const response = await sendCommand("RESTART_LEVEL");
    return parseOK(response);
  },
});

export const go_to_menu = tool({
  description: "Return to main menu",
  args: {},
  async execute() {
    const response = await sendCommand("MENU");
    return parseOK(response);
  },
});
```

## Files to create/modify
- `.opencode/tools/fido-kitch-ipc.ts` (new)

## Test approach
- Manual: Start game with `love . ipc`, run `opencode` and invoke tools
- E2E: `tests/e2e/ipc_control_test.lua` — uses tools via test runner

## Acceptance criteria
- [ ] All 6 tools exported and typed
- [ ] Tools connect to `127.0.0.1:8080` (configurable via `FIDO_KITCH_IPC_PORT`)
- [ ] Tools handle connection errors gracefully
- [ ] Response parsing returns typed objects (not raw strings)
- [ ] Tools load in OpenCode without errors
- [ ] Agent can invoke tools and get structured results

## Blocked by
04-main-integration (server must be running)