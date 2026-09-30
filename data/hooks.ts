import { useMemo } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useSQLiteContext } from 'expo-sqlite';
import { LedgerRepository } from './repository';
import { getBackupHistory } from './backup';
import type { TransactionFilters, TransactionInput } from '@/domain/types';

export function useLedgerRepository() {
  const db = useSQLiteContext();
  return useMemo(() => new LedgerRepository(db), [db]);
}

export function useDashboardSummary() {
  const repository = useLedgerRepository();
  return useQuery({ queryKey: ['dashboard'], queryFn: () => repository.getDashboardSummary() });
}

export function useAccounts() {
  const repository = useLedgerRepository();
  return useQuery({ queryKey: ['accounts'], queryFn: () => repository.getAccounts() });
}

export function useCategories(includeArchived = false) {
  const repository = useLedgerRepository();
  return useQuery({
    queryKey: ['categories', includeArchived],
    queryFn: () => repository.getCategories(includeArchived),
  });
}

export function useTransactions(filters: TransactionFilters = {}) {
  const repository = useLedgerRepository();
  return useQuery({ queryKey: ['transactions', filters], queryFn: () => repository.getTransactions(filters) });
}

export function useLoans() {
  const repository = useLedgerRepository();
  return useQuery({ queryKey: ['loans'], queryFn: () => repository.getLoans() });
}

export function useRecurringTransactions() {
  const repository = useLedgerRepository();
  return useQuery({ queryKey: ['recurring'], queryFn: () => repository.getRecurringTransactions() });
}

export function useBackupHistory() {
  const db = useSQLiteContext();
  return useQuery({ queryKey: ['backup-history'], queryFn: () => getBackupHistory(db) });
}

function refreshLedger(queryClient: ReturnType<typeof useQueryClient>) {
  return Promise.all([
    queryClient.invalidateQueries({ queryKey: ['dashboard'] }),
    queryClient.invalidateQueries({ queryKey: ['accounts'] }),
    queryClient.invalidateQueries({ queryKey: ['transactions'] }),
    queryClient.invalidateQueries({ queryKey: ['loans'] }),
    queryClient.invalidateQueries({ queryKey: ['categories'] }),
  ]);
}

export function useCreateTransaction() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: TransactionInput) => repository.createTransaction(input),
    onSuccess: () => refreshLedger(queryClient),
  });
}

export function useDeleteTransaction() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => repository.deleteTransaction(id),
    onSuccess: () => refreshLedger(queryClient),
  });
}

export function useUpdateTransaction() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: TransactionInput }) => repository.updateTransaction(id, input),
    onSuccess: () => refreshLedger(queryClient),
  });
}

export function useCreateAccount() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ name, type }: { name: string; type: Parameters<LedgerRepository['createAccount']>[1] }) =>
      repository.createAccount(name, type),
    onSuccess: () => refreshLedger(queryClient),
  });
}

export function useReconcileAccount() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, balance }: { id: string; balance: number }) => repository.reconcileAccount(id, balance),
    onSuccess: () => refreshLedger(queryClient),
  });
}

export function useCreateCategory() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      name,
      type,
      color,
    }: {
      name: string;
      type: Parameters<LedgerRepository['createCategory']>[1];
      color: string;
    }) => repository.createCategory(name, type, color),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['categories'] }),
  });
}

export function useArchiveCategory() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, archived }: { id: string; archived: boolean }) => repository.setCategoryArchived(id, archived),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['categories'] }),
  });
}

export function useMergeCategories() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ sourceId, targetId }: { sourceId: string; targetId: string }) =>
      repository.mergeCategories(sourceId, targetId),
    onSuccess: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: ['categories'] }),
        queryClient.invalidateQueries({ queryKey: ['transactions'] }),
        queryClient.invalidateQueries({ queryKey: ['recurring'] }),
      ]),
  });
}

export function useCreateLoan() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: Parameters<LedgerRepository['createLoan']>[0]) => repository.createLoan(input),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['loans'] }),
  });
}

export function useRecordLoanPayment() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ loanId, amount, accountId }: { loanId: string; amount: number; accountId?: string | null }) =>
      repository.recordLoanPayment(loanId, amount, accountId),
    onSuccess: () => refreshLedger(queryClient),
  });
}

export function useCreateRecurring() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (input: Parameters<LedgerRepository['createRecurring']>[0]) => {
      const recurring = await repository.createRecurring(input);
      // A start date in the past should post its due occurrences right away, not on the next foreground.
      await repository.postDueRecurring();
      return recurring;
    },
    onSuccess: () =>
      Promise.all([queryClient.invalidateQueries({ queryKey: ['recurring'] }), refreshLedger(queryClient)]),
  });
}

export function useUpdateRecurring() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, patch }: { id: string; patch: Parameters<LedgerRepository['updateRecurring']>[1] }) => {
      await repository.updateRecurring(id, patch);
      await repository.postDueRecurring();
    },
    onSuccess: () =>
      Promise.all([queryClient.invalidateQueries({ queryKey: ['recurring'] }), refreshLedger(queryClient)]),
  });
}

export function useToggleRecurring() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) => repository.setRecurringActive(id, active),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['recurring'] }),
  });
}

export function usePostDueRecurring() {
  const repository = useLedgerRepository();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (now?: Date) => repository.postDueRecurring(now),
    onSuccess: (posted) =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: ['recurring'] }),
        posted ? refreshLedger(queryClient) : undefined,
      ]),
  });
}
