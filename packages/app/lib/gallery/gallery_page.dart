import 'package:flutter/material.dart';

import '../design/design.dart';

/// A sample sheet of the design system, shown until the real screens exist.
class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _scene = [
    ['赵太爷愈看愈生气了，抢进几步说：', '『你敢胡说！我怎么会有你这样的本家？你姓赵么？』'],
    ['阿Q不开口，想往后退了；赵太爷跳过去，给了他一个嘴巴。'],
    ['『你怎么会姓赵！——你那里配姓赵！』'],
    ['阿Q并没有抗辩他确凿姓赵，只用手摸着左颊，和地保退出去了。'],
  ];
  static const _speakers = [
    ['我', '赵太爷'],
    ['我'],
    ['赵太爷'],
    ['我'],
  ];

  var _current = (0, 1);
  (int, int)? _selected;
  var _playing = true;
  var _auditioning = '阿Q';
  var _mode = 'audiobook';
  var _autoGenerate = true;
  var _fontSize = 18.0;
  var _speed = '1.25';

  Future<void> _openLineMenu(int paragraph, int line, Offset at) async {
    setState(() => _selected = (paragraph, line));
    final p = context.ps;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy + 8, at.dx, at.dy),
      items: [
        PopupMenuItem(
          value: 'play',
          child: Row(
            spacing: PsSpace.s3,
            children: [
              PsIcon(PsIcons.playFrom, size: 20, color: p.ink2),
              const Text('从这里播放'),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    setState(() {
      _selected = null;
      if (choice == 'play') _current = (paragraph, line);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _header(),
                _section('书架', _shelf()),
                _section('正文', _passage(), pad: true),
                _section('演员表', _cast(), pad: false),
                _section('目录', _chapters(), pad: false),
                _section('操作', _actions()),
                _section('输入', _inputs()),
                _section('状态', _status()),
                _section('设置与浮层', _settings()),
                _section('图标', _icons()),
              ],
            ),
          ),
          // Text scrolls under the mini player and fades out above it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.paddingOf(context).bottom + 12 + 64 + 48,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.55],
                    colors: [p.paper.withValues(alpha: 0), p.paper],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: PsMiniPlayer(
              book: '阿Q正传',
              bookTone: 4,
              title: '第一章　序',
              speaker: _speakers[_current.$1][_current.$2],
              speakerTone: _speakers[_current.$1][_current.$2] == '我' ? 1 : 3,
              subtitle: _speakers[_current.$1][_current.$2],
              playing: _playing,
              progress: 0.41,
              onToggle: () => setState(() => _playing = !_playing),
              onNext: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PsSpace.s5,
        PsSpace.s3,
        PsSpace.s5,
        PsSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PsMark(size: 26, wordmark: true),
                  ),
                ),
              ),
              const SizedBox(width: PsSpace.s3),
              PsSegmentedControl<ThemeMode>(
                small: true,
                value: widget.themeMode,
                onChanged: widget.onThemeMode,
                segments: const [
                  PsSegment(ThemeMode.light, '纸'),
                  PsSegment(ThemeMode.dark, '夜'),
                  PsSegment(ThemeMode.system, '跟随'),
                ],
              ),
            ],
          ),
          const SizedBox(height: PsSpace.s6),
          Text('设计样张', style: PsType.title1.copyWith(color: p.ink)),
          const SizedBox(height: 2),
          Text(
            '一本会念给你听的书：纸面安静，声音是主角。',
            style: PsType.subhead.copyWith(color: p.ink2),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {bool pad = true}) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.only(top: PsSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s5,
              0,
              PsSpace.s5,
              PsSpace.s3,
            ),
            child: Text(
              title,
              style: PsType.caption.copyWith(color: p.ink2, letterSpacing: 2),
            ),
          ),
          pad
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
                  child: child,
                )
              : child,
        ],
      ),
    );
  }

  Widget _shelf() {
    final p = context.ps;
    const books = [
      ('阿Q正传', '鲁迅', 4, 0.32, '听到第 2 章'),
      ('Pride and Prejudice', 'Jane Austen', 2, null, '示例书'),
      ('聊斋志异', '蒲松龄', 5, 0.05, '建档中 12 / 40'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in books)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PsBookCover(title: b.$1, author: b.$2, tone: b.$3, width: 104),
                const SizedBox(height: PsSpace.s3),
                Text(
                  b.$1,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (b.$1.contains(' ')
                              ? PsType.style(
                                  PsFonts.serifEn,
                                  16,
                                  20,
                                  FontWeight.w500,
                                )
                              : PsType.style(
                                  PsFonts.serif,
                                  15,
                                  20,
                                  FontWeight.w600,
                                ))
                          .copyWith(color: p.ink),
                ),
                if (b.$4 != null) ...[
                  const SizedBox(height: PsSpace.s2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(value: b.$4, minHeight: 2),
                  ),
                ],
                const SizedBox(height: 6),
                Text(b.$5, style: PsType.caption.copyWith(color: p.ink2)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _passage() {
    final paragraphs = [
      for (var pi = 0; pi < _scene.length; pi++)
        [
          for (var li = 0; li < _scene[pi].length; li++)
            PsLine(
              _scene[pi][li],
              speaker: _speakers[pi][li],
              current: _current == (pi, li),
              selected: _selected == (pi, li),
            ),
        ],
      [const PsLine('（作者的话：本章完。）', skip: true)],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsPassage(
          heading: const PsPassageHeading(number: '第一章', title: '序'),
          size: _fontSize <= 16
              ? PsReadingSize.sm
              : _fontSize >= 21
              ? PsReadingSize.lg
              : PsReadingSize.md,
          paragraphs: paragraphs,
          onLineTap: (pi, li, at) {
            if (pi < _scene.length) _openLineMenu(pi, li, at);
          },
        ),
        const SizedBox(height: PsSpace.s6),
        const PsPassage(
          english: true,
          paragraphs: [
            [
              PsLine(
                '“My dear Mr. Bennet,”',
                speaker: 'Mrs. Bennet',
                current: true,
              ),
              PsLine(' said his lady to him one day, '),
              PsLine('“have you heard that Netherfield Park is let at last?”'),
            ],
            [PsLine('Mr. Bennet replied that he had not.')],
          ],
        ),
      ],
    );
  }

  Widget _cast() {
    void audition(String name) =>
        setState(() => _auditioning = _auditioning == name ? '' : name);
    return Column(
      children: [
        for (final c in const [
          ('旁白', 0, '沉稳的中年男声 · 阿里百炼', false),
          ('我', 1, '台词 312 · 温和的中年男声 · 阿里百炼', false),
          ('阿Q', 2, '台词 86 · 设计音色 · MiniMax', false),
          ('赵太爷', 3, '台词 23 · 威严的老年男声 · MiniMax', false),
          ('小D', 6, '少年男声', true),
        ])
          PsCastRow(
            name: c.$1,
            tone: c.$2 == 0 ? null : c.$2,
            narrator: c.$2 == 0,
            subtitle: c.$3,
            extra: c.$4,
            auditioning: _auditioning == c.$1,
            onAudition: () => audition(c.$1),
            onMore: () {},
          ),
      ],
    );
  }

  Widget _chapters() {
    return Column(
      children: [
        for (final c in const [
          (1, '第一章　序', PsChapterStatus.synthesized, '18:42'),
          (2, '第二章　优胜记略', PsChapterStatus.synthesized, '21:05'),
          (3, '第三章　续优胜记略', PsChapterStatus.directed, null),
          (4, '第四章　恋爱的悲剧', PsChapterStatus.working, null),
          (5, '第五章　生计问题', PsChapterStatus.none, null),
        ])
          PsChapterRow(
            index: c.$1,
            title: c.$2,
            status: c.$3,
            duration: c.$4,
            current: c.$1 == 2,
            playing: _playing,
            onTap: () {},
          ),
      ],
    );
  }

  Widget _actions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PsSpace.s4,
      children: [
        Wrap(
          spacing: PsSpace.s3,
          runSpacing: PsSpace.s3,
          children: [
            PsButton(
              label: '生成本章',
              variant: PsButtonVariant.primary,
              onPressed: () {},
            ),
            PsButton(label: '用系统朗读', onPressed: () {}),
            PsButton(
              label: '取消',
              variant: PsButtonVariant.ghost,
              onPressed: () {},
            ),
            PsButton(
              label: '删除这本书',
              icon: PsIcons.trash,
              variant: PsButtonVariant.danger,
              onPressed: () {},
            ),
            PsButton(
              label: '导入',
              icon: PsIcons.import,
              small: true,
              variant: PsButtonVariant.primary,
              onPressed: () {},
            ),
            PsButton(
              label: '试听',
              icon: PsIcons.play,
              small: true,
              onPressed: () {},
            ),
            PsButton(
              label: '正在生成',
              loading: true,
              variant: PsButtonVariant.primary,
              onPressed: () {},
            ),
            const PsButton(
              label: '同意并开始建档',
              variant: PsButtonVariant.primary,
              onPressed: null,
            ),
          ],
        ),
        Row(
          spacing: PsSpace.s3,
          children: [
            PsIconButton(icon: PsIcons.settings, label: '设置', onPressed: () {}),
            PsIconButton(
              icon: PsIcons.close,
              label: '关闭',
              variant: PsIconButtonVariant.tonal,
              onPressed: () {},
            ),
            PsIconButton(
              icon: PsIcons.moon,
              label: '定时关闭',
              active: true,
              onPressed: () {},
            ),
            PsIconButton(
              icon: PsIcons.lineForward,
              label: '下一句',
              size: PsControlSize.lg,
              onPressed: () {},
            ),
          ],
        ),
        Row(
          spacing: PsSpace.s8,
          children: [
            PsPlayButton(
              size: PsPlaySize.lg,
              playing: _playing,
              onPressed: () => setState(() => _playing = !_playing),
            ),
            PsPlayButton(
              size: PsPlaySize.lg,
              playing: true,
              buffering: true,
              onPressed: () {},
            ),
            PsPlayButton(onPressed: () {}),
            PsPlayButton(size: PsPlaySize.sm, onPressed: () {}),
          ],
        ),
      ],
    );
  }

  Widget _inputs() {
    final p = context.ps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PsSpace.s5,
      children: [
        PsSegmentedControl<String>(
          expand: true,
          value: _mode,
          onChanged: (v) => setState(() => _mode = v),
          segments: const [
            PsSegment('audiobook', '有声书'),
            PsSegment('drama', '广播剧'),
          ],
        ),
        Row(
          children: [
            Text(
              'A',
              style: PsType.style(
                PsFonts.serif,
                14,
                14,
                FontWeight.w400,
              ).copyWith(color: p.ink2),
            ),
            Expanded(
              child: Slider(
                min: 14,
                max: 26,
                divisions: 12,
                value: _fontSize,
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ),
            Text(
              'A',
              style: PsType.style(
                PsFonts.serif,
                22,
                22,
                FontWeight.w400,
              ).copyWith(color: p.ink2),
            ),
          ],
        ),
        Wrap(
          spacing: PsSpace.s2,
          runSpacing: PsSpace.s2,
          children: [
            for (final s in const ['0.75', '1.0', '1.25', '1.5', '2.0', '3.0'])
              ChoiceChip(
                label: Text(
                  '$s×',
                  style: PsType.numeral.copyWith(
                    color: _speed == s ? p.paper : p.ink,
                  ),
                ),
                selected: _speed == s,
                onSelected: (_) => setState(() => _speed = s),
              ),
          ],
        ),
        PsListGroup(
          children: [
            PsListRow(
              title: '自动生成下一章',
              subtitle: '播到未合成的章节时',
              trailing: Switch(
                value: _autoGenerate,
                onChanged: (v) => setState(() => _autoGenerate = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _status() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PsSpace.s4,
      children: [
        const Wrap(
          spacing: PsSpace.s2,
          runSpacing: PsSpace.s2,
          children: [
            PsTag('AI 合成', tone: PsTagTone.outline),
            PsTag('旁白'),
            PsTag('新增 12 章', tone: PsTagTone.accent),
            PsTag('已合成', tone: PsTagTone.jade),
            PsTag('建档中', tone: PsTagTone.amber),
            PsTag('key 无效', tone: PsTagTone.danger, icon: PsIcons.alert),
          ],
        ),
        Wrap(
          spacing: PsSpace.s5,
          runSpacing: PsSpace.s2,
          children: [
            for (final s in PsChapterStatus.values)
              PsStatusMark(s, showLabel: true),
          ],
        ),
        const LinearProgressIndicator(value: 0.3),
      ],
    );
  }

  Widget _settings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PsSpace.s4,
      children: [
        PsListGroup(
          header: '服务商',
          iconInset: true,
          children: [
            const PsListRow(
              icon: PsIcons.key,
              title: 'LLM',
              subtitle: 'DeepSeek · deepseek-chat',
              trailing: PsTag('key 无效', tone: PsTagTone.danger),
            ),
            PsListRow(
              icon: PsIcons.voice,
              title: 'MiniMax',
              subtitle: 'speech-02-hd',
              chevron: true,
              onTap: () {},
            ),
            PsListRow(
              icon: PsIcons.voice,
              title: '阿里百炼',
              detail: '未配置',
              chevron: true,
              onTap: () {},
            ),
          ],
        ),
        Wrap(
          spacing: PsSpace.s2,
          runSpacing: PsSpace.s2,
          children: [
            PsButton(label: '对话框', small: true, onPressed: _showConsent),
            PsButton(label: '底部面板', small: true, onPressed: _showSheet),
            PsButton(label: '提示条', small: true, onPressed: _showToast),
          ],
        ),
      ],
    );
  }

  Widget _icons() {
    final p = context.ps;
    return Wrap(
      spacing: PsSpace.s5,
      runSpacing: PsSpace.s5,
      children: [
        for (final icon in PsIcons.values)
          Tooltip(
            message: icon.name,
            child: PsIcon(icon, color: p.ink),
          ),
      ],
    );
  }

  void _showConsent() {
    final p = context.ps;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('把正文发给 DeepSeek？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: PsSpace.s4,
          children: [
            const Text('建档需要读这本书的正文。同意后，以后发给 DeepSeek 不再询问。'),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PsSpace.s4,
                vertical: PsSpace.s3,
              ),
              decoration: BoxDecoration(
                color: p.paperSunken,
                borderRadius: BorderRadius.circular(PsRadius.sm),
              ),
              child: DefaultTextStyle.merge(
                style: PsType.body.copyWith(fontSize: 14, height: 20 / 14),
                child: Table(
                  columnWidths: const {0: IntrinsicColumnWidth()},
                  children: [
                    for (final (k, v) in const [
                      ('发送', '《阿Q正传》第 1–5 章'),
                      ('发给', 'api.deepseek.com'),
                      ('用途', '整理角色和专有名词读音'),
                    ])
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              right: PsSpace.s4,
                              bottom: 6,
                            ),
                            child: Text(k, style: TextStyle(color: p.ink2)),
                          ),
                          Text(v, style: TextStyle(color: p.ink)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PsSpace.s2,
            children: [
              PsButton(
                label: '同意并开始建档',
                variant: PsButtonVariant.primary,
                expand: true,
                onPressed: () => Navigator.pop(context),
              ),
              PsButton(
                label: '取消',
                variant: PsButtonVariant.ghost,
                expand: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final p = context.ps;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s5,
              0,
              PsSpace.s5,
              PsSpace.s10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PsSpace.s3,
              children: [
                Text('朗读设置', style: PsType.title3.copyWith(color: p.ink)),
                Text('演播模式', style: PsType.subhead.copyWith(color: p.ink2)),
                PsSegmentedControl<String>(
                  expand: true,
                  value: _mode,
                  onChanged: (v) {
                    setState(() => _mode = v);
                    setSheet(() {});
                  },
                  segments: const [
                    PsSegment('audiobook', '有声书'),
                    PsSegment('drama', '广播剧'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已合并：新增 12 章'),
        action: SnackBarAction(label: '查看', onPressed: () {}),
      ),
    );
  }
}
