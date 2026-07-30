import { tool } from "@opencode-ai/plugin";
import net from "node:net";
import { spawn, exec } from "node:child_process";
import { promisify } from "node:util";

const DEFAULT_PORT = parseInt(process.env.FIDO_KITCH_IPC_PORT || "8081", 10);
const HOST = "127.0.0.1";

const GAME_COMMAND = process.env.FIDO_KITCH_BIN || "love";
const GAME_ARGS = process.env.FIDO_KITCH_ARGS ? process.env.FIDO_KITCH_ARGS.split(" ") : [".", "ipc", "map=sandbox"];

const execAsync = promisify(exec);

/**
 * Kill any process holding the IPC port.
 */
async function clearPort(): Promise<void> {
    try {
        const { stdout } = await execAsync(`lsof -ti:${DEFAULT_PORT}`);
        const pids = stdout.trim().split("\n").filter(Boolean);
        for (const pid of pids) {
            console.log(`[IPC] Killing process ${pid} on port ${DEFAULT_PORT}`);
            await execAsync(`kill -9 ${pid}`);
        }
    } catch {
        // lsof returns non-zero if no process found - that's fine
    }
}

/**
 * Quick ping check to see if the game IPC socket is actively accepting connections.
 */
async function isServerUp(): Promise<boolean> {
    return new Promise((resolve) => {
        const socket = net.createConnection({ host: HOST, port: DEFAULT_PORT }, () => {
            socket.destroy();
            resolve(true);
        });
        socket.on("error", () => {
            socket.destroy();
            resolve(false);
        });
    });
}

let gameProcess: ReturnType<typeof spawn> | null = null;

/**
 * Explicitly launch the game with optional map override.
 * Returns when IPC socket is accepting connections.
 */
async function launchGame(map?: string): Promise<void> {
    // Clean up any existing process on the port first
    await clearPort();

    if (await isServerUp()) {
        console.log("[IPC] Game already running");
        return;
    }

    const args = map ? [".", "ipc", `map=${map}`] : GAME_ARGS;
    console.log(`[IPC] Launching ${GAME_COMMAND} ${args.join(" ")}...`);

    gameProcess = spawn(GAME_COMMAND, args, {
        detached: true,
        stdio: "ignore",
        cwd: process.cwd(),
    });
    gameProcess.unref();

    // Poll for up to 10 seconds (100 attempts x 100ms) for the socket to become active
    // This accounts for LÖVE startup + menu + map load + player spawn
    const maxRetries = 100;
    for (let i = 0; i < maxRetries; i++) {
        await new Promise((r) => setTimeout(r, 100));
        if (await isServerUp()) {
            console.log("[IPC] Game successfully started and IPC socket is ready.");
            return;
        }
    }

    throw new Error(`Failed to start game: IPC socket at ${HOST}:${DEFAULT_PORT} did not open within 10 seconds.`);
}

/**
 * Requires the game to be running - fails fast with clear error if not.
 * Removes auto-spawn to prevent race conditions and silent failures.
 */
async function requireGameRunning(): Promise<void> {
    if (!(await isServerUp())) {
        throw new Error(
            `Game not running on port ${DEFAULT_PORT}. ` +
            `Call launch_game first, or start manually with: love . ipc map=sandbox`
        );
    }
}

/**
 * Sends a single line command to the game over the TCP socket.
 * Does NOT auto-launch - use launch_game first.
 */
async function sendCommand(cmd: string): Promise<string> {
    await requireGameRunning();

    return new Promise((resolve, reject) => {
        const client = net.createConnection({ host: HOST, port: DEFAULT_PORT }, () => {
            client.write(cmd + "\n");
        });

        let buffer = "";

        client.on("data", (data) => {
            buffer += data.toString();
            if (buffer.includes("\n")) {
                const line = buffer.trim();
                client.destroy();
                resolve(line);
            }
        });

        client.on("error", (err) => {
            client.destroy();
            reject(new Error(`IPC connection failed: ${err.message}`));
        });

        client.on("timeout", () => {
            client.destroy();
            reject(new Error("IPC timeout"));
        });

        client.setTimeout(2000);
    });
}

function parseResponse(response: string): string {
    if (response.startsWith("OK: ")) return response.slice(4);
    if (response.startsWith("STATE ")) return response.slice(6);
    if (response.startsWith("ERROR: ")) throw new Error(response.slice(7));
    throw new Error(`Unexpected response: ${response}`);
}

/**
 * Launch the game with optional map. Blocks until IPC server is ready.
 */
export const launch_game = tool({
    description: "Launch the game with IPC server. Blocks until ready for commands.",
    args: {
        map: tool.schema.string().optional().describe("Map to load (e.g., 'sandbox', 'll1'). Defaults to 'sandbox'."),
    },
    async execute({ map }) {
        await launchGame(map);
        return `Game launched${map ? ` with map: ${map}` : ""} - IPC ready`;
    },
});

export const resize_window = tool({
    description: "Resize the game window (requires game running via launch_game)",
    args: {
        width: tool.schema.number().describe("Width in pixels"),
        height: tool.schema.number().describe("Height in pixels"),
    },
    async execute({ width, height }) {
        const response = await sendCommand(`RESIZE ${width} ${height}`);
        return parseResponse(response);
    },
});

export const move_player = tool({
    description: "Move a player by relative delta (direct position change)",
    args: {
        player: tool.schema.number().describe("Player index (1 or 2)"),
        dx: tool.schema.number().describe("Delta X"),
        dy: tool.schema.number().describe("Delta Y"),
    },
    async execute({ player, dx, dy }) {
        const response = await sendCommand(`MOVE_PLAYER ${player} ${dx} ${dy}`);
        return parseResponse(response);
    },
});

export const press_key = tool({
    description: "Press a key for a player (simulates keyboard input: left, right, up, down, use)",
    args: {
        player: tool.schema.number().describe("Player index (1 or 2)"),
        action: tool.schema.string().describe("Action: left, right, up, down, use"),
    },
    async execute({ player, action }) {
        const response = await sendCommand(`INPUT ${player} ${action} down`);
        return parseResponse(response);
    },
});

export const release_key = tool({
    description: "Release a key for a player",
    args: {
        player: tool.schema.number().describe("Player index (1 or 2)"),
        action: tool.schema.string().describe("Action: left, right, up, down, use"),
    },
    async execute({ player, action }) {
        const response = await sendCommand(`INPUT ${player} ${action} up`);
        return parseResponse(response);
    },
});

export const hold_key = tool({
    description: "Hold a key for a player for a duration (in seconds)",
    args: {
        player: tool.schema.number().describe("Player index (1 or 2)"),
        action: tool.schema.string().describe("Action: left, right, up, down, use"),
        duration: tool.schema.number().describe("Duration in seconds"),
    },
    async execute({ player, action, duration }) {
        await sendCommand(`INPUT ${player} ${action} down`);
        await new Promise((r) => setTimeout(r, duration * 1000));
        await sendCommand(`INPUT ${player} ${action} up`);
        return `Held ${action} for player ${player} for ${duration}s`;
    },
});

export const get_game_state = tool({
    description: "Get full game state snapshot (player positions, window size, current map)",
    args: {},
    async execute() {
        const response = await sendCommand("GET_STATE");
        return parseResponse(response); // Returns string: "p1x=X p1y=Y p2x=X p2y=Y w=W h=H map=NAME"
    },
});

export const get_player_pos = tool({
    description: "Get single player position",
    args: {
        player: tool.schema.number().describe("Player index (1 or 2)"),
    },
    async execute({ player }) {
        const response = await sendCommand(`GET_PLAYER_POS ${player}`);
        return parseResponse(response); // "Player N at X,Y"
    },
});

export const restart_level = tool({
    description: "Restart the current level",
    args: {},
    async execute() {
        const response = await sendCommand("RESTART_LEVEL");
        return parseResponse(response);
    },
});

export const go_to_menu = tool({
    description: "Return to main menu",
    args: {},
    async execute() {
        const response = await sendCommand("MENU");
        return parseResponse(response);
    },
});

export const toggle_camera = tool({
    description: "Toggle camera overview mode (zooms out to full map view)",
    args: {},
    async execute() {
        const response = await sendCommand("TOGGLE_CAMERA");
        return parseResponse(response);
    },
});