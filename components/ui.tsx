import { PropsWithChildren, useCallback, useEffect, useState } from 'react';
import { useFocusEffect, useRouter } from 'expo-router';
import {
  Animated,
  Easing,
  Pressable,
  PressableProps,
  ScrollView,
  StyleProp,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { Circle, Defs, LinearGradient, Line, Path, Stop, Svg } from 'react-native-svg';
import { colors, radius, spacing, useAppTheme } from '@/lib/theme';
import { formatCurrency, formatRelativeDate, titleCase } from '@/lib/format';
import type { Account, Transaction } from '@/domain/types';
import { useAppStore } from '@/store/app-store';

export function Screen({ children, scroll = true, style }: PropsWithChildren<{ scroll?: boolean; style?: ViewStyle }>) {
  const { colors: theme } = useAppTheme();
  const [progress] = useState(() => new Animated.Value(0));
  useFocusEffect(
    useCallback(() => {
      progress.setValue(0);
      const animation = Animated.timing(progress, {
        toValue: 1,
        duration: 280,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      });
      animation.start();
      return () => animation.stop();
    }, [progress]),
  );
  const motionStyle = {
    opacity: progress,
    transform: [
      {
        translateY: progress.interpolate({ inputRange: [0, 1], outputRange: [10, 0] }),
      },
    ],
  };
  const content = (
    <Animated.View style={[styles.screen, { backgroundColor: theme.canvas }, style, motionStyle]}>
      {children}
    </Animated.View>
  );
  return scroll ? (
    <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
      {content}
    </ScrollView>
  ) : (
    content
  );
}

type MotionPressableProps = PropsWithChildren<Omit<PressableProps, 'style'> & { style?: StyleProp<ViewStyle> }>;

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function MotionPressable({ children, style, onPressIn, onPressOut, ...props }: MotionPressableProps) {
  const [scale] = useState(() => new Animated.Value(1));
  const animateTo = (value: number) => {
    Animated.spring(scale, {
      toValue: value,
      damping: 18,
      stiffness: 260,
      mass: 0.6,
      useNativeDriver: true,
    }).start();
  };
  return (
    <AnimatedPressable
      {...props}
      onPressIn={(event) => {
        animateTo(0.97);
        onPressIn?.(event);
      }}
      onPressOut={(event) => {
        animateTo(1);
        onPressOut?.(event);
      }}
      style={[style, { transform: [{ scale }] }]}
    >
      {children}
    </AnimatedPressable>
  );
}

export function AnimatedEntry({
  children,
  delay = 0,
  style,
}: PropsWithChildren<{ delay?: number; style?: StyleProp<ViewStyle> }>) {
  const [progress] = useState(() => new Animated.Value(0));
  useEffect(() => {
    progress.setValue(0);
    const animation = Animated.timing(progress, {
      toValue: 1,
      duration: 240,
      delay,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    });
    animation.start();
    return () => animation.stop();
  }, [delay, progress]);
  return (
    <Animated.View
      style={[
        style,
        {
          opacity: progress,
          transform: [{ translateY: progress.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }],
        },
      ]}
    >
      {children}
    </Animated.View>
  );
}

export function Header({
  title,
  eyebrow,
  action,
  onAction,
}: {
  title: string;
  eyebrow?: string;
  action?: string;
  onAction?: () => void;
}) {
  const { colors: theme } = useAppTheme();
  return (
    <View style={styles.header}>
      <View>
        <Text style={[styles.eyebrow, { color: theme.inkMuted }]}>{eyebrow?.toUpperCase()}</Text>
        <Text style={[styles.title, { color: theme.ink }]}>{title}</Text>
      </View>
      {action && (
        <MotionPressable onPress={onAction} hitSlop={10}>
          <Text style={[styles.headerAction, { color: theme.primary }]}>{action}</Text>
        </MotionPressable>
      )}
    </View>
  );
}

export function SectionHeader({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  const { colors: theme } = useAppTheme();
  return (
    <View style={styles.sectionHeader}>
      <Text style={[styles.sectionTitle, { color: theme.ink }]}>{title}</Text>
      {action && (
        <MotionPressable onPress={onAction}>
          <Text style={[styles.headerAction, { color: theme.primary }]}>{action}</Text>
        </MotionPressable>
      )}
    </View>
  );
}

export function MetricCard({
  label,
  value,
  detail,
  tone = 'default',
  large = false,
}: {
  label: string;
  value: string;
  detail?: string;
  tone?: 'default' | 'positive' | 'negative';
  large?: boolean;
}) {
  const { colors: theme } = useAppTheme();
  const background = tone === 'positive' ? theme.primarySoft : tone === 'negative' ? theme.expenseSoft : theme.surface;
  return (
    <View
      style={[
        styles.metricCard,
        { backgroundColor: background, borderColor: theme.line },
        large && styles.metricCardLarge,
      ]}
    >
      <Text style={[styles.metricLabel, { color: theme.inkMuted }]}>{label}</Text>
      <Text style={[large ? styles.metricValueLarge : styles.metricValue, { color: theme.ink }]}>{value}</Text>
      {detail && <Text style={[styles.metricDetail, { color: theme.inkMuted }]}>{detail}</Text>}
    </View>
  );
}

export function BalanceChart({ values, markerIndex }: { values: number[]; markerIndex?: number }) {
  const { colors: theme } = useAppTheme();
  const safeValues = values.length > 1 ? values : [values[0] ?? 0, values[0] ?? 0];
  const min = Math.min(...safeValues);
  const max = Math.max(...safeValues);
  const range = Math.max(max - min, 1);
  const points = safeValues.map((value, index) => ({
    x: 8 + (index / (safeValues.length - 1)) * 304,
    y: 18 + (1 - (value - min) / range) * 104,
  }));
  const linePath = points.map((point, index) => `${index === 0 ? 'M' : 'L'} ${point.x} ${point.y}`).join(' ');
  const areaPath = `${linePath} L ${points.at(-1)?.x ?? 312} 140 L ${points[0]?.x ?? 8} 140 Z`;
  const currentPoint = points[Math.min(markerIndex ?? points.length - 1, points.length - 1)] ?? points.at(-1)!;

  return (
    <View style={styles.balanceChart}>
      <View pointerEvents="none" style={styles.chartGrid}>
        {[0, 1, 2, 3].map((row) => (
          <View key={row} style={[styles.chartGridLine, { backgroundColor: theme.line }]} />
        ))}
      </View>
      <Svg width="100%" height="100%" viewBox="0 0 320 150" preserveAspectRatio="none">
        <Defs>
          <LinearGradient id="balanceFill" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor={theme.primary} stopOpacity="0.18" />
            <Stop offset="1" stopColor={theme.primary} stopOpacity="0" />
          </LinearGradient>
        </Defs>
        <Path d={areaPath} fill="url(#balanceFill)" />
        <Path
          d={linePath}
          fill="none"
          stroke={theme.primary}
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <Line
          x1={currentPoint.x}
          x2={currentPoint.x}
          y1="8"
          y2="140"
          stroke={theme.primary}
          strokeWidth="2"
          strokeDasharray="6 6"
          opacity="0.8"
        />
        <Circle
          cx={currentPoint.x}
          cy={currentPoint.y}
          r="8"
          fill={theme.surface}
          stroke={theme.primary}
          strokeWidth="4"
        />
        <Circle
          cx={points.at(-1)?.x}
          cy={points.at(-1)?.y}
          r="6"
          fill={theme.surface}
          stroke={theme.primary}
          strokeWidth="3"
          opacity="0.55"
        />
      </Svg>
    </View>
  );
}

export function Pill({
  label,
  selected = false,
  tone = 'default',
  onPress,
}: {
  label: string;
  selected?: boolean;
  tone?: 'default' | 'income' | 'expense' | 'transfer';
  onPress?: () => void;
}) {
  const { colors: theme } = useAppTheme();
  const background = selected
    ? theme.primary
    : tone === 'income'
      ? theme.incomeSoft
      : tone === 'expense'
        ? theme.expenseSoft
        : tone === 'transfer'
          ? theme.transferSoft
          : theme.surfaceAlt;
  return (
    <MotionPressable onPress={onPress} style={[styles.pill, { backgroundColor: background }]}>
      <Text
        style={[
          styles.pillText,
          {
            color: selected
              ? theme.white
              : tone === 'income'
                ? theme.income
                : tone === 'expense'
                  ? theme.expense
                  : theme.inkMuted,
          },
        ]}
      >
        {label}
      </Text>
    </MotionPressable>
  );
}

export function EmptyState({
  icon = 'auto-graph',
  title,
  message,
  action,
  onAction,
}: {
  icon?: keyof typeof MaterialIcons.glyphMap;
  title: string;
  message: string;
  action?: string;
  onAction?: () => void;
}) {
  const { colors: theme } = useAppTheme();
  return (
    <View style={[styles.empty, { backgroundColor: theme.surface, borderColor: theme.line }]}>
      <View style={[styles.emptyIcon, { backgroundColor: theme.primarySoft }]}>
        <MaterialIcons name={icon} size={28} color={theme.primary} />
      </View>
      <Text style={[styles.emptyTitle, { color: theme.ink }]}>{title}</Text>
      <Text style={[styles.emptyMessage, { color: theme.inkMuted }]}>{message}</Text>
      {action && (
        <MotionPressable onPress={onAction} style={[styles.primaryButton, { backgroundColor: theme.primary }]}>
          <Text style={styles.primaryButtonText}>{action}</Text>
        </MotionPressable>
      )}
    </View>
  );
}

export function TransactionRow({
  transaction,
  account,
  onPress,
}: {
  transaction: Transaction;
  account?: Account;
  onPress?: () => void;
}) {
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const currency = useAppStore((state) => state.currency);
  const positive = transaction.type === 'income';
  const tone = positive ? theme.income : transaction.type === 'expense' ? theme.expense : theme.transfer;
  const icon =
    transaction.type === 'income' ? 'arrow-downward' : transaction.type === 'expense' ? 'arrow-upward' : 'swap-horiz';
  return (
    <MotionPressable onPress={onPress} style={styles.transactionRow}>
      <View
        style={[
          styles.transactionIcon,
          {
            backgroundColor: positive
              ? theme.incomeSoft
              : transaction.type === 'expense'
                ? theme.expenseSoft
                : theme.transferSoft,
          },
        ]}
      >
        <MaterialIcons name={icon} size={18} color={tone} />
      </View>
      <View style={styles.transactionMain}>
        <Text numberOfLines={1} style={[styles.transactionTitle, { color: theme.ink }]}>
          {transaction.title}
        </Text>
        <Text style={[styles.transactionMeta, { color: theme.inkMuted }]}>
          {formatRelativeDate(transaction.date)}
          {account ? ` · ${account.name}` : ''}
        </Text>
      </View>
      <Text style={[styles.transactionAmount, { color: tone }]}>
        {hidden
          ? '••••'
          : `${positive ? '+' : transaction.type === 'expense' ? '−' : ''}${formatCurrency(transaction.amount, currency)}`}
      </Text>
    </MotionPressable>
  );
}

export function AccountRow({ account, onPress }: { account: Account; onPress?: () => void }) {
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const currency = useAppStore((state) => state.currency);
  return (
    <MotionPressable onPress={onPress} style={styles.accountRow}>
      <View style={[styles.accountIcon, { backgroundColor: theme.primarySoft }]}>
        <MaterialIcons
          name={
            account.type === 'bank'
              ? 'account-balance'
              : account.type === 'credit_card'
                ? 'credit-card'
                : 'account-balance-wallet'
          }
          size={19}
          color={theme.primary}
        />
      </View>
      <View style={styles.transactionMain}>
        <Text style={[styles.transactionTitle, { color: theme.ink }]}>{account.name}</Text>
        <Text style={[styles.transactionMeta, { color: theme.inkMuted }]}>{titleCase(account.type)}</Text>
      </View>
      <Text style={[styles.accountAmount, { color: theme.ink }]}>
        {formatCurrency(account.balance, currency, hidden)}
      </Text>
    </MotionPressable>
  );
}

export function FloatingAdd() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  return (
    <MotionPressable
      accessibilityLabel="Add transaction"
      onPress={() => router.push('/transaction/new')}
      style={[styles.fab, { backgroundColor: theme.primary }]}
    >
      <MaterialIcons name="add" size={28} color={theme.white} />
    </MotionPressable>
  );
}

export function LoadingBlock() {
  const { colors: theme } = useAppTheme();
  return <View style={[styles.loading, { backgroundColor: theme.surface }]} />;
}

const styles = StyleSheet.create({
  screen: { flex: 1, paddingHorizontal: spacing.md },
  scrollContent: { paddingBottom: 110 },
  header: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    paddingTop: spacing.xl,
    paddingBottom: spacing.lg,
  },
  eyebrow: { fontSize: 11, letterSpacing: 1.5, fontWeight: '700', marginBottom: 5 },
  title: { fontSize: 32, fontWeight: '800', letterSpacing: -1 },
  headerAction: { fontSize: 14, fontWeight: '700' },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  sectionTitle: { fontSize: 18, fontWeight: '800' },
  metricCard: {
    borderRadius: radius.md,
    padding: spacing.md,
    minHeight: 108,
    justifyContent: 'space-between',
    flex: 1,
  },
  metricCardLarge: { minHeight: 142, padding: spacing.lg },
  metricLabel: { fontSize: 12, fontWeight: '700', letterSpacing: 0.4 },
  metricValue: { fontSize: 20, fontWeight: '800', letterSpacing: -0.5 },
  metricValueLarge: { fontSize: 34, fontWeight: '800', letterSpacing: -1.5 },
  metricDetail: { fontSize: 12 },
  balanceChart: { height: 170, marginTop: spacing.sm, overflow: 'hidden' },
  chartGrid: {
    bottom: 0,
    justifyContent: 'space-between',
    left: 0,
    paddingVertical: 15,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  chartGridLine: { height: 1, width: '100%', opacity: 0.72 },
  pill: { borderRadius: radius.pill, paddingHorizontal: 13, paddingVertical: 8, marginRight: 8 },
  pillText: { fontSize: 12, fontWeight: '700' },
  empty: { alignItems: 'center', borderRadius: radius.lg, borderWidth: 1, padding: spacing.xl, marginTop: spacing.md },
  emptyIcon: {
    width: 58,
    height: 58,
    borderRadius: 29,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  emptyTitle: { fontSize: 17, fontWeight: '800', marginBottom: 5 },
  emptyMessage: { maxWidth: 290, textAlign: 'center', fontSize: 13, lineHeight: 20, marginBottom: spacing.md },
  primaryButton: { paddingHorizontal: 18, paddingVertical: 12, borderRadius: radius.pill },
  primaryButtonText: { color: colors.white, fontSize: 13, fontWeight: '800' },
  transactionRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12 },
  transactionIcon: {
    width: 40,
    height: 40,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  transactionMain: { flex: 1 },
  transactionTitle: { fontSize: 14, fontWeight: '700' },
  transactionMeta: { fontSize: 12, marginTop: 3 },
  transactionAmount: { fontSize: 14, fontWeight: '800', marginLeft: 10 },
  accountRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12 },
  accountIcon: {
    width: 40,
    height: 40,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  accountAmount: { fontSize: 14, fontWeight: '800' },
  fab: {
    position: 'absolute',
    right: 22,
    bottom: 88,
    width: 58,
    height: 58,
    borderRadius: 29,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 5,
    shadowColor: '#000',
    shadowOpacity: 0.18,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
  },
  loading: { height: 130, borderRadius: radius.md, marginTop: spacing.md },
});
