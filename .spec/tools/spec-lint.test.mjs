// spec-lint 自测：用临时仓库验证 FantasyWord 当前认定的 .spec 必需结构。
import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const LINT = join(dirname(fileURLToPath(import.meta.url)), "spec-lint.mjs");

function fixture(overrides = {}) {
  const root = mkdtempSync(join(tmpdir(), "fantasyword-spec-lint-"));
  const files = {
    "AGENTS.md": "# 入口\n\n.spec/AGENTS.md\n.spec/rules/system.md\n.spec/knowledge/README.md\n",
    ".spec/AGENTS.md": "# 中心\n",
    ".spec/rules/system.md": "# 红线\n",
    ".spec/knowledge/README.md": [
      "---",
      "name: knowledge",
      "description: 导航",
      "metadata:",
      "  type: index",
      "  status: 已交付",
      "---",
      "",
      "# 导航",
      "",
      "| 文档 | 何时查 |",
      "|------|--------|",
      "| [workflow](standards/workflow.md) | 工作流 |",
      "| [dispatch](standards/dispatch.md) | 派活 |",
      "| [template](features/_TEMPLATE.md) | 模板 |",
      "| [lessons](lessons.md) | 经验 |",
      "",
    ].join("\n"),
    ".spec/knowledge/lessons.md": "---\nname: lessons\ndescription: 经验\nmetadata:\n  type: doc\n  status: 已交付\n---\n\n# 经验\n",
    ".spec/knowledge/standards/workflow.md": "---\nname: workflow\ndescription: 工作流\nmetadata:\n  type: doc\n  status: 已交付\n---\n\n# 工作流\n",
    ".spec/knowledge/standards/dispatch.md": "---\nname: dispatch\ndescription: 派活\nmetadata:\n  type: doc\n  status: 已交付\n---\n\n# 派活\n",
    ".spec/knowledge/features/_TEMPLATE.md": "---\nname: template\ndescription: 模板\nmetadata:\n  type: doc\n  status: 设计中\n---\n\n# 模板\n",
    ".spec/decisions/README.md": "# 决策\n",
    ".spec/tasks/README.md": "# 任务\n",
    ".spec/tools/spec-lint.test.mjs": "// fixture placeholder\n",
    ...overrides,
  };

  for (const [relativePath, content] of Object.entries(files)) {
    if (content === null) continue;
    const filePath = join(root, relativePath);
    mkdirSync(dirname(filePath), { recursive: true });
    writeFileSync(filePath, content, "utf8");
  }

  return root;
}

function runLint(root) {
  try {
    const output = execFileSync(process.execPath, [LINT], { cwd: root, encoding: "utf8" });
    return { code: 0, output };
  } catch (error) {
    return {
      code: error.status ?? 1,
      output: `${error.stdout ?? ""}${error.stderr ?? ""}`,
    };
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("最小合法结构通过", () => {
  const { code, output } = runLint(fixture());
  assert.equal(code, 0, output);
  assert.match(output, /spec-lint passed/);
});

test("缺少 dispatch 必需文件会失败", () => {
  const { code, output } = runLint(fixture({
    ".spec/knowledge/standards/dispatch.md": null,
  }));
  assert.equal(code, 1);
  assert.match(output, /缺少必需文件：\.spec\/knowledge\/standards\/dispatch\.md/);
});

test("skill frontmatter 多余字段会失败", () => {
  const { code, output } = runLint(fixture({
    ".spec/skills/demo/SKILL.md": "---\nname: demo\ndescription: 演示\ntools: shell\n---\n\n# Demo\n",
  }));
  assert.equal(code, 1);
  assert.match(output, /frontmatter 只允许 name\/description/);
});

test("knowledge 悬空链接会失败", () => {
  const { code, output } = runLint(fixture({
    ".spec/knowledge/README.md": [
      "---",
      "name: knowledge",
      "description: 导航",
      "metadata:",
      "  type: index",
      "  status: 已交付",
      "---",
      "",
      "# 导航",
      "",
      "[missing](standards/missing.md)",
      "",
    ].join("\n"),
  }));
  assert.equal(code, 1);
  assert.match(output, /链接不存在：standards\/missing\.md/);
});
