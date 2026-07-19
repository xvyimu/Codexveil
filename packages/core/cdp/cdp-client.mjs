/**
 * @file cdp-client.mjs
 * @description CDP 客户端出口（兼容旧 import 路径）
 * 子模块：cdp-helpers / cdp-targets / cdp-session
 */
export {
  filterRendererTargets,
  fetchRendererTargets,
  waitForRendererTargets,
} from "./cdp-targets.mjs";
export { CdpSession } from "./cdp-session.mjs";
