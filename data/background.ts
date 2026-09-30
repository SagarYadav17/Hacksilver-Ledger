import * as BackgroundTask from 'expo-background-task';
import * as TaskManager from 'expo-task-manager';
import type { SQLiteDatabase } from 'expo-sqlite';
import { openLedgerDatabase } from './database';
import { LedgerRepository } from './repository';
import { syncService } from './sync';

export const BACKGROUND_SYNC_TASK = 'hacksilver-background-sync';

TaskManager.defineTask(BACKGROUND_SYNC_TASK, async () => {
  let db: SQLiteDatabase | null = null;
  try {
    db = await openLedgerDatabase();
    await new LedgerRepository(db).postDueRecurring();
    const result = await syncService.restoreSession();
    if (!result) return BackgroundTask.BackgroundTaskResult.Success;
    const sync = await syncService.sync(db);
    return sync.success ? BackgroundTask.BackgroundTaskResult.Success : BackgroundTask.BackgroundTaskResult.Failed;
  } catch {
    return BackgroundTask.BackgroundTaskResult.Failed;
  } finally {
    await db?.closeAsync().catch(() => undefined);
  }
});

export async function registerBackgroundSync(): Promise<void> {
  try {
    const status = await BackgroundTask.getStatusAsync();
    if (status !== BackgroundTask.BackgroundTaskStatus.Available) return;
    const registered = await TaskManager.isTaskRegisteredAsync(BACKGROUND_SYNC_TASK);
    if (!registered) await BackgroundTask.registerTaskAsync(BACKGROUND_SYNC_TASK, { minimumInterval: 360 });
  } catch {
    // Background scheduling is intentionally best effort; foreground sync remains available.
  }
}
