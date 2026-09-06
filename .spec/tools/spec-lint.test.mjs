#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const lintPath = fileURLToPath(new URL("./spec-lint.mjs", import.meta.url));

function run(command, args, cwd) {
  return execFileSync(command, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

function write(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text, "utf8");
}

function docFrontmatter(name, description, type = "doc") {
  return [
    "---",
    `name: ${name}`,
    `description: ${description}`,
    "metadata:",
    `  type: ${type}`,
    "  status: 已交付",
    "---",
    "",
  ].join("\n");
}

function makeFixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "fantasyword-spec-lint-"));

  write(path.join(root, "AGENTS.md"), [
    "# Test",
    ".spec/AGENTS.md",
    ".spec/rules/system.md",
    ".spec/knowledge/README.md",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/AGENTS.md"), "# Spec\n");
  write(path.join(root, ".spec/rules/system.md"), "# Rules\n");
  write(path.join(root, ".spec/decisions/README.md"), [
    "# Decisions",
    "",
    "- [0001-测试决策](0001-test-decision.md)",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/decisions/0001-test-decision.md"), [
    "# 0001-测试决策",
    "",
    "- 状态：已采纳",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/tasks/README.md"), "# Tasks\n");
  write(path.join(root, ".spec/tasks/current-work.md"), [
    "---",
    "status: active",
    "owner: main",
    "---",
    "",
    "# 当前任务",
    "",
  ].join("\n"));

  write(path.join(root, ".spec/knowledge/README.md"), [
    docFrontmatter("knowledge", "结构检查入口", "index"),
    "# Knowledge",
    "",
    "| 文档 | 何时查 |",
    "|------|--------|",
    "| [`standards/code-design.md`](standards/code-design.md) | 写代码时查。 |",
    "| [`features/project/文档索引.md`](features/project/文档索引.md) | 不确定入口时查。 |",
    "| [`lessons.md`](lessons.md) | 经验池。 |",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/knowledge/standards/code-design.md"), [
    docFrontmatter("code-design", "代码设计规范"),
    "# Code Design",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/knowledge/features/project/文档索引.md"), [
    docFrontmatter("文档索引", "项目文档索引", "index"),
    "# 文档索引",
    "",
    "- Bug 排查入口：`Bug排查索引.md`",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/knowledge/features/project/Bug排查索引.md"), [
    docFrontmatter("Bug排查索引", "Bug 案例索引", "index"),
    "# Bug 排查索引",
    "",
    "- 案例：`bugs/已登记案例.md`",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/knowledge/features/project/bugs/已登记案例.md"), [
    docFrontmatter("已登记案例", "已登记案例"),
    "# 已登记案例",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/knowledge/lessons.md"), [
    docFrontmatter("lessons", "经验池"),
    "# Lessons",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/skills/before-you-code/SKILL.md"), [
    "---",
    "name: before-you-code",
    "description: 动手前协议",
    "---",
    "",
    "# Before You Code",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/agents/reviewer.agent.md"), [
    "---",
    "name: reviewer",
    "description: 审查角色",
    "---",
    "",
    "# Reviewer",
    "",
  ].join("\n"));

  return root;
}

test("accepts FantasyWord spec shape", () => {
  const root = makeFixture();
  assert.equal(run(process.execPath, [lintPath, root], root).trim(), "spec-lint passed");
});

test("rejects standards that are not registered in the root knowledge index", () => {
  const root = makeFixture();
  write(path.join(root, ".spec/knowledge/standards/unindexed-standard.md"), [
    docFrontmatter("unindexed-standard", "未登记标准"),
    "# Missing",
    "",
  ].join("\n"));

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /未直接登记到知识根索引/);
});

test("rejects knowledge files that cannot be reached through index documents", () => {
  const root = makeFixture();
  write(path.join(root, ".spec/knowledge/features/project/bugs/未登记案例.md"), [
    docFrontmatter("未登记案例", "未登记案例"),
    "# 未登记案例",
    "",
  ].join("\n"));

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /无法从 \.spec\/knowledge\/README\.md/);
});

test("rejects copied UnitySkills package docs inside project skill entry", () => {
  const root = makeFixture();
  write(path.join(root, ".spec/skills/unity-skills/SKILL.md"), [
    "---",
    "name: unity-skills",
    "description: UnitySkills 项目薄入口",
    "---",
    "",
    "# UnitySkills",
    "",
    "Packages/com.besty.unity-skills/unity-skills~/SKILL.md",
    "Packages/com.besty.unity-skills/unity-skills~/skills/SKILL.md",
    "不在 `.spec/skills/unity-skills/` 内保存上游",
    ".spec/skills/unity-package-management/SKILL.md",
    "",
  ].join("\n"));
  write(path.join(root, ".spec/skills/unity-skills/skills/scene/SKILL.md"), [
    "---",
    "name: scene",
    "description: 错误复制的上游模块",
    "---",
    "",
    "# Scene",
    "",
  ].join("\n"));

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /UnitySkills 上游资料镜像/);
});

test("rejects retired project roots", () => {
  const root = makeFixture();
  write(path.join(root, "." + "codex", "skills", "old", "SKILL.md"), "# old\n");

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /废弃项目入口仍存在/);
});

test("rejects retired project-local diagnostics script", () => {
  const root = makeFixture();
  write(path.join(root, "scripts", "Watch-CodexAbort.ps1"), "# old host diagnostic\n");

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /废弃项目入口仍存在/);
});

test("rejects retired project skill lock", () => {
  const root = makeFixture();
  write(path.join(root, "skills-lock.json"), JSON.stringify({ version: 1, skills: {} }));

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /废弃项目入口仍存在/);
});

test("rejects retired ignore entries", () => {
  const root = makeFixture();
  fs.appendFileSync(path.join(root, ".gitignore"), "/.codexbridge/\n/AIBridgeCache/\n/test-results/\n/.learnings/\n/docs/archive/legacy-recovery/MigrationStaging/\n/_ai_preview_*.jpg\n", "utf8");

  const result = spawnSync(process.execPath, [lintPath, root], { cwd: root, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /\.gitignore 仍隐藏废弃入口或阶段证据目录/);
});
