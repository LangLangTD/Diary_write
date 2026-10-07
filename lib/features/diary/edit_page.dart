import 'package:flutter/material.dart';

import '../../core/cn_date.dart';
import '../../data/entry_repo.dart';
import '../../data/models/entry.dart';

/// 新建 / 编辑日记。
///
/// 元信息（日期、心情、天气、标签）集中在顶部一条，正文占据剩余全部空间，
/// 打开就能直接写，不需要先点进哪个区域。
class EntryEditPage extends StatefulWidget {
  const EntryEditPage({super.key, required this.entry, this.onSaved});

  final Entry entry;
  final ValueChanged<Entry>? onSaved;

  /// 打开编辑页，返回保存后的 Entry，取消返回 null
  static Future<Entry?> open(
    BuildContext context, {
    required Entry entry,
    ValueChanged<Entry>? onSaved,
  }) {
    return Navigator.of(context).push<Entry>(
      MaterialPageRoute<Entry>(
        builder: (_) => EntryEditPage(entry: entry, onSaved: onSaved),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<EntryEditPage> createState() => _EntryEditPageState();
}

class _EntryEditPageState extends State<EntryEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;

  late DateTime _date;
  int? _mood;
  String? _weather;
  List<String> _knownTags = <String>[];
  bool _dirty = false;
  bool _saving = false;

  bool get _isNew => widget.entry.id == null;

  @override
  void initState() {
    super.initState();
    final Entry e = widget.entry;
    _title = TextEditingController(text: e.title);
    _content = TextEditingController(text: e.content);
    _tags = TextEditingController(text: e.tags.join(', '));
    _date = e.date;
    _mood = e.mood;
    _weather = e.weather;
    for (final TextEditingController c in <TextEditingController>[_title, _content, _tags]) {
      c.addListener(_markDirty);
    }
    EntryRepo.allTags().then((List<String> tags) {
      if (mounted) setState(() => _knownTags = tags);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  List<String> get _parsedTags {
    return _tags.text
        .split(RegExp(r'[,，\s]+'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  void _addTag(String tag) {
    final List<String> next = <String>{..._parsedTags, tag}.toList();
    _tags.text = next.join(', ');
    setState(() {});
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: '这篇日记属于哪天',
    );
    if (picked == null) return;
    setState(() => _date = CnDate.dayOnly(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final Entry draft = widget.entry.copyWith(
      title: _title.text.trim(),
      content: _content.text,
      date: _date,
      mood: _mood,
      clearMood: _mood == null,
      weather: _weather,
      clearWeather: _weather == null,
      tags: _parsedTags,
      wordCount: Entry.countWords(_content.text),
      updatedAt: DateTime.now(),
    );
    if (draft.isBlank) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和正文都是空的，没法保存')),
      );
      return;
    }

    setState(() => _saving = true);
    final int? id;
    if (draft.id == null) {
      id = await EntryRepo.insert(draft);
    } else {
      await EntryRepo.update(draft);
      id = draft.id;
    }
    final Entry saved = draft.copyWith(id: id);

    if (!mounted) return;
    widget.onSaved?.call(saved);
    Navigator.of(context).pop(saved);
  }

  Future<void> _discardAndClose() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    // canPop 为 false 时必须先解除拦截，否则 pop 不生效
    setState(() => _dirty = false);
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('当前内容还没有保存。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _discardAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _discardAndClose,
          ),
          title: Text(_isNew ? '写日记' : '编辑'),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            _metaBar(cs),
            const Divider(height: 1),
            Expanded(child: _editor(cs)),
            _tagBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _metaBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.event, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${CnDate.cnFull(_date)} ${CnDate.weekday(_date)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 18, color: cs.primary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _moodPicker(cs),
            ],
          ),
          const SizedBox(height: 10),
          _weatherPicker(cs),
        ],
      ),
    );
  }

  Widget _moodPicker(ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ...Moods.faces.asMap().entries.map(
              (MapEntry<int, String> e) => GestureDetector(
                onTap: () => setState(() => _mood = _mood == e.key + 1 ? null : e.key + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity: _mood == null || _mood == e.key + 1 ? 1 : 0.32,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: _mood == e.key + 1
                            ? Border.all(color: cs.primary, width: 1.4)
                            : null,
                      ),
                      child: Text(e.value, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _weatherPicker(ColorScheme cs) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Weathers.names.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (BuildContext ctx, int i) {
          final bool selected = _weather == Weathers.names[i];
          return ChoiceChip(
            label: Text('${Weathers.icons[i]} ${Weathers.names[i]}'),
            selected: selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            onSelected: (_) =>
                setState(() => _weather = selected ? null : Weathers.names[i]),
          );
        },
      ),
    );
  }

  Widget _editor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _title,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText: '标题',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TextField(
              controller: _content,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: 16, height: 1.75, color: cs.onSurface),
              decoration: const InputDecoration(
                hintText: '今天发生了什么？',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagBar(ColorScheme cs) {
    final List<String> suggestions = _knownTags
        .where((String t) => !_parsedTags.contains(t))
        .take(8)
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              hintText: '标签，用逗号分隔',
              prefixIcon: Icon(Icons.sell_outlined, size: 17),
            ),
          ),
          if (suggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 26,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: suggestions
                    .map(
                      (String t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text('#$t', style: const TextStyle(fontSize: 11.5)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _addTag(t),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}