import { useState, useCallback, useEffect } from 'react';
import { useMutation } from '@tanstack/react-query';
import { api } from '../api';

export function useConversation(period, region) {
  const [threadId, setThreadId] = useState(() => crypto.randomUUID());
  const [messages, setMessages] = useState([]);

  // Reset the conversation when the period/region context changes so turns
  // from different contexts aren't mixed into the same agent thread.
  useEffect(() => {
    setThreadId(crypto.randomUUID());
    setMessages([]);
  }, [period, region]);

  const mutation = useMutation({
    mutationFn: (message) =>
      api.post('/conversations', { thread_id: threadId, period, region, message }),
    onMutate: (message) => {
      setMessages(prev => [...prev, { role: 'user', content: message }]);
    },
    onSuccess: (data) => {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: data.narrative ?? '',
        key_drivers: data.key_drivers ?? [],
        analytics: data.analytics ?? null,
      }]);
    },
  });

  const send = useCallback((content) => {
    mutation.mutate(content);
  }, [mutation]);

  return { threadId, messages, isPending: mutation.isPending, send };
}
