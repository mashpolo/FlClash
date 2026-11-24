import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';

Future<void> showOutboundIpsSheet(BuildContext context) {
  return showModalSideSheet<void>(
    context: context,
    barrierColor: context.colorScheme.modalScrim,
    builder: (_) => const _OutboundIpsSheet(),
  );
}

typedef _Path = ({String node, String group});
typedef _Address = ({IpInfo info, Set<_Path> paths});

class _OutboundIpsSheet extends ConsumerStatefulWidget {
  const _OutboundIpsSheet();

  @override
  ConsumerState<_OutboundIpsSheet> createState() => _OutboundIpsSheetState();
}

class _OutboundIpsSheetState extends ConsumerState<_OutboundIpsSheet>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<_OutboundIpsSheet>,
        RouteMotionHoldMixin<_OutboundIpsSheet> {
  late final OutboundIpFamilyProbe _probe;
  Set<_Path>? _paths;
  Set<OutboundIpTarget> _targets = {};
  var _scanFailed = false;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpFamilyProbeProvider.notifier);
  }

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  Future<void> poll(PollGuard isCurrent) async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      _showPaths(const {}, isCurrent);
      return;
    }
    try {
      final chains = await ref
          .read(coreHandlerProvider)
          .getActiveOutboundPaths();
      if (!isCurrent()) return;
      _showPaths({for (final chain in chains) _pathOf(chain)}, isCurrent);
    } catch (error) {
      commonPrint.log(
        'active outbound paths failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
      _showPaths(const {}, isCurrent, failed: true);
    }
  }

  void _showPaths(
    Set<_Path> paths,
    PollGuard isCurrent, {
    bool failed = false,
  }) {
    updateWhenRouteSettled(() {
      if (!isCurrent() || (setEquals(_paths, paths) && _scanFailed == failed)) {
        return;
      }
      final targets = {
        for (final path in paths)
          for (final family in [
            InternetAddressType.IPv4,
            InternetAddressType.IPv6,
          ])
            (name: path.node, family: family),
      };
      targets.difference(_targets).forEach(_probe.watch);
      _targets.difference(targets).forEach(_probe.unwatch);
      setState(() {
        _paths = paths;
        _targets = targets;
        _scanFailed = failed;
      });
    });
  }

  @override
  void dispose() {
    _targets.forEach(_probe.unwatch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.appLocalizations;
    final entries = ref.watch(outboundIpFamilyProbeProvider);
    final target = ref.watch(dashboardOutboundTargetProvider);
    final mainIp = ref.watch(
      outboundIpProbeProvider.select((state) => state.valueOf(target)?.ip),
    );
    final (rows, pending, failed) = _addresses(entries, mainIp);
    final status = _scanFailed || failed
        ? localizations.serviceFailed
        : pending || _paths == null
        ? localizations.loading
        : rows.isEmpty
        ? localizations.noActiveOutboundIps
        : null;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        text: localizations.activeOutboundIps,
                        children: [
                          TextSpan(
                            text: ' · ${rows.length}',
                            style: AppTextStyle.footnote
                                .of(context)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      style: AppTextStyle.headline.of(context),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: localizations.close,
                  icon: const GlyphIcon(AppGlyphs.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverPrismList(
                    itemCount: rows.length,
                    itemBuilder: (_, index) => ItemPositionProvider(
                      key: ValueKey(rows[index].info.ip),
                      position: ItemPosition.get(index, rows.length),
                      child: _OutboundIpRow(rows[index]),
                    ),
                  ),
                ),
                if (status != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        status,
                        style: AppTextStyle.subheadline
                            .of(context)
                            .copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (List<_Address>, bool, bool) _addresses(
    RoutedProbeState<OutboundIpTarget, IpInfo> entries,
    String? mainIp,
  ) {
    final byIp = <String, _Address>{};
    var pending = false;
    var failed = false;
    for (final path in _paths ?? const <_Path>{}) {
      final name = path.node;
      final v4 = entries.entryOf((
        name: name,
        family: InternetAddressType.IPv4,
      ));
      final v6 = entries.entryOf((
        name: name,
        family: InternetAddressType.IPv6,
      ));
      for (final entry in [v4, v6]) {
        if (entry.value case final info?) {
          (byIp[info.ip] ??= (info: info, paths: {})).paths.add(path);
        }
      }
      pending |= _unresolved(v4) || _unresolved(v6);
      failed |= v4.phase == ProbePhase.failed && v6.phase == ProbePhase.failed;
    }
    int order(_Address row) {
      if (row.info.ip == mainIp) return 0;
      return row.paths.any((path) => path.group == mainOutbound) ? 1 : 2;
    }

    final rows = byIp.values.toList()
      ..sort((a, b) {
        final priority = order(a).compareTo(order(b));
        return priority == 0 ? a.info.ip.compareTo(b.info.ip) : priority;
      });
    return (rows, pending, failed);
  }
}

bool _unresolved(ProbeEntry<IpInfo> entry) =>
    entry.phase == ProbePhase.empty || entry.phase == ProbePhase.probing;

_Path _pathOf(List<String> chain) => (
  node: chain.first,
  group: chain.contains(mainOutbound) ? mainOutbound : chain.last,
);

class _OutboundIpRow extends ConsumerWidget {
  const _OutboundIpRow(this.row);

  final _Address row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = row.info;
    final quality = ref.watch(ipQualityProvider(info.ip));
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final localizations = context.appLocalizations;
    final family = info.ip.contains(':') ? 'IPv6' : 'IPv4';
    final sources = row.paths.map((path) {
      final node = path.node == directOutbound
          ? localizations.direct
          : path.node;
      return path.node == path.group ? node : '${path.group} · $node';
    });
    final colorScheme = context.colorScheme;
    final qualityValue = quality.value;
    return DecorationListItem(
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: AppShape.sm,
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
        ),
        child: Text(
          info.countryCode.countryFlagEmoji,
          style: AppTextStyle.body
              .of(context)
              .copyWith(fontFamily: FontFamily.twEmoji.value),
        ),
      ),
      title: Text.rich(
        TextSpan(
          text: hideIp ? '*****' : info.ip,
          style: AppTextStyle.subheadline.of(context, emphasized: true),
          children: [
            TextSpan(
              text: '  $family',
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EmojiText(sources.join(' / ')),
          if (qualityValue != null) ...[
            DashboardChip(label: qualityValue.type.label(context)),
            DashboardChip(
              label:
                  '${localizations.ipQualityShort} ${qualityValue.level.label(context)}',
            ),
          ] else
            DashboardChip(
              label: quality.isLoading
                  ? localizations.loading
                  : localizations.ipTypeUnknown,
            ),
        ],
      ),
      onPressed: () => showIpQualitySheet(context, ip: info.ip),
    );
  }
}
