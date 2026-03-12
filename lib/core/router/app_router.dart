import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lexiq_iraq/core/auth/auth_controller.dart';
import 'package:lexiq_iraq/features/admin/presentation/pages/admin_page.dart';
import 'package:lexiq_iraq/features/ai_workspace/presentation/pages/ai_workspace_page.dart';
import 'package:lexiq_iraq/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:lexiq_iraq/features/auth/presentation/pages/login_page.dart';
import 'package:lexiq_iraq/features/auth/presentation/pages/register_page.dart';
import 'package:lexiq_iraq/features/billing/presentation/pages/billing_page.dart';
import 'package:lexiq_iraq/features/cases/presentation/pages/details.dart';
import 'package:lexiq_iraq/features/cases/presentation/pages/cases_page.dart';
import 'package:lexiq_iraq/features/cases/presentation/pages/create_case_wizard_page.dart';
import 'package:lexiq_iraq/features/clients/presentation/pages/clients_page.dart';
import 'package:lexiq_iraq/features/constitution/presentation/pages/constitution_explorer_page.dart';
import 'package:lexiq_iraq/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:lexiq_iraq/features/dashboard/presentation/pages/splash_page.dart';
import 'package:lexiq_iraq/features/decisions/presentation/pages/decisions_explorer_page.dart';
import 'package:lexiq_iraq/features/documents/presentation/pages/documents_page.dart';
import 'package:lexiq_iraq/features/hearings/presentation/pages/hearings_calendar_page.dart';
import 'package:lexiq_iraq/features/lawyer_hub/presentation/pages/hub_profile.dart';
import 'package:lexiq_iraq/features/laws/presentation/pages/laws_explorer_page.dart';
import 'package:lexiq_iraq/features/notifications/presentation/pages/notifications_page.dart';
import 'package:lexiq_iraq/features/research/presentation/pages/research_workspace_page.dart';
import 'package:lexiq_iraq/features/settings/presentation/pages/settings_page.dart';
import 'package:lexiq_iraq/features/tasks/presentation/pages/tasks_page.dart';
import 'package:lexiq_iraq/shared/layout/lexiq_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/auth/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/auth/register', builder: (context, state) => const RegisterPage()),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final title = _routeTitle(state.uri.path);
          return LexiqShell(title: title, child: child);
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
          GoRoute(path: '/lawyer-hub', builder: (context, state) => const LawyerHubPage()),
          GoRoute(path: '/clients', builder: (context, state) => const ClientsPage()),
          GoRoute(path: '/cases', builder: (context, state) => const CasesPage()),
          GoRoute(path: '/cases/new', builder: (context, state) => const CreateCaseWizardPage()),
          GoRoute(
            path: '/cases/:id',
            builder: (context, state) => CaseDetailsPage(caseId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/hearings', builder: (context, state) => const HearingsCalendarPage()),
          GoRoute(path: '/tasks', builder: (context, state) => const TasksPage()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsPage()),
          GoRoute(path: '/billing', builder: (context, state) => const BillingPage()),
          GoRoute(
            path: '/research',
            builder: (context, state) => const ResearchWorkspacePage(),
          ),
          GoRoute(
            path: '/constitution',
            builder: (context, state) => const ConstitutionExplorerPage(),
          ),
          GoRoute(path: '/laws', builder: (context, state) => const LawsExplorerPage()),
          GoRoute(
            path: '/decisions',
            builder: (context, state) => const DecisionsExplorerPage(),
          ),
          GoRoute(
            path: '/ai-workspace',
            builder: (context, state) => const AiWorkspacePage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
        ],
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthRoute = path.startsWith('/auth');
      final isSplash = path == '/splash';
      final isProtectedRoute = !isAuthRoute && !isSplash;

      if (authState.isBootstrapping) {
        return isSplash ? null : '/splash';
      }

      if (!authState.isAuthenticated && isProtectedRoute) {
        return '/auth/login';
      }

      if (authState.isAuthenticated && (isAuthRoute || isSplash || path == '/')) {
        return '/dashboard';
      }

      if (!authState.isAuthenticated && path == '/') {
        return '/auth/login';
      }

      return null;
    },
  );
});

String _routeTitle(String path) {
  if (path.startsWith('/dashboard')) return 'Home Dashboard';
  if (path.startsWith('/lawyer-hub')) return 'Lawyer Intelligence Hub';
  if (path.startsWith('/clients')) return 'Clients';
  if (path.startsWith('/cases/new')) return 'Create New Case Wizard';
  if (path.startsWith('/cases/')) return 'Case Details';
  if (path.startsWith('/cases')) return 'Cases';
  if (path.startsWith('/hearings')) return 'Hearings Calendar';
  if (path.startsWith('/tasks')) return 'Tasks & Reminders';
  if (path.startsWith('/documents')) return 'Documents / Archive';
  if (path.startsWith('/billing')) return 'Billing & Fees';
  if (path.startsWith('/research')) return 'Research Workspace';
  if (path.startsWith('/constitution')) return 'Constitution Explorer';
  if (path.startsWith('/laws')) return 'Iraqi Laws Explorer';
  if (path.startsWith('/decisions')) return 'Judicial Decisions Explorer';
  if (path.startsWith('/ai-workspace')) return 'AI Legal Workspace';
  if (path.startsWith('/notifications')) return 'Notifications Center';
  if (path.startsWith('/admin')) return 'Admin Panel';
  if (path.startsWith('/settings')) return 'Settings';
  return 'LexIQ Iraq';
}
