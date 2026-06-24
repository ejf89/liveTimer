import { useEffect, useRef } from 'react';
import { Linking } from 'react-native';

export type UrlControlHandlers = {
  start: (name?: string) => void;
  stop: () => void;
  pause: () => void;
  resume: () => void;
};

/**
 * Maps deep links to timer actions, for scripted testing and deep-linking:
 *   livetimer://start?name=Foo · livetimer://stop · pause · resume
 *
 * Handlers are read through a ref so the listener is registered once but always
 * calls the latest closures (no stale captures, no re-subscribing per render).
 */
export function useUrlControl(handlers: UrlControlHandlers) {
  const handlersRef = useRef(handlers);
  useEffect(() => {
    handlersRef.current = handlers;
  });

  useEffect(() => {
    function handleUrl(url: string | null) {
      const match = url?.match(/^livetimer:\/\/([^?]+)(?:\?(.*))?$/);
      if (!match) return;
      const [, action, query] = match;
      const h = handlersRef.current;
      if (action === 'start') {
        const nameParam = (query ?? '')
          .split('&')
          .map((kv) => kv.split('='))
          .find(([key]) => key === 'name')?.[1];
        h.start(nameParam ? decodeURIComponent(nameParam) : undefined);
      } else if (action === 'stop') {
        h.stop();
      } else if (action === 'pause') {
        h.pause();
      } else if (action === 'resume') {
        h.resume();
      }
    }
    const sub = Linking.addEventListener('url', ({ url }) => handleUrl(url));
    Linking.getInitialURL().then(handleUrl);
    return () => sub.remove();
  }, []);
}
