import type { ResultError } from "../dt/index.js";

export class CancelError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export class RunnableError extends Error {
  errors: ResultError[];
  constructor(message: string, errors: ResultError[]) {
    super(message);
    this.errors = errors;
  }
}
