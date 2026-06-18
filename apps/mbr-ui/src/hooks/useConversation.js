import { useState, useCallback } from 'react';
import { useMutation } from '@tanstack/react-query';
import { api } from '../api';

export function useConversation(period, region) {
  const [threadId] = useState(() => crypto.randomUUID());
  const [messages, setMessages] = useState([]);

  const mutation = useMutation({
    mutationFn: (message) =>
      api.post('/conversations', { thread_id: threadId, period, region, message }),
    onMutate: (message) => {
      setMessages(prev => [...prev, { role: 'user', content: message }]);
    },
    onSuccess: (data) => {
      setMessages(prev => [...prev, { role: 'assistant', content: data.narrative ?? '' }]);
    },
  });

  const send = useCallback((content) => {
    mutation.mutate(content);
  }, [mutation]);

  return { threadId, messages, isPending: mutation.isPending, send };
}
