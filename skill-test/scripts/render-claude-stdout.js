#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");

function usage() {
  console.log(`Usage: scripts/render-claude-stdout.js [RUN_DIR|STDOUT_FILE] [options]

Turns Claude Code stdout.txt into a readable transcript.

Arguments:
  RUN_DIR|STDOUT_FILE        A runs/<run-id> directory or stdout.txt file.
                             Defaults to the newest directory under runs/.

Options:
  --output FILE              Write transcript to FILE instead of stdout.
  --show-tool-json           Include full tool input JSON.
  --show-raw                 Include unparsable raw lines.
  -h, --help                 Show this help.

Examples:
  scripts/render-claude-stdout.js
  scripts/render-claude-stdout.js runs/20260616T125005Z-qdrant-latency-remote-skill
  scripts/render-claude-stdout.js runs/20260616T125005Z-qdrant-latency-remote-skill/stdout.txt --output readable.txt
`);
}

function parseArgs(argv) {
  const options = {
    input: "",
    output: "",
    showToolJson: false,
    showRaw: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") {
      usage();
      process.exit(0);
    }
    if (arg === "--output") {
      options.output = requireValue(arg, argv[i + 1]);
      i += 1;
      continue;
    }
    if (arg === "--show-tool-json") {
      options.showToolJson = true;
      continue;
    }
    if (arg === "--show-raw") {
      options.showRaw = true;
      continue;
    }
    if (arg.startsWith("-")) {
      fail(`Unknown option: ${arg}`);
    }
    if (options.input) {
      fail(`Only one input path is supported: got ${options.input} and ${arg}`);
    }
    options.input = arg;
  }

  return options;
}

function requireValue(option, value) {
  if (!value) {
    fail(`Missing value for ${option}`);
  }
  return value;
}

function fail(message) {
  console.error(message);
  process.exit(64);
}

function resolveInput(input) {
  if (input) {
    const absolute = path.resolve(input);
    return stdoutPathFor(absolute);
  }

  const runsDir = path.join(repoRoot, "runs");
  if (!fs.existsSync(runsDir)) {
    fail("No input provided and runs/ does not exist.");
  }

  const newest = fs
    .readdirSync(runsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const dir = path.join(runsDir, entry.name);
      return { dir, mtimeMs: fs.statSync(dir).mtimeMs };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs)[0];

  if (!newest) {
    fail("No input provided and runs/ has no run directories.");
  }

  return stdoutPathFor(newest.dir);
}

function stdoutPathFor(inputPath) {
  if (!fs.existsSync(inputPath)) {
    fail(`Input path not found: ${inputPath}`);
  }

  const stats = fs.statSync(inputPath);
  if (stats.isDirectory()) {
    const stdoutPath = path.join(inputPath, "stdout.txt");
    if (!fs.existsSync(stdoutPath)) {
      fail(`Run directory has no stdout.txt: ${inputPath}`);
    }
    return stdoutPath;
  }

  return inputPath;
}

function readJsonIfExists(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }

  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function oneLine(value) {
  return String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
}

function indent(text, spaces = 2) {
  const prefix = " ".repeat(spaces);
  return String(text)
    .split("\n")
    .map((line) => (line ? `${prefix}${line}` : ""))
    .join("\n");
}

function prettyJson(value) {
  return JSON.stringify(value, null, 2);
}

function summarizeToolInput(input) {
  if (!input || typeof input !== "object") {
    return "";
  }

  const parts = [];
  if (input.url) {
    parts.push(`url=${input.url}`);
  }
  if (input.query) {
    parts.push(`query=${input.query}`);
  }
  if (input.command) {
    parts.push(`command=${input.command}`);
  }
  if (input.cmd) {
    parts.push(`cmd=${input.cmd}`);
  }
  if (input.file_path) {
    parts.push(`file=${input.file_path}`);
  }
  if (input.path) {
    parts.push(`path=${input.path}`);
  }
  if (input.prompt) {
    parts.push(`prompt=${oneLine(input.prompt).slice(0, 220)}`);
  }
  return parts.join("\n");
}

function getToolResultText(content) {
  if (typeof content === "string") {
    return content;
  }
  if (!Array.isArray(content)) {
    return "";
  }

  return content
    .map((item) => {
      if (typeof item === "string") {
        return item;
      }
      if (item && typeof item === "object") {
        if (typeof item.content === "string") {
          return item.content;
        }
        if (typeof item.text === "string") {
          return item.text;
        }
        if (item.type === "tool_reference" && item.tool_name) {
          return `tool reference: ${item.tool_name}`;
        }
      }
      return "";
    })
    .filter(Boolean)
    .join("\n");
}

function truncate(text, max = 1800) {
  const value = String(text ?? "");
  if (value.length <= max) {
    return value;
  }
  return `${value.slice(0, max)}\n... [truncated ${value.length - max} chars]`;
}

function renderSystem(event, lines) {
  if (event.subtype !== "init") {
    lines.push(`## System: ${event.subtype || event.type}`);
    return;
  }

  lines.push("## Claude Code Session");
  lines.push("");
  lines.push(`- Session: ${event.session_id || "unknown"}`);
  lines.push(`- CWD: ${event.cwd || "unknown"}`);
  lines.push(`- Model: ${event.model || "unknown"}`);
  lines.push(`- Claude Code: ${event.claude_code_version || "unknown"}`);
  lines.push(`- Permission mode: ${event.permissionMode || "unknown"}`);
  lines.push(`- Auth source: ${event.apiKeySource || "unknown"}`);
  if (Array.isArray(event.skills) && event.skills.length > 0) {
    lines.push(`- Loaded skills: ${event.skills.join(", ")}`);
  }
  if (Array.isArray(event.plugins) && event.plugins.length > 0) {
    lines.push(`- Plugins: ${event.plugins.join(", ")}`);
  }
}

function renderAssistant(event, lines, options) {
  const content = event.message && event.message.content;
  if (!Array.isArray(content)) {
    return;
  }

  for (const item of content) {
    if (!item || typeof item !== "object") {
      continue;
    }

    if (item.type === "text" && item.text) {
      lines.push("");
      lines.push("## Assistant");
      lines.push("");
      lines.push(item.text.trim());
      continue;
    }

    if (item.type === "tool_use") {
      lines.push("");
      lines.push(`## Tool Use: ${item.name || "unknown"}`);
      if (item.id) {
        lines.push(`- ID: ${item.id}`);
      }
      const summary = summarizeToolInput(item.input);
      if (summary) {
        lines.push("");
        lines.push(indent(summary));
      }
      if (options.showToolJson && item.input !== undefined) {
        lines.push("");
        lines.push("```json");
        lines.push(prettyJson(item.input));
        lines.push("```");
      }
      continue;
    }
  }
}

function renderUserToolResult(event, lines) {
  const content = event.message && event.message.content;
  if (!Array.isArray(content)) {
    return;
  }

  for (const item of content) {
    if (!item || item.type !== "tool_result") {
      continue;
    }

    lines.push("");
    lines.push("## Tool Result");
    if (item.tool_use_id) {
      lines.push(`- For: ${item.tool_use_id}`);
    }

    const result = event.tool_use_result;
    if (result && typeof result === "object") {
      const facts = [];
      if (result.url) {
        facts.push(`URL: ${result.url}`);
      }
      if (result.code || result.codeText) {
        facts.push(`HTTP: ${[result.code, result.codeText].filter(Boolean).join(" ")}`);
      }
      if (result.durationMs !== undefined) {
        facts.push(`Duration: ${result.durationMs}ms`);
      }
      if (facts.length > 0) {
        lines.push("");
        lines.push(indent(facts.join("\n")));
      }
    }

    const text = getToolResultText(item.content);
    if (text) {
      lines.push("");
      lines.push(indent(truncate(text)));
    }
  }
}

function renderResult(event, lines) {
  lines.push("");
  lines.push("## Run Result");
  lines.push("");
  lines.push(`- Status: ${event.is_error ? "error" : "success"}`);
  if (event.subtype) {
    lines.push(`- Subtype: ${event.subtype}`);
  }
  if (event.terminal_reason) {
    lines.push(`- Terminal reason: ${event.terminal_reason}`);
  }
  if (event.stop_reason) {
    lines.push(`- Stop reason: ${event.stop_reason}`);
  }
  if (event.num_turns !== undefined) {
    lines.push(`- Turns: ${event.num_turns}`);
  }
  if (event.duration_ms !== undefined) {
    lines.push(`- Duration: ${(event.duration_ms / 1000).toFixed(1)}s`);
  }
  if (event.total_cost_usd !== undefined) {
    lines.push(`- Cost: $${Number(event.total_cost_usd).toFixed(6)}`);
  }
  if (Array.isArray(event.errors) && event.errors.length > 0) {
    lines.push(`- Errors: ${event.errors.join("; ")}`);
  }
}

function renderPlainText(raw, lines) {
  const text = raw.trim();
  if (!text) {
    return;
  }
  lines.push("");
  lines.push("## Output");
  lines.push("");
  lines.push(text);
}

function renderTranscript(stdoutPath, options) {
  const runDir = path.dirname(stdoutPath);
  const metadata = readJsonIfExists(path.join(runDir, "metadata.json"));
  const prompt = fs.existsSync(path.join(runDir, "prompt.md"))
    ? fs.readFileSync(path.join(runDir, "prompt.md"), "utf8").trim()
    : "";

  const lines = [];
  lines.push(`# Claude Code Transcript`);
  lines.push("");
  lines.push(`- Source: ${stdoutPath}`);
  if (metadata) {
    lines.push(`- Run ID: ${metadata.run_id || path.basename(runDir)}`);
    lines.push(`- Exit code: ${metadata.exit_code}`);
    lines.push(`- Output format: ${metadata.output_format}`);
    lines.push(`- Max turns: ${metadata.max_turns}`);
  }
  if (prompt) {
    lines.push("");
    lines.push("## Prompt");
    lines.push("");
    lines.push(prompt);
  }

  const raw = fs.readFileSync(stdoutPath, "utf8");
  const rawLines = raw.split(/\r?\n/).filter((line) => line.trim());
  let parsedAny = false;

  for (const line of rawLines) {
    let event;
    try {
      event = JSON.parse(line);
      parsedAny = true;
    } catch {
      if (options.showRaw) {
        renderPlainText(line, lines);
      } else if (!parsedAny && rawLines.length === 1) {
        renderPlainText(line, lines);
      }
      continue;
    }

    if (event.type === "system") {
      lines.push("");
      renderSystem(event, lines);
    } else if (event.type === "assistant") {
      renderAssistant(event, lines, options);
    } else if (event.type === "user") {
      renderUserToolResult(event, lines);
    } else if (event.type === "result") {
      renderResult(event, lines);
    } else if (options.showRaw) {
      lines.push("");
      lines.push(`## Raw Event: ${event.type || "unknown"}`);
      lines.push("");
      lines.push("```json");
      lines.push(prettyJson(event));
      lines.push("```");
    }
  }

  return `${lines.join("\n")}\n`;
}

const options = parseArgs(process.argv.slice(2));
const stdoutPath = resolveInput(options.input);
const transcript = renderTranscript(stdoutPath, options);

if (options.output) {
  fs.writeFileSync(path.resolve(options.output), transcript);
} else {
  process.stdout.write(transcript);
}
