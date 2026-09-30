import { Database } from 'bun:sqlite';

export class MemoryDatabase {
  private readonly database = new Database(':memory:');

  async execAsync(source: string): Promise<void> {
    this.database.exec(source);
  }

  async runAsync(source: string, ...params: Array<string | number | null>): Promise<void> {
    this.database.query(source).run(...params);
  }

  async getFirstAsync<T>(source: string, ...params: Array<string | number | null>): Promise<T | null> {
    return (this.database.query(source).get(...params) as T | undefined) ?? null;
  }

  async getAllAsync<T>(source: string, ...params: Array<string | number | null>): Promise<T[]> {
    return this.database.query(source).all(...params) as T[];
  }

  async withTransactionAsync<T>(task: () => Promise<T>): Promise<T> {
    this.database.exec('BEGIN');
    try {
      const result = await task();
      this.database.exec('COMMIT');
      return result;
    } catch (error) {
      this.database.exec('ROLLBACK');
      throw error;
    }
  }
}
