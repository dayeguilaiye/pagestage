import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/labels.dart';

/// Where book text may go, with a way to take each agreement back. Taking
/// one back pauses AI voices that need it until the reader agrees again.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, required this.consents});

  final Consents consents;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  List<ConsentRecord>? _records;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.consents.records();
      if (mounted) setState(() => _records = records);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _revoke(ConsentRecord record) async {
    final l = AppLocalizations.of(context);
    try {
      await widget.consents.revoke(record);
      if (mounted) showPsToast(context, l.consentRevoked);
    } catch (_) {
      if (mounted) showPsToast(context, l.saveFailed);
    }
    await _load();
  }

  static String _host(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final records = _records;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(back: true, backLabel: l.settings, title: l.privacy),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: PsSpace.s10 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(l.privacy),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: PsSpace.s6,
                    children: [
                      Text(
                        l.privacyIntro,
                        style: PsType.body.copyWith(
                          color: p.ink2,
                          height: 22 / 15,
                        ),
                      ),
                      if (_failed)
                        PsBanner(
                          tone: PsBannerTone.danger,
                          title: l.privacyLoadFailed,
                        )
                      else if (records != null)
                        PsListGroup(
                          header: l.consentsSection,
                          footer: l.consentsNote,
                          children: [
                            if (records.isEmpty)
                              PsListRow(title: l.consentsEmpty)
                            else
                              for (final record in records)
                                PsListRow(
                                  key: ValueKey(
                                    'consent-${record.provider}-${record.endpoint}',
                                  ),
                                  title: Labels.provider(l, record.provider),
                                  subtitle: _host(record.endpoint),
                                  trailing: PsButton(
                                    label: l.revokeConsent,
                                    small: true,
                                    onPressed: () => _revoke(record),
                                  ),
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
