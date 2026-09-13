export class Cache {
  bucket: Record<string, any> = {};

  async get(key: string) {
    return this.bucket[key];
  }

  async set(key: string, value: any, ttl?: number) {
    this.bucket[key] = value;
  }

  async del(key: string) {
    delete this.bucket[key];
  }
}

export const cache = new Cache();
