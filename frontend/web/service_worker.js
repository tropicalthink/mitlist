self.addEventListener('push', function(event) {
  const data = event.data.json();
  const options = {
    body: data.body || '',
    icon: '/icon.png',
    badge: '/badge.png',
  };
  event.waitUntil(
    self.registration.showNotification(data.title || 'mitlist', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = event.notification.data?.url || '/';
  clients.openWindow(url);
});
