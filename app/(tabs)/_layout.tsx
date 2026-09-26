import { useEffect, useState } from 'react';
import { Tabs } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import { Animated, ColorValue, StyleSheet } from 'react-native';
import { useAppTheme } from '@/lib/theme';

export default function TabsLayout() {
  const { colors: theme, dark } = useAppTheme();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        animation: 'fade',
        tabBarActiveTintColor: theme.primary,
        tabBarInactiveTintColor: theme.inkMuted,
        tabBarStyle: {
          position: 'absolute',
          bottom: 12,
          left: 14,
          right: 14,
          height: 68,
          paddingTop: 7,
          paddingBottom: 7,
          borderRadius: 34,
          backgroundColor: theme.surface,
          borderTopWidth: 0,
          shadowColor: dark ? '#000000' : '#6A7A7E',
          shadowOpacity: dark ? 0.28 : 0.12,
          shadowRadius: 18,
          shadowOffset: { width: 0, height: 7 },
          elevation: 5,
        },
        tabBarItemStyle: { borderRadius: 28, marginHorizontal: 2, marginVertical: 3 },
        tabBarLabelStyle: { fontSize: 10, fontWeight: '700' },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ color, size, focused }) => (
            <TabIcon name="space-dashboard" size={size} color={color} focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="activity"
        options={{
          title: 'Activity',
          tabBarIcon: ({ color, size, focused }) => (
            <TabIcon name="receipt-long" size={size} color={color} focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="accounts"
        options={{
          title: 'Accounts',
          tabBarIcon: ({ color, size, focused }) => (
            <TabIcon name="account-balance-wallet" size={size} color={color} focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="loans"
        options={{
          title: 'Loans',
          tabBarIcon: ({ color, size, focused }) => (
            <TabIcon name="handshake" size={size} color={color} focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="more"
        options={{
          title: 'More',
          tabBarIcon: ({ color, size, focused }) => (
            <TabIcon name="more-horiz" size={size} color={color} focused={focused} />
          ),
        }}
      />
    </Tabs>
  );
}

function TabIcon({
  name,
  size,
  color,
  focused,
}: {
  name: keyof typeof MaterialIcons.glyphMap;
  size: number;
  color: ColorValue;
  focused: boolean;
}) {
  const { colors: theme } = useAppTheme();
  const [progress] = useState(() => new Animated.Value(focused ? 1 : 0));
  useEffect(() => {
    Animated.spring(progress, {
      toValue: focused ? 1 : 0,
      damping: 18,
      stiffness: 260,
      mass: 0.6,
      useNativeDriver: true,
    }).start();
  }, [focused, progress]);
  return (
    <Animated.View
      style={[
        styles.tabIcon,
        focused && { backgroundColor: theme.primarySoft },
        { transform: [{ scale: progress.interpolate({ inputRange: [0, 1], outputRange: [0.9, 1] }) }] },
      ]}
    >
      <MaterialIcons name={name} size={size} color={focused ? theme.primary : color} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  tabIcon: { alignItems: 'center', borderRadius: 20, height: 30, justifyContent: 'center', width: 54 },
});
