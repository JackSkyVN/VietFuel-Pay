/// Station Map Screen – OSM map + OSRM routing + Google Maps / Waze navigation.
///
/// Features:
///   • FlutterMap (OSM tiles, no API key)
///   • 165 real Hanoi stations from backend
///   • Tap a marker → route preview drawn on map via OSRM free API
///   • Bottom sheet with Navigate button → opens Google Maps / Waze
///   • My-location button, refresh
library;

import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/gas_station.dart';
import '../providers/station_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kHanoiCenter = LatLng(21.0285, 105.8542);
const _kDefaultZoom = 13.0;

// ── Screen ────────────────────────────────────────────────────────────────────

class StationMapScreen extends ConsumerStatefulWidget {
  const StationMapScreen({super.key});

  @override
  ConsumerState<StationMapScreen> createState() => _StationMapScreenState();
}

class _StationMapScreenState extends ConsumerState<StationMapScreen> {
  final MapController _mapController = MapController();

  /// Currently selected station (for route preview).
  GasStation? _selectedStation;

  /// Route polyline points from OSRM.
  List<LatLng> _routePoints = [];

  /// Notifies the bottom sheet of route loading state changes.
  final _routeNotifier = ValueNotifier<({bool loading, bool hasRoute})>(
    (loading: false, hasRoute: false),
  );

  /// User's current position (for routing origin).
  LatLng? _myPosition;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _routeNotifier.dispose();
    super.dispose();
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final pos = await _getPosition();
    if (pos != null && mounted) {
      setState(() => _myPosition = pos);
    }
  }

  Future<LatLng?> _getPosition() async {
    try {
      bool ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _goToMyLocation() async {
    final pos = await _getPosition();
    if (pos != null) {
      setState(() => _myPosition = pos);
      _mapController.move(pos, _kDefaultZoom);
    }
  }

  // ── OSRM Routing ───────────────────────────────────────────────────────────

  /// Fetches a driving route from [origin] to [dest] using the free OSRM API.
  Future<List<LatLng>> _fetchRoute(LatLng origin, LatLng dest) async {
    // OSRM expects lon,lat order
    final url =
        'http://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      final resp = await dio.get<Map<String, dynamic>>(url);
      final routes = resp.data?['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];

      final coords = (routes[0]['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return coords;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRoute(GasStation station) async {
    final origin = _myPosition ?? _kHanoiCenter;
    _routeNotifier.value = (loading: true, hasRoute: false);
    setState(() => _routePoints = []);

    final points =
        await _fetchRoute(origin, LatLng(station.latitude, station.longitude));
    if (mounted) {
      setState(() => _routePoints = points);
      _routeNotifier.value = (loading: false, hasRoute: points.isNotEmpty);
    }
  }

  void _clearRoute() {
    _routeNotifier.value = (loading: false, hasRoute: false);
    setState(() {
      _routePoints = [];
      _selectedStation = null;
    });
  }

  // ── Marker tap ─────────────────────────────────────────────────────────────

  void _onMarkerTap(GasStation station) {
    setState(() => _selectedStation = station);
    // Pan map to station
    _mapController.move(
      LatLng(station.latitude, station.longitude),
      15.0,
    );
    // Draw route
    _loadRoute(station);
    // Show bottom sheet
    _showStationSheet(station);
  }

  // ── Bottom Sheet ───────────────────────────────────────────────────────────

  void _showStationSheet(GasStation station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StationBottomSheet(
        station: station,
        myPosition: _myPosition,
        routeNotifier: _routeNotifier,
        onDismiss: _clearRoute,
      ),
    ).whenComplete(_clearRoute);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncStations = ref.watch(stationsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _kHanoiCenter,
              initialZoom: _kDefaultZoom,
              interactionOptions:
                  InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              // OSM tiles
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vietfuel.smart_refuel',
                maxZoom: 19,
              ),

              // Route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: AppColors.primaryRed.withOpacity(0.85),
                      borderStrokeWidth: 2,
                      borderColor: Colors.white.withOpacity(0.6),
                    ),
                  ],
                ),

              // My location dot
              if (_myPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPosition!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.info.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Station markers
              asyncStations.when(
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
                data: (stations) => MarkerLayer(
                  markers: stations.map(_buildMarker).toList(),
                ),
              ),
            ],
          ),

          // ── Header ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _MapHeader(
                stationCount: asyncStations.valueOrNull?.length,
                onRefresh: () {
                  _clearRoute();
                  // ignore: unused_result
                  ref.refresh(stationsProvider);
                },
                onMyLocation: _goToMyLocation,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),

          // ── Route loading badge ───────────────────────────────────────────
          ValueListenableBuilder<({bool loading, bool hasRoute})>(
            valueListenable: _routeNotifier,
            builder: (_, state, __) => state.loading
                ? Positioned(
                    top: 110,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryRed,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Calculating route…',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.charcoal,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Station count pill ────────────────────────────────────────────
          if (asyncStations.hasValue)
            Positioned(
              bottom: 24,
              left: 20,
              child: _StationCountPill(
                count: asyncStations.value!.length,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.4),
            ),

          // ── Loading ───────────────────────────────────────────────────────
          if (asyncStations.isLoading)
            const Center(child: _MapLoadingOverlay()),

          // ── Error ─────────────────────────────────────────────────────────
          if (asyncStations.hasError)
            _MapErrorView(
              onRetry: () => ref.refresh(stationsProvider),
            ),
        ],
      ),
    );
  }

  // ── Marker builder ─────────────────────────────────────────────────────────

  Marker _buildMarker(GasStation station) {
    final isSelected = _selectedStation?.id == station.id;
    final statusColor = station.isOpen
        ? AppColors.primaryRed
        : station.isBusy
            ? AppColors.warning
            : AppColors.mediumGray;

    return Marker(
      point: LatLng(station.latitude, station.longitude),
      width: isSelected ? 56 : 46,
      height: isSelected ? 62 : 52,
      child: GestureDetector(
        onTap: () => _onMarkerTap(station),
        child: AnimatedScale(
          scale: isSelected ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isSelected ? 42 : 34,
                height: isSelected ? 42 : 34,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(isSelected ? 0.6 : 0.35),
                      blurRadius: isSelected ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_gas_station_rounded,
                  color: Colors.white,
                  size: isSelected ? 22 : 18,
                ),
              ),
              CustomPaint(
                size: const Size(12, 7),
                painter: _PinTailPainter(color: statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pin tail ──────────────────────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter old) => old.color != color;
}

// ── Bottom Sheet ──────────────────────────────────────────────────────────────

class _StationBottomSheet extends StatelessWidget {
  final GasStation station;
  final LatLng? myPosition;
  final ValueNotifier<({bool loading, bool hasRoute})> routeNotifier;
  final VoidCallback onDismiss;

  const _StationBottomSheet({
    required this.station,
    required this.myPosition,
    required this.routeNotifier,
    required this.onDismiss,
  });

  // Build navigation URL for the platform
  Uri _googleMapsUrl() => Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${station.latitude},${station.longitude}'
      '&travelmode=driving');

  Uri _wazeUrl() => Uri.parse(
      'https://waze.com/ul?ll=${station.latitude},${station.longitude}'
      '&navigate=yes');

  Future<void> _launchNav(BuildContext context, Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open navigation app')),
        );
      }
    }
  }

  void _showAppPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Open with',
                  style: TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _NavAppTile(
                icon: Icons.map_rounded,
                color: const Color(0xFF4285F4),
                label: 'Google Maps',
                onTap: () {
                  Navigator.pop(context);
                  _launchNav(context, _googleMapsUrl());
                },
              ),
              _NavAppTile(
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF00AAFF),
                label: 'Waze',
                onTap: () {
                  Navigator.pop(context);
                  _launchNav(context, _wazeUrl());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = station.isOpen
        ? AppColors.success
        : station.isBusy
            ? AppColors.warning
            : AppColors.mediumGray;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon + name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A2E), AppColors.primaryRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              station.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppColors.primaryRed, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.address,
                    style: const TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Route status — live via ValueListenableBuilder
          ValueListenableBuilder<({bool loading, bool hasRoute})>(
            valueListenable: routeNotifier,
            builder: (_, state, __) {
              if (!state.loading && !state.hasRoute) {
                return const SizedBox(height: 10);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: state.loading
                        ? AppColors.borderGray
                        : AppColors.primaryRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.loading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryRed),
                        )
                      else
                        const Icon(Icons.route_rounded,
                            color: AppColors.primaryRed, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        state.loading
                            ? 'Calculating route…'
                            : 'Route previewed on map',
                        style: TextStyle(
                          color: state.loading
                              ? AppColors.mediumGray
                              : AppColors.primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Navigate button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), AppColors.primaryRed],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.redGlow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showAppPicker(context),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Navigate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Call / Share buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _OutlineButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: () {
                      final text =
                          '${station.name}\nhttps://www.google.com/maps?q='
                          '${station.latitude},${station.longitude}';
                      launchUrl(Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent(text)}'));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlineButton(
                    icon: Icons.close_rounded,
                    label: 'Dismiss',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOut)
        .fadeIn(duration: 300.ms);
  }
}

// ── Nav app tile ──────────────────────────────────────────────────────────────

class _NavAppTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _NavAppTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
            color: AppColors.charcoal,
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.mediumGray),
    );
  }
}

// ── Outline button ────────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.charcoal, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Map header ────────────────────────────────────────────────────────────────

class _MapHeader extends StatelessWidget {
  final int? stationCount;
  final VoidCallback onRefresh;
  final VoidCallback onMyLocation;

  const _MapHeader({
    required this.stationCount,
    required this.onRefresh,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded,
                      color: AppColors.primaryRed, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nearby Stations',
                        style: TextStyle(
                            color: AppColors.charcoal,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (stationCount != null)
                      Text('$stationCount stations found',
                          style: const TextStyle(
                              color: AppColors.mediumGray, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _IconBtn(icon: Icons.my_location_rounded, onTap: onMyLocation),
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.softShadow,
        ),
        child: Icon(icon, color: AppColors.charcoal, size: 20),
      ),
    );
  }
}

// ── Station count pill ────────────────────────────────────────────────────────

class _StationCountPill extends StatelessWidget {
  final int count;
  const _StationCountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), AppColors.primaryRed]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.redGlow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pin_drop_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text('$count stations on map',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Loading overlay ───────────────────────────────────────────────────────────

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.6),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.softShadow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primaryRed),
              ),
              SizedBox(width: 14),
              Text('Loading stations…',
                  style: TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _MapErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _MapErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightGray.withOpacity(0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.primaryRed, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Could not load stations',
                style: TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Check your connection & backend.',
                style:
                    TextStyle(color: AppColors.mediumGray, fontSize: 13)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A2E), AppColors.primaryRed]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
