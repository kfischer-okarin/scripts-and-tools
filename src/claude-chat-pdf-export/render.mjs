#!/usr/bin/env node
// Render a Claude.ai conversation JSON into a standalone HTML file.
// Usage: node render.mjs <input.json> [output.html]

import { readFile, writeFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { createRequire } from "node:module";
import { marked } from "marked";

const require = createRequire(import.meta.url);
const { renderConversation } = require("./extension/renderer.js");

async function main() {
  const [inputArg, outputArg] = process.argv.slice(2);
  if (!inputArg) {
    console.error("usage: render.mjs <input.json> [output.html]");
    process.exit(1);
  }
  const inputPath = resolve(inputArg);
  const outputPath = resolve(outputArg || inputPath.replace(/\.json$/, ".html"));
  const conv = JSON.parse(await readFile(inputPath, "utf8"));
  marked.setOptions({ gfm: true, breaks: false });
  const html = renderConversation(conv, (md) => marked.parse(md));
  await writeFile(outputPath, html, "utf8");
  console.log(outputPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
