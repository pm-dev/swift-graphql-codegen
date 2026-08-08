class AbortSignal {
  constructor() {
    this.aborted = false;
    this.listeners = new Map();
    this.onabort = null;
    this.reason = undefined;
  }

  addEventListener(type, listener, options = {}) {
    if (type === 'abort') {
      this.listeners.set(listener, options.once === true);
    }
  }

  removeEventListener(type, listener) {
    if (type === 'abort') {
      this.listeners.delete(listener);
    }
  }

  throwIfAborted() {
    if (this.aborted) {
      throw this.reason;
    }
  }

  abort(reason) {
    if (this.aborted) {
      return;
    }
    this.aborted = true;
    this.reason = reason;
    const event = { type: 'abort', target: this };
    if (this.onabort !== null) {
      this.onabort(event);
    }
    for (const [listener, once] of this.listeners) {
      if (typeof listener === 'function') {
        listener(event);
      } else {
        listener.handleEvent(event);
      }
      if (once) {
        this.listeners.delete(listener);
      }
    }
  }
}

class AbortController {
  constructor() {
    this.signal = new AbortSignal();
  }

  abort(reason) {
    if (reason === undefined) {
      reason = new Error('This operation was aborted');
      reason.name = 'AbortError';
    }
    this.signal.abort(reason);
  }
}

globalThis.AbortController ??= AbortController;
globalThis.AbortSignal ??= AbortSignal;
