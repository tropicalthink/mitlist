self.addEventListener('push', function(event) {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) { data = {}; }
  const options = {
    body: data.body || '',
    icon: '/icon.png',
    badge: '/badge.png',
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
    default:                  return '/';
  }
}

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = urlForPayload(event.notification.data);
  event.waitUntil(clients.openWindow(url));
});
