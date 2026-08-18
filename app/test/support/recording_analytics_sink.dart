import 'package:hayati_app/core/analytics/analytics_dimensions.dart';
import 'package:hayati_app/core/analytics/analytics_event.dart';
import 'package:hayati_app/core/analytics/analytics_sink.dart';

/// An [AnalyticsSink] that keeps what it was given, so a test can assert the
/// event AND the dimensions attached to it (ADR-057 D2/D3).
class RecordingAnalyticsSink implements AnalyticsSink {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  final List<AnalyticsDimensions> dimensions = <AnalyticsDimensions>[];

  /// The §7 wire names recorded, in order — what most assertions want.
  List<String> get names => events.map((e) => e.name.wire).toList();

  @override
  void record(AnalyticsEvent event, AnalyticsDimensions dimensions) {
    events.add(event);
    this.dimensions.add(dimensions);
  }
}
