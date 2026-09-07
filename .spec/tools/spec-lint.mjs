#!/usr/bin/env node
/**
 * FantasyWord spec-lint — .spec/ 组织结构一致性机械校验。
 *
 * 校验范围：
 *  1. 核心入口存在，根 AGENTS.md 只做 .spec 指针。
 *  2. ADR 文件名、标题、索引登记和无 frontmatter。
 *  3. 任务卡 frontmatter 只保留 status/owner，status 使用项目枚举。
 *  4. skill / agent / knowledge frontmatter、链接和知识索引可达性。
 *  5. standards 文档必须直接登记到 .spec/knowledge/README.md。
 *  6. UnitySkills 项目入口只能保留薄 SKILL.md，不得把包内 modules / references 镜像复制进 .spec。
 *  7. 废弃入口、迁移残留和运行时引用兜底表述不得回流。
 */
import fs from "node:fs";
import path from "node:path";

const root = process.argv[2] ? path.resolve(process.argv[2]) : process.cwd();
const specRoot = path.join(root, ".spec");
const errors = [];
const statuses = new Set(["设计中", "实施中", "已交付", "历史归档"]);
const retiredProjectRootPaths = [
  "." + "codex",
  "." + "agents",
  "." + "codexbridge",
  "." + "learnings",
  "." + "tmp",
  "AIBridgeCache",
  "docs",
  "skills-lock.json",
  "test-results",
  "_ai_preview_clickmove_gas_attack.jpg",
  path.join("scripts", "Watch-CodexAbort.ps1"),
  path.join("." + "spec", "backups"),
];

function rel(file) {
  return path.relative(root, file).replaceAll(path.sep, "/");
}

function fail(message) {
  errors.push(message);
}

function exists(relativePath) {
  return fs.existsSync(path.join(root, relativePath));
}

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

function parseFrontmatter(file) {
  const text = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  if (!text.startsWith("---\n")) return null;
  const end = text.indexOf("\n---", 4);
  if (end < 0) return null;
  const raw = text.slice(4, end).trim();
  const result = {};
  const lines = raw.split(/\r?\n/);
  for (const line of lines) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (match) result[match[1]] = match[2].trim();
  }
  result.__raw = raw;
  return result;
}

function assertRequiredFiles() {
  const required = [
    "AGENTS.md",
    ".spec/AGENTS.md",
    ".spec/rules/system.md",
    ".spec/knowledge/README.md",
    ".spec/knowledge/lessons.md",
    ".spec/knowledge/standards/dispatch.md",
    ".spec/knowledge/features/_TEMPLATE.md",
    ".spec/decisions/README.md",
    ".spec/tasks/README.md",
    ".spec/tools/spec-lint.test.mjs",
  ];
  for (const file of required) {
    if (!exists(file)) fail(`缺少必需文件：${file}`);
  }
}

function assertRootPointer() {
  const rootAgents = read("AGENTS.md");
  for (const token of [".spec/AGENTS.md", ".spec/rules/system.md", ".spec/knowledge/README.md"]) {
    if (!rootAgents.includes(token)) fail(`根 AGENTS.md 未指向 ${token}`);
  }
}

function assertDecisionRecords() {
  const decisionsDir = path.join(specRoot, "decisions");
  const indexPath = path.join(decisionsDir, "README.md");
  if (!fs.existsSync(indexPath)) return;

  const indexText = fs.readFileSync(indexPath, "utf8");
  if (indexText.startsWith("---")) fail(".spec/decisions/README.md 不应使用 frontmatter；ADR 格式契约由正文说明");

  const decisionFiles = walk(decisionsDir)
    .filter((file) => file.endsWith(".md") && path.basename(file) !== "README.md");

  for (const file of decisionFiles) {
    const name = path.basename(file);
    const text = fs.readFileSync(file, "utf8");
    if (!/^\d{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$/.test(name)) {
      fail(`${rel(file)} ADR 文件名必须是 NNNN-<slug>.md`);
    }
    if (text.startsWith("---")) fail(`${rel(file)} ADR 不应使用 frontmatter`);
    const number = name.slice(0, 4);
    if (!new RegExp(`^#\\s+${number}\\b`, "m").test(text)) {
      fail(`${rel(file)} ADR 标题必须以 "# ${number}" 开头`);
    }
    if (!indexText.includes(`](${name})`)) fail(`${rel(file)} 未登记进 decisions/README.md 索引`);
  }
}

function assertTaskCards() {
  const tasksDir = path.join(specRoot, "tasks");
  const readme = path.join(tasksDir, "README.md");
  if (fs.existsSync(readme) && fs.readFileSync(readme, "utf8").startsWith("---")) {
    fail(".spec/tasks/README.md 不应使用 frontmatter；任务卡格式契约由正文说明");
  }
  if (!fs.existsSync(tasksDir)) return;

  const statusEnum = new Set(["pending", "in_progress", "completed", "active"]);
  for (const entry of fs.readdirSync(tasksDir, { withFileTypes: true })) {
    if (entry.isDirectory() || !entry.name.endsWith(".md") || entry.name === "README.md") continue;
    const file = path.join(tasksDir, entry.name);
    const fm = parseFrontmatter(file);
    if (!fm) {
      fail(`${rel(file)} 任务卡缺少 frontmatter`);
      continue;
    }
    const keys = Object.keys(fm).filter((key) => key !== "__raw");
    for (const key of keys) {
      if (!["status", "owner"].includes(key)) fail(`${rel(file)} 任务卡 frontmatter 只允许 status/owner，发现 ${key}`);
    }
    if (!statusEnum.has(fm.status)) fail(`${rel(file)} status 不在枚举内：${fm.status ?? ""}`);
    if (keys.includes("owner") && !fm.owner) fail(`${rel(file)} owner 不能为空`);
  }
}

function assertNoRetiredEntrypoints() {
  for (const retiredPath of retiredProjectRootPaths) {
    const retiredAbsolute = path.join(root, retiredPath);
    if (fs.existsSync(retiredAbsolute)) {
      fail(`废弃项目入口仍存在：${retiredPath.replaceAll(path.sep, "/")}`);
    }
  }

  const scopedRoots = [
    "AGENTS.md",
    ".spec/AGENTS.md",
    ".spec/rules/system.md",
    ".spec/knowledge",
    ".spec/skills",
    ".spec/agents",
    ".spec/decisions",
    "scripts",
  ];
  const forbidden = [
    new RegExp(["docs", "ai"].join("/"), "i"),
    new RegExp(String.raw`docs\\ai`, "i"),
    new RegExp(["docs", "ai"].join("-"), "i"),
    new RegExp(String.raw`\.` + "codex" + String.raw`[\\/]`, "i"),
    new RegExp(String.raw`\.` + "agents" + String.raw`[\\/]`, "i"),
    new RegExp(String.raw`\.` + "codexbridge", "i"),
    new RegExp(["docs", "archive"].join(String.raw`[\\/]`), "i"),
    new RegExp(String.raw`\.` + "spec" + String.raw`[\\/]backups`, "i"),
    new RegExp("safe-image-reading-" + "disabled", "i"),
    new RegExp("session-" + "hand" + "off", "i"),
    new RegExp(["历史", "兼容"].join("")),
    new RegExp(["兼容", "说明"].join("")),
    new RegExp(["迁移", "版"].join("")),
    new RegExp(["迁移", "来源"].join("")),
    new RegExp(["已迁移", "来源"].join("")),
    new RegExp(["待用户", "决策"].join("")),
    new RegExp(["需要用户", "决策"].join("")),
    new RegExp(["暂", "保留"].join("")),
    new RegExp(["不", "删除"].join("")),
  ];

  for (const scopedRoot of scopedRoots) {
    const absolute = path.join(root, scopedRoot);
    if (!fs.existsSync(absolute)) continue;
    const files = fs.statSync(absolute).isDirectory()
      ? walk(absolute).filter((file) => file.endsWith(".md") || file.endsWith(".mjs"))
      : [absolute];
    for (const file of files) {
      const text = fs.readFileSync(file, "utf8");
      for (const pattern of forbidden) {
        pattern.lastIndex = 0;
        if (pattern.test(text)) fail(`${rel(file)} 包含废弃入口或迁移残留：${pattern}`);
      }
    }
  }
}

function assertNoRetiredIgnoreEntries() {
  const ignorePath = path.join(root, ".gitignore");
  if (!fs.existsSync(ignorePath)) return;

  const text = fs.readFileSync(ignorePath, "utf8");
  const retiredIgnoreEntries = [
    "/.codexbridge/",
    "/AIBridgeCache/",
    "/test-results/",
    "/.learnings/",
    "/docs/archive/",
    "/_ai_preview_*.jpg",
  ];

  for (const entry of retiredIgnoreEntries) {
    if (text.includes(entry)) fail(`.gitignore 仍隐藏废弃入口或阶段证据目录：${entry}`);
  }
}

function assertSkillFrontmatter() {
  const skillsDir = path.join(specRoot, "skills");
  for (const skillFile of walk(skillsDir).filter((file) => path.basename(file) === "SKILL.md")) {
    const fm = parseFrontmatter(skillFile);
    const expectedName = path.basename(path.dirname(skillFile));
    if (!fm) {
      fail(`${rel(skillFile)} 缺少 YAML frontmatter`);
      continue;
    }
    const keys = Object.keys(fm).filter((key) => key !== "__raw");
    for (const key of keys) {
      if (!["name", "description"].includes(key)) fail(`${rel(skillFile)} frontmatter 只允许 name/description，发现 ${key}`);
    }
    if (fm.name !== expectedName) fail(`${rel(skillFile)} name=${fm.name}，应为 ${expectedName}`);
    if (!fm.description) fail(`${rel(skillFile)} 缺少 description`);
  }
}

function assertUnitySkillsThinEntrypoint() {
  const unitySkillsDir = path.join(specRoot, "skills", "unity-skills");
  if (!fs.existsSync(unitySkillsDir)) return;

  const files = walk(unitySkillsDir).map((file) => rel(file));
  const allowed = new Set([".spec/skills/unity-skills/SKILL.md"]);
  for (const file of files) {
    if (!allowed.has(file)) {
      fail(`${file} 是 UnitySkills 上游资料镜像；.spec/skills/unity-skills 只能保留薄 SKILL.md，通用资料读取 Packages/com.besty.unity-skills/unity-skills~`);
    }
  }

  const skillPath = path.join(unitySkillsDir, "SKILL.md");
  if (!fs.existsSync(skillPath)) {
    fail(".spec/skills/unity-skills 缺少 SKILL.md");
    return;
  }

  const skillText = fs.readFileSync(skillPath, "utf8");
  for (const required of [
    "Packages/com.besty.unity-skills/unity-skills~/SKILL.md",
    "Packages/com.besty.unity-skills/unity-skills~/skills/SKILL.md",
    "不在 `.spec/skills/unity-skills/` 内保存上游",
    ".spec/skills/unity-package-management/SKILL.md",
  ]) {
    if (!skillText.includes(required)) fail(`.spec/skills/unity-skills/SKILL.md 缺少薄入口说明：${required}`);
  }
}

function assertAgentFrontmatter() {
  const agentsDir = path.join(specRoot, "agents");
  for (const agentFile of walk(agentsDir).filter((file) => file.endsWith(".agent.md"))) {
    const fm = parseFrontmatter(agentFile);
    const expectedName = path.basename(agentFile, ".agent.md");
    if (!fm) {
      fail(`${rel(agentFile)} 缺少 YAML frontmatter`);
      continue;
    }
    const keys = Object.keys(fm).filter((key) => key !== "__raw");
    for (const key of keys) {
      if (!["name", "description"].includes(key)) fail(`${rel(agentFile)} frontmatter 只允许 name/description，发现 ${key}`);
    }
    if (fm.name !== expectedName) fail(`${rel(agentFile)} name=${fm.name}，应为 ${expectedName}`);
    if (!fm.description) fail(`${rel(agentFile)} 缺少 description`);
  }
}

function assertKnowledgeFrontmatter() {
  const files = walk(path.join(specRoot, "knowledge")).filter((file) => file.endsWith(".md"));
  for (const file of files) {
    const fm = parseFrontmatter(file);
    if (!fm) {
      fail(`${rel(file)} 缺少 YAML frontmatter`);
      continue;
    }
    if (!fm.name) fail(`${rel(file)} 缺少 name`);
    if (!fm.description) fail(`${rel(file)} 缺少 description`);
    if (fm.description && [...fm.description].length > 120) fail(`${rel(file)} description 超过 120 字`);
    const text = fs.readFileSync(file, "utf8");
    const statusMatch = text.match(/status:\s*(.+)/);
    if (statusMatch && !statuses.has(statusMatch[1].trim())) fail(`${rel(file)} status 不在枚举内：${statusMatch[1].trim()}`);
  }
}

function assertKnowledgeLinks() {
  const files = walk(path.join(specRoot, "knowledge")).filter((file) => file.endsWith(".md"));
  const linkPattern = /\[[^\]]+\]\(([^)]+)\)/g;
  for (const file of files) {
    const text = fs.readFileSync(file, "utf8");
    for (const match of text.matchAll(linkPattern)) {
      const target = match[1];
      if (/^(https?:|mailto:|#)/.test(target)) continue;
      const clean = target.split("#")[0];
      if (!clean) continue;
      const resolved = path.resolve(path.dirname(file), clean);
      if (!fs.existsSync(resolved)) fail(`${rel(file)} 链接不存在：${target}`);
    }
  }
}

function resolveKnowledgeTarget(file, target) {
  if (/^(https?:|mailto:|#|[A-Za-z]:\\)/.test(target)) return null;
  const clean = target.split("#")[0].trim();
  if (!clean || !clean.endsWith(".md")) return null;

  const normalized = clean.replaceAll("\\", "/");
  if (normalized.startsWith(".spec/knowledge/")) {
    return path.resolve(root, normalized);
  }
  if (normalized.startsWith("standards/") || normalized.startsWith("features/") || normalized === "lessons.md") {
    return path.resolve(path.join(specRoot, "knowledge"), normalized);
  }
  return path.resolve(path.dirname(file), normalized);
}

function localKnowledgeRouteLinks(file) {
  const links = [];
  const frontmatter = parseFrontmatter(file);
  if (!frontmatter || !/(?:^|\n)\s*type:\s*index\s*$/m.test(frontmatter.__raw)) return links;

  const text = fs.readFileSync(file, "utf8");
  const rows = text
    .split(/\r?\n/)
    .filter((line) => line.trimStart().startsWith("|") || line.trimStart().startsWith("-"));
  const patterns = [
    /\[[^\]]+\]\(([^)]+)\)/g,
    /`([^`]+\.md)`/g,
  ];

  for (const row of rows) {
    for (const pattern of patterns) {
      for (const match of row.matchAll(pattern)) {
        const resolved = resolveKnowledgeTarget(file, match[1]);
        if (resolved && resolved.startsWith(path.join(specRoot, "knowledge")) && fs.existsSync(resolved)) {
          links.push(resolved);
        }
      }
    }
  }

  return links;
}

function assertKnowledgeRouting() {
  const knowledgeRoot = path.join(specRoot, "knowledge");
  const entry = path.join(knowledgeRoot, "README.md");
  if (!fs.existsSync(entry)) return;

  const allKnowledge = walk(knowledgeRoot).filter((file) => file.endsWith(".md"));
  const reachable = new Set();
  const pending = [entry];

  while (pending.length > 0) {
    const file = pending.pop();
    if (reachable.has(file) || !fs.existsSync(file)) continue;
    reachable.add(file);
    for (const target of localKnowledgeRouteLinks(file)) {
      if (!reachable.has(target)) pending.push(target);
    }
  }

  for (const file of allKnowledge) {
    if (!reachable.has(file)) {
      fail(`${rel(file)} 无法从 .spec/knowledge/README.md 的索引链到达，缺少渐进式读取入口`);
    }
  }

  const rootIndex = fs.readFileSync(entry, "utf8");
  for (const standard of walk(path.join(knowledgeRoot, "standards")).filter((file) => file.endsWith(".md"))) {
    const relative = path.relative(knowledgeRoot, standard).replaceAll(path.sep, "/");
    if (!rootIndex.includes(`](${relative})`)) {
      fail(`${rel(standard)} 未直接登记到知识根索引的 standards 路由表`);
    }
  }
}

function assertNoRuntimeFallbackLanguage() {
  const scopedRoots = [
    ".spec/knowledge",
    ".spec/skills",
    ".spec/agents",
  ];
  const forbidden = [
    "运行时查找只作引用缺失兜底",
    "运行时唯一 `Hero` 查找只作为引用缺失兜底",
    "运行时查找只作为引用缺失时的兜底",
    "引用缺失时的兜底",
    "引用缺失兜底",
    "兜底成功",
  ];

  for (const scopedRoot of scopedRoots) {
    const absolute = path.join(root, scopedRoot);
    if (!fs.existsSync(absolute)) continue;
    const files = fs.statSync(absolute).isDirectory()
      ? walk(absolute).filter((file) => file.endsWith(".md"))
      : [absolute];
    for (const file of files) {
      const text = fs.readFileSync(file, "utf8");
      for (const phrase of forbidden) {
        if (text.includes(phrase)) fail(`${rel(file)} 包含禁止的运行时引用兜底表述：${phrase}`);
      }
    }
  }
}

assertRequiredFiles();
assertRootPointer();
assertDecisionRecords();
assertTaskCards();
assertNoRetiredEntrypoints();
assertNoRetiredIgnoreEntries();
assertSkillFrontmatter();
assertUnitySkillsThinEntrypoint();
assertAgentFrontmatter();
assertKnowledgeFrontmatter();
assertKnowledgeLinks();
assertKnowledgeRouting();
assertNoRuntimeFallbackLanguage();

if (errors.length > 0) {
  console.error("spec-lint failed:");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log("spec-lint passed");
