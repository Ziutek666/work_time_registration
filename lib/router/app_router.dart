// router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:work_time_registration/screens/area/select_area_for_user_screen.dart';
import 'package:work_time_registration/screens/history/user-history-menu-screen.dart';
import 'package:work_time_registration/screens/members/add_project_member_screen.dart';
import 'package:work_time_registration/screens/members/project_members_screen.dart';
import 'package:work_time_registration/services/area_service.dart';
import 'package:work_time_registration/user/edit_user_screen.dart';
import '../home_screen.dart';
import '../models/area.dart';
import '../models/information.dart';
import '../models/information_category.dart';
import '../models/license.dart';
import '../models/project.dart';
import '../models/project_member.dart';
import '../models/work_entry.dart';
import '../models/work_type.dart';
import '../screens/area/areas_screen.dart';
import '../screens/area/create_area_screen.dart';
import '../screens/area/edit_area_screen.dart';
import '../screens/area/select_area_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/verification_screen.dart';
import '../screens/employer/my_employers_screen.dart';
import '../screens/history/admin-history-menu-screen.dart';
import '../screens/history/admin-info-history.dart';
import '../screens/history/admin_work_history.dart';
import '../screens/history/user_work_history.dart';
import '../screens/information/create_information_screen.dart';
import '../screens/information/edit_information_screen.dart';
import '../screens/information/informations_screen.dart';
import '../screens/information/select_information_screen.dart';
import '../screens/members/edit_project_member_screen.dart';
import '../screens/project/create_project_screen.dart';
import '../screens/project/edit_project_screen.dart';
import '../screens/project/my_projects_screen.dart';
import '../screens/project/project_menu_screen.dart';
import '../screens/work_type/area_work_types_screen.dart';
import '../screens/work_type/create_work_type_screen.dart';
import '../screens/work_type/edit_work_type_screen.dart';
import '../screens/work_type/select_work_type_screen.dart';
import '../screens/work_type/work_types_screen.dart';
import '../services/user_service.dart';
import '../user/user_create_data_screen.dart';// Założenie, że VerifyEmailScreen jest w osobnym pliku

// Funkcja do sprawdzania stanu logowania i weryfikacji emaila
Future<String?> _redirect(BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  final loggedIn = user != null;
  final emailVerified = user?.emailVerified ?? false;
  final goingToAuth = state.uri.path == '/auth';
  final goingToVerifyEmail = state.uri.path == '/verificationl';
  final goingToUserData = state.uri.path == '/user-data';
  final goingToRegistration = state.uri.path == '/registration';

  // Jeśli nie jest zalogowany i nie idzie do strony logowania, przekieruj na /auth
  if (!loggedIn && !goingToAuth && !goingToRegistration) {
    return '/auth';
  }

  // Jeśli jest zalogowany, ale nie zweryfikował emaila i nie jest na stronie weryfikacji, przekieruj na /verify-email
  if (loggedIn && !emailVerified && !goingToVerifyEmail) {
    return '/verification';
  }

  // Sprawdź, czy dane użytkownika istnieją
  final userDataExists = loggedIn ? await userService.doesUserDataExist() : false;

  // Jeśli jest zalogowany, zweryfikował email i dane użytkownika nie istnieją, przekieruj na /user-data
  if (loggedIn && emailVerified && !userDataExists && !goingToUserData) {
  return '/user-data';
  }

  // Jeśli jest zalogowany i próbuje iść na stronę logowania lub weryfikacji emaila, przekieruj na /
  if (loggedIn && (goingToAuth || goingToVerifyEmail)) {
    return '/';
  }

  // W przeciwnym razie, pozwól mu iść tam, gdzie zamierzał
  return null;
}

// Konfiguracja routera
final appRouter = GoRouter(
  initialLocation: '/',
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/verification',
      builder: (context, state) => const VerificationScreen(),
    ),
    GoRoute(
      path: '/user-data',
      builder: (context, state) => const UserCreateDataScreen(),
    ),
    GoRoute(
      path: '/registration',
      builder: (context, state) => const RegistrationScreen(),
    ),
    GoRoute(
      path: '/edit-user',
      builder: (context, state) => const EditUserScreen(),
    ),
    GoRoute(
      path: '/my-projects',
      builder: (context, state) => const MyProjectsScreen(),
    ),
    GoRoute(
      path: '/create-project',
      builder: (context, state) => CreateProjectScreen(),
    ),
    GoRoute(
      path: '/edit-project',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final license = extra['license'] as License;
        return EditProjectScreen(project: project,license: license,);
      },
    ),
    GoRoute(
      path: '/project-menu',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final license = extra['license'] as License;
        return ProjectMenuScreen(project: project,license: license,);
      },
    ),
    GoRoute(
      path: '/work_types_screen',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final license = extra['license'] as License;
        return WorkTypesScreen(project: project,license: license,);
      },
    ),
    // Dodatkowo, potrzebujesz trasy do wyboru WorkType jako powiązanej akcji (podzadania/przerwy), np.:
    GoRoute(
        path: '/select_work_type',
        builder: (context, state) {
          // Tutaj extraData może zawierać projectId
          final extraData = state.extra as Map<String, dynamic>?;
          final projectId = extraData?['projectId'] as String?; // Przekazanie całego obiektu Project
          final String? filterType = extraData?['filter_type'] as String?; // Odczytanie nowego filtra
          final List<String>? excludeIds = extraData?['exclude_ids'] as List<String>?;
          if (projectId == null) {
            return Scaffold(body: Center(child: Text("Błąd: Brak danych projektu dla wyboru akcji.")));
          }
          return SelectWorkTypeScreen(projectId: projectId, filterType: filterType,excludeIds: excludeIds,); // Przykładowy ekran
        }
    ),
    GoRoute(
      path: '/edit_work_type',
      builder: (context, state) {
        final workTypeToEdit = state.extra as WorkType;
        return EditWorkTypeScreen(workTypeToEdit: workTypeToEdit,);
      },
    ),
    GoRoute(
      path: '/create_work_type',
      builder: (context, state) {
        final extraData = state.extra as Map<String, dynamic>?;
        final project = extraData?['project'] as Project?;
        if (project == null) {
          // Można tu rzucić błąd lub przekierować, jeśli projekt jest wymagany
          // Dla bezpieczeństwa, można wrócić do poprzedniej strony lub strony głównej
          // return const ErrorScreen(message: 'Brak danych projektu do utworzenia typu pracy.');
          // Lub, jeśli masz domyślną stronę, na którą można wrócić:
          // WidgetsBinding.instance.addPostFrameCallback((_) => GoRouter.of(context).pop());
          // return const SizedBox.shrink(); // Pusty widget, aby uniknąć błędu budowania
          // Najlepiej jednak zapewnić, że project jest zawsze przekazywany
          return Scaffold(body: Center(child: Text("Błąd: Brak danych projektu.")));
        }
        final initialIsBreak = extraData?['isBreak'] as bool?;
        final initialIsSubTask = extraData?['isSubTask'] as bool?;
        final workTypeCategory = extraData?['workTypeCategory'] as String?;
        return CreateWorkTypeScreen(
          project: project,
          initialIsBreak: initialIsBreak,
          initialIsSubTask: initialIsSubTask,
          workTypeCategory: workTypeCategory,
        );
      },
    ),
    GoRoute(
      path: '/create-information',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final category = extra['category'] as InformationCategory;
        return CreateInformationScreen(project: project,category: category,);
      },
    ),
    GoRoute(
      path: '/informations',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final license = extra['license'] as License;
        return InformationsScreen(project: project,license: license,);
      },
    ),

    GoRoute(
      path: '/edit-information',
      builder: (context, state) {
        final information = state.extra as Information;
        return EditInformationScreen(information: information,);
      },
    ),
    GoRoute(
      path: '/select-information',
      builder: (context, state) {
        final projectId = state.extra as String;
        return SelectInformationScreen(projectId: projectId,);
      },
    ),
    GoRoute(
      path: '/select-area-for-user',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final lastWorkTypeEntry = extra['lastWorkTypeEntry'] as WorkEntry?;
        return SelectAreaForUserScreen(project: project,lastWorkTypeEntry: lastWorkTypeEntry,);
      },
    ),
    GoRoute(
      path: '/areas',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final license = extra['license'] as License;
        return AreasScreen(project: project,license: license,);
      },
    ),
    GoRoute(
      path: '/create-area',
      builder: (context, state) {
        final project = state.extra as Project;
        return CreateAreaScreen(project: project);
      },
    ),
    GoRoute(
      path: '/edit-area',
      builder: (context, state) {
        final area = state.extra as Area;
        return EditAreaScreen(area: area,);
      },
    ),
    GoRoute(
      path: '/project_members',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final license = extra['license'] as License;
        return ProjectMembersScreen(project: project,license: license,);
      },
    ),
    GoRoute(
      path: '/edit_project_member',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final projectMember = extra['projectMember'] as ProjectMember;
        return EditProjectMemberScreen(project: project,projectMember:projectMember,);
      },
    ),
    GoRoute(
      path: '/add_project_member_to_project',
      builder: (context, state) {
        final project = state.extra as Project;
        return AddProjectMemberScreen(project: project,);
      },
    ),
    GoRoute(
      path: '/my-employers',
      builder: (context, state) {
        final lastWorkEntry = state.extra as WorkEntry?;
        return MyEmployersScreen(lastWorkTypeEntry: lastWorkEntry,);
      },
    ),
    GoRoute(
      path: '/area-work-types',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final project = extra['project'] as Project;
        final area = extra['area'] as Area;
        final lastWorkEntry = extra['lastWorkTypeEntry'] as WorkEntry?;
        return AreaWorkTypesScreen(project: project,area: area,lastActiveWorkEntry: lastWorkEntry,);
      },
    ),
    GoRoute(
      path: '/user-history-menu',
      builder: (context, state) => const UserHistoryMenuScreen(),
    ),
    GoRoute(
      path: '/user-work-history',
      builder: (context, state) => const UserWorkHistoryScreen(),
    ),
    GoRoute(
      path: '/admin-history-menu',
      builder: (context, state) => const AdminHistoryMenuScreen(),
    ),
    GoRoute(
      path: '/admin-work-history',
      builder: (context, state) => const AdminWorkHistoryScreen(),
    ),
    GoRoute(
      path: '/admin-info-history',
      builder: (context, state) => const AdminInfoHistoryScreen(),
    ),
  ],
);