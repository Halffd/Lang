import React from 'react';
import { Stack } from 'expo-router';

export default function WebLayout(): React.ReactElement {
  return (
    <Stack>
      <Stack.Screen
        name="index"
        options={{
          headerShown: false,
        }}
      />
    </Stack>
  );
} 