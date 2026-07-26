/**
 * @file cdp-exposure.mjs - CDP 监听地址暴露面检查（doctor 用 · CV-CR-001）
 *
 * 威胁模型：CDP evaluate 是本机信任边界 —— 任何能连上 9335 的本机进程
 * 都能注入 Codex 渲染进程。本模块只回答一个问题：该端口是否只绑 loopback。
 * 监听到 0.0.0.0 / [::] / 局域网地址 → doctor 必须给出显式警告。
 *
 * 纯函数（parse/evaluate）无 IO，可单测；inspectCdpExposure 在 win32 上
 * 调 netstat（无需管理员），其余平台标记 not-checked（产品 Windows-only）。
 */
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { isValidPort } from "./cdp-helpers.mjs";

const execFileAsync = promisify(execFile);

/** 固定安全提示：随 doctor JSON 一起输出，勿删。 */
export const CDP_LOCAL_TRUST_ADVICE =
  "CDP 是本机信任边界（CV-CR-001）：任何能连上该端口的本机进程都可经 Runtime.evaluate 影响 Codex 渲染进程；" +
  "请勿用防火墙放行规则 / netsh portproxy / 端口转发把 CDP 或控制面端口暴露到局域网或公网。";

/** @param {string} address netstat 本地地址列（不含端口），如 "127.0.0.1" / "[::1]" / "0.0.0.0" / "[::]" */
export function isLoopbackListenAddress(address) {
  if (typeof address !== "string" || address.length === 0) return false;
  const bare = address.replace(/^\[|\]$/g, "");
  if (bare === "::1") return true;
  // 127.0.0.0/8 全段算 loopback；0.0.0.0 / :: 是通配，明确不算
  return /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(bare);
}

/**
 * 解析 `netstat -ano -p tcp|tcpv6` 输出，取指定端口的 LISTENING 行。
 * @param {string} stdout
 * @param {number} port
 * @returns {Array<{ address: string, port: number, pid: number | null }>}
 */
export function parseNetstatListeners(stdout, port) {
  const listeners = [];
  if (typeof stdout !== "string" || !isValidPort(port)) return listeners;
  for (const rawLine of stdout.split(/\r?\n/)) {
    const parts = rawLine.trim().split(/\s+/);
    if (parts.length < 4) continue;
    const [proto, local, , state] = parts;
    if (!/^tcp$/i.test(proto)) continue;
    if (!/^listening$/i.test(state)) continue;
    const splitAt = local.lastIndexOf(":");
    if (splitAt <= 0) continue;
    const localPort = Number(local.slice(splitAt + 1));
    if (localPort !== port) continue;
    const pid = parts.length >= 5 ? Number(parts[4]) : NaN;
    listeners.push({
      address: local.slice(0, splitAt),
      port: localPort,
      pid: Number.isInteger(pid) ? pid : null,
    });
  }
  return listeners;
}

/**
 * 纯判定：给定监听列表 → 暴露面结论。
 * @param {{ port?: number, listeners?: Array<{ address: string }>, checked?: boolean, reason?: string | null }} input
 */
export function evaluateCdpExposure({
  port,
  listeners = [],
  checked = true,
  reason = null,
} = {}) {
  const result = {
    port: isValidPort(port) ? port : null,
    checked: Boolean(checked),
    reason: reason ?? (checked ? "ok" : "not-checked"),
    listening: false,
    /** null = 未监听或未检查；true = 仅 loopback；false = 有非 loopback 监听 */
    loopbackOnly: null,
    exposedAddresses: [],
    advice: CDP_LOCAL_TRUST_ADVICE,
  };
  if (!result.checked) return result;
  result.listening = listeners.length > 0;
  if (!result.listening) return result;
  const exposed = listeners.filter((entry) => !isLoopbackListenAddress(entry.address));
  result.exposedAddresses = [...new Set(exposed.map((entry) => entry.address))];
  result.loopbackOnly = exposed.length === 0;
  return result;
}

/**
 * 面向 doctor 的一行结论（中文，与 diagnosis 其余分句风格一致）。
 * @param {ReturnType<typeof evaluateCdpExposure>} exposure
 */
export function formatCdpExposureNote(exposure) {
  if (!exposure.checked) return `CDP 暴露面未检查（${exposure.reason}）`;
  if (!exposure.listening) return "CDP 端口未在监听（Codex 未运行或未带调试参数）";
  if (exposure.loopbackOnly) return "CDP 仅监听 loopback，符合本机信任边界";
  return (
    `警告：CDP 端口 ${exposure.port} 监听非 loopback 地址（${exposure.exposedAddresses.join(", ")}）；` +
    "调试端口不应暴露到局域网，请移除端口转发 / 防火墙放行规则"
  );
}

/**
 * win32 实测：netstat -ano（IPv4 + IPv6 两次），失败降级为 not-checked。
 * @param {{ port: number, platform?: NodeJS.Platform, exec?: typeof execFileAsync }} opts
 */
export async function inspectCdpExposure({
  port,
  platform = process.platform,
  exec = execFileAsync,
} = {}) {
  if (!isValidPort(port)) {
    return evaluateCdpExposure({ port, checked: false, reason: "invalid-port" });
  }
  if (platform !== "win32") {
    return evaluateCdpExposure({ port, checked: false, reason: "platform-unsupported" });
  }
  const listeners = [];
  let sawOutput = false;
  for (const proto of ["tcp", "tcpv6"]) {
    try {
      const { stdout } = await exec("netstat", ["-ano", "-p", proto], { windowsHide: true });
      sawOutput = true;
      listeners.push(...parseNetstatListeners(stdout, port));
    } catch {
      // 单协议失败不致命；两次都失败在下方兜底
    }
  }
  if (!sawOutput) {
    return evaluateCdpExposure({ port, checked: false, reason: "netstat-failed" });
  }
  return evaluateCdpExposure({ port, listeners });
}
