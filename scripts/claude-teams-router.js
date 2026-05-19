#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { spawn, spawnSync } = require("child_process");

const CONFIG_FILENAME = "router.json";
const SECRETS_FILENAME = "router.local.json";
const TAG = "[claude-teams-router]";

function sameFile(a, b) {
  try {
    return fs.realpathSync(a) === fs.realpathSync(b);
  } catch {
    return false;
  }
}

function resolveRealClaude() {
  if (process.env.CLAUDE_ROUTER_REAL_CLAUDE) {
    return process.env.CLAUDE_ROUTER_REAL_CLAUDE;
  }
  const result = spawnSync("/usr/bin/which", ["-a", "claude"], { encoding: "utf8" });
  if (result.status !== 0) return null;
  const candidates = result.stdout.split("\n").map((s) => s.trim()).filter(Boolean);
  for (const c of candidates) {
    if (!sameFile(c, __filename)) return c;
  }
  return null;
}

function log(msg) {
  process.stderr.write(`${TAG} ${msg}\n`);
}

function debug(msg) {
  if (process.env.CLAUDE_ROUTER_DEBUG) log(msg);
}

function findConfigFile(startDir) {
  let dir = path.resolve(startDir);
  while (true) {
    const candidate = path.join(dir, ".claude", CONFIG_FILENAME);
    if (fs.existsSync(candidate)) return candidate;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function loadSecrets(configDir, profileName) {
  const secretsPath = path.join(configDir, SECRETS_FILENAME);
  if (!fs.existsSync(secretsPath)) {
    debug(`no ${SECRETS_FILENAME} at ${secretsPath}`);
    return {};
  }

  let secrets;
  try {
    secrets = JSON.parse(fs.readFileSync(secretsPath, "utf8"));
  } catch (e) {
    log(`failed to parse ${secretsPath}: ${e.message} — skipping secrets`);
    return {};
  }

  if (!secrets[profileName]) {
    debug(`no secrets for profile "${profileName}" in ${secretsPath}`);
    return {};
  }

  const entries = secrets[profileName];
  if (typeof entries !== "object" || entries === null) {
    log(`secrets for "${profileName}" is not an object — skipping`);
    return {};
  }

  debug(`loaded ${Object.keys(entries).length} secret(s) for profile "${profileName}" from ${secretsPath}`);
  return entries;
}

function parseFlag(argv, flag) {
  const eq = `${flag}=`;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === flag && i + 1 < argv.length) return argv[i + 1];
    if (a.startsWith(eq)) return a.slice(eq.length);
  }
  return null;
}

function isProbe(argv) {
  return argv.includes("--print") && !argv.some((a) => !a.startsWith("-"));
}

function resolveProfileName(config, agentName) {
  if (process.env.CLAUDE_ROUTER_PROFILE) {
    return { name: process.env.CLAUDE_ROUTER_PROFILE, source: "CLAUDE_ROUTER_PROFILE env" };
  }
  if (agentName && config.agents && config.agents[agentName]) {
    return { name: config.agents[agentName], source: `agents["${agentName}"]` };
  }
  if (agentName && config.profiles && config.profiles[agentName]) {
    return { name: agentName, source: `profiles["${agentName}"] (agent name match)` };
  }
  return null;
}

function loadSelection(argv) {
  const configPath = findConfigFile(process.cwd());
  if (!configPath) {
    debug(`no ${CONFIG_FILENAME} found from ${process.cwd()}`);
    return null;
  }

  let config;
  try {
    config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  } catch (e) {
    log(`failed to parse ${configPath}: ${e.message} — passing through`);
    return null;
  }

  const agentName = parseFlag(argv, "--agent-name");
  const resolved = resolveProfileName(config, agentName);
  if (!resolved) {
    debug(`no profile resolved (agent="${agentName ?? ""}") — passing through`);
    return null;
  }

  const profile = config.profiles && config.profiles[resolved.name];
  if (!profile) {
    log(`profile "${resolved.name}" (via ${resolved.source}) not in ${configPath} — passing through`);
    return null;
  }

  return {
    configPath,
    agentName,
    profileName: resolved.name,
    profileSource: resolved.source,
    env: { ...profile, ...loadSecrets(path.dirname(configPath), resolved.name) },
  };
}

function main() {
  const argv = process.argv.slice(2);

  if (isProbe(argv)) process.exit(0);

  const realClaude = resolveRealClaude();
  if (!realClaude || !fs.existsSync(realClaude)) {
    log(
      `real claude binary not found (looked at $CLAUDE_ROUTER_REAL_CLAUDE then \`which -a claude\`; set CLAUDE_ROUTER_REAL_CLAUDE to override)`,
    );
    process.exit(127);
  }

  const selection = loadSelection(argv);
  const env = { ...process.env };
  if (selection) {
    for (const [k, v] of Object.entries(selection.env)) {
      env[k] = v;
    }
    debug(
      `agent="${selection.agentName}" -> profile "${selection.profileName}" (${selection.profileSource}); injected: ${Object.keys(selection.env).join(", ")}`,
    );
  }

  const child = spawn(realClaude, argv, {
    stdio: "inherit",
    env,
  });

  const forward = (sig) => {
    if (!child.killed) child.kill(sig);
  };
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP", "SIGQUIT"]) {
    process.on(sig, () => forward(sig));
  }

  child.on("error", (err) => {
    log(`failed to spawn ${realClaude}: ${err.message}`);
    process.exit(127);
  });

  child.on("exit", (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
    } else {
      process.exit(code ?? 0);
    }
  });
}

main();
