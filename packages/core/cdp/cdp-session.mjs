/** @file cdp-session.mjs - CDP WebSocket 会话 */
import {
  DEFAULT_COMMAND_TIMEOUT_MS,
  DEFAULT_CONNECT_TIMEOUT_MS,
  buildCdpError,
  buildEvaluationError,
  errorMessage,
  parseLoopbackWebSocketUrl,
  validateDuration,
} from "./cdp-helpers.mjs";

export class CdpSession {
  constructor(
    webSocketDebuggerUrl,
    {
      WebSocketImpl = globalThis.WebSocket,
      commandTimeoutMs = DEFAULT_COMMAND_TIMEOUT_MS,
      connectTimeoutMs = DEFAULT_CONNECT_TIMEOUT_MS,
    } = {},
  ) {
    parseLoopbackWebSocketUrl(webSocketDebuggerUrl);
    if (typeof WebSocketImpl !== "function") {
      throw new TypeError("WebSocketImpl must be a WebSocket constructor");
    }
    validateDuration(commandTimeoutMs, "commandTimeoutMs", { allowZero: false });
    validateDuration(connectTimeoutMs, "connectTimeoutMs", { allowZero: false });

    this.webSocketDebuggerUrl = webSocketDebuggerUrl;
    this.WebSocketImpl = WebSocketImpl;
    this.commandTimeoutMs = commandTimeoutMs;
    this.connectTimeoutMs = connectTimeoutMs;
    this.socket = null;
    this.nextRequestId = 1;
    this.pending = new Map();
    this.socketOpen = false;
    this.opened = false;
    this.closed = false;
    this.closeStarted = false;
    this.terminalError = null;
    this.openPromise = null;
    this.resolveOpen = null;
    this.rejectOpen = null;
    this.connectTimer = null;
  }

  open() {
    if (this.closed) {
      return Promise.reject(this.terminalError ?? new Error("CDP session is closed"));
    }
    if (this.opened) return Promise.resolve(this);
    if (this.openPromise) return this.openPromise;

    this.openPromise = new Promise((resolve, reject) => {
      this.resolveOpen = resolve;
      this.rejectOpen = reject;
    });
    this.connectTimer = setTimeout(() => {
      this.terminate(
        new Error(
          `CDP WebSocket connect timed out after ${this.connectTimeoutMs}ms`,
        ),
      );
      this.closeSocket();
    }, this.connectTimeoutMs);

    try {
      this.socket = new this.WebSocketImpl(this.webSocketDebuggerUrl);
    } catch (error) {
      this.terminate(
        new Error(`failed to open CDP WebSocket: ${errorMessage(error)}`, {
          cause: error,
        }),
      );
      return this.openPromise;
    }

    this.socket.onopen = () => {
      if (this.closed || this.socketOpen) return;
      this.clearConnectTimer();
      this.socketOpen = true;
      Promise.all([this.send("Runtime.enable"), this.send("Page.enable")])
        .then(() => {
          if (this.closed) return;
          this.opened = true;
          const resolve = this.resolveOpen;
          this.resolveOpen = null;
          this.rejectOpen = null;
          resolve?.(this);
        })
        .catch((error) => {
          this.terminate(error);
          this.closeSocket();
        });
    };
    this.socket.onmessage = (event) => this.handleMessage(event);
    this.socket.onerror = (event) => {
      const source = event?.error;
      const detail =
        source instanceof Error
          ? source.message
          : typeof event?.message === "string" && event.message.length > 0
            ? event.message
            : "unknown socket error";
      this.terminate(
        new Error(`CDP WebSocket error: ${detail}`, {
          cause: source instanceof Error ? source : undefined,
        }),
      );
      this.closeSocket();
    };
    this.socket.onclose = (event) => {
      this.closeStarted = true;
      const code = Number.isInteger(event?.code) ? event.code : "unknown";
      const reason =
        typeof event?.reason === "string" && event.reason.length > 0
          ? `, reason: ${event.reason}`
          : "";
      this.terminate(new Error(`CDP WebSocket closed (code: ${code}${reason})`));
    };

    return this.openPromise;
  }

  send(method, params = {}, { timeoutMs = this.commandTimeoutMs } = {}) {
    if (this.closed) {
      return Promise.reject(this.terminalError ?? new Error("CDP session is closed"));
    }
    if (!this.socketOpen || !this.socket) {
      return Promise.reject(new Error("CDP session is not open"));
    }
    if (typeof method !== "string" || method.length === 0) {
      return Promise.reject(new TypeError("CDP method must be a non-empty string"));
    }

    try {
      validateDuration(timeoutMs, "timeoutMs", { allowZero: false });
    } catch (error) {
      return Promise.reject(error);
    }

    const id = this.nextRequestId;
    this.nextRequestId += 1;

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP ${method} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, { method, resolve, reject, timer });

      try {
        this.socket.send(JSON.stringify({ id, method, params }));
      } catch (error) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(
          new Error(`failed to send CDP ${method}: ${errorMessage(error)}`, {
            cause: error,
          }),
        );
      }
    });
  }

  async evaluate(expression, { timeoutMs = this.commandTimeoutMs } = {}) {
    if (typeof expression !== "string") {
      throw new TypeError("Runtime.evaluate expression must be a string");
    }

    const response = await this.send(
      "Runtime.evaluate",
      {
        expression,
        awaitPromise: true,
        returnByValue: true,
      },
      { timeoutMs },
    );

    if (response?.exceptionDetails) {
      throw buildEvaluationError(response.exceptionDetails);
    }
    if (response?.result?.type === "undefined") return undefined;
    return response?.result?.value;
  }

  close() {
    if (this.closeStarted) return;
    this.terminate(new Error("CDP session closed by client"));
    this.closeSocket();
  }

  handleMessage(event) {
    if (typeof event?.data !== "string") {
      this.terminate(new Error("received a non-text CDP WebSocket message"));
      this.closeSocket();
      return;
    }

    let message;
    try {
      message = JSON.parse(event.data);
    } catch (error) {
      this.terminate(
        new Error(`received malformed CDP JSON: ${errorMessage(error)}`, {
          cause: error,
        }),
      );
      this.closeSocket();
      return;
    }

    if (!Number.isInteger(message?.id)) return;
    const pending = this.pending.get(message.id);
    if (!pending) return;

    this.pending.delete(message.id);
    clearTimeout(pending.timer);
    if (message.error) {
      pending.reject(buildCdpError(pending.method, message.error));
      return;
    }
    pending.resolve(message.result);
  }

  terminate(error) {
    if (this.terminalError) return;
    this.clearConnectTimer();
    this.terminalError = error;
    this.closed = true;
    this.socketOpen = false;

    const rejectOpen = this.rejectOpen;
    this.resolveOpen = null;
    this.rejectOpen = null;
    rejectOpen?.(error);

    for (const { reject, timer } of this.pending.values()) {
      clearTimeout(timer);
      reject(error);
    }
    this.pending.clear();
  }

  clearConnectTimer() {
    if (this.connectTimer === null) return;
    clearTimeout(this.connectTimer);
    this.connectTimer = null;
  }

  closeSocket() {
    if (this.closeStarted) return;
    this.closeStarted = true;
    if (!this.socket || typeof this.socket.close !== "function") return;

    const closing = this.WebSocketImpl.CLOSING ?? 2;
    const closed = this.WebSocketImpl.CLOSED ?? 3;
    if (this.socket.readyState === closing || this.socket.readyState === closed) return;
    this.socket.close();
  }
}
