#!/usr/bin/env node
/**
 * @file cli.mjs
 * @description codex-skin 统一 CLI（主题控制面 + 诊断）
 *
 * 模块边界：
 * - packages/core     发现 Codex / CDP / doctor
 * - packages/themes   主题读写与 DreamSkin 适配
 * - apps/launcher     日常打开 Codex（PowerShell，默认安静）
 *
 * apply：写 active-theme → 控制面 /kick → watch 热更新
 *   （不再允许 --once heige 旁路，避免与 DreamSkin CSS 叠层）
 */
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  classifyInjection,
  discoverActiveCdpPort,
  discoverCodex,
  runtimeDiagnostics,
} from "./index.mjs";
import { DEFAULT_CDP_PORT, DEFAULT_THEME_ID, resolveStudioPaths } from "./constants.mjs";
import { detectDreamSkinRuntime } from "./state/dreamskin-guard.mjs";
import { formatKickResultNote, kickThemeInjectNow } from "./state/kick-inject.mjs";
import { inspectInjectorPathFreshness } from "./state/state-freshness.mjs";
import {
  importAllBundledThemes,
  listThemes,
  createSingleImageTheme,
  touchThemesCatalog,
  writeActiveThemeFromHeige,
} from "../themes/index.mjs";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const bundledThemesRoot = join(repoRoot, "themes");

// All CLI options currently take a value (--theme ID, --image PATH, --port N).
// If a future boolean flag is added, list its name here.
const BOOLEAN_FLAGS = new Set();

function options(argv) {
  const result = {};
  for (let index = 1; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith("--")) throw new Error(`无法识别的参数：${key}`);
    const name = key.slice(2);
    if (BOOLEAN_FLAGS.has(name)) {
      result[name] = true;
      continue;
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`${key} 缺少值`);
    result[name] = value;
    index += 1;
  }
  return result;
}

function portFrom(value) {
  const port = value === undefined ? DEFAULT_CDP_PORT : Number(value);
  if (!Number.isInteger(port) || port < 1024 || port > 65535) {
    throw new Error("--port 必须是 1024 到 65535 的整数");
  }
  return port;
}

async function resolvePort(args, deps) {
  if (args.port !== undefined) return { port: portFrom(args.port), source: "flag" };
  const preferred = DEFAULT_CDP_PORT;
  const discovered = await (deps.discoverActiveCdpPort ?? discoverActiveCdpPort)({
    preferredPort: preferred,
  });
  return {
    port: discovered.open ? discovered.port : preferred,
    source: discovered.open ? discovered.source : "default",
    open: discovered.open,
    browser: discovered.browser ?? null,
  };
}

function defaults(overrides) {
  const paths = resolveStudioPaths();
  return {
    bundledThemesRoot,
    userThemesRoot: paths.userThemesRoot,
    devThemesRoot: paths.devThemesRoot,
    dreamStateRoot: paths.dreamStateRoot,
    installRoot: paths.installRoot,
    listThemes,
    createSingleImageTheme,
    discoverActiveCdpPort,
    discoverCodex,
    runtimeDiagnostics,
    detectDreamSkinRuntime,
    writeActiveThemeFromHeige,
    importAllBundledThemes,
    touchThemesCatalog,
    ...overrides,
  };
}

export async function runCli(argv, overrides = {}) {
  const command = argv[0] ?? "help";
  const args = options(argv);
  const deps = defaults(overrides);
  // User store last so listThemes de-dupe prefers installed catalog over repo copies.
  const roots = [deps.bundledThemesRoot, deps.devThemesRoot, deps.userThemesRoot];

  if (command === "help") {
    return {
      product: "codex-skin",
      dailyEntry: "任务栏 / 开始菜单 Codex（CodexDreamSkin 启动器 + watch injector）",
      defaultCdpPort: DEFAULT_CDP_PORT,
      commands: [
        "list",
        "create --image PATH --name NAME",
        "import-themes",
        "apply --theme ID                 # 写 active-theme，交给 watch 热更新",
        "pause | restore | status | doctor",
      ],
      notes: [
        "默认 apply 不再启动第二套 injector，只更新 %LOCALAPPDATA%\\CodexDreamSkin\\active-theme。",
        "请先用任务栏 Codex 打开带 watch 的会话；改主题后数秒内应自动换肤。",
        "import-themes 会把仓内 10 套主题导入 DreamSkin themes 目录（需先 unlock）。",
      ],
    };
  }

  if (command === "list") {
    const themes = await deps.listThemes({ roots, preferRoot: deps.userThemesRoot, dedupe: true });
    return {
      count: themes.length,
      userThemesRoot: deps.userThemesRoot,
      themes,
    };
  }

  if (command === "create") {
    if (!args.image) throw new Error("create 需要 --image");
    if (!args.name) throw new Error("create 需要 --name");
    return deps.createSingleImageTheme({
      imagePath: args.image,
      name: args.name,
      storeRoot: deps.devThemesRoot,
    });
  }

  if (command === "import-themes") {
    const result = await deps.importAllBundledThemes({
      bundledRoot: deps.bundledThemesRoot,
      stateRoot: deps.dreamStateRoot,
    });
    await deps.touchThemesCatalog(deps.dreamStateRoot);
    return {
      mode: "import-themes",
      importedCount: result.imported.length,
      failedCount: result.failed.length,
      ...result,
    };
  }

  if (command === "apply") {
    const themeId = args.theme ?? DEFAULT_THEME_ID;
    const themes = await deps.listThemes({ roots, preferRoot: deps.userThemesRoot, dedupe: true });
    const selected = themes.find((theme) => theme.id === themeId);
    if (!selected) throw new Error(`找不到主题：${themeId}`);

    // dream summary is only used for the response envelope; run it alongside
    // the theme write instead of before it.
    const detect = deps.detectDreamSkinRuntime ?? detectDreamSkinRuntime;
    const [written, dream] = await Promise.all([
      deps.writeActiveThemeFromHeige({
        heigeThemeDir: selected.path,
        stateRoot: deps.dreamStateRoot,
      }),
      detect(),
    ]);
    await deps.touchThemesCatalog(deps.dreamStateRoot);
    const kick = await kickThemeInjectNow({
      stateRoot: deps.dreamStateRoot,
      installRoot: deps.installRoot,
    });
    return {
      mode: "hot-active-theme",
      themeId: written.id,
      name: written.name,
      activeRoot: written.activeRoot,
      themePath: written.themePath,
      imageName: written.imageName,
      dreamSkin: dream.summary,
      injectorAlive: dream.injectorAlive,
      kick,
      note: formatKickResultNote(kick),
    };
  }

  if (command === "pause" || command === "restore") {
    // DreamSkin pause file: watch injector honors it (skips ensure).
    const { writeFile, rm } = await import("node:fs/promises");
    if (command === "pause") {
      await writeFile(join(deps.dreamStateRoot, "paused"), "paused\n", "utf8");
    } else {
      await rm(join(deps.dreamStateRoot, "paused"), { force: true });
    }
    return { mode: command, paused: command === "pause" };
  }

  if (command === "status") {
    const [dream, resolved] = await Promise.all([
      (deps.detectDreamSkinRuntime ?? detectDreamSkinRuntime)(),
      resolvePort(args, deps),
    ]);
    return {
      port: resolved.port,
      portSource: resolved.source,
      dreamSkin: dream,
    };
  }

  if (command === "doctor") {
    const requestedPort = args.port !== undefined ? portFrom(args.port) : DEFAULT_CDP_PORT;
    // discovery.app is needed for runtimeDiagnostics; the other three are
    // independent — run them alongside discovery instead of after it.
    const [discovery, dreamSkin, themes, injectorPathFreshness] = await Promise.all([
      (deps.discoverCodex ?? discoverCodex)(),
      (deps.detectDreamSkinRuntime ?? detectDreamSkinRuntime)(),
      deps.listThemes({ roots, preferRoot: deps.userThemesRoot, dedupe: true }),
      inspectInjectorPathFreshness({
        installRoot: deps.installRoot,
        stateRoot: deps.dreamStateRoot,
      }),
    ]);
    const runtime = await (deps.runtimeDiagnostics ?? runtimeDiagnostics)({
      appPath: discovery.app,
      port: requestedPort,
      autoDiscoverPort: args.port === undefined,
    });
    const freshnessNote = injectorPathFreshness.fresh
      ? "injector 路径与 current runtime 对齐"
      : `injector 路径漂移：${injectorPathFreshness.reason}`;
    const userThemeCount = themes.filter((t) => t.source === "user").length;
    return {
      product: "codex-skin",
      repoRoot,
      ...discovery,
      cdpPort: runtime.activePort ?? requestedPort,
      requestedPort,
      ...runtime,
      dreamSkin,
      themeCount: themes.length,
      userThemeCount,
      injectorPathFreshness,
      dailyEntry: "CodexDreamSkin（任务栏 Codex）",
      diagnosis: [
        dreamSkin.injectorAlive
          ? `${classifyInjection(runtime)}；watch injector 存活，可用 apply --theme 热切换`
          : `${classifyInjection(runtime)}；watch injector 未检测到，请先点任务栏 Codex`,
        freshnessNote,
      ].join("；"),
    };
  }

  throw new Error(`未知命令：${command}`);
}

function isMainEntry() {
  const entry = process.argv[1];
  if (!entry) return false;
  let real = entry;
  try {
    real = realpathSync(entry);
  } catch {
    // keep original
  }
  return pathToFileURL(real).href === import.meta.url;
}

if (isMainEntry()) {
  runCli(process.argv.slice(2))
    .then((result) => process.stdout.write(`${JSON.stringify(result, null, 2)}\n`))
    .catch((error) => {
      process.stderr.write(`codex-skin：${error.message}\n`);
      process.exitCode = 1;
    });
}
