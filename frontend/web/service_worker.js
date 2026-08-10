self.addEventListener('push', function(event) {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) { data = {}; }
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data.data || {},
  };
  event.waitUntil(self.registration.showNotification(data.title || 'mitlist', options));
});

function urlForPayload(d) {
  if (!d) return '/';
  if (d.url) return d.url;
  const id = d.id || '';
  switch (d.screen) {
    case 'listDetail':        return id ? `/lists/${id}` : '/lists';
    case 'choreDetail':       return '/chores';
    case 'expenseDetail':     return '/money';
    case 'recipeDetail':      return id ? `/recipes/${id}` : '/recipes';
    case 'mealPlan':          return '/recipes/meal-plan';
    case 'recurringExpenses': return '/money/recurring';
    case 'householdHub':      return '/home';
    case 'settlements':       return '/money';
    default:                  return '/';
  }
}

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = urlForPayload(event.notification.data);
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(openClients) {
      for (const client of openClients) {
        if ('navigate' in client) {
          return client.navigate(url).then(function(navigated) { return navigated.focus(); });
        }
      }
      return clients.openWindow(url);
    })
  );
});
