import * as Notifications from 'expo-notifications';

export async function scheduleLoanReminder(title: string, date: Date): Promise<boolean> {
  const permission = await Notifications.requestPermissionsAsync();
  if (!permission.granted) return false;
  const reminderDate = new Date(date);
  reminderDate.setDate(reminderDate.getDate() - 1);
  if (reminderDate.getTime() <= Date.now()) return false;
  await Notifications.scheduleNotificationAsync({
    content: { title: 'Loan reminder', body: `${title} payment is due tomorrow.` },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: reminderDate },
  });
  return true;
}
