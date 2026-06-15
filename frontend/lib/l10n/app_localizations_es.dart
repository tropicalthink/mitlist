// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonDone => 'Hecho';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get commonDismiss => 'Descartar';

  @override
  String get commonClear => 'Limpiar';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonSkip => 'Saltar';

  @override
  String get commonChange => 'Cambiar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonArchive => 'Archivar';

  @override
  String get commonOptions => 'Opciones';

  @override
  String get commonSettings => 'Configuración';

  @override
  String get commonName => 'Nombre';

  @override
  String get commonDescription => 'Descripción';

  @override
  String get commonNotes => 'Notas';

  @override
  String get commonAmount => 'Importe';

  @override
  String get commonPreview => 'Vista previa';

  @override
  String get commonShare => 'Compartir';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonListName => 'Nombre de la lista';

  @override
  String get commonSaving => 'Guardando…';

  @override
  String get commonAdding => 'Añadiendo…';

  @override
  String get commonDeleting => 'Eliminando…';

  @override
  String get commonNoHousehold => 'Aún no hay hogar';

  @override
  String get commonCreateJoinHousehold =>
      'Crea o únete a un hogar antes de añadir elementos.';

  @override
  String get commonGoToHouseholds => 'Ir a hogares';

  @override
  String get commonSomethingWentWrong => 'Algo salió mal';

  @override
  String get commonFailedToLoad => 'Error al cargar. Inténtalo de nuevo.';

  @override
  String get commonCheckConnection =>
      'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get commonClearSearch => 'Limpiar búsqueda';

  @override
  String commonMember(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '$count miembro',
    );
    return '$_temp0';
  }

  @override
  String commonItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '1 artículo',
    );
    return '$_temp0';
  }

  @override
  String get commonLoadingMembers => 'Cargando miembros...';

  @override
  String get welcomeTagline => 'Tu hogar, organizado.';

  @override
  String get welcomeCardTitle =>
      'Listas, tareas, dinero.\nTodo en un solo lugar.';

  @override
  String get welcomeCardBody =>
      'Hecho para compañeros de piso que quieren menos fricción y más claridad.';

  @override
  String get welcomeCreateHousehold => 'Crear hogar gratis';

  @override
  String get welcomeSignIn => 'Iniciar sesión';

  @override
  String get welcomeGuestLoading => 'Configurando...';

  @override
  String get welcomeContinueAsGuest => 'Continuar como invitado';

  @override
  String get welcomeGuestFootnote =>
      'Sin necesidad de cuenta. Prueba todo gratis durante 30 días.';

  @override
  String get hubAppBarTitle => 'Inicio';

  @override
  String get hubHouseholdsSheetTitle => 'Hogares';

  @override
  String hubSwitchToHousehold(String name) {
    return 'Cambiar a $name';
  }

  @override
  String get hubCreateHousehold => 'Crear hogar';

  @override
  String get hubJoinHousehold => 'Unirse a hogar';

  @override
  String get hubInviteToHousehold => 'Invitar al hogar';

  @override
  String get hubHouseholdSettings => 'Configuración del hogar';

  @override
  String get hubWelcomeHeadline => 'Bienvenido a mitlist';

  @override
  String get hubWelcomeDescription =>
      'Crea o únete a un hogar para empezar a compartir listas, tareas y gastos.';

  @override
  String get hubCreateAHousehold => 'Crear un hogar';

  @override
  String get hubJoinWithInviteCode => 'Unirse con código de invitación';

  @override
  String get hubQuickAdd => 'Añadir rápido';

  @override
  String get hubLoadError =>
      'No se pudieron cargar tus hogares. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get hubCalendarTooltip => 'Calendario';

  @override
  String get myHouseholdsTitle => 'Mis hogares';

  @override
  String get groupsJoinWithCode => 'Unirse con código';

  @override
  String get groupsFailedLoad => 'Error al cargar los hogares';

  @override
  String get groupsFailedMore => 'Error al cargar más hogares';

  @override
  String get groupsEmptyTitle => 'Aún no hay hogares';

  @override
  String get groupsEmptyDesc => 'Crea uno para empezar a organizar tu hogar.';

  @override
  String get groupsCreateHousehold => 'Crear hogar';

  @override
  String get choreAppBarTitle => 'Tareas';

  @override
  String get choreAddChore => 'Añadir tarea';

  @override
  String get choreAddHouseholds => 'Hogares';

  @override
  String get choreRetry => 'Reintentar';

  @override
  String get choreNoHouseholdTitle => 'Aún no hay hogar';

  @override
  String get choreNoHouseholdDesc =>
      'Crea o únete a un hogar antes de añadir tareas.';

  @override
  String get choreGoToHouseholds => 'Ir a hogares';

  @override
  String get choreNoChoresTitle => 'Aún no hay tareas';

  @override
  String get choreNoChoresDesc =>
      'Haz seguimiento de las tareas recurrentes del hogar. Asígnalas a cualquiera de tu grupo.';

  @override
  String get choreAddAChore => 'Añadir una tarea';

  @override
  String get choreSectionOverdue => 'Atrasadas';

  @override
  String get choreSectionToday => 'Hoy';

  @override
  String get choreSectionThisWeek => 'Esta semana';

  @override
  String get choreSectionLater => 'Más adelante';

  @override
  String get choreNothingOnYou => 'Nada pendiente para ti';

  @override
  String get choreNothingOnYouDesc =>
      'Tu hogar tiene tareas, pero ninguna te ha sido asignada.';

  @override
  String get choreSeeEveryonesChores => 'Ver las tareas de todos';

  @override
  String choreDoneSnackbar(String choreTitle) {
    return '$choreTitle hecha';
  }

  @override
  String get choreFailedComplete =>
      'Error al completar la tarea. Inténtalo de nuevo.';

  @override
  String get choreFailedUndo =>
      'Error al deshacer la tarea. Inténtalo de nuevo.';

  @override
  String get choreFailedSkip => 'Error al saltar la tarea. Inténtalo de nuevo.';

  @override
  String get choreFailedUpdateSubtask =>
      'Error al actualizar la subtarea. Inténtalo de nuevo.';

  @override
  String get choreFailedAddSubtask =>
      'Error al añadir la subtarea. Inténtalo de nuevo.';

  @override
  String get choreCreateListFirst => 'Crea una lista de compras primero.';

  @override
  String get choreAddSuppliesToList => 'Añadir suministros a la lista';

  @override
  String get choreSuppliesAdded => 'Suministros añadidos a la lista';

  @override
  String get choreFailedAddSupplies =>
      'Error al añadir suministros. Inténtalo de nuevo.';

  @override
  String get choreFailedReschedule =>
      'Error al reprogramar la tarea. Inténtalo de nuevo.';

  @override
  String get choreDeleteTitle => 'Eliminar tarea';

  @override
  String get choreDeleteBody =>
      'Esto eliminará permanentemente esta tarea y su historial. No se puede deshacer.';

  @override
  String get choreStatusDone => 'Hecha';

  @override
  String get choreStatusOverdue => 'Atrasada';

  @override
  String get choreStatusDueToday => 'Vence hoy';

  @override
  String get choreStatusDueSoon => 'Vence pronto';

  @override
  String get choreStatusScheduled => 'Programada';

  @override
  String get choreStatusPending => 'Pendiente';

  @override
  String get choreYourTurn => 'Te toca a ti';

  @override
  String get choreYoureClear => 'Estás al día';

  @override
  String choreHeroDescSingular(num count) {
    return '$count tarea te necesita ahora.';
  }

  @override
  String choreHeroDescPlural(num count) {
    return '$count tareas te necesitan ahora.';
  }

  @override
  String choreMeLabel(num count) {
    return 'Yo ($count)';
  }

  @override
  String choreEveryoneLabel(num count) {
    return 'Todos ($count)';
  }

  @override
  String get choreHowItSplits => 'Cómo se reparte';

  @override
  String choreSupplySingular(num count) {
    return '$count suministro';
  }

  @override
  String choreSupplyPlural(num count) {
    return '$count suministros';
  }

  @override
  String get choreFrequencyHourly => 'Cada hora';

  @override
  String get choreFrequencyDaily => 'Diaria';

  @override
  String get choreFrequencyWeekly => 'Semanal';

  @override
  String get choreFrequencyMonthly => 'Mensual';

  @override
  String get choreFrequencyYearly => 'Anual';

  @override
  String get choreFrequencyAsNeeded => 'Según necesidad';

  @override
  String get choreFrequencyOneOff => 'Una sola vez';

  @override
  String choreEveryInterval(num interval, String unit) {
    return 'Cada $interval $unit';
  }

  @override
  String get choreDoneToday => 'Hecha hoy';

  @override
  String get choreDoneYesterday => 'Hecha ayer';

  @override
  String choreDoneDaysAgo(num days) {
    return 'Hecha hace ${days}d';
  }

  @override
  String get choreSkipped => 'Saltada';

  @override
  String choreMarkNotDone(String title) {
    return 'Marcar $title como no hecha';
  }

  @override
  String choreMarkDone(String title) {
    return 'Marcar $title como hecha';
  }

  @override
  String get choreAllCaughtUp => 'Estás al día con todo';

  @override
  String choreCarryingShare(num my, num total) {
    return 'Llevas $my de $total tareas pendientes';
  }

  @override
  String get choreNothingShare => 'Nada pendiente para ti';

  @override
  String get choreCreationTitle => 'Añadir tarea';

  @override
  String get choreCreationNameHint => 'Nombre de la tarea';

  @override
  String get choreCreationYourRoutines => 'Tus rutinas';

  @override
  String get choreCreationStartFromRoutine => 'Empezar desde una rutina';

  @override
  String get choreCreationSuggestions => 'Sugerencias';

  @override
  String get choreCreationZoneLabel => 'Zona';

  @override
  String get choreCreationZoneKitchen => 'Cocina';

  @override
  String get choreCreationZoneBathroom => 'Baño';

  @override
  String get choreCreationZoneLivingRoom => 'Salón';

  @override
  String get choreCreationZoneBedroom => 'Dormitorio';

  @override
  String get choreCreationZoneOutdoor => 'Exterior';

  @override
  String get choreCreationZoneShared => 'Compartido';

  @override
  String get choreCreationRepeatsLabel => 'Se repite';

  @override
  String get choreCreationRecurrenceNone => 'Ninguna';

  @override
  String get choreCreationRecurrenceHourly => 'Cada hora';

  @override
  String get choreCreationRecurrenceDaily => 'Diaria';

  @override
  String get choreCreationRecurrenceWeekly => 'Semanal';

  @override
  String get choreCreationRecurrenceMonthly => 'Mensual';

  @override
  String get choreCreationRecurrenceYearly => 'Anual';

  @override
  String get choreCreationRecurrenceAdaptive => 'Adaptativa';

  @override
  String get choreCreationHintNone =>
      'Una tarea única. No volverá por sí sola.';

  @override
  String get choreCreationHintHourly => 'Vuelve cada cierto número de horas.';

  @override
  String get choreCreationHintDaily => 'Vuelve cada cierto número de días.';

  @override
  String get choreCreationHintWeekly =>
      'Vuelve cada semana en los días que elijas.';

  @override
  String get choreCreationHintMonthly => 'Vuelve cada mes en la misma fecha.';

  @override
  String get choreCreationHintYearly => 'Vuelve cada año en la misma fecha.';

  @override
  String get choreCreationHintAdaptive =>
      'Vuelve según cuándo se hizo por última vez, no según el calendario.';

  @override
  String get choreCreationIntervalHint => '1';

  @override
  String get choreCreationMoreOptions => 'Más opciones';

  @override
  String get choreCreationAssignLabel => 'Asignar';

  @override
  String get choreCreationAssignTakeTurns => 'Por turnos';

  @override
  String get choreCreationAssignLeastDone => 'Quien menos ha hecho';

  @override
  String get choreCreationAssignAlphabetical => 'Alfabético';

  @override
  String get choreCreationAssignRandom => 'Aleatorio';

  @override
  String get choreCreationAssignNoAssignee => 'Sin asignar';

  @override
  String get choreCreationAssignHintTurns =>
      'Rota a la siguiente persona cada vez.';

  @override
  String get choreCreationAssignHintAlpha =>
      'Va en orden alfabético de nombres.';

  @override
  String get choreCreationAssignHintLeast => 'Va a quien menos la ha hecho.';

  @override
  String get choreCreationAssignHintRandom =>
      'Elige a alguien al azar cada vez.';

  @override
  String get choreCreationAssignHintNone =>
      'Queda sin asignar. Cualquiera del hogar puede hacerla.';

  @override
  String get choreCreationLogWhenDone => 'Registrar al hacer, no marcar';

  @override
  String get choreCreationLogWhenDoneHelper =>
      'Registra la fecha sin marcarla como completada. Ideal para tareas de las que quieras un historial.';

  @override
  String get choreCreationRollOver => 'Mover si no se hace';

  @override
  String get choreCreationRollOverHelper =>
      'La desplaza a la siguiente fecha en lugar de acumularse como atrasada.';

  @override
  String get choreCreationNotesHint =>
      'Notas (opcional) — pasos, recordatorios, lo que sea útil';

  @override
  String get choreCreationSaveAsRoutine => 'Guardar como rutina';

  @override
  String get choreCreationSaveAsRoutineSemantic =>
      'Guardar esta tarea como rutina reutilizable';

  @override
  String get choreCreationScanChoreSemantic => 'Escanear tarea con la cámara';

  @override
  String get choreCreationChoreAdded => 'Tarea añadida';

  @override
  String choreCreationChoreAddedNextUp(String assignee) {
    return 'Tarea añadida · siguiente: $assignee';
  }

  @override
  String get choreCreationJoinFirst => 'Crea o únete a un hogar primero.';

  @override
  String get choreCreationEditRoutine => 'Editar rutina';

  @override
  String choreCreationEverySingular(String unit) {
    return 'Cada $unit';
  }

  @override
  String choreCreationEveryPlural(num n, String unit) {
    return 'Cada $n $unit';
  }

  @override
  String get choreCreationUnitHourSingular => 'hora';

  @override
  String get choreCreationUnitHourPlural => 'horas';

  @override
  String get choreCreationUnitDaySingular => 'día';

  @override
  String get choreCreationUnitDayPlural => 'días';

  @override
  String get choreCreationUnitWeekSingular => 'semana';

  @override
  String get choreCreationUnitWeekPlural => 'semanas';

  @override
  String get choreCreationUnitMonthSingular => 'mes';

  @override
  String get choreCreationUnitMonthPlural => 'meses';

  @override
  String get choreCreationUnitYearSingular => 'año';

  @override
  String get choreCreationUnitYearPlural => 'años';

  @override
  String get choreDayMon => 'Lun';

  @override
  String get choreDayTue => 'Mar';

  @override
  String get choreDayWed => 'Mié';

  @override
  String get choreDayThu => 'Jue';

  @override
  String get choreDayFri => 'Vie';

  @override
  String get choreDaySat => 'Sáb';

  @override
  String get choreDaySun => 'Dom';

  @override
  String get choreDetailTitle => 'Detalles de la tarea';

  @override
  String get choreDetailAssignee => 'Asignada a';

  @override
  String get choreDetailDue => 'Vence';

  @override
  String get choreDetailTracked => 'Seguimiento';

  @override
  String get choreDetailLastDone => 'Última vez hecha';

  @override
  String get choreDetailLastBy => 'Última por';

  @override
  String get choreDetailAverage => 'Promedio';

  @override
  String get choreDetailSubtasks => 'Subtareas';

  @override
  String get choreDetailNewSubtask => 'Nueva subtarea';

  @override
  String get choreDetailSupplies => 'Suministros';

  @override
  String get choreDetailAddSuppliesToList => 'Añadir suministros a la lista';

  @override
  String get choreDetailMarkDone => 'Marcar como hecha';

  @override
  String get choreDetailMoveToTomorrow => 'Mover a mañana';

  @override
  String get choreDetailUndoLast => 'Deshacer última ejecución';

  @override
  String get choreDetailSkipTitle => 'Saltar tarea';

  @override
  String get choreDetailSkipReason => 'Motivo (opcional)';

  @override
  String get choreDetailSkipReasonHint => 'ej. Fuera esta semana';

  @override
  String get choreDetailDeleteTitleDialog => 'Eliminar tarea';

  @override
  String get choreDetailDeleteBody =>
      'Esto eliminará permanentemente esta tarea y su historial.';

  @override
  String get choreDetailDeleteSubtask => 'Eliminar subtarea';

  @override
  String get choreDetailSubtaskMarkNotDone => 'Marcar subtarea como no hecha';

  @override
  String get choreDetailSubtaskMarkDone => 'Marcar subtarea como hecha';

  @override
  String get choreLoadTitle => 'Quién hace las tareas';

  @override
  String choreLoadEmpty(num days) {
    return 'Aún no se han completado tareas en los últimos $days días. Cuando la gente empiece a marcar tareas, el reparto aparecerá aquí.';
  }

  @override
  String choreLoadCountSingular(num count) {
    return '$count tarea';
  }

  @override
  String choreLoadCountPlural(num count) {
    return '$count tareas';
  }

  @override
  String get recipeAppBarTitle => 'Cocina';

  @override
  String get recipeSearchLabel => 'Buscar en la cocina';

  @override
  String get recipeSearchHint => 'Receta, etiqueta, ingrediente';

  @override
  String get recipeMealPlanTooltip => 'Plan de comidas';

  @override
  String get recipeSearchTooltip => 'Buscar';

  @override
  String get recipeSortLabel => 'Ordenar recetas';

  @override
  String get recipeSortNewest => 'Más recientes';

  @override
  String get recipeSortOldest => 'Más antiguas';

  @override
  String get recipeSortAZ => 'A-Z';

  @override
  String get recipeAddRecipe => 'Añadir receta';

  @override
  String get recipeFailedLoad => 'Error al cargar la cocina';

  @override
  String get recipeFailedMore => 'Error al cargar más recetas';

  @override
  String get recipeBuildKitchen => 'Construye tu cocina';

  @override
  String get recipeBuildKitchenDesc =>
      'Importa recetas, agrupa libros de cocina, planifica comidas y convierte la semana en una lista de compras.';

  @override
  String recipeMealsPlanned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comidas planificadas esta semana',
      one: '1 comida planificada esta semana',
    );
    return '$_temp0';
  }

  @override
  String get recipePlanButton => 'Planificar';

  @override
  String recipeCountLabel(num visible, num total) {
    return '$visible de $total recetas';
  }

  @override
  String recipeCountLabelAll(num total) {
    return '$total recetas';
  }

  @override
  String get recipeFilterAll => 'Todas';

  @override
  String get recipeFilterShared => 'Compartidas';

  @override
  String get recipeFilterPrivate => 'Privadas';

  @override
  String recipeImageSemantics(String title) {
    return 'Imagen de $title';
  }

  @override
  String recipeMinLabel(num minutes) {
    return '$minutes min';
  }

  @override
  String recipeServesLabel(num servings) {
    return 'Para $servings';
  }

  @override
  String recipeOpenRecipe(String title) {
    return 'Abrir receta $title';
  }

  @override
  String get recipeAddToList => 'Añadir a la lista';

  @override
  String recipeSharedPrivate(num shared, num private) {
    return '$shared compartidas · $private privadas';
  }

  @override
  String recipeCookbooksLabel(num count) {
    return ' · $count libros de cocina';
  }

  @override
  String recipeRatingLabel(String rating, num count) {
    return '$rating ($count)';
  }

  @override
  String get recipeCreationTitle => 'Nueva receta';

  @override
  String get recipeCreationStepSource => 'Origen';

  @override
  String get recipeCreationStepDetails => 'Detalles';

  @override
  String get recipeCreationStepContent => 'Contenido';

  @override
  String get recipeCreationStartHeadline => 'Empieza tu receta';

  @override
  String get recipeCreationStartSubtitle =>
      'Importa desde un enlace, escríbela tú mismo o escanea una foto.';

  @override
  String get recipeCreationImportURL => 'Importar desde URL';

  @override
  String get recipeCreationImportURLDesc =>
      'Pega un enlace de receta y extraeremos los detalles';

  @override
  String get recipeCreationTypeItIn => 'Escribirla';

  @override
  String get recipeCreationTypeItInDesc =>
      'Empieza con un título y añade ingredientes después';

  @override
  String get recipeCreationScanning => 'Escaneando…';

  @override
  String get recipeCreationScanPhoto => 'Escanear una foto';

  @override
  String get recipeCreationScanPhotoDesc =>
      'Fotografía una tarjeta de receta o una página de libro de cocina';

  @override
  String get recipeCreationURLInput => 'URL de la receta';

  @override
  String get recipeCreationURLHint => 'https://ejemplo.com/receta';

  @override
  String get recipeCreationFetching => 'Obteniendo…';

  @override
  String get recipeCreationFetchDetails => 'Obtener detalles';

  @override
  String get recipeCreationChooseImage => 'Elegir una imagen';

  @override
  String recipeCreationSelectImage(num index) {
    return 'Seleccionar imagen $index';
  }

  @override
  String get recipeCreationTitleInput => 'Título de la receta';

  @override
  String get recipeCreationTitleHint => 'Tortitas del domingo';

  @override
  String get recipeCreationDiscardTitle => '¿Descartar receta?';

  @override
  String get recipeCreationDiscardBody =>
      'Tienes contenido sin guardar en esta receta.';

  @override
  String get recipeCreationKeepEditing => 'Seguir editando';

  @override
  String get recipeCreationDiscard => 'Descartar';

  @override
  String get recipeCreationCouldNotScan => 'No se pudo escanear la receta.';

  @override
  String recipeCreationImported(String parts) {
    return '$parts';
  }

  @override
  String get recipeCreationCouldNotFetch =>
      'No se pudieron obtener los detalles de ese enlace.';

  @override
  String get recipeCreationCreated => 'Receta creada';

  @override
  String get recipeCreationCouldNotCreate => 'No se pudo crear la receta.';

  @override
  String get recipeCreationImportedTitle => 'Receta importada';

  @override
  String recipeCreationFromHost(String host) {
    return 'Receta de $host';
  }

  @override
  String recipeCreationNutrition(String info) {
    return 'Información nutricional: $info';
  }

  @override
  String get recipeCreationNextDetails => 'Siguiente: detalles';

  @override
  String get recipeCreationNextContent => 'Siguiente: contenido';

  @override
  String get recipeCreationTitleOverride => 'Sobrescribir título';

  @override
  String get recipeCreationNotesInput => 'Notas';

  @override
  String get recipeCreationNotesHint =>
      'Qué hace que valga la pena guardar esta receta';

  @override
  String get recipeCreationPrepLabel => 'Preparación (min)';

  @override
  String get recipeCreationPrepHint => '10';

  @override
  String get recipeCreationCookLabel => 'Cocción (min)';

  @override
  String get recipeCreationCookHint => '20';

  @override
  String get recipeCreationServingsLabel => 'Raciones';

  @override
  String get recipeCreationServingsHint => '4';

  @override
  String get recipeCreationTagsInput => 'Etiquetas';

  @override
  String get recipeCreationTagsHint => 'rápido, vegetariano';

  @override
  String get recipeCreationSaveForHousehold => 'Guardar para el hogar';

  @override
  String get recipeCreationSaveForHouseholdDesc =>
      'Todos en este hogar pueden encontrar y usar esta receta.';

  @override
  String get recipeCreationSaveForHouseholdPrivate =>
      'Mantenla privada por ahora. Puedes compartirla más tarde.';

  @override
  String get recipeCreationIngredients => 'Ingredientes';

  @override
  String get recipeCreationIngredientsHelper =>
      'Añade un ingrediente por línea.';

  @override
  String get recipeCreationAddIngredient => 'Añadir ingrediente';

  @override
  String get recipeCreationIngredientHint => '2 tazas de harina';

  @override
  String get recipeCreationSteps => 'Pasos';

  @override
  String get recipeCreationStepsHelper =>
      'Mantén cada paso lo bastante corto para seguirlo mientras cocinas.';

  @override
  String get recipeCreationAddStep => 'Añadir paso';

  @override
  String get recipeCreationStepHint => 'Mezclar la masa';

  @override
  String get recipeCreationNutritionInput => 'Información nutricional';

  @override
  String get recipeCreationNutritionHint =>
      '520 kcal, 24g proteína, alto en fibra';

  @override
  String get recipeCreationCreating => 'Creando…';

  @override
  String get recipeCreationCreateRecipe => 'Crear receta';

  @override
  String recipeCreationStepLabel(String type) {
    return '$type';
  }

  @override
  String recipeCreationRemoveItem(String type, num index) {
    return 'Quitar $type $index';
  }

  @override
  String recipeCreationStepSemantics(
      num index, num total, String label, String status) {
    return 'Paso $index de $total, $label, $status';
  }

  @override
  String get recipeDetailTitle => 'Receta';

  @override
  String get recipeDetailDeleteTooltip => 'Eliminar receta';

  @override
  String get recipeDetailAddToList => 'Añadir a la lista';

  @override
  String get recipeDetailCook => 'Cocinar';

  @override
  String get recipeDetailCouldNotLoad => 'No se pudo cargar la receta';

  @override
  String get recipeDetailDeleteTitle => 'Eliminar receta';

  @override
  String get recipeDetailDeleteBody =>
      'Esto eliminará permanentemente esta receta. No se puede deshacer.';

  @override
  String get recipeDetailSharedLabel => 'Compartida';

  @override
  String get recipeDetailPrivateLabel => 'Privada';

  @override
  String recipeDetailBy(String author) {
    return 'Por $author';
  }

  @override
  String get recipeDetailPrep => 'Preparación';

  @override
  String get recipeDetailServings => 'Raciones';

  @override
  String get recipeDetailUpdated => 'Actualizada';

  @override
  String get recipeDetailNotSet => 'No definido';

  @override
  String get recipeDetailNutrition => 'Información nutricional';

  @override
  String get recipeDetailEquipment => 'Equipamiento';

  @override
  String get recipeDetailIngredients => 'Ingredientes';

  @override
  String get recipeDetailSteps => 'Pasos';

  @override
  String get recipeDetailWatchVideo => 'Ver vídeo';

  @override
  String get recipeDetailWatchVideoSemantics => 'Ver vídeo de la receta';

  @override
  String get recipeDetailViewOriginal => 'Ver receta original';

  @override
  String get recipeDetailViewOriginalSemantics =>
      'Ver receta original en el navegador';

  @override
  String get cookModeCouldNotLoad => 'No se pudo cargar la receta';

  @override
  String get cookModeClose => 'Cerrar';

  @override
  String get cookModeServings => 'Raciones';

  @override
  String get cookModeDecreaseServings => 'Reducir raciones';

  @override
  String get cookModeIncreaseServings => 'Aumentar raciones';

  @override
  String get cookModeStartCooking => 'Empezar a cocinar';

  @override
  String get cookModeGathered => 'reunido';

  @override
  String get cookModeNotGathered => 'no reunido';

  @override
  String cookModeStepOf(num step, num total) {
    return 'Paso $step de $total';
  }

  @override
  String get cookModeExitTooltip => 'Salir del modo cocina';

  @override
  String get cookModeTimerDone => '¡Temporizador terminado!';

  @override
  String get cookModeDoneArrow => 'Hecho →';

  @override
  String get cookModeFinish => 'Terminar';

  @override
  String cookModeStepLabel(num number) {
    return 'Paso $number';
  }

  @override
  String cookModeStepDone(num number) {
    return 'Paso $number hecho. Toca para volver';
  }

  @override
  String cookModeCurrentStep(num number) {
    return 'Paso actual $number';
  }

  @override
  String cookModeStepJump(num number, String description) {
    return 'Paso $number: $description. Toca para saltar a este paso';
  }

  @override
  String cookModeBackToStep(num step) {
    return 'Volver al paso $step';
  }

  @override
  String get cookModeShowIngredients => 'Mostrar ingredientes';

  @override
  String get cookModeIngredients => 'Ingredientes';

  @override
  String get cookModeFinished => 'Terminado — buen trabajo';

  @override
  String get cookModeFinishCooking => 'Terminar de cocinar';

  @override
  String get cookModeAdvanceStep => 'Hecho, avanzar al siguiente paso';

  @override
  String get expenseAppBarTitle => 'Dinero';

  @override
  String get expenseScanReceiptTooltip => 'Escanear recibo';

  @override
  String get expenseRecurringTooltip => 'Recurrentes';

  @override
  String get expenseAddExpense => 'Añadir gasto';

  @override
  String get expenseYouAreOwed => 'Te deben';

  @override
  String get expenseYouOwe => 'Debes';

  @override
  String get expenseAllSquare => 'En paz';

  @override
  String expenseSuggestedPayments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pagos sugeridos',
      one: '$count pago sugerido',
    );
    return '$_temp0 para saldar cuentas';
  }

  @override
  String expenseOpenBalances(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saldos pendientes',
      one: '$count saldo pendiente',
    );
    return '$_temp0 en el hogar';
  }

  @override
  String get expenseNoOneOwes => 'Nadie necesita pagar a nadie ahora mismo';

  @override
  String get expenseTabTimeline => 'Historial';

  @override
  String get expenseTabSettlements => 'Liquidaciones';

  @override
  String get expenseToday => 'Hoy';

  @override
  String get expenseYesterday => 'Ayer';

  @override
  String get expenseNoExpensesTitle => 'Aún no hay gastos';

  @override
  String get expenseNoExpensesDesc =>
      'Haz seguimiento de los gastos compartidos con tu hogar.';

  @override
  String get expenseAddFirstExpense => 'Añadir primer gasto';

  @override
  String get expenseLoadError =>
      'No se pudieron cargar los gastos. Comprueba tu conexión.';

  @override
  String get expenseLoadMoreError => 'Error al cargar más gastos.';

  @override
  String expensePaidBy(String payer) {
    return 'Pagado por $payer';
  }

  @override
  String expenseConvertedAmount(String amount) {
    return '≈ $amount';
  }

  @override
  String get expenseDeleteTitle => 'Eliminar gasto';

  @override
  String get expenseDeleteBody =>
      'Esto eliminará permanentemente este gasto y todos los recibos asociados. No se puede deshacer.';

  @override
  String get expenseSettlementRecorded => 'Liquidación registrada';

  @override
  String get expenseSettlementFailed => 'No se pudo registrar la liquidación.';

  @override
  String get expenseSuggestedPaymentsTitle => 'Pagos sugeridos';

  @override
  String get expenseSuggestedPaymentsDesc =>
      'Calculado a partir de cada gasto, reparto y liquidación registrada en este hogar.';

  @override
  String get expenseAllSettled => '¡Todo saldado!';

  @override
  String get expenseNoOneOwesRight => 'Nadie debe nada a nadie ahora mismo.';

  @override
  String get expenseSameAccount => 'Misma cuenta';

  @override
  String get expenseFrom => 'De';

  @override
  String get expenseTo => 'Para';

  @override
  String get expenseRecordHelper =>
      'Registra esta liquidación después de hacer el pago.';

  @override
  String get expenseRecording => 'Registrando...';

  @override
  String get expenseRecordSettlement => 'Registrar liquidación';

  @override
  String get expenseBalances => 'Saldos';

  @override
  String expenseBalancesOpen(num count) {
    return '$count pendientes';
  }

  @override
  String get expenseExpandBalances => 'Expandir saldos';

  @override
  String get expenseCollapseBalances => 'Contraer saldos';

  @override
  String get expenseNoBalances =>
      'Aún no hay saldos. Añade un gasto con reparto para iniciar el libro mayor.';

  @override
  String get expenseIsOwed => 'le deben';

  @override
  String get expenseOwes => 'debe';

  @override
  String get expenseSettled => 'saldado';

  @override
  String get recurringAppBarTitle => 'Recurrentes';

  @override
  String get recurringAddRecurring => 'Añadir recurrente';

  @override
  String get recurringAddRecurringTooltip => 'Añadir gasto recurrente';

  @override
  String get recurringNoRecurringTitle => 'No hay gastos recurrentes';

  @override
  String get recurringNoRecurringDesc =>
      'Añade un gasto recurrente para hacer seguimiento de pagos regulares';

  @override
  String get recurringAddExpense => 'Añadir gasto';

  @override
  String get recurringPauseTooltip => 'Pausar';

  @override
  String get recurringResumeTooltip => 'Reanudar';

  @override
  String get recurringDeleteTooltip => 'Eliminar';

  @override
  String recurringNextDate(String date) {
    return 'Próximo: $date';
  }

  @override
  String get recurringDeleteTitle => 'Eliminar gasto recurrente';

  @override
  String get recurringDeleteBody =>
      'Esto detendrá la creación de gastos futuros.';

  @override
  String get recurringFrequencyDaily => 'Diario';

  @override
  String get recurringFrequencyWeekly => 'Semanal';

  @override
  String get recurringFrequencyBiweekly => 'Cada 2 semanas';

  @override
  String get recurringFrequencyMonthly => 'Mensual';

  @override
  String get recurringFrequencyQuarterly => 'Trimestral';

  @override
  String get recurringFrequencyYearly => 'Anual';

  @override
  String get recurringSheetTitle => 'Añadir gasto recurrente';

  @override
  String get recurringSheetDescription => 'Descripción';

  @override
  String get recurringSheetAmount => 'Importe';

  @override
  String get recurringSheetFrequency => 'Frecuencia';

  @override
  String get recurringSheetPayer => 'Pagador';

  @override
  String get recurringValidationDesc => 'Introduce una descripción.';

  @override
  String get recurringValidationAmount => 'Introduce un importe.';

  @override
  String get recurringValidationPayer => 'Selecciona un pagador.';

  @override
  String get recurringValidationAmountPositive =>
      'Introduce un importe válido mayor que cero.';

  @override
  String get recurringNoHouseholdDesc =>
      'Únete o crea un hogar para gestionar gastos recurrentes';

  @override
  String get listAppBarTitle => 'Listas';

  @override
  String get listShoppingTripTooltip => 'Viaje de compras';

  @override
  String get listSearchLabel => 'Buscar listas';

  @override
  String get listSearchHint => 'Nombre, ej. supermercado';

  @override
  String get listScanTooltip => 'Escanear recibo o lista';

  @override
  String get listSortLabel => 'Ordenar';

  @override
  String get listSortNewest => 'Más recientes';

  @override
  String get listSortOldest => 'Más antiguas';

  @override
  String get listSortAZ => 'A–Z';

  @override
  String get listSortMostItems => 'Más artículos';

  @override
  String get listSortGridView => 'Vista de cuadrícula';

  @override
  String get listNewList => 'Nueva lista';

  @override
  String get listFilterAll => 'Todas';

  @override
  String get listFilterShopping => 'Compras';

  @override
  String get listFilterTodo => 'Tareas';

  @override
  String get listFilterCustom => 'Personalizada';

  @override
  String get listEmptyShopping => 'No hay listas de compras';

  @override
  String get listEmptyTodo => 'No hay listas de tareas';

  @override
  String get listEmptyCustom => 'No hay listas personalizadas';

  @override
  String get listEmptyAll => 'Aún no hay listas';

  @override
  String get listEmptyShoppingDesc =>
      'Ideal para la compra, preparación de comidas, recados del fin de semana.';

  @override
  String get listEmptyTodoDesc =>
      'Tareas, quehaceres, cualquier cosa con una casilla.';

  @override
  String get listEmptyCustomDesc => 'Forma libre — tu lista, tus reglas.';

  @override
  String get listEmptyAllDesc =>
      'Añade líneas dentro de una lista; las primeras aparecen como resumen en su tarjeta.';

  @override
  String get listCreateShopping => 'Crear una lista de compras';

  @override
  String get listCreateTodo => 'Crear una lista de tareas';

  @override
  String get listCreateCustom => 'Crear una lista personalizada';

  @override
  String get listCreateFirst => 'Crear tu primera lista';

  @override
  String listNoMatch(String query) {
    return 'Ninguna lista coincide con \"$query\"';
  }

  @override
  String get listSearchDesc => 'Se buscan nombres y elementos de las listas.';

  @override
  String get listRenameTitle => 'Renombrar lista';

  @override
  String get listCouldNotRename => 'No se pudo renombrar la lista.';

  @override
  String get listDeleteTitle => 'Eliminar lista';

  @override
  String get listDeleteBody =>
      'Esto eliminará permanentemente esta lista y todos sus artículos.';

  @override
  String get listCouldNotDelete => 'No se pudo eliminar la lista.';

  @override
  String listAddItemTo(String name) {
    return 'Añadir artículo a $name';
  }

  @override
  String get listItemName => 'Nombre del artículo';

  @override
  String get listCouldNotAddItem => 'No se pudo añadir el artículo.';

  @override
  String get listQuickAddItemTooltip => 'Añadir artículo rápido';

  @override
  String listQuickAddItemSemantics(String name) {
    return 'Añadir artículo rápido a $name';
  }

  @override
  String get listOptionsTooltip => 'Opciones de lista';

  @override
  String listDetailEditName(String name) {
    return 'Editar nombre de lista, $name';
  }

  @override
  String get listDetailCloseSearch => 'Cerrar búsqueda';

  @override
  String get listDetailSearchTooltip => 'Buscar';

  @override
  String get listDetailFilterLabel => 'Filtrar artículos';

  @override
  String get listDetailFilterHint => 'Nombre, ej. leche';

  @override
  String get listDetailAllCheckedOff => 'Todo marcado';

  @override
  String get listDetailClearChecked => 'Limpiar marcados';

  @override
  String get listDetailCheckedOff => 'Marcados';

  @override
  String get listDetailNothingHere => 'Nada aquí todavía';

  @override
  String get listDetailNothingHereDesc =>
      'Fotografía una lista escrita a mano, una nota de nevera o una captura. Extraeremos los artículos.';

  @override
  String get listDetailScanThisList => 'Escanear esta lista';

  @override
  String get listDetailTypeItem => 'Escribir un artículo';

  @override
  String get listDetailNoMatch => 'Ningún artículo coincide con tu filtro';

  @override
  String get listDetailCouldNotLoad => 'No se pudo cargar la lista.';

  @override
  String get listDetailCouldNotUpdate =>
      'No se pudo actualizar. Inténtalo de nuevo.';

  @override
  String get listDetailCouldNotAddItem =>
      'No se pudo añadir el artículo. Inténtalo de nuevo.';

  @override
  String get listDetailCouldNotClear =>
      'No se pudieron limpiar los artículos. Inténtalo de nuevo.';

  @override
  String listDetailItemDeleted(String name) {
    return '$name eliminado';
  }

  @override
  String get listDetailCouldNotRestore => 'No se pudo restaurar el artículo.';

  @override
  String get listDetailCouldNotReorder =>
      'No se pudo reordenar los artículos. Inténtalo de nuevo.';

  @override
  String listDetailItemsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos añadidos a la lista',
      one: '1 artículo añadido a la lista',
    );
    return '$_temp0';
  }

  @override
  String get listDetailCouldNotStartScan =>
      'No se pudo iniciar el escaneo. Inténtalo de nuevo.';

  @override
  String get listDetailSetPrice => 'Establecer precio';

  @override
  String get listDetailPriceInput => 'Precio';

  @override
  String get listDetailPriceHint => '0.00';

  @override
  String get listDetailCouldNotSetPrice => 'No se pudo establecer el precio.';

  @override
  String get listDetailClearTitle => 'Vaciar lista';

  @override
  String listDetailClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'los $count artículos',
      one: 'el artículo',
    );
    return 'Esto eliminará $_temp0. No se puede deshacer.';
  }

  @override
  String get listDetailClearConfirm => 'Vaciar lista';

  @override
  String get listDetailArchiveTitle => 'Archivar lista';

  @override
  String get listDetailArchiveBody => 'Esta lista se ocultará de tu hogar.';

  @override
  String get listDetailFailedArchive => 'Error al archivar la lista.';

  @override
  String get listDetailDeleteTitle => 'Eliminar lista';

  @override
  String get listDetailDeleteBody =>
      'Esto eliminará permanentemente esta lista y todos sus artículos. No se puede deshacer.';

  @override
  String get listDetailCouldNotDelete => 'No se pudo eliminar la lista.';

  @override
  String get listDetailExpenseGenerated => 'Gasto generado';

  @override
  String get listDetailCouldNotLoadCostSummary =>
      'No se pudo cargar el resumen de costes.';

  @override
  String get listDetailCouldNotAddPhoto => 'No se pudo añadir la foto.';

  @override
  String get listDetailCouldNotRemovePhoto => 'No se pudo eliminar la foto.';

  @override
  String get listDetailListImage => 'Imagen de la lista';

  @override
  String get listDetailCheckAll => 'Marcar todo';

  @override
  String get listDetailUncheckAll => 'Desmarcar todo';

  @override
  String get listDetailCostSummary => 'Resumen de costes';

  @override
  String get listDetailScanList => 'Escanear lista';

  @override
  String get calendarAppBarTitle => 'Calendario';

  @override
  String get calendarViewWeek => 'Semana';

  @override
  String get calendarViewMonth => 'Mes';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarWeekView => 'Vista semanal';

  @override
  String get calendarMonthView => 'Vista mensual';

  @override
  String get calendarAgendaView => 'Vista de agenda';

  @override
  String get calendarPreviousWeek => 'Semana anterior';

  @override
  String get calendarNextWeek => 'Semana siguiente';

  @override
  String get calendarPreviousMonth => 'Mes anterior';

  @override
  String get calendarNextMonth => 'Mes siguiente';

  @override
  String get calendarMonthJanuary => 'Enero';

  @override
  String get calendarMonthFebruary => 'Febrero';

  @override
  String get calendarMonthMarch => 'Marzo';

  @override
  String get calendarMonthApril => 'Abril';

  @override
  String get calendarMonthMay => 'Mayo';

  @override
  String get calendarMonthJune => 'Junio';

  @override
  String get calendarMonthJuly => 'Julio';

  @override
  String get calendarMonthAugust => 'Agosto';

  @override
  String get calendarMonthSeptember => 'Septiembre';

  @override
  String get calendarMonthOctober => 'Octubre';

  @override
  String get calendarMonthNovember => 'Noviembre';

  @override
  String get calendarMonthDecember => 'Diciembre';

  @override
  String get calendarShortMon => 'Lun';

  @override
  String get calendarShortTue => 'Mar';

  @override
  String get calendarShortWed => 'Mié';

  @override
  String get calendarShortThu => 'Jue';

  @override
  String get calendarShortFri => 'Vie';

  @override
  String get calendarShortSat => 'Sáb';

  @override
  String get calendarShortSun => 'Dom';

  @override
  String get calendarWeekdayMonday => 'Lunes';

  @override
  String get calendarWeekdayTuesday => 'Martes';

  @override
  String get calendarWeekdayWednesday => 'Miércoles';

  @override
  String get calendarWeekdayThursday => 'Jueves';

  @override
  String get calendarWeekdayFriday => 'Viernes';

  @override
  String get calendarWeekdaySaturday => 'Sábado';

  @override
  String get calendarWeekdaySunday => 'Domingo';

  @override
  String get calendarToday => 'Hoy';

  @override
  String calendarDayLabel(num day) {
    return 'Día $day';
  }

  @override
  String get calendarNothingPlanned => 'Nada planificado';

  @override
  String get calendarNothingAhead => 'Nada por delante';

  @override
  String get calendarNothingAheadDesc =>
      'Las próximas tareas, planes de comidas y gastos recurrentes aparecerán aquí.';

  @override
  String get calendarAddChore => 'Añadir tarea';

  @override
  String get calendarAddExpense => 'Añadir gasto';

  @override
  String get calendarViewInWeek => 'Ver en la semana';

  @override
  String get calendarEventMeal => 'Comida';

  @override
  String get calendarEventChore => 'Tarea';

  @override
  String get calendarEventRecurring => 'Recurrente';

  @override
  String get calendarEventExpense => 'Gasto';

  @override
  String get calendarEventReminder => 'Recordatorio';

  @override
  String calendarServingsPpl(num servings) {
    return '$servings pers. ';
  }

  @override
  String get calendarNoHouseholdDesc =>
      'Únete o crea un hogar para ver el calendario';

  @override
  String get calendarCreateHousehold => 'Crear hogar';

  @override
  String calendarWeekHeader(String weekStart, String weekEnd) {
    return '$weekStart – $weekEnd';
  }

  @override
  String calendarMonthHeader(String month, num year) {
    return '$month $year';
  }

  @override
  String get mealPlanAppBarTitle => 'Plan de comidas';

  @override
  String get mealPlanGenerateShoppingList => 'Generar lista de compras';

  @override
  String get mealPlanPreviousWeek => 'Semana anterior';

  @override
  String get mealPlanNextWeek => 'Semana siguiente';

  @override
  String get mealPlanBreakfast => 'Desayuno';

  @override
  String get mealPlanLunch => 'Almuerzo';

  @override
  String get mealPlanDinner => 'Cena';

  @override
  String get mealPlanAddMeal => 'Añadir comida';

  @override
  String get mealPlanRecipeFallback => 'Receta';

  @override
  String mealPlanServings(num servings) {
    return '${servings}p';
  }

  @override
  String mealPlanShoppingListCreated(num count) {
    return 'Lista de compras creada con $count artículos';
  }

  @override
  String get mealPlanTrackCosts => 'Controlar gastos';

  @override
  String get mealPlanCouldNotAdd => 'No se pudo añadir la comida.';

  @override
  String get mealPlanCouldNotRemove => 'No se pudo quitar la comida.';

  @override
  String get mealPlanCouldNotUpdate => 'No se pudo actualizar la comida.';

  @override
  String get mealPlanPickRecipe => 'Elegir una receta';

  @override
  String get mealPlanCouldNotLoadRecipes => 'No se pudieron cargar las recetas';

  @override
  String get mealPlanNoRecipes => 'Aún no hay recetas';

  @override
  String get mealPlanAddRecipesDesc => 'Añade recetas para planificar comidas';

  @override
  String get mealPlanSearchRecipes => 'Buscar recetas...';

  @override
  String mealPlanNoMatch(String query) {
    return 'Ninguna receta coincide con \"$query\"';
  }

  @override
  String get mealPlanServingsSheet => 'Raciones';

  @override
  String get mealPlanFewerServings => 'Menos raciones';

  @override
  String get mealPlanMoreServings => 'Más raciones';

  @override
  String mealPlanOpenRecipe(String slot) {
    return 'Abrir receta para $slot';
  }

  @override
  String mealPlanAddMealFor(String slot) {
    return 'Añadir comida para $slot';
  }

  @override
  String get accountAppBarTitle => 'Tú';

  @override
  String get accountFailedLoadProfile =>
      'Error al cargar el perfil. Inténtalo de nuevo.';

  @override
  String get accountFailedSaveName => 'Error al guardar el nombre';

  @override
  String get accountEditYourName => 'Editar tu nombre';

  @override
  String get accountChangePassword => 'Cambiar contraseña';

  @override
  String get accountFillPasswordFields =>
      'Rellena todos los campos de contraseña.';

  @override
  String get accountPasswordMinLength =>
      'La nueva contraseña debe tener al menos 6 caracteres.';

  @override
  String get accountPasswordsMismatch => 'Las nuevas contraseñas no coinciden.';

  @override
  String get accountPasswordChanged => 'Contraseña cambiada';

  @override
  String get accountCurrentPassword => 'Contraseña actual';

  @override
  String get accountNewPassword => 'Nueva contraseña';

  @override
  String get accountConfirmPassword => 'Confirmar nueva contraseña';

  @override
  String get accountChangePasswordButton => 'Cambiar contraseña';

  @override
  String get accountTermsTitle => 'Términos del servicio';

  @override
  String get accountTermsBody =>
      'Usa mitlist de forma responsable y respeta la privacidad de los miembros de tu hogar. No hagas un mal uso de las funciones o datos compartidos. mitlist se proporciona tal cual, sin garantías.';

  @override
  String get accountDeleteAccount => 'Eliminar cuenta';

  @override
  String get accountDeleteAccountBody =>
      'Esto eliminará permanentemente tu cuenta y todos los datos asociados. No se puede deshacer.';

  @override
  String get accountLogOut => 'Cerrar sesión';

  @override
  String get accountDeleteAccountButton => 'Eliminar cuenta';

  @override
  String get accountHouseholdSection => 'Hogar';

  @override
  String accountSwitchToHousehold(String name) {
    return 'Cambiar a $name';
  }

  @override
  String get accountNotificationInbox => 'Bandeja de notificaciones';

  @override
  String get accountNotificationPreferences => 'Preferencias de notificaciones';

  @override
  String get accountAppearance => 'Apariencia';

  @override
  String get accountAppearanceSystem => 'Sistema';

  @override
  String get accountAppearanceLight => 'Claro';

  @override
  String get accountAppearanceDark => 'Oscuro';

  @override
  String get accountChangePasswordRow => 'Cambiar contraseña';

  @override
  String get accountVersion => 'Versión';

  @override
  String get accountTermsRow => 'Términos del servicio';

  @override
  String get accountGuestTitle => 'Estás usando una cuenta de invitado';

  @override
  String get accountGuestDesc =>
      'Crea una cuenta completa para conservar tus datos permanentemente y acceder a todas las funciones.';

  @override
  String get accountCreateFullAccount => 'Crear cuenta completa';

  @override
  String get accountExportCSV => 'Exportar gastos (CSV)';

  @override
  String get accountShareJSON => 'Compartir gastos (JSON)';

  @override
  String get accountCopyJSON => 'Copiar gastos (JSON)';

  @override
  String get accountJSONCopied => 'Gastos en JSON copiados al portapapeles';

  @override
  String get accountCreateAccountTitle => 'Crear tu cuenta';

  @override
  String get accountFillAllFields => 'Por favor, rellena todos los campos.';

  @override
  String get accountYourName => 'Tu nombre';

  @override
  String get accountYourNameHint => 'ej. Alejandro García';

  @override
  String get accountEmail => 'Correo electrónico';

  @override
  String get accountEmailHint => 'tu@ejemplo.com';

  @override
  String get accountPassword => 'Contraseña';

  @override
  String get accountCreatingAccount => 'Creando cuenta…';

  @override
  String get accountCreateAccount => 'Crear cuenta';

  @override
  String get accountCreatedWelcome => 'Cuenta creada. ¡Bienvenido!';

  @override
  String get notificationsAppBarTitle => 'Notificaciones';

  @override
  String get notificationsMarkAllRead => 'Marcar todo como leído';

  @override
  String get notificationsFailedLoad => 'Error al cargar las notificaciones.';

  @override
  String get notificationsFailedLoadMore =>
      'Error al cargar más notificaciones.';

  @override
  String get notificationsFailedMarkAllRead =>
      'Error al marcar todo como leído.';

  @override
  String get notificationsFailedMarkRead => 'Error al marcar como leído.';

  @override
  String get notificationsNoHouseholdDesc =>
      'Crea o únete a un hogar para recibir notificaciones.';

  @override
  String get notificationsNoNotifications => 'Aún no hay notificaciones';

  @override
  String get notificationsNoNotificationsDesc =>
      'Cuando alguien añada una tarea, reparta un gasto o te mencione, aparecerá aquí.';

  @override
  String notificationsUnreadLabel(String title) {
    return 'No leída, $title';
  }

  @override
  String get notifPrefAppBarTitle => 'Preferencias de notificaciones';

  @override
  String get notifPrefFailedLoad =>
      'Error al cargar las preferencias de notificaciones.';

  @override
  String get notifPrefNoHouseholdDesc =>
      'Únete o crea un hogar para configurar las preferencias de notificaciones.';

  @override
  String get notifPrefNoPreferences => 'Aún no hay preferencias';

  @override
  String get notifPrefNoPreferencesDesc =>
      'Las preferencias se crean cuando te unes a un hogar. Si acabas de unirte, deberían aparecer en breve.';

  @override
  String get notifPrefGroupName => 'Notificaciones';

  @override
  String get notifPrefChoreDueReminders => 'Recordatorios de tareas pendientes';

  @override
  String get notifPrefChoreDueRemindersDesc =>
      'Cuando una tarea está por vencer';

  @override
  String get notifPrefChoreDueDayOf => 'Tarea pendiente el mismo día';

  @override
  String get notifPrefChoreDueDayOfDesc => 'El día que vence una tarea';

  @override
  String get notifPrefListItemAdded => 'Artículo añadido a la lista';

  @override
  String get notifPrefListItemAddedDesc =>
      'Cuando alguien añade algo a una lista compartida';

  @override
  String get notifPrefExpenseCreated => 'Gasto creado';

  @override
  String get notifPrefExpenseCreatedDesc => 'Cuando se registra un nuevo gasto';

  @override
  String get notifPrefMealPlanChanged => 'Plan de comidas modificado';

  @override
  String get notifPrefMealPlanChangedDesc =>
      'Cuando se actualiza el plan de comidas';

  @override
  String get notifPrefWeeklyDigest => 'Resumen semanal';

  @override
  String get notifPrefWeeklyDigestDesc =>
      'Un resumen de la actividad del hogar';

  @override
  String get notifPrefPinwallReminders => 'Recordatorios del Pinwall';

  @override
  String get notifPrefPinwallRemindersDesc =>
      'Cuando alguien fija un recordatorio para más tarde';

  @override
  String get notifPrefPushNotifications => 'Notificaciones push';

  @override
  String get notifPrefPushNotificationsDesc =>
      'Recibir notificaciones en este dispositivo';

  @override
  String get shoppingTripAppBarTitle => 'Viaje de compras';

  @override
  String get shoppingTripChooseStore => 'Elegir tienda';

  @override
  String get shoppingTripNoLists => 'Aún no hay listas';

  @override
  String get shoppingTripNoListsDesc =>
      'Crea una lista de compras para empezar un viaje';

  @override
  String get shoppingTripAllCaughtUp => 'Todo al día';

  @override
  String get shoppingTripAllCaughtUpDesc =>
      'No hay artículos pendientes en tus listas. Añade artículos a una lista para verlos aquí.';

  @override
  String get shoppingTripSortedByAisles => 'Ordenado por pasillos';

  @override
  String shoppingTripSortedByStoreAisles(String store) {
    return 'Ordenado por pasillos de $store';
  }

  @override
  String get shoppingTripMarkDone => 'Marcar como hecho';

  @override
  String shoppingTripBasketBar(num collected, String price) {
    return '/ $collected recogidos$price';
  }

  @override
  String shoppingTripItemsWorthDone(String amount) {
    return 'Artículos por valor de $amount marcados como hechos';
  }

  @override
  String get shoppingTripAddExpense => 'Añadir gasto';

  @override
  String get shoppingTripStampDone => 'HECHO';

  @override
  String shoppingTripStampItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '1 artículo',
    );
    return '$_temp0';
  }

  @override
  String get shoppingTripFallbackList => 'Lista';

  @override
  String shoppingTripMarkNotPurchased(String item) {
    return 'Marcar $item como no comprado';
  }

  @override
  String shoppingTripMarkPurchased(String item) {
    return 'Marcar $item como comprado';
  }

  @override
  String get scannerAppBarTitle => 'Escáner';

  @override
  String get scannerShoppingAt => 'Comprando en';

  @override
  String get scannerChooseStore => 'Elige tu tienda';

  @override
  String get scannerHintText =>
      'Escanea un recibo, lista, receta\no recordatorio de tarea';

  @override
  String get scannerAnalyzing => 'Analizando…';

  @override
  String get scannerScanGrocery => 'Escanear lista de compras';

  @override
  String get scannerScanReceipt => 'Escanear recibo, receta o tarea';

  @override
  String get scannerAnalyzeThis => 'Analizar esta imagen';

  @override
  String get scannerTakeOrChoose => 'Haz una foto o elige una';

  @override
  String get scannerPickDifferent => 'Elegir otra imagen';

  @override
  String get scannerScanSheetTitle => 'Escanear lista de compras';

  @override
  String get scannerAddScanTitle => 'Añadir escaneo';

  @override
  String get scannerTakePhoto => 'Hacer una foto';

  @override
  String get scannerChooseFromGallery => 'Elegir de la galería';

  @override
  String get scannerTypeReceipt => 'Recibo';

  @override
  String get scannerTypeShoppingList => 'Lista de compras';

  @override
  String get scannerTypeRecipe => 'Receta';

  @override
  String get scannerTypeChore => 'Tarea';

  @override
  String scannerDetectedType(String type) {
    return 'Detectado: $type';
  }

  @override
  String scannerItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '$count artículo',
    );
    return '$_temp0';
  }

  @override
  String scannerAndMore(num count) {
    return '…y $count más';
  }

  @override
  String scannerStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos',
      one: '$count paso',
    );
    return '$_temp0';
  }

  @override
  String scannerTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get scannerAddToLists => 'Añadir a listas';

  @override
  String get scannerCreateExpense => 'Crear gasto';

  @override
  String get scannerCreateRecipe => 'Crear receta';

  @override
  String get scannerCreateChore => 'Crear tarea';

  @override
  String get scannerUseThis => 'Usar esto';

  @override
  String get scannerScanAgain => 'Escanear de nuevo';

  @override
  String get smartCaptureBack => 'Atrás';

  @override
  String get smartCaptureShowEnhanced => 'Mostrar mejorada';

  @override
  String get smartCaptureOriginal => 'Original';

  @override
  String get smartCaptureUseAnyway => 'Usar de todos modos';

  @override
  String get smartCaptureUseScan => 'Usar escaneo';

  @override
  String get smartCaptureRetake => 'Repetir';

  @override
  String get smartCaptureReady => 'Listo';

  @override
  String get smartCaptureUsable => 'Utilizable';

  @override
  String get smartCaptureRetakeSuggested => 'Se sugiere repetir';

  @override
  String get liveSmartCaptureNoCamera => 'No hay cámara disponible.';

  @override
  String get liveSmartCaptureCouldNotOpen => 'No se pudo abrir la cámara.';

  @override
  String get liveSmartCaptureFrameList => 'Encuadra la lista';

  @override
  String get liveSmartCaptureCameraUnavailable => 'Cámara no disponible';

  @override
  String get liveSmartCaptureGallery => 'Galería';

  @override
  String get liveSmartCaptureScan => 'Escanear';

  @override
  String get liveSmartCaptureCouldNotCapture => 'No se pudo capturar esa foto.';

  @override
  String scanReviewAddToList(String list) {
    return 'Añadir a $list';
  }

  @override
  String get scanReviewReviewItems => 'Revisar artículos';

  @override
  String scanReviewAcceptAll(num count) {
    return 'Aceptar todo ($count)';
  }

  @override
  String get scanReviewStoreLabel => 'Tienda:';

  @override
  String get scanReviewYouMightNeed => 'También podrías necesitar';

  @override
  String get scanReviewIgnored => 'Ignorados';

  @override
  String get scanReviewNewList => 'Nueva lista';

  @override
  String get scanReviewAddToWhichList => '¿Añadir a qué lista?';

  @override
  String get scanReviewNewListOption => 'Nueva lista…';

  @override
  String get scanReviewScannedList => 'Lista escaneada';

  @override
  String get scanReviewCreateList => 'Crear lista';

  @override
  String get scanReviewAdding => 'Añadiendo…';

  @override
  String scanReviewRemoveItem(String item) {
    return 'Quitar $item';
  }

  @override
  String get scanReviewRestore => 'Restaurar';

  @override
  String get scanReviewEditItem => 'Editar artículo';

  @override
  String scanReviewOCRSaw(String text) {
    return 'OCR leyó: \"$text\"';
  }

  @override
  String get scanReviewItemName => 'Nombre del artículo';

  @override
  String get scanReviewQty => 'Cant.';

  @override
  String get scanReviewUnit => 'Unidad';

  @override
  String get scanReviewDidYouMean => '¿Quisiste decir?';

  @override
  String get shareTargetAppBarTitle => 'Guardar en mitlist';

  @override
  String get shareTargetSharedText => 'Texto compartido';

  @override
  String get shareTargetPasteHint => 'Pega o escribe el texto compartido aquí…';

  @override
  String get shareTargetAddPhotos => 'Añadir fotos';

  @override
  String shareTargetPhotosAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos añadidas',
      one: '1 foto añadida',
    );
    return '$_temp0';
  }

  @override
  String get shareTargetPreviewPlaceholder =>
      'Pega texto aquí ahora, o envía contenido desde la extensión de compartir cuando esté disponible.';

  @override
  String get shareTargetDestLists => 'Listas';

  @override
  String get shareTargetDestListsDesc =>
      'Guardar en una lista de compras o tareas';

  @override
  String get shareTargetDestPinwall => 'Pinwall';

  @override
  String get shareTargetDestPinwallDesc =>
      'Publicar una nota (y fotos opcionales) en tu hogar';

  @override
  String get shareTargetDestRecipes => 'Recetas';

  @override
  String get shareTargetDestRecipesDesc => 'Añadir a recetas guardadas';

  @override
  String get shareTargetSelectHousehold => 'Seleccionar hogar';

  @override
  String get shareTargetSaved => 'Guardado';

  @override
  String get shareTargetFailedSave => 'Error al guardar. Inténtalo de nuevo.';

  @override
  String get shareTargetValidationText => 'Pega o escribe algo para guardar.';

  @override
  String get shareTargetValidationNote => 'Añade una nota o al menos una foto.';

  @override
  String get shareTargetValidationHousehold =>
      'Crea o únete a un hogar primero.';

  @override
  String get expenseCreationTitle => 'Añadir gasto';

  @override
  String get expenseCreationAmountHint => '0,00';

  @override
  String expenseCreationRateHint(String currency, String groupCurrency) {
    return 'Tasa: 1 $currency = ? $groupCurrency';
  }

  @override
  String get expenseCreationWhatsItFor => '¿Para qué es esto?';

  @override
  String get expenseCreationNotesHint => 'Notas (opcional)';

  @override
  String get expenseCreationDateLabel => 'Fecha del gasto. Toca para cambiar.';

  @override
  String get expenseCreationReceiptButton => 'Recibo';

  @override
  String get expenseCreationScanning => 'Escaneando…';

  @override
  String get expenseCreationScanButton => 'Escanear';

  @override
  String get expenseCreationReceiptAttached =>
      'Recibo adjunto. Toca para volver a escanear.';

  @override
  String get expenseCreationScanReceiptSemantics =>
      'Escanear recibo con la cámara';

  @override
  String get expenseCreationSplitMode => 'Modo de reparto';

  @override
  String get expenseCreationSplitEqual => 'Igual';

  @override
  String get expenseCreationSplitExact => 'Exacto';

  @override
  String get expenseCreationSplitShares => 'Partes';

  @override
  String get expenseCreationSplitPercent => 'Porcentaje';

  @override
  String get expenseCreationSplitHintExact =>
      'Introduce la cantidad exacta que debe cada persona.';

  @override
  String get expenseCreationSplitHintPercent =>
      'Introduce la parte de cada persona; debe sumar 100%.';

  @override
  String get expenseCreationSplitHintShares =>
      'Repartir por partes, ej. 2 partes paga el doble.';

  @override
  String get expenseCreationSplitHintEqual =>
      'Dividir el total a partes iguales entre los miembros seleccionados.';

  @override
  String get expenseCreationSplitSharesLabel => 'Partes';

  @override
  String get expenseCreationSplitValuesAmount => 'Importe';

  @override
  String get expenseCreationSplitValuesPercent => '%';

  @override
  String get expenseCreationPaidBy => 'Pagado por';

  @override
  String get expenseCreationSplitWith => 'Repartir con';

  @override
  String get expenseCreationSelectSplitter =>
      'Selecciona al menos una persona con quien repartir.';

  @override
  String get expenseCreationEnterAmount =>
      'Introduce un importe arriba para previsualizar cada parte.';

  @override
  String get expenseCreationValidationAmount =>
      'Introduce un importe válido mayor que cero.';

  @override
  String get expenseCreationValidationRate =>
      'Introduce una tasa de conversión mayor que cero.';

  @override
  String get expenseCreationReceiptUploadFailed =>
      'Gasto guardado, pero la subida del recibo falló.';

  @override
  String get expenseCreationExpenseAdded => 'Gasto añadido';

  @override
  String get pinwallBoardLabel => 'Pinwall';

  @override
  String get pinwallDragHint =>
      'Arrastra las notas para moverlas  ·  Pellizca para hacer zoom';

  @override
  String get pinwallCloseBoard => 'Cerrar tablero';

  @override
  String get pinwallEmptyBoard =>
      'El muro está vacío.\nFija una nota desde el inicio para empezar.';

  @override
  String pinwallNoteSemantics(String user, String content) {
    return '$user · $content';
  }

  @override
  String pinwallReminderLabel(String text) {
    return 'Recordatorio · $text';
  }

  @override
  String pinwallRemindedLabel(String text) {
    return 'Recordado · $text';
  }

  @override
  String get pinwallChooseReminderDate => 'Elegir fecha de recordatorio';

  @override
  String get pinwallChooseReminderTime => 'Elegir hora de recordatorio';

  @override
  String get pinwallLinkTo => 'Vincular a…';

  @override
  String get pinwallLinkExpense => 'Un gasto';

  @override
  String get pinwallRemoveLink => 'Quitar vínculo';

  @override
  String pinwallSelectEntity(String type) {
    return 'Seleccionar $type';
  }

  @override
  String get pinwallOpenBoard => 'Abrir panel de pinwall';

  @override
  String get pinwallLinkToChore => 'Vincular a una tarea, lista…';

  @override
  String get pinwallPickFutureTime => 'Elige una hora futura.';

  @override
  String get pinwallCouldNotLoadEntities =>
      'No se pudieron cargar las entidades.';

  @override
  String get pinwallPinned => 'Fijado al muro';

  @override
  String get pinwallOpenBoardBtn => 'Abrir tablero';

  @override
  String get pinwallPostHint => 'Publicar una nota para el hogar…';

  @override
  String get pinwallAddReminder => 'Añadir recordatorio';

  @override
  String pinwallReminderSet(String label) {
    return 'Recordatorio para $label. Toca para cambiar.';
  }

  @override
  String get pinwallClearReminder => 'Eliminar recordatorio';

  @override
  String get pinwallAttachPhoto => 'Adjuntar foto';

  @override
  String get pinwallUploading => 'Subiendo…';

  @override
  String get pinwallPosting => 'Publicando…';

  @override
  String get pinwallPinIt => 'Fijar';

  @override
  String get pinwallCouldNotLoadImage => 'No se pudo cargar la imagen.';

  @override
  String get pinwallRemoveFromPost => 'Quitar de la publicación';

  @override
  String get pinwallCouldNotRemovePhoto => 'No se pudo quitar la foto.';

  @override
  String get pinwallCouldNotAddPhoto => 'No se pudo añadir la foto.';

  @override
  String get pinwallLinkedList => 'Lista vinculada';

  @override
  String get pinwallLinkedChore => 'Tarea vinculada';

  @override
  String get pinwallLinkedExpense => 'Gasto vinculado';

  @override
  String pinwallOpenLinkedEntity(String entity) {
    return 'Abrir $entity vinculada';
  }

  @override
  String get pinwallPostOptions => 'Opciones de publicación';

  @override
  String get pinwallDeletePin => 'Eliminar pin';

  @override
  String get pinwallDeletePinBody =>
      'Este pin se eliminará permanentemente. No se puede deshacer.';

  @override
  String get pinwallAddPhotoMenu => 'Añadir foto';

  @override
  String get tonightBreakfast => 'Hoy · Desayuno';

  @override
  String get tonightLunch => 'Hoy · Almuerzo';

  @override
  String tonightOpenRecipe(String title) {
    return 'Esta noche: $title. Abrir receta';
  }

  @override
  String get captureHintClearer => 'Prueba una foto más clara';

  @override
  String get captureHintHoldSteady => 'Mantén firme';

  @override
  String get captureHintMoreLight => 'Busca más luz';

  @override
  String get captureHintReduceGlare => 'Reduce el reflejo';

  @override
  String get captureHintMoveCloser => 'Acércate más';

  @override
  String get accountLanguage => 'Idioma';

  @override
  String get accountLanguageSystem => 'Sistema';

  @override
  String get navHome => 'Inicio';

  @override
  String get navChores => 'Tareas';

  @override
  String get navMoney => 'Dinero';

  @override
  String get navLists => 'Listas';

  @override
  String get navKitchen => 'Cocina';

  @override
  String get offlineBannerTitle => 'Estado de sincronización';

  @override
  String get offlineBannerStatusOffline => 'Sin conexión';

  @override
  String get offlineBannerStatusPending => 'Pendiente';

  @override
  String get offlineBannerStatusFailed => 'Falló';

  @override
  String get offlineBannerRetryHint =>
      'Los cambios se reintentarán automáticamente cuando se restablezca la conexión.';

  @override
  String get offlineBannerOfflineHint =>
      'Puedes seguir haciendo cambios sin conexión. Todo se sincronizará al reconectarte.';

  @override
  String get offlineBannerBarOffline =>
      'Sin conexión — los cambios se sincronizarán al reconectar';

  @override
  String offlineBannerSyncingCount(num count) {
    return 'Sincronizando $count cambios…';
  }

  @override
  String get offlineBannerSyncing => 'Sincronizando cambios…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'No se pudieron sincronizar $count cambios';
  }

  @override
  String get offlineBannerFailedOne => 'No se pudo sincronizar un cambio';

  @override
  String get offlineBannerRetry => 'Reintentar';

  @override
  String get composerNewItem => 'Nuevo artículo';

  @override
  String get composerScanList => 'Escanear lista';

  @override
  String get composerAddItem => 'Agregar artículo';

  @override
  String get listItemViewPhoto => 'Ver foto';

  @override
  String get listItemReplacePhoto => 'Reemplazar foto';

  @override
  String get listItemAddPhoto => 'Agregar foto';

  @override
  String get listItemRemovePhoto => 'Quitar foto';

  @override
  String get listItemSetPrice => 'Fijar precio';

  @override
  String get listItemDeleteAction => 'Eliminar';

  @override
  String get listItemReorder => 'Reordenar';

  @override
  String listItemMarkUnchecked(String name) {
    return 'Marcar $name como no completado';
  }

  @override
  String listItemMarkChecked(String name) {
    return 'Marcar $name como completado';
  }

  @override
  String listItemViewPhotoFor(String name) {
    return 'Ver foto de $name';
  }

  @override
  String get listItemFailedSave =>
      'Error al guardar — toca la barra de sincronización para reintentar';

  @override
  String get listItemLongPressHint => 'Mantén presionado para más opciones';

  @override
  String get scanCheckListPhoto => 'Revisar foto de la lista';

  @override
  String get scanReadingList => 'Leyendo tu lista…';

  @override
  String get scanCouldNotProcess =>
      'No se pudo procesar la imagen. Inténtalo de nuevo.';

  @override
  String get scanSnapYourList => 'Fotografiar tu lista';

  @override
  String get scanTakePhoto => 'Tomar una foto';

  @override
  String get scanChooseFromGallery => 'Elegir de la galería';

  @override
  String get appDialogClose => 'Cerrar';

  @override
  String get appDialogPressBack => 'Presiona atrás para cerrar';

  @override
  String get shellNotifications => 'Notificaciones';

  @override
  String get shellAccount => 'Cuenta';

  @override
  String get errorSomethingWentWrong => 'Algo salió mal';

  @override
  String filterRemoveLabel(String label) {
    return 'Quitar filtro $label';
  }

  @override
  String get currencyDropdownLabel => 'Moneda';

  @override
  String get passwordStrengthWeak => 'Débil';

  @override
  String get passwordStrengthFair => 'Regular';

  @override
  String get passwordStrengthGood => 'Buena';

  @override
  String get passwordStrengthStrong => 'Fuerte';

  @override
  String get checkToggleChecked => 'Marcado';

  @override
  String get checkToggleNotChecked => 'No marcado';

  @override
  String get notificationsDeleteNotification => 'Eliminar notificación';

  @override
  String get calendarTomorrow => 'Mañana';

  @override
  String get scannerCheckScan => 'Revisar escaneo';

  @override
  String get scannerCheckGrocery => 'Revisar lista de compras';

  @override
  String recipeCreationNoItemsYet(String type) {
    return 'Aún no hay $type.';
  }

  @override
  String get captureHintReady => 'Listo para escanear';

  @override
  String get captureHintUsable => 'Parece utilizable';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginEmail => 'Email';

  @override
  String get authLoginYouExample => 'you@example.com';

  @override
  String get authLoginPassword => 'Password';

  @override
  String get authLoginYourPassword => 'Your password';

  @override
  String get authLoginForgotPassword => 'Forgot password?';

  @override
  String get authLoginSignInButton => 'Sign in';

  @override
  String get authLoginSigningIn => 'Signing in…';

  @override
  String get authLoginNoAccount => 'No account?';

  @override
  String get authLoginCreateOne => 'Create one';

  @override
  String get authLoginFillAllFields => 'Fill out all fields.';

  @override
  String get authLoginEmailRequired => 'Email is required.';

  @override
  String get authLoginPasswordRequired => 'Password is required.';

  @override
  String get authLoginGenericError =>
      'Couldn\'t sign in. Check your connection and try again.';

  @override
  String get authLoginRememberMe => 'Remember me';

  @override
  String get authLoginRememberMeOn => 'Remember me: on';

  @override
  String get authLoginRememberMeOff => 'Remember me: off';

  @override
  String get authLoginGoogle => 'Continue with Google';

  @override
  String get authLoginApple => 'Continue with Apple';

  @override
  String authLoginOAuthUnsupported(String provider) {
    return '$provider sign-in is only available on web, Android, and iOS right now.';
  }

  @override
  String get authLoginResetPasswordTitle => 'Reset Password';

  @override
  String get authLoginSendResetCode => 'Send reset code';

  @override
  String get authLoginResetCodeLabel => 'Reset code';

  @override
  String get authLoginResetCodeHint => 'Paste the code from your email';

  @override
  String get authLoginResetPasswordButton => 'Reset password';

  @override
  String get authLoginResetCodeSent =>
      'If that email exists, a reset code has been sent.';

  @override
  String get authLoginResetFillAllFields =>
      'Fill out the reset code and both password fields.';

  @override
  String get authLoginResetSuccess =>
      'Password reset successful. You can sign in now.';

  @override
  String get authSignupTitle => 'Create account';

  @override
  String get authSignupFirstName => 'First name';

  @override
  String get authSignupFirstNameHint => 'Alex';

  @override
  String get authSignupLastName => 'Last name';

  @override
  String get authSignupLastNameHint => 'Smith';

  @override
  String get authSignupEmail => 'Email';

  @override
  String get authSignupEmailHint => 'you@example.com';

  @override
  String get authSignupPassword => 'Password';

  @override
  String get authSignupPasswordHint => 'At least 6 characters';

  @override
  String get authSignupCreateAccount => 'Create account';

  @override
  String get authSignupCreatingAccount => 'Creating account…';

  @override
  String get authSignupHaveAccount => 'Have an account?';

  @override
  String get authSignupSignInLink => 'Sign in';

  @override
  String get authSignupFillAllFields => 'Fill out all fields.';

  @override
  String get authSignupPasswordMinLength =>
      'Password must be at least 6 characters.';

  @override
  String get authSignupJoinTitle => 'Join household';

  @override
  String get authSignupAccountCreated => 'Account created. Welcome!';

  @override
  String get authSignupNameRequired => 'Name is required.';

  @override
  String get authSignupEmailRequired => 'Email is required.';

  @override
  String get authSignupPasswordRequired => 'Password is required.';

  @override
  String get authSignupGenericError =>
      'Couldn\'t create account. Check your connection and try again.';

  @override
  String get authSignupNameHint => 'Your name';

  @override
  String get authSignupTermsPrefix =>
      'By creating an account, you agree to our ';

  @override
  String get authSignupAnd => ' and ';

  @override
  String get authSignupPeriod => '.';

  @override
  String get authSignupPrivacyPolicy => 'Privacy Policy';

  @override
  String get authSignupTermsP1 =>
      'Use mitlist responsibly. Shared household content is visible to the members of that household.';

  @override
  String get authSignupTermsP2 =>
      'Do not upload unlawful content, impersonate others, or abuse the service. Accounts and shared data may be removed for misuse.';

  @override
  String get authSignupTermsP3 =>
      'The app is provided as-is while the product is still evolving. Keep your own backups for anything critical.';

  @override
  String get authSignupPrivacyP1 =>
      'mitlist stores the account details and household content needed to operate the app.';

  @override
  String get authSignupPrivacyP2 =>
      'Shared data such as lists, chores, expenses, and recipes is visible to other members of the same household.';

  @override
  String get authSignupPrivacyP3 =>
      'Only provide information you are comfortable keeping in a shared household workspace.';

  @override
  String get authJoinTitle => 'Join household';

  @override
  String authJoinInvitedBy(String name) {
    return '$name invited you';
  }

  @override
  String get authJoinJoinNow => 'Join now';

  @override
  String get authJoinSignInToJoin => 'Sign in to join';

  @override
  String get authJoinCreateToJoin => 'Create account to join';

  @override
  String get authJoinGuestWarning => 'Guest accounts can\'t join households.';

  @override
  String get authJoinCouldNotLoad => 'Couldn\'t load invite details.';

  @override
  String get authJoinJoining => 'Joining…';

  @override
  String get authJoinNotNow => 'Not now';

  @override
  String get authJoinYoureIn => 'You\'re in.';

  @override
  String get authJoinGoToHousehold => 'Go to household';

  @override
  String authJoinInviteCodeSemantic(String code) {
    return 'Invite code: $code';
  }

  @override
  String authJoinErrorWithHint(String error) {
    return '$error\n\nYou can also enter a code from the household switcher.';
  }

  @override
  String get authOnboardingTitle => 'Welcome';

  @override
  String get authOnboardingSetupHome => 'Set up your home';

  @override
  String get authOnboardingCreateOrJoin =>
      'Create or join a household to start sharing with flatmates.';

  @override
  String get authOnboardingCreateHousehold => 'Create a household';

  @override
  String get authOnboardingJoinInvite => 'Join with invite code';

  @override
  String get authOnboardingHaveCode => 'Have an invite code?';

  @override
  String get authOnboardingCreateDesc =>
      'Start fresh: name it, invite flatmates, share everything in one place.';

  @override
  String get authOnboardingJoinDesc =>
      'Already got an invite? Enter the code to jump right in.';

  @override
  String get authOnboardingJoinSemantic => 'Join a household with invite code';

  @override
  String get authOnboardingHomeIconSemantic => 'Household home icon';

  @override
  String get hubStatsChores => 'Chores';

  @override
  String get hubStatsDue => 'due';

  @override
  String get hubStatsMeals => 'Meals';

  @override
  String get hubStatsPlanned => 'planned';

  @override
  String get hubStatsOverdue => 'overdue';

  @override
  String get hubStatsAllDone => 'all done';

  @override
  String get hubStatsBalance => 'Balance';

  @override
  String get hubStatsOpen => 'open';

  @override
  String get hubStatsLists => 'Lists';

  @override
  String get hubStatsActiveList => 'active list';

  @override
  String get hubStatsActiveLists => 'active lists';

  @override
  String get hubStatsReminders => 'Reminders';

  @override
  String get hubStatsPinwallReminder => 'pinwall reminder';

  @override
  String get hubStatsPinwallReminders => 'pinwall reminders';

  @override
  String get hubQuickAddTitle => 'Quick add';

  @override
  String get hubQuickAddChore => 'Add chore';

  @override
  String get hubQuickAddExpense => 'Add expense';

  @override
  String get hubQuickAddNote => 'Pin a note';

  @override
  String get hubQuickAddList => 'New list';

  @override
  String get hubActivityTitle => 'Activity';

  @override
  String get hubActivityEmpty =>
      'Nothing happening yet.\nActivity from your household will appear here.';

  @override
  String get hubActivityError =>
      'Couldn’t load activity. Pull to refresh on the hub.';

  @override
  String get hubOnboardingSwap => 'Swap';

  @override
  String get hubOnboardingSettle => 'Settle';

  @override
  String get hubOnboardingDone => 'All done';

  @override
  String get hubOnboardingSwapDesc =>
      'Pick a flatmate who owes the least to take over this chore.';

  @override
  String get hubOnboardingSettleDesc =>
      'Pay everyone back all at once with suggested settlements.';

  @override
  String get hubOnboardingDoneDesc =>
      'Chores, balances, lists — everything in one place, accounted for.';

  @override
  String get appBottomSheetHandle => 'Handle';

  @override
  String get appBottomSheetClose => 'Close';

  @override
  String get storePickerTitle => 'Choose store';

  @override
  String get storePickerSearchLabel => 'Search stores';

  @override
  String get storePickerSearchHint => 'Name...';

  @override
  String get storePickerNoMatch => 'No stores match your search.';

  @override
  String get storePickerNoStore => 'No store';

  @override
  String get storePickerNoStoreDesc =>
      'Sort by category instead of a store layout';

  @override
  String get storePickerLoadError => 'Couldn’t load stores.';

  @override
  String get smartCaptureLaunchTitle => 'Check photo';

  @override
  String get hubQuickAddToList => 'Add to a list';

  @override
  String get hubQuickAddShoppingTrip => 'Start shopping trip';

  @override
  String get hubOnboardingGetStarted => 'Get started';

  @override
  String get hubOnboardingDismiss => 'Dismiss quick start';

  @override
  String get hubOnboardingDescription =>
      'Everything starts here. Pick what matters most.';

  @override
  String get hubOnboardingInvite => 'Invite flatmates';

  @override
  String get hubOnboardingCreateList => 'Create a list';

  @override
  String get hubOnboardingAddChore => 'Add a chore';

  @override
  String get hubOnboardingTrackExpense => 'Track an expense';

  @override
  String get appBottomSheetDiscardTitle => 'Discard changes?';

  @override
  String get appBottomSheetDiscardBody => 'You have unsaved changes.';

  @override
  String get appBottomSheetKeepEditing => 'Keep editing';

  @override
  String get sheetExpenseDetailTitle => 'Expense details';

  @override
  String get sheetExpenseDetailSplits => 'Splits';

  @override
  String sheetExpenseDetailSplitsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count splits',
      one: '$count split',
    );
    return '$_temp0';
  }

  @override
  String get sheetSettlementTitle => 'Record settlement';

  @override
  String get sheetSettlementFrom => 'From';

  @override
  String get sheetSettlementTo => 'To';

  @override
  String get sheetSettlementRecordPayment =>
      'Record this settlement after the payment is made.';

  @override
  String get sheetSettlementConfirm => 'Confirm settlement';

  @override
  String get sheetGroupSettingsTitle => 'Household settings';

  @override
  String get sheetGroupSettingsName => 'Household name';

  @override
  String get sheetGroupSettingsSaved => 'Settings saved';

  @override
  String get sheetGroupSettingsCouldNotSave => 'Couldn\'t save settings.';

  @override
  String get sheetGroupSettingsLeave => 'Leave household';

  @override
  String get sheetGroupSettingsLeaveConfirm =>
      'Are you sure you want to leave this household? All your data will be retained by the household.';

  @override
  String get sheetGroupSettingsLeaveAction => 'Leave';

  @override
  String get sheetGroupSettingsDelete => 'Delete household';

  @override
  String get sheetGroupSettingsDeleteConfirm =>
      'This will permanently delete this household and all associated data. This cannot be undone.';

  @override
  String get sheetRecipeAddToListTitle => 'Add to list';

  @override
  String sheetRecipeAddToListAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added',
      one: '1 item added',
    );
    return '$_temp0';
  }

  @override
  String get sheetRecipeAddToListCouldNotAdd => 'Couldn\'t add ingredients.';

  @override
  String get sheetJoinTitle => 'Join household';

  @override
  String get sheetJoinCodeLabel => 'Invite code';

  @override
  String get sheetJoinCodeHint => 'Paste invite code';

  @override
  String get sheetJoinJoin => 'Join';

  @override
  String get sheetCreateHouseholdTitle => 'Create household';

  @override
  String get sheetCreateHouseholdName => 'Household name';

  @override
  String get sheetCreateHouseholdNameHint => 'e.g. Flat 4B';

  @override
  String get sheetInviteTitle => 'Invite to household';

  @override
  String get sheetInviteCopy => 'Copy link';

  @override
  String get sheetInviteCopied => 'Invite link copied';

  @override
  String get sheetInviteShare => 'Share link';

  @override
  String get sheetCreateListTitle => 'New list';

  @override
  String get sheetCreateListName => 'List name';

  @override
  String get sheetCreateListNameHint => 'e.g. Weekly groceries';

  @override
  String get sheetCreateListType => 'Type';

  @override
  String get sheetCreateListTypeShopping => 'Shopping';

  @override
  String get sheetCreateListTypeTodo => 'To-do';

  @override
  String get sheetCreateListTypeCustom => 'Custom';

  @override
  String get sheetCreateListCreate => 'Create list';

  @override
  String get sheetCostSummaryTitle => 'Cost summary';

  @override
  String get sheetCostSummaryTotal => 'Total';

  @override
  String get sheetConflictTitle => 'Sync conflict';

  @override
  String get sheetConflictDescription =>
      'This item was changed on another device while you were editing. Choose which version to keep.';

  @override
  String get sheetConflictLocal => 'Your version';

  @override
  String get sheetConflictServer => 'Server version';

  @override
  String get sheetConflictKeepLocal => 'Keep yours';

  @override
  String get sheetConflictKeepServer => 'Keep server';

  @override
  String get sheetFailedChangesTitle => 'Failed changes';

  @override
  String get sheetFailedChangesDescription =>
      'These changes couldn\'t be saved. You can retry or discard them.';

  @override
  String get sheetFailedChangesRetryAll => 'Retry all';

  @override
  String get sheetFailedChangesDiscardAll => 'Discard all';

  @override
  String get sheetFailedChangesDiscard => 'Discard';

  @override
  String get sheetFailedChangesRetry => 'Retry';

  @override
  String get sheetFailedChangesEmpty =>
      'No failed changes. Everything is synced or waiting to retry.';

  @override
  String get sheetFailedChangesOpAddItem => 'Add item';

  @override
  String get sheetFailedChangesOpUpdateItem => 'Update item';

  @override
  String get sheetFailedChangesOpDeleteItem => 'Delete item';

  @override
  String get sheetFailedChangesOpReorderItems => 'Reorder list';

  @override
  String get sheetFailedChangesOpCreateExpense => 'Add expense';

  @override
  String get sheetFailedChangesOpUpdateExpense => 'Update expense';

  @override
  String get sheetFailedChangesOpDeleteExpense => 'Delete expense';

  @override
  String get sheetFailedChangesOpCreateRecipe => 'Add recipe';

  @override
  String get sheetFailedChangesOpUpdateRecipe => 'Update recipe';

  @override
  String get sheetFailedChangesOpDeleteRecipe => 'Delete recipe';

  @override
  String get sheetFailedChangesOpCompleteChore => 'Complete chore';

  @override
  String get sheetFailedChangesOpSkipChore => 'Skip chore';

  @override
  String get sheetFailedChangesOpRescheduleChore => 'Reschedule chore';

  @override
  String get sheetFailedChangesOpUndoChore => 'Undo chore';

  @override
  String get sheetFailedChangesOpCreatePinwallPost => 'Post to pinwall';

  @override
  String get sheetFailedChangesOpDeletePinwallPost => 'Delete pinwall post';

  @override
  String get sheetFailedChangesOpChange => 'Change';

  @override
  String get sheetGroupSettingsChoreZonesUpdated => 'Chore zones updated';

  @override
  String get sheetGroupSettingsRemoveMember => 'Remove member';

  @override
  String sheetGroupSettingsRemoveMemberConfirm(String name) {
    return 'Remove $name from this household?';
  }

  @override
  String sheetGroupSettingsMemberRemoved(String name) {
    return '$name removed';
  }

  @override
  String get sheetGroupSettingsHouseholdDeleted => 'Household deleted';

  @override
  String get sheetGroupSettingsDescriptionHint =>
      'A few words about this household';

  @override
  String get sheetGroupSettingsChoreZonesLabel => 'Chore zones';

  @override
  String get sheetGroupSettingsChoreZonesDesc =>
      'Areas of your home for grouping chores. They show up when adding a chore.';

  @override
  String get sheetGroupSettingsAddZone => 'Add zone';

  @override
  String get sheetGroupSettingsZoneHint => 'Kitchen, Bathroom…';

  @override
  String get sheetGroupSettingsSaveZones => 'Save zones';

  @override
  String get sheetGroupSettingsMembersLabel => 'Members';

  @override
  String get sheetGroupSettingsInvite => 'Invite';

  @override
  String sheetGroupSettingsRemoveMemberTooltip(String name) {
    return 'Remove $name';
  }

  @override
  String get tonightRecipe => 'Recipe';

  @override
  String get tonightHeader => 'Tonight';

  @override
  String get tonightCook => 'Cook';

  @override
  String get tonightNothingPlanned => 'Nothing planned for tonight';

  @override
  String get tonightPlanDinner => 'Plan dinner';

  @override
  String activityAddedToList(String name, String when) {
    return 'Added $name to a list · $when';
  }

  @override
  String activityAddedItemToList(String when) {
    return 'Added an item to a list · $when';
  }

  @override
  String activityLoggedExpense(String name, String when) {
    return 'Logged $name · $when';
  }

  @override
  String activityLoggedExpenseGeneric(String when) {
    return 'Logged an expense · $when';
  }

  @override
  String activityCompletedChore(String name, String when) {
    return 'Completed $name · $when';
  }

  @override
  String activityCompletedChoreGeneric(String when) {
    return 'Completed a chore · $when';
  }

  @override
  String activitySavedRecipe(String name, String when) {
    return 'Saved $name · $when';
  }

  @override
  String activitySavedRecipeGeneric(String when) {
    return 'Saved a recipe · $when';
  }

  @override
  String activityPlannedMeal(String name, String when) {
    return 'Planned $name · $when';
  }

  @override
  String activityUpdatedMealPlan(String when) {
    return 'Updated meal plan · $when';
  }

  @override
  String get activityYou => 'You';

  @override
  String get activityMember => 'Member';

  @override
  String inviteLinkShareText(String link, String code) {
    return 'Join my household on mitlist!\nTap: $link\nOr open mitlist and enter the code: $code';
  }

  @override
  String get errorBoundaryTitle => 'Something went wrong';

  @override
  String get errorBoundaryDesc =>
      'We hit an unexpected error. Please try again.';

  @override
  String get recurringTomorrow => 'Tomorrow';

  @override
  String get recurringCouldNotUpdate => 'Couldn\'t update recurring expense.';

  @override
  String get recurringCouldNotDelete => 'Couldn\'t delete recurring expense.';

  @override
  String get recurringCouldNotCreate => 'Couldn\'t create recurring expense.';

  @override
  String get recipeAddToListNoLists => 'No lists';

  @override
  String get recipeAddToListCreateListFirst =>
      'Create a list first to add ingredients';

  @override
  String get costSummaryNoPrices =>
      'No items have prices yet. Open the item options (⋯) and choose Set price to see the cost summary.';

  @override
  String get costSummaryNotAvailable => 'N/A';

  @override
  String get costSummaryEqualShare => 'Equal share per person';

  @override
  String get costSummaryItemsWithPrices => 'Items with prices';

  @override
  String get costSummaryNone => 'None';

  @override
  String get costSummaryGenerateExpense => 'Generate expense';

  @override
  String get createListScanFinished => 'Scan finished';

  @override
  String createListScanned(String name) {
    return 'Scanned \"$name\"';
  }

  @override
  String get createListShoppingDesc =>
      'Best for groceries and errands with quantities.';

  @override
  String get createListNameRequired => 'List name is required';

  @override
  String get createListCreated => 'List created';

  @override
  String get recipeCreationScanRecipe => 'Scan recipe';

  @override
  String get recipeCreationScanRecipeViaCamera => 'Scan recipe via camera';

  @override
  String get joinCodeFormatHint =>
      'Codes look like WORD-WORD-42. Ask whoever invited you.';

  @override
  String joinEnterGroup(String name) {
    return 'Enter $name';
  }

  @override
  String inviteCodeLabel(String code) {
    return 'Invite code: $code';
  }

  @override
  String get inviteQrTitle => 'Household invite QR code';

  @override
  String get inviteQrSemantic => 'Household invite QR';

  @override
  String get inviteQrHint =>
      'Scan with a phone camera to join, or share the code below.';

  @override
  String get inviteGenerating => 'Generating…';

  @override
  String get inviteNewCode => 'New code';

  @override
  String get createHouseholdCreated => 'Household created';

  @override
  String get createHouseholdDescriptionOptional => 'Description (optional)';

  @override
  String get conflictNoneToResolve => 'No conflicts to resolve.';

  @override
  String get conflictItemChanged => 'Item changed';

  @override
  String conflictItemLabel(String name) {
    return 'Item: $name';
  }

  @override
  String get scannerCouldNotAnalyze =>
      'Couldn\'t analyze the image. Please try again with a clearer photo.';

  @override
  String get oauthMissingParams => 'Missing OAuth callback parameters.';

  @override
  String get oauthSigningYouIn => 'Signing you in';

  @override
  String get expenseCreationSharesNegative => 'Shares can\'t be negative.';

  @override
  String get expenseCreationAssignShare => 'Assign at least one share.';

  @override
  String get expenseCreationCouldNotLoadMembers =>
      'Couldn\'t load household members.';

  @override
  String get expenseCreationJoinHouseholdSplit =>
      'Join or create a household to split this expense.';

  @override
  String expenseCreationRemoveAddSplitter(String name) {
    return 'Remove/Add $name from/to split';
  }

  @override
  String get expenseDetailFailedLoadReceipt => 'Failed to load receipt';

  @override
  String get expenseDetailReceipt => 'Receipt';

  @override
  String get expenseDetailView => 'View';

  @override
  String get expenseDetailNotSplitYet => 'This expense isn\'t split yet.';

  @override
  String get expenseDetailNoReceipts =>
      'No receipts attached. Add one when editing the expense.';

  @override
  String pinwallLinkedTo(String entity) {
    return 'Linked to $entity';
  }

  @override
  String get commonView => 'View';

  @override
  String get commonPhoto => 'Photo';

  @override
  String cookModeTimerStart(String label) {
    return 'Timer: $label. Tap to start';
  }

  @override
  String get errorServerHiccup => 'Server hiccup — try again in a moment.';

  @override
  String get errorConflict =>
      'Someone else changed this. Refresh and try again.';

  @override
  String get errorNotFound => 'Not found. It may have been deleted.';

  @override
  String get errorNoPermission => 'You don\'t have permission for this.';

  @override
  String get errorSignInAgain => 'Please sign in again.';

  @override
  String get errorGenericRetry => 'Something went wrong. Please try again.';

  @override
  String get createListTodoDesc =>
      'A simple checklist for tasks that need doing.';

  @override
  String get createListCustomDesc =>
      'A flexible list for anything that does not fit.';

  @override
  String get createListScanSemantics => 'Scan list via camera';

  @override
  String get createListHouseholdLabel => 'Household';

  @override
  String get createListNoHousehold => 'No household available.';

  @override
  String get sheetJoinCodeExample => 'SUNNY-TACO-42';

  @override
  String joinMembersAlreadyInside(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members already inside',
      one: '1 member already inside',
    );
    return '$_temp0';
  }

  @override
  String get inviteQrUnavailable => 'QR unavailable';

  @override
  String expenseCreationSplitAssignedOf(String assigned, String total) {
    return '$assigned of $total';
  }

  @override
  String expenseCreationSplitAmountsNegative(String assigned) {
    return '$assigned · amounts can\'t be negative';
  }

  @override
  String expenseCreationSplitLeftToAssign(String assigned, String remaining) {
    return '$assigned · $remaining left to assign';
  }

  @override
  String expenseCreationSplitOver(String assigned, String over) {
    return '$assigned · $over over';
  }

  @override
  String expenseCreationSplitPercentRange(String sum) {
    return '$sum% assigned · each share must be 0–100%';
  }

  @override
  String expenseCreationSplitPercentOf100(String sum) {
    return '$sum% of 100%';
  }

  @override
  String expenseCreationSplitSharesPerShare(num count, String perShare) {
    return '$count shares · $perShare per share';
  }

  @override
  String expenseCreationSplitEach(String amount) {
    return '$amount each';
  }

  @override
  String expenseCreationSplitApproxEach(String amount) {
    return '≈ $amount each';
  }

  @override
  String expenseCreationRemoveFromSplit(String name) {
    return 'Remove $name from split';
  }

  @override
  String expenseCreationAddToSplit(String name) {
    return 'Add $name to split';
  }

  @override
  String get expenseDetailCouldNotLoadSplits => 'Couldn\'t load splits.';

  @override
  String get expenseDetailCouldNotLoadReceipts => 'Couldn\'t load receipts.';

  @override
  String get expenseDetailCouldNotRemoveReceipt => 'Couldn\'t remove receipt.';

  @override
  String get expenseDetailRemoving => 'Removing…';

  @override
  String get recipeAddToListTargetList => 'Target list';

  @override
  String get recipeAddToListNoIngredients => 'No ingredients';

  @override
  String get recipeAddToListNoIngredientsDesc =>
      'This recipe has no parsed ingredients';

  @override
  String recipeAddToListRemoveFromSelection(String name) {
    return 'Remove $name from selection';
  }

  @override
  String recipeAddToListAddToSelection(String name) {
    return 'Add $name to selection';
  }

  @override
  String get pinwallLinkChore => 'A chore';

  @override
  String get pinwallLinkList => 'A list';

  @override
  String get pinwallCouldNotLoad => 'Couldn\'t load the pinwall.';

  @override
  String get composerItemHint => 'e.g. Milk, 2 avocados, or 500g flour';

  @override
  String get aisleOther => 'Other';

  @override
  String hubHouseholdsCurrent(String name) {
    return 'Households, current $name';
  }

  @override
  String recipeDetailStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get currencyUsd => 'USD - US Dollar';

  @override
  String get currencyEur => 'EUR - Euro';

  @override
  String get currencyGbp => 'GBP - British Pound';

  @override
  String get currencyJpy => 'JPY - Japanese Yen';

  @override
  String get currencyCad => 'CAD - Canadian Dollar';

  @override
  String get currencyAud => 'AUD - Australian Dollar';

  @override
  String get currencyChf => 'CHF - Swiss Franc';

  @override
  String get currencySek => 'SEK - Swedish Krona';

  @override
  String get currencyNok => 'NOK - Norwegian Krone';

  @override
  String get currencyDkk => 'DKK - Danish Krone';

  @override
  String get currencyPln => 'PLN - Polish Zloty';

  @override
  String get currencyCzk => 'CZK - Czech Koruna';

  @override
  String get currencyHuf => 'HUF - Hungarian Forint';
}
