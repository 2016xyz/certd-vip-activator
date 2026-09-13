// @ts-ignore
import AsyncLock from "async-lock";

export class Locker {
  private asyncLocker: AsyncLock;

  constructor() {
    this.asyncLocker = new AsyncLock();
  }

  async execute(lockStr: string, callback: any, options?: { timeout?: number }) {
    const timeout = options?.timeout ?? 120000;
    return this.asyncLocker.acquire(lockStr, callback, { timeout });
  }
}

export const locker = new Locker();
