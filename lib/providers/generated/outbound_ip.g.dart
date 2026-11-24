// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../outbound_ip.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dashboardOutboundTarget)
final dashboardOutboundTargetProvider = DashboardOutboundTargetProvider._();

final class DashboardOutboundTargetProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  DashboardOutboundTargetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardOutboundTargetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardOutboundTargetHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return dashboardOutboundTarget(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$dashboardOutboundTargetHash() =>
    r'c9461a148832bb8c36902be964b81110b6a006f0';

@ProviderFor(OutboundIpFamilyProbe)
final outboundIpFamilyProbeProvider = OutboundIpFamilyProbeProvider._();

final class OutboundIpFamilyProbeProvider
    extends
        $NotifierProvider<
          OutboundIpFamilyProbe,
          RoutedProbeState<OutboundIpTarget, IpInfo>
        > {
  OutboundIpFamilyProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboundIpFamilyProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboundIpFamilyProbeHash();

  @$internal
  @override
  OutboundIpFamilyProbe create() => OutboundIpFamilyProbe();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutedProbeState<OutboundIpTarget, IpInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<RoutedProbeState<OutboundIpTarget, IpInfo>>(value),
    );
  }
}

String _$outboundIpFamilyProbeHash() =>
    r'494e998d96965f8266178b530eba3f3af7e1a6b1';

abstract class _$OutboundIpFamilyProbe
    extends $Notifier<RoutedProbeState<OutboundIpTarget, IpInfo>> {
  RoutedProbeState<OutboundIpTarget, IpInfo> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              RoutedProbeState<OutboundIpTarget, IpInfo>,
              RoutedProbeState<OutboundIpTarget, IpInfo>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                RoutedProbeState<OutboundIpTarget, IpInfo>,
                RoutedProbeState<OutboundIpTarget, IpInfo>
              >,
              RoutedProbeState<OutboundIpTarget, IpInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Keyed by the outbound a lookup pins: a node name, `DIRECT`, or
/// [routedOutbound] for whatever the rules pick right now.

@ProviderFor(OutboundIpProbe)
final outboundIpProbeProvider = OutboundIpProbeProvider._();

/// Keyed by the outbound a lookup pins: a node name, `DIRECT`, or
/// [routedOutbound] for whatever the rules pick right now.
final class OutboundIpProbeProvider
    extends
        $NotifierProvider<OutboundIpProbe, RoutedProbeState<String, IpInfo>> {
  /// Keyed by the outbound a lookup pins: a node name, `DIRECT`, or
  /// [routedOutbound] for whatever the rules pick right now.
  OutboundIpProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outboundIpProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outboundIpProbeHash();

  @$internal
  @override
  OutboundIpProbe create() => OutboundIpProbe();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutedProbeState<String, IpInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutedProbeState<String, IpInfo>>(
        value,
      ),
    );
  }
}

String _$outboundIpProbeHash() => r'6ca9b0ac7d8041e21352e36ea7c5e8bf53fef80e';

/// Keyed by the outbound a lookup pins: a node name, `DIRECT`, or
/// [routedOutbound] for whatever the rules pick right now.

abstract class _$OutboundIpProbe
    extends $Notifier<RoutedProbeState<String, IpInfo>> {
  RoutedProbeState<String, IpInfo> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              RoutedProbeState<String, IpInfo>,
              RoutedProbeState<String, IpInfo>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                RoutedProbeState<String, IpInfo>,
                RoutedProbeState<String, IpInfo>
              >,
              RoutedProbeState<String, IpInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
