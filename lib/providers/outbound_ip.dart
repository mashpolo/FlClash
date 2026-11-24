import 'dart:io';

import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/models/models.dart';
import 'package:riverpod/riverpod.dart' show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app.dart';
import 'core.dart';
import 'route_state.dart';
import 'routed_probe.dart';

part 'generated/outbound_ip.g.dart';

const mainOutbound = 'MAIN';

@riverpod
String dashboardOutboundTarget(Ref ref) =>
    ref.watch(
      groupsProvider.select((groups) => groups.getGroup(mainOutbound) != null),
    )
    ? mainOutbound
    : routedOutbound;

typedef OutboundIpTarget = ({String name, InternetAddressType family});

@Riverpod(keepAlive: true)
class OutboundIpFamilyProbe extends _$OutboundIpFamilyProbe
    with RoutedProbe<OutboundIpTarget, IpInfo> {
  @override
  RoutedProbeState<OutboundIpTarget, IpInfo> build() => buildProbe();

  @override
  Future<Map<OutboundIpTarget, ProbeAnswer<IpInfo>>> probe(
    OutboundIpTarget target,
    RouteState route,
  ) async {
    final result = await lookupOutboundIp(
      ref.read(coreHandlerProvider),
      target.name,
      family: target.family,
    );
    return {
      target: ProbeAnswer(
        value: parseOutboundIp(result, family: target.family),
        coreEpoch: result.coreEpoch,
        routeVersion: result.routeVersion,
        hits: result.hits,
      ),
    };
  }
}

/// Keyed by the outbound a lookup pins: a node name, `DIRECT`, or
/// [routedOutbound] for whatever the rules pick right now.
@Riverpod(keepAlive: true)
class OutboundIpProbe extends _$OutboundIpProbe
    with RoutedProbe<String, IpInfo> {
  @override
  RoutedProbeState<String, IpInfo> build() => buildProbe();

  @override
  Future<Map<String, ProbeAnswer<IpInfo>>> probe(
    String target,
    RouteState route,
  ) async {
    final proxyName = target == routedOutbound && !route.proxied
        ? directOutbound
        : target;
    final result = await lookupOutboundIp(
      ref.read(coreHandlerProvider),
      proxyName,
    );
    final value = parseOutboundIp(result);
    final exit = result.chains.firstOrNull;
    return {
      target: ProbeAnswer(
        value: value,
        coreEpoch: result.coreEpoch,
        routeVersion: result.routeVersion,
        hits: result.hits,
      ),
      // A node leaves through the same address whatever it is asked for.
      if (value != null && exit != null && exit != target)
        exit: ProbeAnswer(
          value: value,
          coreEpoch: result.coreEpoch,
          routeVersion: result.routeVersion,
          hits: result.nodeHits,
        ),
    };
  }
}
