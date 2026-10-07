import 'package:flutter/material.dart';

import '../data/models/entry.dart';
import '../data/tag_scope.dart';
import 'diary/detail_page.dart';
import 'diary/edit_page.dart';
import 'diary/list_page.dart';
import 'settings/settings_page.dart';

/// 桌面与移动共用的主壳。
///
/// 窄窗口：底部 Tab + FAB；宽窗口（≥1000）：左侧列表 + 右侧阅读区双栏，
/// 选中即读，不用为每一篇都跳一次页面。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const double wideBreakpoint = 1000;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<DiaryListPageState> _listKey = GlobalKey<DiaryListPageState>();
  final GlobalKey<SettingsPageState> _settingsKey = GlobalKey<SettingsPageState>();
  final TagPaletteNotifier _palette = TagPaletteNotifier();

  int _tab = 0;
  Entry? _selected;

  @override
  void initState() {
    super.initState();
    _palette.reload();
  }

  @override
  void dispose() {
    _palette.dispose();
    super.dispose();
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= HomePage.wideBreakpoint;

  void _selectTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _settingsKey.currentState?.reload();
  }

  void _openEntry(Entry e) {
    if (_wide) {
      setState(() => _selected = e);
    } else {
      EntryDetailView.open(context, e).then((_) => _listKey.currentState?.reload());
    }
  }

  Future<void> _newEntry() async {
    final Entry? saved = await EntryEditPage.open(
      context,
      entry: Entry.draft(),
    );
    if (saved == null) return;
    await _listKey.currentState?.reload();
    if (!mounted) return;
    if (_wide) setState(() => _selected = saved);
  }

  void _refreshAfterEdit(Entry updated) {
    _listKey.currentState?.reload();
    _palette.reload();
    if (_wide && _selected != null) setState(() => _selected = updated);
  }

  @override
  Widget build(BuildContext context) {
    return TagScope(
      notifier: _palette,
      child: _wide ? _buildWide() : _buildNarrow(),
    );
  }

  // ------------------------------------------------------------- 窄窗口

  Widget _buildNarrow() {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: <Widget>[
            DiaryListPage(key: _listKey, onOpenEntry: _openEntry),
            SettingsPage(key: _settingsKey),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '日记',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _newEntry,
              tooltip: '写日记',
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  // ------------------------------------------------------------- 宽窗口

  Widget _buildWide() {
    final double width = MediaQuery.sizeOf(context).width;
    final bool extended = width >= 1320;

    final Widget diaryPane = Row(
      children: <Widget>[
        SizedBox(
          width: 340,
          child: DiaryListPage(key: _listKey, onOpenEntry: _openEntry),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(child: _reader()),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _tab,
              extended: extended,
              minExtendedWidth: 168,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              onDestinationSelected: _selectTab,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Icon(
                  Icons.auto_stories,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: Text('日记'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('我的'),
                ),
              ],
            ),
            VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: _tab == 0 ? diaryPane : SettingsPage(key: _settingsKey),
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _newEntry,
              tooltip: '写日记',
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _reader() {
    final Entry? e = _selected;
    if (e == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.chrome_reader_mode_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '从左边选一篇日记',
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return EntryDetailView(
      entry: e,
      onChanged: (Entry updated) => _refreshAfterEdit(updated),
      onEdit: () => _listKey.currentState?.reload(),
    );
  }
}