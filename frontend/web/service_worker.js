const notificationCopy = {
  en: {
    chore_due_soon: ['Chore due soon', '{chore_name} is due soon'],
    chore_due_today: ['Chore due today', '{chore_name} is due today'],
    expense_created: ['Expense added', '{actor_name} added {expense_name} in {group_name}.'],
    recurring_expense_created: ['Recurring expense added', '{expense_name} was added.'],
    settlement_requested_paid_you: ['Settlement to confirm', '{actor_name} says they paid you {amount} in {group_name}. Confirm to update balances.'],
    settlement_requested_you_paid: ['Settlement to confirm', '{actor_name} says you paid them {amount} in {group_name}. Confirm to update balances.'],
    settlement_confirmed: ['Settlement confirmed', '{actor_name} confirmed your settlement of {amount} in {group_name}.'],
    settlement_declined: ['Settlement declined', '{actor_name} declined your settlement of {amount} in {group_name}.'],
    meal_plan_changed: ['Meal plan updated', '{actor_name} updated the meal plan in {group_name}.'],
    pinwall_reminder: ['Reminder', '{content}'],
  },
  de: {
    chore_due_soon: ['Aufgabe bald fällig', '{chore_name} ist bald fällig'],
    chore_due_today: ['Aufgabe heute fällig', '{chore_name} ist heute fällig'],
    expense_created: ['Ausgabe hinzugefügt', '{actor_name} hat {expense_name} in {group_name} hinzugefügt.'],
    recurring_expense_created: ['Wiederkehrende Ausgabe hinzugefügt', '{expense_name} wurde hinzugefügt.'],
    settlement_requested_paid_you: ['Ausgleich bestätigen', '{actor_name} sagt, dir {amount} in {group_name} gezahlt zu haben. Bestätige, um die Salden zu aktualisieren.'],
    settlement_requested_you_paid: ['Ausgleich bestätigen', '{actor_name} sagt, du hättest {amount} in {group_name} gezahlt. Bestätige, um die Salden zu aktualisieren.'],
    settlement_confirmed: ['Ausgleich bestätigt', '{actor_name} hat deinen Ausgleich über {amount} in {group_name} bestätigt.'],
    settlement_declined: ['Ausgleich abgelehnt', '{actor_name} hat deinen Ausgleich über {amount} in {group_name} abgelehnt.'],
    meal_plan_changed: ['Essensplan aktualisiert', '{actor_name} hat den Essensplan in {group_name} aktualisiert.'],
    pinwall_reminder: ['Erinnerung', '{content}'],
  },
  es: {
    chore_due_soon: ['Tarea próxima', '{chore_name} vence pronto'],
    chore_due_today: ['Tarea para hoy', '{chore_name} vence hoy'],
    expense_created: ['Gasto añadido', '{actor_name} añadió {expense_name} en {group_name}.'],
    recurring_expense_created: ['Gasto recurrente añadido', 'Se añadió {expense_name}.'],
    settlement_requested_paid_you: ['Pago por confirmar', '{actor_name} dice que te pagó {amount} en {group_name}. Confirma para actualizar los saldos.'],
    settlement_requested_you_paid: ['Pago por confirmar', '{actor_name} dice que le pagaste {amount} en {group_name}. Confirma para actualizar los saldos.'],
    settlement_confirmed: ['Pago confirmado', '{actor_name} confirmó tu pago de {amount} en {group_name}.'],
    settlement_declined: ['Pago rechazado', '{actor_name} rechazó tu pago de {amount} en {group_name}.'],
    meal_plan_changed: ['Plan de comidas actualizado', '{actor_name} actualizó el plan de comidas en {group_name}.'],
    pinwall_reminder: ['Recordatorio', '{content}'],
  },
  fr: {
    chore_due_soon: ['Tâche bientôt due', '{chore_name} arrive bientôt à échéance'],
    chore_due_today: ['Tâche due aujourd’hui', '{chore_name} est à faire aujourd’hui'],
    expense_created: ['Dépense ajoutée', '{actor_name} a ajouté {expense_name} dans {group_name}.'],
    recurring_expense_created: ['Dépense récurrente ajoutée', '{expense_name} a été ajoutée.'],
    settlement_requested_paid_you: ['Règlement à confirmer', '{actor_name} indique vous avoir payé {amount} dans {group_name}. Confirmez pour actualiser les soldes.'],
    settlement_requested_you_paid: ['Règlement à confirmer', '{actor_name} indique que vous lui avez payé {amount} dans {group_name}. Confirmez pour actualiser les soldes.'],
    settlement_confirmed: ['Règlement confirmé', '{actor_name} a confirmé votre règlement de {amount} dans {group_name}.'],
    settlement_declined: ['Règlement refusé', '{actor_name} a refusé votre règlement de {amount} dans {group_name}.'],
    meal_plan_changed: ['Menu mis à jour', '{actor_name} a mis à jour le menu dans {group_name}.'],
    pinwall_reminder: ['Rappel', '{content}'],
  },
  nl: {
    chore_due_soon: ['Taak binnenkort verwacht', '{chore_name} moet binnenkort gebeuren'],
    chore_due_today: ['Taak voor vandaag', '{chore_name} moet vandaag gebeuren'],
    expense_created: ['Uitgave toegevoegd', '{actor_name} voegde {expense_name} toe in {group_name}.'],
    recurring_expense_created: ['Terugkerende uitgave toegevoegd', '{expense_name} is toegevoegd.'],
    settlement_requested_paid_you: ['Betaling bevestigen', '{actor_name} zegt je {amount} te hebben betaald in {group_name}. Bevestig om de saldi bij te werken.'],
    settlement_requested_you_paid: ['Betaling bevestigen', '{actor_name} zegt dat jij {amount} betaalde in {group_name}. Bevestig om de saldi bij te werken.'],
    settlement_confirmed: ['Betaling bevestigd', '{actor_name} bevestigde je betaling van {amount} in {group_name}.'],
    settlement_declined: ['Betaling afgewezen', '{actor_name} wees je betaling van {amount} in {group_name} af.'],
    meal_plan_changed: ['Maaltijdplan bijgewerkt', '{actor_name} werkte het maaltijdplan bij in {group_name}.'],
    pinwall_reminder: ['Herinnering', '{content}'],
  },
};

function localizedNotification(data, payload) {
  let copy = payload.copy;
  if (typeof copy === 'string') {
    try { copy = JSON.parse(copy); } catch (_) { copy = null; }
  }
  if (!copy || copy.version !== 1 || !copy.template || !copy.params) return data;
  const locale = (self.navigator.language || 'en').split('-')[0];
  const catalog = notificationCopy[locale] || notificationCopy.en;
  let template = catalog[copy.template];
  const count = Number(copy.params.item_count || copy.params.activity_count || 0);
  if (copy.template === 'list_items_added') {
    const listCopy = {
      en: ['{list_name} updated', '{actor_name} added {last_item_name} to {list_name} in {group_name}.', '{actor_name} added {item_count} items to {list_name} in {group_name}.'],
      de: ['{list_name} aktualisiert', '{actor_name} hat {last_item_name} zu {list_name} in {group_name} hinzugefügt.', '{actor_name} hat {item_count} Einträge zu {list_name} in {group_name} hinzugefügt.'],
      es: ['{list_name} actualizada', '{actor_name} añadió {last_item_name} a {list_name} en {group_name}.', '{actor_name} añadió {item_count} artículos a {list_name} en {group_name}.'],
      fr: ['{list_name} mise à jour', '{actor_name} a ajouté {last_item_name} à {list_name} dans {group_name}.', '{actor_name} a ajouté {item_count} éléments à {list_name} dans {group_name}.'],
      nl: ['{list_name} bijgewerkt', '{actor_name} voegde {last_item_name} toe aan {list_name} in {group_name}.', '{actor_name} voegde {item_count} items toe aan {list_name} in {group_name}.'],
    }[locale] || null;
    const selected = listCopy || ['{list_name} updated', '{actor_name} added {last_item_name} to {list_name} in {group_name}.', '{actor_name} added {item_count} items to {list_name} in {group_name}.'];
    template = [selected[0], selected[count === 1 ? 1 : 2]];
  } else if (copy.template === 'weekly_digest') {
    const weeklyCopy = {
      en: ['Weekly summary', 'No household activity this week', 'Your household had 1 activity this week', 'Your household had {activity_count} activities this week'],
      de: ['Wochenübersicht', 'Diese Woche gab es keine Haushaltsaktivität', 'Dein Haushalt hatte diese Woche 1 Aktivität', 'Dein Haushalt hatte diese Woche {activity_count} Aktivitäten'],
      es: ['Resumen semanal', 'No hubo actividad en el hogar esta semana', 'Tu hogar tuvo 1 actividad esta semana', 'Tu hogar tuvo {activity_count} actividades esta semana'],
      fr: ['Résumé de la semaine', 'Aucune activité du foyer cette semaine', 'Votre foyer a eu 1 activité cette semaine', 'Votre foyer a eu {activity_count} activités cette semaine'],
      nl: ['Weekoverzicht', 'Deze week was er geen huishoudactiviteit', 'Je huishouden had deze week 1 activiteit', 'Je huishouden had deze week {activity_count} activiteiten'],
    }[locale] || ['Weekly summary', 'No household activity this week', 'Your household had 1 activity this week', 'Your household had {activity_count} activities this week'];
    template = [weeklyCopy[0], weeklyCopy[count === 0 ? 1 : count === 1 ? 2 : 3]];
  }
  if (!template) return data;
  const fill = value => value.replace(/\{([a-z_]+)\}/g, (_, key) => copy.params[key] || '');
  return { ...data, title: fill(template[0]), body: fill(template[1]) };
}

self.addEventListener('push', function(event) {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) { data = {}; }
  const payload = data.data || {};
  data = localizedNotification(data, payload);
  const entityTag = payload.entity_type && payload.id
    ? `${payload.entity_type}:${payload.id}`
    : payload.notification_id || undefined;
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload,
    tag: entityTag,
    renotify: false,
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
