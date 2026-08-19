self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = {};
  }
  const notification = payload.notification || payload.data?.notification || {};
  const data = payload.data || {};
  event.waitUntil(self.registration.showNotification(
    notification.title || 'ComboReel',
    {
      body: notification.body || 'A new story is waiting for you.',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: { deep_link: data.deep_link || 'comboreel://home' },
    },
  ));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const deepLink = event.notification.data?.deep_link || 'comboreel://home';
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((windows) => {
      for (const client of windows) {
        if ('navigate' in client && 'focus' in client) {
          return client.navigate('/?deep_link=' + encodeURIComponent(deepLink))
            .then(() => client.focus());
        }
      }
      return clients.openWindow('/?deep_link=' + encodeURIComponent(deepLink));
    }));
});
