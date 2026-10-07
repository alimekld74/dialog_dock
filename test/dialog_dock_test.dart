import 'package:dialog_dock/dialog_dock.dart';
import 'package:dialog_dock/src/view/floating_dialog_effects.dart';
import 'package:dialog_dock/src/view/widgets/floating_dialog_holder_item.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _strings = FloatingDialogStrings();
const _config = FloatingDialogConfig();

/// Shared across holders within a test to simulate app restarts.
late FloatingDialogStorage storage;
Object? user;

FloatingDialogHolderCubit _cubit({
  Listenable? availabilityChanges,
  FloatingDialogConfig config = _config,
}) => FloatingDialogHolderCubit(
  host: FloatingDialogHostDelegate(storage: storage, userId: () => user),
  availabilityChanges: availabilityChanges,
  config: config,
);

FloatingDialogAction _action(
  String id, {
  bool Function()? canPause,
  WidgetBuilder? builder,
  bool isRestorable = true,
  bool Function()? isAvailable,
  bool showFrame = true,
  List<FloatingDialogHeaderAction> headerActions = const [],
  Set<FloatingDialogWindowButton>? windowButtons,
  FloatingDialogWindowFrameBuilder? frameBuilder,
  FloatingDialogIconBuilder? iconBuilder,
}) => FloatingDialogAction(
  id: id,
  title: id,
  icon: Icons.inventory_2_outlined,
  iconBuilder: iconBuilder,
  builder: builder ?? (_) => const SizedBox(),
  canPause: canPause,
  isRestorable: isRestorable,
  isAvailable: isAvailable,
  showFrame: showFrame,
  headerActions: headerActions,
  windowButtons: windowButtons,
  frameBuilder: frameBuilder,
);

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  static int closedCount = 0;

  @override
  Future<void> close() {
    closedCount++;
    return super.close();
  }
}

Widget _formDialog(BuildContext context) => BlocProvider(
  lazy: false,
  create: (_) => _CounterCubit(),
  child: const TextField(key: Key('field')),
);

final _homeKey = GlobalKey();
final _navigatorKey = GlobalKey<NavigatorState>();

/// The app as a host would build it: the holder in `MaterialApp.builder`.
Widget _app(
  FloatingDialogHolderCubit holder, {
  Widget? home,
  ThemeData? theme,
  TextDirection? direction,
}) => MaterialApp(
  navigatorKey: _navigatorKey,
  theme: theme,
  builder: (context, child) {
    final app = FloatingDialogHolder(controller: holder, child: child!);
    return direction == null
        ? app
        : Directionality(textDirection: direction, child: app);
  },
  home: home ?? Scaffold(key: _homeKey, body: const SizedBox.expand()),
);

void _desktop(WidgetTester tester, {Size size = const Size(1600, 1000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    storage = InMemoryFloatingDialogStorage();
    user = 7;
  });

  group('FloatingDialogHolderCubit', () {
    test('opening an existing action restores the same window', () {
      final holder = _cubit();
      final action = _action('treasury');
      expect(holder.open(action).status, FloatingDialogStatus.opened);
      holder.minimize('treasury');
      expect(holder.open(action).status, FloatingDialogStatus.restored);

      expect(holder.state.entries, hasLength(1));
      expect(holder.state.activeEntry?.id, 'treasury');
      holder.close();
    });

    test('only one active window: switching is refused', () {
      final holder = _cubit();
      holder.open(_action('a'));
      expect(holder.open(_action('b')).status, FloatingDialogStatus.busy);
      expect(holder.state.activeEntry?.id, 'a');
      expect(holder.state.heldEntries, isEmpty);

      holder.minimize('a');
      expect(holder.open(_action('b')).status, FloatingDialogStatus.opened);
      expect(holder.restore('a'), FloatingDialogStatus.busy);
      expect(holder.restore('nope'), FloatingDialogStatus.notFound);
      expect(holder.state.activeEntry?.id, 'b');
      holder.close();
    });

    test('a window that cannot pause stays active', () {
      final holder = _cubit();
      holder.open(_action('a', canPause: () => false));

      expect(holder.minimize('a'), isFalse);
      expect(holder.state.activeEntry?.id, 'a');
      holder.close();
    });

    test('re-opening uses the latest callbacks', () {
      final holder = _cubit();
      holder.open(_action('x'));
      expect(holder.minimize('x'), isTrue);
      holder.open(_action('x', canPause: () => false));
      expect(holder.minimize('x'), isFalse);

      var allowed = true;
      holder.registerActions([_action('x', isAvailable: () => allowed)]);
      allowed = false;
      holder.revalidate();
      expect(holder.state.entryOf('x')?.isDormant, isTrue);
      holder.close();
    });

    test('dismissing a pinned new window sends it to the dock', () async {
      final holder = _cubit();
      holder.open(_action('a'));
      holder.togglePin('a');
      expect(holder.dismissActive(), isTrue);
      final entry = holder.state.entryOf('a')!;
      expect(entry.isMinimized, isTrue);
      expect(entry.isPinned, isTrue);
      expect(holder.state.pinnedEntries.map((e) => e.id), ['a']);
      await holder.close();
    });

    test('dismissing an unpinned new window closes it', () async {
      final holder = _cubit();
      holder.open(_action('a'));
      holder.dismissActive();
      expect(holder.state.entryOf('a'), isNull);
      await holder.close();
    });

    test('result completes with the close value, once', () async {
      final holder = _cubit();
      final handle = holder.open<int>(_action('a'));
      holder.minimize('a');
      final again = holder.open<int>(_action('a'));
      holder.closeDialog('a', 42);
      expect(await handle.result, 42);
      expect(await again.result, 42);

      holder.open(_action('b'));
      final busy = holder.open<int>(_action('c'));
      expect(busy.status, FloatingDialogStatus.busy);
      expect(await busy.result, isNull);

      final wrongType = holder.open<String>(_action('b'));
      holder.closeDialog('b', 1);
      expect(await wrongType.result, isNull);

      final pending = holder.open<int>(_action('d')).result;
      await holder.close();
      expect(await pending, isNull);
    });

    testWidgets('minimized windows expire after the lifetime', (tester) async {
      final holder = _cubit();
      final result = holder.open<int>(_action('a')).result;
      holder.minimize('a');

      await tester.pump(_config.defaultLifetime - const Duration(seconds: 1));
      expect(holder.state.entryOf('a')?.isDormant, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(holder.state.entryOf('a')?.isDormant, isTrue);

      // Eviction keeps the result pending; it completes on close.
      holder.restore('a');
      holder.closeDialog('a', 7);
      expect(await result, 7);
      await holder.close();
    });

    testWidgets(
      'pinned windows never expire; unpinning restarts the lifetime',
      (tester) async {
        final holder = _cubit();
        holder.open(_action('a'));
        holder.togglePin('a');
        holder.minimize('a');

        await tester.pump(_config.defaultLifetime * 3);
        expect(holder.state.pinnedEntries.map((e) => e.id), ['a']);

        holder.togglePin('a');
        await tester.pump(_config.defaultLifetime - const Duration(seconds: 1));
        expect(holder.state.entryOf('a')?.isDormant, isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(holder.state.entryOf('a')?.isDormant, isTrue);
        await holder.close();
      },
    );

    testWidgets('restoring cancels expiry', (tester) async {
      final holder = _cubit();
      holder.open(_action('a'));
      holder.minimize('a');
      holder.restore('a');

      await tester.pump(_config.defaultLifetime * 2);
      expect(holder.state.activeEntry?.id, 'a');
      await holder.close();
    });

    testWidgets('lifetime changes apply to already minimized windows', (
      tester,
    ) async {
      final holder = _cubit();
      holder.open(_action('a'));
      holder.minimize('a');
      await holder.setLifetime(const Duration(minutes: 1));

      expect(storage.readLifetimeMinutes(), 1);
      await tester.pump(const Duration(minutes: 1));
      expect(holder.state.entryOf('a')?.isDormant, isTrue);

      final restarted = _cubit();
      expect(restarted.state.lifetime.inMinutes, 1);
      await restarted.close();
      await holder.close();
    });

    test('memory limit evicts the least recently minimized window', () async {
      final holder = _cubit(
        config: const FloatingDialogConfig(maxMountedWindows: 2),
      );
      holder.open(_action('pinned'));
      holder.togglePin('pinned');
      holder.minimize('pinned');
      for (final id in ['a', 'b', 'c']) {
        holder.open(_action(id));
        holder.minimize(id);
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(holder.state.entryOf('a')?.isDormant, isTrue);
      expect(holder.state.entryOf('b')?.isDormant, isFalse);
      expect(holder.state.entryOf('c')?.isDormant, isFalse);
      expect(holder.state.entryOf('pinned')?.isDormant, isFalse);
      await holder.close();
    });

    test('toggleSize flips between normal and large', () {
      final holder = _cubit();
      holder.open(_action('a'));
      holder.toggleSize('a');
      expect(holder.state.isLargeWindowActive, isTrue);
      holder.toggleSize('a');
      expect(holder.state.isLargeWindowActive, isFalse);
      holder.close();
    });

    test('unchanged lists are not written again', () async {
      final counting = _CountingStorage();
      storage = counting;
      final holder = _cubit();
      holder.open(_action('a'));
      final writes = counting.writes;
      holder.toggleExpanded();
      holder.open(_action('a')); // already active: nothing changes
      expect(counting.writes, writes);
      holder.toggleSize('a');
      expect(counting.writes, writes + 1);
      await holder.close();
    });
  });

  group('Restart and storage', () {
    test('restart restores only restorable items of the same user', () async {
      final holder = _cubit();
      holder.open(_action('treasury'));
      holder.minimize('treasury');
      holder.open(_action('inventory'));
      holder.togglePin('inventory');
      holder.open(_action('customers', isRestorable: false));
      holder.minimize('customers');
      await holder.close();

      final restarted = _cubit();
      expect(restarted.state.entries.map((e) => e.id), [
        'treasury',
        'inventory',
      ]);
      expect(restarted.state.entries.every((e) => e.isDormant), isTrue);
      expect(restarted.state.entryOf('inventory')?.isPinned, isTrue);
      // Hidden until the app registers the action again.
      expect(restarted.state.heldEntries, isEmpty);
      restarted.registerActions([_action('treasury'), _action('inventory')]);
      expect(restarted.state.heldEntries.map((e) => e.id), ['treasury']);
      expect(restarted.state.pinnedEntries.map((e) => e.id), ['inventory']);
      await restarted.close();

      user = 8;
      final otherUser = _cubit();
      expect(otherUser.state.entries, isEmpty);
      await otherUser.close();
    });

    test('unpinned items past their lifetime are dropped on startup', () async {
      final old = DateTime.now().subtract(const Duration(days: 1));
      await storage.writeEntries({
        'userId': 7,
        'entries': [
          {'id': 'old', 'pinned': false, 'minimizedAt': old.toIso8601String()},
          {'id': 'kept', 'pinned': true, 'minimizedAt': old.toIso8601String()},
          {
            'id': 'recent',
            'pinned': false,
            'minimizedAt': DateTime.now().toIso8601String(),
          },
          'malformed',
        ],
      });
      final holder = _cubit();
      expect(holder.state.entries.map((e) => e.id), ['kept', 'recent']);
      await holder.close();
    });

    test('key-value storage works with SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'floatingDialogEntries':
            '{"userId":7,"entries":[{"id":"treasury","pinned":true}]}',
      });
      final prefs = await SharedPreferences.getInstance();
      storage = KeyValueFloatingDialogStorage(
        readString: prefs.getString,
        writeString: prefs.setString,
      );

      final holder = _cubit();
      expect(holder.state.entryOf('treasury')?.isPinned, isTrue);
      await holder.setLifetime(const Duration(minutes: 45));
      expect(storage.readLifetimeMinutes(), 45);
      expect(prefs.getString('floatingDialogLifetime'), '45');
      await holder.close();
    });
  });

  group('Windows', () {
    testWidgets('minimize keeps dialog state; close disposes it', (
      tester,
    ) async {
      _desktop(tester);
      _CounterCubit.closedCount = 0;

      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('form', builder: _formDialog));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field')), 'draft');

      await tester.tap(find.byTooltip(_strings.minimize));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field')), findsNothing);
      expect(find.byTooltip('form\n${_strings.pinHint}'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsOneWidget);
      expect(_CounterCubit.closedCount, 0);

      await tester.tap(find.byTooltip(_strings.close));
      await tester.pumpAndSettle();
      expect(holder.state.entries, isEmpty);
      expect(_CounterCubit.closedCount, 1);
      await holder.close();
    });

    testWidgets('an existing AlertDialog works unchanged and returns its '
        'result', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));

      final result = showFloatingDialog<String>(
        context: _homeKey.currentContext!,
        id: 'confirm',
        title: 'Confirm',
        builder:
            (context) => AlertDialog(
              content: const Text('Delete?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'yes'),
                  child: const Text('Yes'),
                ),
              ],
            ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      // One title bar, the holder's.
      expect(find.text('Confirm'), findsOneWidget);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(await result, 'yes');
      expect(holder.state.entries, isEmpty);
      expect(find.byKey(_homeKey), findsOneWidget);
      await holder.close();
    });

    testWidgets('a dialog opened from a window stays above it; Back closes '
        'it first, then the window', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(
        _action(
          'parent',
          builder:
              (context) => TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => const AlertDialog(content: Text('nested')),
                    ),
                child: const Text('open nested'),
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open nested'));
      await tester.pumpAndSettle();
      expect(find.text('nested'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('nested'), findsNothing);
      expect(holder.state.activeEntry?.id, 'parent');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(holder.state.entries, isEmpty);
      // The page underneath was not popped.
      expect(find.byKey(_homeKey), findsOneWidget);
      await holder.close();
    });

    testWidgets('Back while a window is active never leaves the page', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      _navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('details')),
        ),
      );
      await tester.pumpAndSettle();

      holder.open(_action('a'));
      holder.minimize('a');
      holder.restore('a');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(holder.state.activeEntry, isNull);
      expect(holder.state.heldEntries.map((e) => e.id), ['a']);
      expect(find.text('details'), findsOneWidget);

      // With no window open, Back works as usual again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('details'), findsNothing);
      await holder.close();
    });

    testWidgets('Esc dismisses, Ctrl+M minimizes', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));

      holder.open(_action('form', builder: _formDialog));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(holder.state.activeEntry, isNull);
      expect(holder.state.heldEntries, hasLength(1));

      holder.closeDialog('form');
      holder.open(_action('new'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(holder.state.entries, isEmpty);
      await holder.close();
    });

    testWidgets('focus stays in the window and returns to the app after', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      final appField = FocusNode();
      addTearDown(appField.dispose);
      await tester.pumpWidget(
        _app(
          holder,
          home: Scaffold(
            key: _homeKey,
            body: Column(
              children: [
                TextField(focusNode: appField),
                TextButton(onPressed: () {}, child: const Text('behind')),
              ],
            ),
          ),
        ),
      );
      appField.requestFocus();
      await tester.pump();

      holder.open(_action('form', builder: _formDialog));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        expect(
          focused?.findAncestorWidgetOfExactType<TextButton>(),
          isNull,
          reason: 'Tab reached the app behind the window',
        );
        expect(appField.hasFocus, isFalse);
      }

      holder.closeDialog('form');
      await tester.pumpAndSettle();
      expect(appField.hasFocus, isTrue);
      await holder.close();
    });

    testWidgets('tap outside closes a new window, re-holds a held one', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('form', builder: _formDialog));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(holder.state.entries, isEmpty);

      holder.open(_action('form', builder: _formDialog));
      holder.minimize('form');
      holder.restore('form');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(holder.state.activeEntry, isNull);
      expect(holder.state.heldEntries.map((e) => e.id), ['form']);

      holder.open(_action('busy', canPause: () => false));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(holder.state.entryOf('busy'), isNull);
      await holder.close();
    });

    testWidgets('opening while another window is active tells the user', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      await tester.pumpAndSettle();

      final result = showFloatingDialog<int>(
        context: _homeKey.currentContext!,
        id: 'b',
        title: 'b',
        builder: (_) => const SizedBox(),
      );
      expect(await result, isNull);
      await tester.pump();
      expect(find.text(_strings.windowBusy), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await holder.close();
    });

    testWidgets('content pause guard blocks minimize while busy', (
      tester,
    ) async {
      _desktop(tester);
      var busy = true;
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(
        _action(
          'shift',
          builder:
              (_) => FloatingDialogPauseGuard(
                canPause: () => !busy,
                child: const SizedBox(),
              ),
        ),
      );
      await tester.pumpAndSettle();

      expect(holder.minimize('shift'), isFalse);
      busy = false;
      expect(holder.minimize('shift'), isTrue);
      await tester.pumpAndSettle();
      await holder.close();
    });

    testWidgets('minimized window reports inactive', (tester) async {
      _desktop(tester);
      late BuildContext contentContext;
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(
        _action(
          'a',
          builder: (context) {
            contentContext = context;
            return const SizedBox();
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(isFloatingDialogActive(contentContext), isTrue);

      holder.minimize('a');
      await tester.pumpAndSettle();
      expect(isFloatingDialogActive(contentContext), isFalse);
      await holder.close();
    });

    testWidgets('eviction disposes the dialog; the state keeper brings its '
        'content back', (tester) async {
      _desktop(tester);
      _CounterCubit.closedCount = 0;
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('note', builder: (_) => const _KeptNote()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note')), 'kept text');
      holder.minimize('note');
      holder.open(_action('form', builder: _formDialog));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field')), 'draft');
      holder.minimize('form');
      await tester.pump(_config.defaultLifetime);
      await tester.pumpAndSettle();

      expect(holder.state.entryOf('form')?.isDormant, isTrue);
      expect(holder.state.entryOf('note')?.isDormant, isTrue);
      expect(_CounterCubit.closedCount, 1);

      // Without a keeper the content starts fresh...
      expect(holder.restore('form'), FloatingDialogStatus.restored);
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsNothing);
      holder.minimize('form');
      // ...with one it comes back.
      holder.restore('note');
      await tester.pumpAndSettle();
      expect(find.text('kept text'), findsOneWidget);
      await holder.close();
    });

    testWidgets('permission changes close and hide windows', (tester) async {
      _desktop(tester);
      _CounterCubit.closedCount = 0;

      final permissionsChanged = ValueNotifier(0);
      addTearDown(permissionsChanged.dispose);
      var allowed = true;
      bool isAllowed() => allowed;
      final holder = _cubit(availabilityChanges: permissionsChanged);
      await tester.pumpWidget(_app(holder));

      holder.open(
        _action('form', builder: _formDialog, isAvailable: isAllowed),
      );
      holder.minimize('form');
      final customers =
          holder
              .open<int>(
                _action(
                  'customers',
                  isAvailable: isAllowed,
                  isRestorable: false,
                ),
              )
              .result;
      await tester.pumpAndSettle();

      allowed = false;
      permissionsChanged.value++;
      await tester.pumpAndSettle();

      expect(_CounterCubit.closedCount, 1);
      expect(holder.state.activeEntry, isNull);
      expect(holder.state.entryOf('form')?.isDormant, isTrue);
      expect(holder.state.entryOf('customers'), isNull);
      expect(await customers, isNull);
      expect(holder.state.heldEntries, isEmpty);
      expect(holder.restore('form'), FloatingDialogStatus.notFound);

      allowed = true;
      holder.registerActions([
        _action('form', builder: _formDialog, isAvailable: isAllowed),
      ]);
      expect(holder.state.heldEntries.single.isDormant, isTrue);
      expect(holder.restore('form'), FloatingDialogStatus.restored);

      holder.minimize('form');
      allowed = false;
      expect(holder.restore('form'), FloatingDialogStatus.unavailable);
      expect(holder.state.heldEntries, isEmpty);
      await tester.pumpAndSettle();
      await holder.close();
    });

    testWidgets('window follows the screen size', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a', showFrame: false));
      await tester.pumpAndSettle();
      Size windowSize() => tester.getSize(find.byType(AnimatedContainer).first);
      expect(windowSize(), const Size(1600 * 0.64, 1000 * 0.64));

      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpAndSettle();
      expect(windowSize(), const Size(1000 * 0.8, 800 * 0.72));
      await holder.close();
    });

    testWidgets('a holder inside a route still catches Back', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('first')),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder:
              (_) => FloatingDialogHolder(
                controller: holder,
                child: const Scaffold(body: Text('shell')),
              ),
        ),
      );
      await tester.pumpAndSettle();
      holder.open(_action('a', builder: _formDialog));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field')), findsOneWidget);
      await tester.tap(find.byKey(const Key('field')));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(holder.state.entries, isEmpty);
      expect(find.text('shell'), findsOneWidget);
      await holder.close();
    });

    testWidgets('falls back to showDialog without a holder', (tester) async {
      final home = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: Scaffold(key: home)));
      final result = showFloatingDialog<int>(
        context: home.currentContext!,
        id: 'a',
        title: 'Plain',
        builder:
            (context) => TextButton(
              onPressed: () => Navigator.pop(context, 3),
              child: const Text('ok'),
            ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plain'), findsOneWidget);
      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle();
      expect(await result, 3);
    });

    testWidgets('disposing the holder closes the controller it created', (
      tester,
    ) async {
      _desktop(tester);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FloatingDialogHolder(child: child!),
          home: SizedBox(key: key),
        ),
      );
      final holder = FloatingDialogHolder.of(key.currentContext!);
      holder.open(_action('a'));
      holder.minimize('a');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(holder.isClosed, isTrue);
    });
  });

  group('Customization', () {
    testWidgets('extra header actions, chosen buttons, custom frame', (
      tester,
    ) async {
      _desktop(tester);
      var printed = 0;
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(
        _action(
          'invoice',
          headerActions: [
            FloatingDialogHeaderAction(
              tooltip: 'Print',
              icon: Icons.print,
              onPressed: (_) => printed++,
            ),
          ],
          windowButtons: const {
            FloatingDialogWindowButton.minimize,
            FloatingDialogWindowButton.close,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip(_strings.pin), findsNothing);
      expect(find.byTooltip(_strings.maximize), findsNothing);
      await tester.tap(find.byTooltip('Print'));
      expect(printed, 1);
      holder.closeDialog('invoice');

      holder.open(
        _action(
          'custom',
          frameBuilder:
              (context, d) => Column(
                children: [
                  Text('custom ${d.title}'),
                  d.buttons,
                  Expanded(child: d.body),
                ],
              ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('custom custom'), findsOneWidget);
      expect(find.byTooltip(_strings.minimize), findsOneWidget);
      await holder.close();
    });

    testWidgets('icon builder (e.g. SVG) and theme colors', (tester) async {
      _desktop(tester);
      Color? iconColor;
      final holder = _cubit();
      await tester.pumpWidget(
        _app(
          holder,
          theme: ThemeData(
            extensions: const [
              FloatingDialogColors(
                item: Colors.orange,
                headerBackground: Colors.teal,
              ),
            ],
          ),
        ),
      );
      holder.open(
        _action(
          'svg',
          iconBuilder: (context, color, size) {
            iconColor = color;
            return const Placeholder(key: Key('svg-icon'));
          },
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.widget<ColoredBox>(
        find
            .ancestor(of: find.text('svg'), matching: find.byType(ColoredBox))
            .first,
      );
      expect(header.color, Colors.teal);

      holder.minimize('svg');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('svg-icon')), findsOneWidget);
      expect(iconColor, Colors.orange);
      await holder.close();
    });

    testWidgets('RTL puts the holder on the left', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder, direction: TextDirection.rtl));
      holder.open(_action('a'));
      holder.minimize('a');
      await tester.pumpAndSettle();
      final item = tester.getCenter(find.byIcon(Icons.inventory_2_outlined));
      expect(item.dx, lessThan(100));
      await holder.close();
    });

    testWidgets('holder items have screen reader labels', (tester) async {
      _desktop(tester);
      final handle = tester.ensureSemantics();
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('treasury'));
      holder.minimize('treasury');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('treasury'), findsOneWidget);

      // While a window is open, the app behind it is hidden from screen
      // readers.
      String tree() =>
          RendererBinding
              .instance
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!
              .toStringDeep();
      await tester.pumpWidget(
        _app(holder, home: Scaffold(key: _homeKey, body: const Text('page'))),
      );
      expect(tree(), contains('"page"'));
      holder.restore('treasury');
      await tester.pumpAndSettle();
      expect(tree(), isNot(contains('"page"')));
      expect(tree(), contains('"treasury"'));
      handle.dispose();
      await holder.close();
    });
  });

  group('Window design', () {
    Future<FloatingDialogHolderCubit> openOne(
      WidgetTester tester,
      FloatingDialogConfig config, {
      List<FloatingDialogHeaderAction> headerActions = const [],
    }) async {
      _desktop(tester);
      final holder = _cubit(config: config);
      await tester.pumpWidget(_app(holder));
      holder.open(
        FloatingDialogAction(
          id: 'a',
          title: 'Window A',
          icon: Icons.inventory_2_outlined,
          headerActions: headerActions,
          builder: (_) => const Text('body'),
        ),
      );
      await tester.pumpAndSettle();
      return holder;
    }

    double x(WidgetTester tester, String tooltip) =>
        tester.getCenter(find.byTooltip(tooltip)).dx;

    testWidgets('traffic lights: macOS order at the start, title centered', (
      tester,
    ) async {
      final holder = await openOne(tester, const FloatingDialogConfig());
      final title = tester.getRect(find.text('Window A'));
      final close = x(tester, _strings.close);
      expect(close, lessThan(x(tester, _strings.minimize)));
      expect(
        x(tester, _strings.minimize),
        lessThan(x(tester, _strings.maximize)),
      );
      expect(x(tester, _strings.maximize), lessThan(x(tester, _strings.pin)));
      expect(close, lessThan(title.left));
      await holder.close();
    });

    testWidgets('tonal: trailing, close last', (tester) async {
      final holder = await openOne(
        tester,
        const FloatingDialogConfig(
          windowButtonStyle: FloatingDialogWindowButtonStyle.tonal,
        ),
      );
      final title = tester.getRect(find.text('Window A'));
      expect(x(tester, _strings.minimize), greaterThan(title.left));
      expect(
        x(tester, _strings.close),
        greaterThan(x(tester, _strings.maximize)),
      );
      await holder.close();
    });

    testWidgets('custom icons replace the built-in look and still work', (
      tester,
    ) async {
      final holder = await openOne(
        tester,
        const FloatingDialogConfig(
          windowButtonIcons: FloatingDialogWindowButtonIcons(
            minimize: Text('MIN', key: Key('custom-min')),
          ),
        ),
      );
      expect(find.byKey(const Key('custom-min')), findsOneWidget);
      await tester.tap(find.byKey(const Key('custom-min')));
      await tester.pumpAndSettle();
      expect(holder.state.entryOf('a')!.isMinimized, isTrue);
      await holder.close();
    });

    testWidgets('decorations: built-in and per header action', (tester) async {
      const builtIn = BoxDecoration(color: Color(0xFF123456));
      const own = BoxDecoration(color: Color(0xFF654321));
      final holder = await openOne(
        tester,
        const FloatingDialogConfig(windowButtonDecoration: builtIn),
        headerActions: [
          FloatingDialogHeaderAction(
            tooltip: 'Print',
            icon: Icons.print,
            decoration: own,
            onPressed: (_) {},
          ),
        ],
      );
      Iterable<Decoration?> decorationsUnder(String tooltip) => tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byTooltip(tooltip),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .map((c) => c.decoration);
      expect(decorationsUnder(_strings.close), contains(builtIn));
      expect(decorationsUnder('Print'), contains(own));
      await holder.close();
    });

    testWidgets('headerHeight sets the header height', (tester) async {
      final holder = await openOne(
        tester,
        const FloatingDialogConfig(
          headerHeight: 72,
          windowButtonStyle: FloatingDialogWindowButtonStyle.tonal,
        ),
      );
      final header = find.ancestor(
        of: find.text('Window A'),
        matching: find.byType(Container),
      );
      expect(tester.getSize(header.first).height, 72);
      await holder.close();
    });

    testWidgets('liquid glass: frosted window and holder', (tester) async {
      final holder = await openOne(
        tester,
        const FloatingDialogConfig(liquidGlass: true),
      );
      expect(find.byType(BackdropFilter), findsWidgets);
      holder.minimize('a');
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(tester.takeException(), isNull);
      await holder.close();
    });
  });

  group('Draggable holder', () {
    Finder bar() => find.byType(FloatingDialogGlassSurface);
    final bubble = find.byIcon(Icons.inventory_2_outlined);

    Future<FloatingDialogHolderCubit> withBubble(
      WidgetTester tester, {
      FloatingDialogConfig config = _config,
    }) async {
      _desktop(tester);
      final holder = _cubit(config: config);
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      await tester.pumpAndSettle();
      holder.minimize('a');
      await tester.pumpAndSettle();
      return holder;
    }

    testWidgets('moves anywhere; taps still work; the spot is kept', (
      tester,
    ) async {
      final holder = await withBubble(tester);
      final start = tester.getRect(bar());

      await tester.drag(bar(), const Offset(-900, -500));
      await tester.pumpAndSettle();
      final moved = tester.getRect(bar());
      expect(moved.center.dx, lessThan(start.center.dx - 800));
      expect(moved.bottom, lessThan(start.bottom - 400));
      expect(tester.takeException(), isNull);

      // The bubble still restores on tap, and the spot survives a
      // minimize / restore cycle.
      await tester.tap(bubble);
      await tester.pumpAndSettle();
      expect(holder.state.entryOf('a')!.isActive, isTrue);
      holder.minimize('a');
      await tester.pumpAndSettle();
      expect(tester.getRect(bar()), moved);

      // Long press still pins.
      await tester.longPress(bubble);
      await tester.pumpAndSettle();
      expect(holder.state.entryOf('a')!.isPinned, isTrue);
      await holder.close();
    });

    testWidgets('stays fully on screen', (tester) async {
      final holder = await withBubble(tester);
      await tester.drag(bar(), const Offset(-5000, -5000));
      await tester.pumpAndSettle();
      var rect = tester.getRect(bar());
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));

      await tester.drag(bar(), const Offset(5000, 5000));
      await tester.pumpAndSettle();
      rect = tester.getRect(bar());
      expect(rect.right, lessThanOrEqualTo(1600));
      expect(rect.bottom, lessThanOrEqualTo(1000));
      await holder.close();
    });

    testWidgets('back in its corner after an app restart', (tester) async {
      final first = await withBubble(tester);
      final corner = tester.getRect(bar());
      await tester.drag(bar(), const Offset(-700, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar()), isNot(corner));

      // Restart: the old holder goes away, a new one starts.
      await tester.pumpWidget(const SizedBox());
      await first.close();
      final second = await withBubble(tester);
      expect(tester.getRect(bar()), corner);
      await second.close();
    });

    testWidgets('holderDraggable: false keeps it in its corner', (
      tester,
    ) async {
      final holder = await withBubble(
        tester,
        config: const FloatingDialogConfig(holderDraggable: false),
      );
      final corner = tester.getRect(bar());
      await tester.drag(bar(), const Offset(-700, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar()), corner);
      await holder.close();
    });
  });

  group('Animations', () {
    Finder effect() => find.descendant(
      of: find.byType(FloatingDialogEffectsLayer),
      matching: find.byType(CustomPaint),
    );
    Finder effectPaint() => effect();

    for (final style in FloatingDialogMinimizeEffect.values) {
      testWidgets('$style: minimize flies into the item, restore flies back', (
        tester,
      ) async {
        _desktop(tester);
        final holder = _cubit(
          config: FloatingDialogConfig(minimizeEffect: style),
        );
        await tester.pumpWidget(_app(holder));
        holder.open(_action('form', builder: _formDialog));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('field')), 'draft');

        holder.minimize('form');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(effect(), findsOneWidget);
        await tester.pumpAndSettle();
        expect(effect(), findsNothing);
        expect(tester.takeException(), isNull);

        holder.restore('form');
        await tester.pump();
        await tester.pump(); // measures where the window lands, then starts
        await tester.pump(const Duration(milliseconds: 100));
        expect(effect(), findsOneWidget);
        await tester.pumpAndSettle();
        expect(effect(), findsNothing);
        // Usable again, state kept.
        expect(find.text('draft'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('field')), 'again');
        expect(find.text('again'), findsOneWidget);
        await holder.close();
      });
    }

    for (final (effect, kind) in [
      (FloatingDialogCloseEffect.slideDown, FloatingDialogEffectKind.closeDown),
      (FloatingDialogCloseEffect.fade, FloatingDialogEffectKind.close),
    ]) {
      testWidgets('$effect: closing a new window plays $kind', (tester) async {
        _desktop(tester);
        final holder = _cubit(
          config: FloatingDialogConfig(closeEffect: effect),
        );
        await tester.pumpWidget(_app(holder));
        holder.open(_action('a'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(_strings.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final layer = tester.state<FloatingDialogEffectsLayerState>(
          find.byType(FloatingDialogEffectsLayer),
        );
        expect(layer.runningKinds, [kind]);
        expect(effectPaint(), findsOneWidget);
        await tester.pumpAndSettle();
        expect(layer.runningKinds, isEmpty);
        expect(tester.takeException(), isNull);
        await holder.close();
      });
    }

    testWidgets('a header tooltip shown while opening survives the zoom', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('form', builder: _formDialog));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      // The mouse is over a window button while the window zooms in.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byTooltip(_strings.minimize)));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tooltips keep working afterwards.
      await mouse.moveTo(tester.getCenter(find.byTooltip(_strings.close)));
      await tester.pumpAndSettle();
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await holder.close();
    });

    testWidgets('grows out of the origin widget and shrinks back into it', (
      tester,
    ) async {
      _desktop(tester);
      final origin = GlobalKey();
      final holder = _cubit();
      await tester.pumpWidget(
        _app(
          holder,
          home: Scaffold(
            key: _homeKey,
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(key: origin, width: 40, height: 40),
            ),
          ),
        ),
      );
      final result = showFloatingDialog<int>(
        context: _homeKey.currentContext!,
        id: 'photo',
        title: 'Photo',
        originKey: origin,
        showFrame: false,
        builder: (_) => const SizedBox.expand(key: Key('photo-body')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final early = tester.getRect(find.byKey(const Key('photo-body')));
      expect(early.center.dx, lessThan(400));
      expect(early.width, lessThan(400));

      await tester.pumpAndSettle();
      final settled = tester.getRect(find.byKey(const Key('photo-body')));
      expect(settled.center, const Offset(800, 500));

      holder.closeDialog('photo', 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(effect(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(effect(), findsNothing);
      expect(await result, 1);
      await holder.close();
    });

    testWidgets('reduce motion turns the effects off', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(
        MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: FloatingDialogHolder(controller: holder, child: child!),
              ),
          home: const SizedBox(),
        ),
      );
      holder.open(_action('form', builder: _formDialog));
      await tester.pump();
      expect(find.byKey(const Key('field')), findsOneWidget);
      holder.minimize('form');
      await tester.pump();
      expect(effect(), findsNothing);
      holder.restore('form');
      await tester.pump();
      expect(effect(), findsNothing);
      holder.closeDialog('form');
      await tester.pump();
      await tester.pump();
      expect(effect(), findsNothing);
      await holder.close();
    });
  });

  group('Holder bar and dock', () {
    testWidgets('many pinned and held items fit on a short screen', (
      tester,
    ) async {
      _desktop(tester, size: const Size(1000, 500));
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      for (var i = 0; i < 15; i++) {
        holder.open(_action('p$i'));
        holder.togglePin('p$i');
        holder.minimize('p$i');
        holder.open(_action('h$i'));
        holder.minimize('h$i');
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await holder.close();
    });

    testWidgets('settings open from the bar; Back closes them', (tester) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      holder.minimize('a');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text(_strings.lifetime), findsOneWidget);
      await tester.tap(find.text('30 min'));
      await tester.pump();
      expect(holder.state.lifetime, const Duration(minutes: 30));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(_strings.lifetime), findsNothing);
      expect(find.byKey(_homeKey), findsOneWidget);
      await holder.close();
    });

    testWidgets('fast hover in/out on the pinned dock does not crash', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      holder.togglePin('a');
      holder.minimize('a');
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final edge = Offset(1600 - _config.dockEdgeOffset - 4, 500);
      for (var i = 0; i < 4; i++) {
        await mouse.moveTo(edge);
        await tester.pump(const Duration(milliseconds: 30));
        await mouse.moveTo(const Offset(800, 500));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await holder.close();
    });

    testWidgets('minimize tooltip does not linger after minimizing', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('form', builder: _formDialog));
      await tester.pumpAndSettle();

      final minimize = find.byTooltip(_strings.minimize);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(minimize));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text(_strings.minimize), findsOneWidget);

      // iPadOS: the hover pointer is removed while the click is delivered
      // as a touch, then comes back where it was.
      final location = tester.getCenter(minimize);
      await mouse.removePointer();
      await tester.tapAt(location);
      await tester.pump();
      await mouse.addPointer(location: location);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(holder.state.activeEntry, isNull);
      expect(find.text(_strings.minimize, skipOffstage: false), findsNothing);
      await mouse.removePointer();
      await holder.close();
    });

    testWidgets('pinned dock items stay tappable when hover exits on press', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      holder.togglePin('a');
      holder.minimize('a');
      holder.open(_action('b'));
      holder.togglePin('b');
      holder.minimize('b');
      await tester.pumpAndSettle();

      final edge = Offset(1600 - _config.dockEdgeOffset - 4, 500);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(edge);
      await tester.pumpAndSettle();
      final close = find.byTooltip(_strings.close);
      expect(close, findsNWidgets(2));
      final closeCenter = tester.getCenter(close.last);
      await mouse.moveTo(const Offset(800, 500));
      await tester.pump();
      await tester.tapAt(closeCenter);
      await tester.pumpAndSettle();
      expect(holder.state.entryOf('b'), isNull);

      // Touch only: tapping the indicator reveals the dock, then restore.
      await tester.pump(_config.dockTouchRevealDuration);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
      await tester.tapAt(edge);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await tester.pumpAndSettle();
      expect(holder.state.activeEntry?.id, 'a');
      await holder.close();
    });

    testWidgets('phone: pinned strip collapses; tap reveals it briefly', (
      tester,
    ) async {
      _desktop(tester, size: const Size(390, 844));
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      holder.togglePin('a');
      holder.minimize('a');
      await tester.pumpAndSettle();

      final item = find.byIcon(Icons.inventory_2_outlined);
      expect(item, findsNothing);

      await tester.tapAt(Offset(390 - _config.dockEdgeOffset - 12, 422));
      await tester.pumpAndSettle();
      expect(item, findsOneWidget);

      await tester.pump(_config.dockTouchRevealDuration);
      await tester.pumpAndSettle();
      expect(item, findsNothing);
      await holder.close();
    });

    testWidgets('tablet: pinned dock collapses until hovered or tapped', (
      tester,
    ) async {
      _desktop(tester, size: const Size(900, 1100));
      final holder = _cubit();
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      holder.togglePin('a');
      holder.minimize('a');
      await tester.pumpAndSettle();

      final item = find.byIcon(Icons.inventory_2_outlined);
      final strip = Offset(900 - _config.dockEdgeOffset - 12, 550);
      expect(item, findsNothing);

      // Mouse (e.g. iPad with a trackpad, or a narrow browser window).
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(strip);
      await tester.pumpAndSettle();
      expect(item, findsOneWidget);
      await mouse.moveTo(const Offset(100, 100));
      await tester.pump(_config.dockHoverCollapseDelay);
      await tester.pumpAndSettle();
      expect(item, findsNothing);

      // Touch.
      await tester.tapAt(strip);
      await tester.pumpAndSettle();
      expect(item, findsOneWidget);
      await tester.pump(_config.dockTouchRevealDuration);
      await tester.pumpAndSettle();
      expect(item, findsNothing);
      await holder.close();
    });

    testWidgets('dockAlwaysExpanded keeps pinned items visible', (
      tester,
    ) async {
      _desktop(tester);
      final holder = _cubit(
        config: const FloatingDialogConfig(dockAlwaysExpanded: true),
      );
      await tester.pumpWidget(_app(holder));
      holder.open(_action('a'));
      holder.togglePin('a');
      holder.minimize('a');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      await holder.close();
    });
  });
}

class _KeptNote extends StatefulWidget {
  const _KeptNote();

  @override
  State<_KeptNote> createState() => _KeptNoteState();
}

class _KeptNoteState extends State<_KeptNote> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FloatingDialogStateKeeper<String>(
    onSave: () => _controller.text,
    onRestore: (text) => _controller.text = text,
    child: TextField(key: const Key('note'), controller: _controller),
  );
}

class _CountingStorage extends InMemoryFloatingDialogStorage {
  int writes = 0;

  @override
  Future<void> writeEntries(Map<String, dynamic> data) {
    writes++;
    return super.writeEntries(data);
  }
}
