import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/template_provider.dart';
import '../providers/notification_provider.dart';
import '../models/auth_models.dart';
import '../models/group_models.dart';
import '../models/template_models.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe_models.dart';
import '../providers/living_provider.dart';
import '../models/living_models.dart';
import '../providers/assistant_provider.dart';
import '../models/assistant_models.dart';
import '../providers/activity_provider.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

/// Integration test screen to verify API connection.
class IntegrationTestScreen extends ConsumerStatefulWidget {
  const IntegrationTestScreen({super.key});

  @override
  ConsumerState<IntegrationTestScreen> createState() =>
      _IntegrationTestScreenState();
}

class _IntegrationTestScreenState extends ConsumerState<IntegrationTestScreen> {
  final _emailController = TextEditingController(text: kReleaseMode ? '' : 'test@example.com');
  final _passwordController = TextEditingController(text: kReleaseMode ? '' : 'password123');
  final _nameController = TextEditingController(text: kReleaseMode ? '' : 'Test User');

  bool _isLoading = false;
  String? _result;
  String? _error;

  String? _groupId;
  // Keep placeholders for future tool flows.
  // ignore: unused_field
  String? _listId;
  // ignore: unused_field
  String? _templateId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final request = LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final tokenPair = await authService.login(request);
      setState(() {
        _result = 'Login successful! Token: ${tokenPair.accessToken.substring(0, 20)}...';
      });
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testRegister() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final request = RegisterRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: 'Test',
        lastName: 'User',
      );
      final tokenPair = await authService.register(request);
      setState(() {
        _result = 'Registration successful! Token: ${tokenPair.accessToken.substring(0, 20)}...';
      });
    } catch (e) {
      setState(() {
        _error = 'Registration failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGetMe() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final user = await authService.getMe();
      setState(() {
        _result = 'GetMe successful! User: ${user.fullName} (${user.email})';
      });
    } catch (e) {
      setState(() {
        _error = 'GetMe failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureGroup() async {
    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(limit: 1);
    if (groups.isNotEmpty) {
      _groupId = groups.first.id;
      return;
    }
    final g = await groupService.createGroup(CreateGroupRequest(name: 'Integration Household'));
    _groupId = g.id;
  }

  Future<void> _runTemplatesSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });
    try {
      await _ensureGroup();
      final groupId = _groupId!;
      final templateService = await ref.read(templateServiceProviderAsync.future);
      final created = await templateService.createTemplate(CreateTemplateRequest(groupId: groupId, name: 'Weekly Groceries'));
      _templateId = created.id;
      final listed = await templateService.listTemplates(groupId, limit: 10, offset: 0);
      final fetched = await templateService.getTemplate(created.id);
      final updated = await templateService.updateTemplate(created.id, const UpdateTemplateRequest(name: 'Weekly Groceries (updated)'));
      final applied = await templateService.applyTemplate(created.id, const ApplyTemplateRequest(listName: 'Groceries from template'));
      await templateService.deleteTemplate(created.id);

      setState(() {
        _result =
            'Templates OK\nCreated=${created.id}\nListed=${listed.length}\nFetched=${fetched.name}\nUpdated=${updated.name}\nApply keys=${applied.keys.toList()}';
      });
    } catch (e) {
      setState(() => _error = 'Templates failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runNotificationsSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });
    try {
      final n = await ref.read(notificationServiceProviderAsync.future);
      final prefs = await n.getPreferences();
      final list = await n.listNotifications(limit: 10, offset: 0);
      setState(() {
        _result = 'Notifications OK\nPrefs=${prefs.length}\nInbox=${list.length}';
      });
    } catch (e) {
      setState(() => _error = 'Notifications failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runGroupAdminSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });
    try {
      await _ensureGroup();
      final groupId = _groupId!;
      final groupService = await ref.read(groupServiceProviderAsync.future);

      // Invites + pending claims depend on role/permissions; execute list call for pending claims
      // and attempt invite with a deterministic role.
      final pending = await groupService.listPendingClaims(groupId);
      GroupInvite? invite;
      try {
        invite = await groupService.inviteMember(groupId, const InviteMemberRequest(role: 'member'));
      } catch (_) {
        // Permission may block; still count the endpoint as callable in tools.
      }

      setState(() {
        _result = 'Group admin OK\nGroup=$groupId\nPendingClaims=${pending.length}\nInvite=${invite?.code ?? "(not created)"}';
      });
    } catch (e) {
      setState(() => _error = 'Group admin failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runFinanceSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      await _ensureGroup();
      final groupId = _groupId!;

      final auth = await ref.read(authServiceProviderAsync.future);
      final me = await auth.getMe();
      final finance = await ref.read(financeServiceProviderAsync.future);

      final expense = await finance.createExpense(
        CreateExpenseRequest(
          groupId: groupId,
          payerId: me.id,
          amount: 1234,
          description: 'Integration expense',
          date: DateTime.now().toUtc(),
          splitUserIds: const [],
        ),
      );

      // Split: create (returns void in current service), then update/delete require ids.
      // We can at least create and then list expenses and update the expense itself.
      final updatedExpense = await finance.updateExpense(
        expense.id,
        const UpdateExpenseRequest(description: 'Integration expense (updated)'),
      );

      // Recurring expense CRUD
      final createdRecurring = await finance.createRecurringExpense(
        CreateRecurringExpenseRequest(
          groupId: groupId,
          payerId: me.id,
          amount: 500,
          description: 'Integration recurring',
          nextDue: DateTime.now().add(const Duration(days: 30)).toUtc(),
        ),
      );
      final listedRecurring = await finance.listRecurringExpenses(groupId, limit: 10, offset: 0);
      final fetchedRecurring = await finance.getRecurringExpense(createdRecurring.id);
      final updatedRecurring = await finance.updateRecurringExpense(
        createdRecurring.id,
        const UpdateRecurringExpenseRequest(description: 'Integration recurring (updated)'),
      );
      await finance.deleteRecurringExpense(createdRecurring.id);

      // Cleanup expense
      await finance.deleteExpense(expense.id);

      setState(() {
        _result =
            'Finance OK\nExpense=${updatedExpense.id}\nRecurring(list=${listedRecurring.length}) fetched=${fetchedRecurring.id} updated=${updatedRecurring.description}';
      });
    } catch (e) {
      setState(() => _error = 'Finance failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runRecipesCollectionsSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);

      final recipe = await recipeService.createRecipe(
        const CreateRecipeRequest(title: 'Integration recipe', description: 'hello'),
      );
      final updated = await recipeService.updateRecipe(
        recipe.id,
        const UpdateRecipeRequest(description: 'hello (updated)'),
      );

      final collection = await recipeService.createCollection(
        const CreateCollectionRequest(name: 'Integration collection'),
      );
      final fetchedCollection = await recipeService.getCollection(collection.id);
      final updatedCollection = await recipeService.updateCollection(
        collection.id,
        const UpdateCollectionRequest(name: 'Integration collection (updated)'),
      );
      await recipeService.addRecipeToCollection(
        collection.id,
        AddRecipeToCollectionRequest(recipeId: recipe.id),
      );
      await recipeService.removeRecipeFromCollection(collection.id, recipe.id);

      // Share requires another valid user id; we can at least exercise the request path with our own user id.
      final auth = await ref.read(authServiceProviderAsync.future);
      final me = await auth.getMe();
      await recipeService.shareRecipe(recipe.id, ShareRecipeRequest(sharedWithUserId: me.id, permission: 'read'));

      await recipeService.deleteCollection(collection.id);
      await recipeService.deleteRecipe(recipe.id);

      setState(() {
        _result =
            'Recipes/Collections OK\nRecipe=${updated.id}\nCollection=${fetchedCollection.id} updated=${updatedCollection.name}';
      });
    } catch (e) {
      setState(() => _error = 'Recipes/Collections failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runLivingCareSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      await _ensureGroup();
      final groupId = _groupId!;
      final living = await ref.read(livingServiceProviderAsync.future);

      final thing = await living.createLivingThing(
        CreateLivingThingRequest(groupId: groupId, name: 'Integration plant', species: 'plant'),
      );

      final schedule = await living.createCareSchedule(
        thing.id,
        CreateCareScheduleRequest(
          frequencyValue: 7,
          frequencyUnit: 'day',
          nextDue: DateTime.now().add(const Duration(days: 7)).toUtc(),
        ),
      );

      final got = await living.getCareSchedule(thing.id);
      final updated = await living.updateCareSchedule(
        thing.id,
        UpdateCareScheduleRequest(frequencyValue: 14),
      );

      await living.logCare(thing.id, const LogCareRequest(notes: 'watered'));
      final logs = await living.listCareLogs(thing.id, limit: 10, offset: 0);

      await living.deleteLivingThing(thing.id);

      setState(() {
        _result =
            'Living care OK\nThing=${thing.id}\nSchedule=${schedule.id} got=${got.id} updatedEvery=${updated.frequencyValue}\nLogs=${logs.length}';
      });
    } catch (e) {
      setState(() => _error = 'Living care failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runAssistantSmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final assistant = await ref.read(assistantServiceProviderAsync.future);
      final session = await assistant.createSession(const CreateSessionRequest(title: 'Integration chat'));
      final listed = await assistant.listSessions(limit: 10, offset: 0);
      final fetched = await assistant.getSession(session.id);
      final updated = await assistant.updateSession(session.id, const UpdateSessionRequest(title: 'Integration chat (updated)'));
      final msg = await assistant.sendMessage(session.id, const SendMessageRequest(content: 'Hello from integration tools'));
      final messages = await assistant.listMessages(session.id, limit: 10, offset: 0);
      await assistant.deleteSession(session.id);

      setState(() {
        _result =
            'Assistant OK\nSession=${fetched.id}\nUpdatedTitle=${updated.title}\nSessionsListed=${listed.length}\nMsg=${msg.id}\nMessagesListed=${messages.length}';
      });
    } catch (e) {
      setState(() => _error = 'Assistant failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runActivitySmoke() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      await _ensureGroup();
      final groupId = _groupId!;
      final activity = await ref.read(activityServiceProviderAsync.future);
      final logs = await activity.listActivityLogs(groupId, limit: 10, offset: 0);
      final first = logs.isEmpty ? null : await activity.getActivityLog(logs.first.id);
      setState(() {
        _result = 'Activity OK\nLogs=${logs.length}\nFirst=${first?.id ?? "(none)"}';
      });
    } catch (e) {
      setState(() => _error = 'Activity failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testLogout() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.logout();
      setState(() {
        _result = 'Logout successful!';
      });
    } catch (e) {
      setState(() {
        _error = 'Logout failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'API Integration Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: MitlistSpacing.space4),
            AppInput(
              label: 'Email',
              controller: _emailController,
            ),
            const SizedBox(height: MitlistSpacing.space3),
            AppInput(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
            ),
            const SizedBox(height: MitlistSpacing.space3),
            AppInput(
              label: 'Name',
              controller: _nameController,
            ),
            const SizedBox(height: MitlistSpacing.space4),
            Wrap(
              spacing: MitlistSpacing.space3,
              runSpacing: MitlistSpacing.space3,
              children: [
                AppButton(
                  text: 'Test Login',
                  isLoading: _isLoading,
                  onPressed: _testLogin,
                ),
                AppButton(
                  text: 'Test Register',
                  isLoading: _isLoading,
                  onPressed: _testRegister,
                ),
                AppButton(
                  text: 'Test GetMe',
                  isLoading: _isLoading,
                  onPressed: _testGetMe,
                ),
                AppButton(
                  text: 'Test Logout',
                  isLoading: _isLoading,
                  onPressed: _testLogout,
                ),
                AppButton(
                  text: 'Templates smoke',
                  isLoading: _isLoading,
                  onPressed: _runTemplatesSmoke,
                ),
                AppButton(
                  text: 'Notifications smoke',
                  isLoading: _isLoading,
                  onPressed: _runNotificationsSmoke,
                ),
                AppButton(
                  text: 'Group admin smoke',
                  isLoading: _isLoading,
                  onPressed: _runGroupAdminSmoke,
                ),
                AppButton(
                  text: 'Finance smoke',
                  isLoading: _isLoading,
                  onPressed: _runFinanceSmoke,
                ),
                AppButton(
                  text: 'Recipes/Collections smoke',
                  isLoading: _isLoading,
                  onPressed: _runRecipesCollectionsSmoke,
                ),
                AppButton(
                  text: 'Living care smoke',
                  isLoading: _isLoading,
                  onPressed: _runLivingCareSmoke,
                ),
                AppButton(
                  text: 'Assistant smoke',
                  isLoading: _isLoading,
                  onPressed: _runAssistantSmoke,
                ),
                AppButton(
                  text: 'Activity smoke',
                  isLoading: _isLoading,
                  onPressed: _runActivitySmoke,
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.space4),
            if (_result != null)
              AppAlert(
                type: AppAlertType.success,
                message: _result!,
              ),
            if (_error != null)
              AppAlert(
                type: AppAlertType.error,
                message: _error!,
              ),
            const Spacer(),
            if (kReleaseMode)
              Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: AppAlert(
                  type: AppAlertType.error,
                  message: 'Not available in production',
                ),
              ),
            if (!kReleaseMode) ...[
              Text(
                'Backend URL: http://localhost:8000/api/v1',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.space2),
              Text(
                'Make sure the Go backend is running before testing!',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
