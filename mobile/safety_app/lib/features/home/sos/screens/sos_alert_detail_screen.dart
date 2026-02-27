// lib/features/home/sos/screens/sos_alert_detail_screen.dart
//
// Guardian's view when they tap an SOS notification.
// Shows: alert metadata, SOS trigger location + live location on map, voice message player.
//
// Map behaviour:
//   - Red marker  → where SOS was triggered (sos_events lat/lng, static)
//   - Blue marker → dependent's current position (live_locations, polled every 5s)
//   - Tap map     → opens Google Maps app / browser for navigation
//
// pubspec.yaml dependencies needed:
//   google_maps_flutter: ^2.9.0
//   url_launcher: ^6.3.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/sos_event_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

enum SosTriggerType { manual, motion, voice }

class SosAlertData {
  final String dependentName;
  final String dependentAvatarUrl;
  final DateTime triggeredAt;
  final SosTriggerType triggerType;
  final double? latitude;       // SOS trigger location (sos_events)
  final double? longitude;
  final String? voiceMessageUrl;
  final int sosEventId;
  final int? dependentUserId;   // needed to query live_locations

  const SosAlertData({
    required this.dependentName,
    required this.dependentAvatarUrl,
    required this.triggeredAt,
    required this.triggerType,
    required this.sosEventId,
    this.latitude,
    this.longitude,
    this.voiceMessageUrl,
    this.dependentUserId,
  });

  SosAlertData copyWith({
    String? dependentName,
    String? dependentAvatarUrl,
    DateTime? triggeredAt,
    SosTriggerType? triggerType,
    double? latitude,
    double? longitude,
    String? voiceMessageUrl,
    int? sosEventId,
    int? dependentUserId,
  }) {
    return SosAlertData(
      dependentName: dependentName ?? this.dependentName,
      dependentAvatarUrl: dependentAvatarUrl ?? this.dependentAvatarUrl,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      triggerType: triggerType ?? this.triggerType,
      sosEventId: sosEventId ?? this.sosEventId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      voiceMessageUrl: voiceMessageUrl ?? this.voiceMessageUrl,
      dependentUserId: dependentUserId ?? this.dependentUserId,
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SosAlertDetailScreen extends StatefulWidget {
  final SosAlertData alert;

  const SosAlertDetailScreen({super.key, required this.alert});

  @override
  State<SosAlertDetailScreen> createState() => _SosAlertDetailScreenState();
}

class _SosAlertDetailScreenState extends State<SosAlertDetailScreen>
    with TickerProviderStateMixin {
  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _audioLoading = false;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _acknowledged = false;
  late SosAlertData _alertData;
  bool _isLoading = true;

  // ── Map ────────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;

  // SOS trigger location (static, from sos_events) — red marker
  double? _sosLat;
  double? _sosLng;

  // Live current location (from live_locations) — blue marker, polled every 5s
  double? _liveLat;
  double? _liveLng;
  DateTime? _liveUpdatedAt;
  Timer? _liveLocationTimer;

  // ── Service ────────────────────────────────────────────────────────────────
  final SosEventService _sosEventService = SosEventService();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _alertData = widget.alert;

    debugPrint('🚨 [SosAlertDetail] loaded — eventId: ${_alertData.sosEventId}');
    _fetchSosDetails();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  // ─── Fetch SOS event (sos_events table) ───────────────────────────────────
  Future<void> _fetchSosDetails() async {
    try {
      setState(() => _isLoading = true);

      final data = await _sosEventService.getSosEventById(_alertData.sosEventId);
      debugPrint('✅ SOS event: $data');

      SosTriggerType triggerType;
      switch (data['trigger_type']) {
        case 'motion': triggerType = SosTriggerType.motion; break;
        case 'voice':  triggerType = SosTriggerType.voice;  break;
        default:       triggerType = SosTriggerType.manual;
      }

      final lat = data['latitude'] != null
          ? double.tryParse(data['latitude'].toString()) : null;
      final lng = data['longitude'] != null
          ? double.tryParse(data['longitude'].toString()) : null;

      DateTime triggeredAt = DateTime.now();
      if (data['created_at'] != null) {
        try { triggeredAt = DateTime.parse(data['created_at']); } catch (_) {}
      }

      final dependentUserId = data['dependent_user_id'] != null
          ? int.tryParse(data['dependent_user_id'].toString()) : null;

      setState(() {
        _sosLat = lat;
        _sosLng = lng;
        _alertData = _alertData.copyWith(
          dependentName: data['dependent_name'] ?? _alertData.dependentName,
          triggerType: triggerType,
          latitude: lat,
          longitude: lng,
          voiceMessageUrl: data['voice_message_url'],
          triggeredAt: triggeredAt,
          dependentUserId: dependentUserId,
        );
        _isLoading = false;
      });

      if (lat != null && lng != null && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
      }

      // Start polling live_locations every 5 seconds
      if (dependentUserId != null) {
        _startLiveLocationPolling(dependentUserId);
      }
    } catch (e) {
      debugPrint('❌ Error fetching SOS details: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─── Poll live_locations table ─────────────────────────────────────────────
  void _startLiveLocationPolling(int userId) {
    _fetchLiveLocation(userId);
    _liveLocationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchLiveLocation(userId),
    );
  }

  Future<void> _fetchLiveLocation(int userId) async {
    try {
      // Requires backend endpoint: GET /live-locations/:userId
      // SQL: SELECT * FROM live_locations WHERE user_id = $1
      final data = await _sosEventService.getLiveLocation(userId);

      final lat = data['latitude'] != null
          ? double.tryParse(data['latitude'].toString()) : null;
      final lng = data['longitude'] != null
          ? double.tryParse(data['longitude'].toString()) : null;
      DateTime? updatedAt;
      if (data['updated_at'] != null) {
        try { updatedAt = DateTime.parse(data['updated_at'].toString()); } catch (_) {}
      }

      if (lat != null && lng != null && mounted) {
        setState(() {
          _liveLat = lat;
          _liveLng = lng;
          _liveUpdatedAt = updatedAt;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Live location fetch failed: $e');
    }
  }

  // ─── Open Google Maps app ──────────────────────────────────────────────────
  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final nativeUri = Uri.parse('google.navigation:q=$lat,$lng');
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Build map markers ─────────────────────────────────────────────────────
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_sosLat != null && _sosLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('sos_trigger'),
        position: LatLng(_sosLat!, _sosLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: '🚨 SOS triggered here',
          snippet: 'Alert sent ${_timeAgo(_alertData.triggeredAt)}',
        ),
      ));
    }

    if (_liveLat != null && _liveLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('live_location'),
        position: LatLng(_liveLat!, _liveLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: '📍 Last seen here',
          snippet: _liveUpdatedAt != null
              ? 'Updated ${_timeAgo(_liveUpdatedAt!)}'
              : _alertData.dependentName,
        ),
      ));
    }

    return markers;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
    _mapController?.dispose();
    _liveLocationTimer?.cancel();
    super.dispose();
  }

  // ── Audio controls ─────────────────────────────────────────────────────────

  Future<void> _togglePlayback() async {
    final url = _alertData.voiceMessageUrl;
    if (url == null || url.isEmpty) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
      return;
    }

    setState(() => _audioLoading = true);
    try {
      if (_playerState == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        if (url.startsWith('http')) {
          await _audioPlayer.play(UrlSource(url));
        } else {
          await _audioPlayer.play(DeviceFileSource(url));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load voice message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  Future<void> _seekTo(double value) async {
    await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
  }

  void _acknowledge() {
    setState(() => _acknowledged = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _triggerLabel(SosTriggerType t) {
    switch (t) {
      case SosTriggerType.manual: return 'Manual SOS';
      case SosTriggerType.motion: return 'Motion Detected';
      case SosTriggerType.voice:  return 'Voice Activated';
    }
  }

  IconData _triggerIcon(SosTriggerType t) {
    switch (t) {
      case SosTriggerType.manual: return Icons.pan_tool_alt_rounded;
      case SosTriggerType.motion: return Icons.sensors_rounded;
      case SosTriggerType.voice:  return Icons.mic_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _AppAlertColors(isDark);

    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primaryGreen))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(context, colors),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildAlertHeader(colors, isDark),
                            const SizedBox(height: 24),
                            _buildLocationSlot(colors, isDark),
                            const SizedBox(height: 24),
                            _buildVoiceMessagePlayer(colors),
                            const SizedBox(height: 32),
                            _buildAcknowledgeButton(colors),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAppBar(BuildContext context, _AppAlertColors colors) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: colors.onSurface, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'SOS Alert',
        style: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: colors.divider),
      ),
    );
  }

  Widget _buildAlertHeader(_AppAlertColors colors, bool isDark) {
    final alert = _alertData;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.sosRed.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.sosRed.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.sosRed.withOpacity(0.15),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.sosRed.withOpacity(0.2),
                    backgroundImage: alert.dependentAvatarUrl.isNotEmpty
                        ? NetworkImage(alert.dependentAvatarUrl)
                        : null,
                    child: alert.dependentAvatarUrl.isEmpty
                        ? Text(
                            alert.dependentName.isNotEmpty
                                ? alert.dependentName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colors.sosRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.dependentName,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'needs your help',
                      style: TextStyle(
                          color: colors.sosRed,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _metaChip(
                icon: _triggerIcon(alert.triggerType),
                label: _triggerLabel(alert.triggerType),
                color: colors.sosRed,
                bgColor: colors.sosRed.withOpacity(0.1),
                textColor: colors.sosRed,
              ),
              const SizedBox(width: 8),
              _metaChip(
                icon: Icons.access_time_rounded,
                label: _timeAgo(alert.triggeredAt),
                color: colors.hint,
                bgColor: colors.chipBg,
                textColor: colors.hint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Location slot ─────────────────────────────────────────────────────────

  Widget _buildLocationSlot(_AppAlertColors colors, bool isDark) {
    final hasSos  = _sosLat != null && _sosLng != null;
    final hasLive = _liveLat != null && _liveLng != null;
    final hasAny  = hasSos || hasLive;

    // Navigation target: prefer live (most current), fall back to SOS trigger
    final navLat = _liveLat ?? _sosLat;
    final navLng = _liveLng ?? _sosLng;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header row ──────────────────────────────────────────────
        Row(
          children: [
            _sectionLabel('Live Location', Icons.location_on_rounded, colors),
            const Spacer(),
            if (hasLive && _liveUpdatedAt != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: colors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Updated ${_timeAgo(_liveUpdatedAt!)}',
                      style: TextStyle(
                          color: colors.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Map tile (tap → Google Maps) ────────────────────────────────────
        GestureDetector(
          onTap: hasAny ? () => _openInGoogleMaps(navLat!, navLng!) : null,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Map or fallback placeholder
                  if (hasAny)
                    SizedBox(
                      height: 220,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _sosLat ?? _liveLat!,
                            _sosLng ?? _liveLng!,
                          ),
                          zoom: 17,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (isDark) controller.setMapStyle(_darkMapStyle);
                        },
                        markers: _buildMarkers(),
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        mapType: MapType.normal,
                        // FIX 1: claim touch events immediately so scroll view
                        // only activates when the finger starts outside the map
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<EagerGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_rounded,
                              color: colors.hint, size: 32),
                          const SizedBox(height: 8),
                          Text('Location unavailable',
                              style: TextStyle(
                                  color: colors.hint, fontSize: 13)),
                        ],
                      ),
                    ),

                  // "Open in Maps" overlay badge
                  if (hasAny)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.open_in_new_rounded,
                                color: Colors.white, size: 12),
                            SizedBox(width: 5),
                            Text(
                              'Open in Maps',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Descriptive legend ──────────────────────────────────────────────
        if (hasSos || hasLive) ...[
          const SizedBox(height: 12),
          if (hasSos)
            _locationLegendRow(
              color: colors.sosRed,
              icon: Icons.crisis_alert_rounded,
              title: 'Where the SOS was triggered',
              subtitle: 'Alert sent ${_timeAgo(_alertData.triggeredAt)} · static location',
              colors: colors,
            ),
          if (hasSos && hasLive) const SizedBox(height: 8),
          if (hasLive)
            _locationLegendRow(
              color: const Color(0xFF1565C0),
              icon: Icons.person_pin_circle_rounded,
              title: 'Where they were last seen',
              subtitle: _liveUpdatedAt != null
                  ? 'Updated ${_timeAgo(_liveUpdatedAt!)} · updates every 5s'
                  : 'Fetching current position…',
              colors: colors,
            ),
          if (navLat != null && navLng != null) ...[
            const SizedBox(height: 8),
            Text(
              '${navLat.toStringAsFixed(5)}, ${navLng.toStringAsFixed(5)}',
              style: TextStyle(
                  color: colors.hint, fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _locationLegendRow({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required _AppAlertColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: colors.hint, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Voice message player ──────────────────────────────────────────────────

  Widget _buildVoiceMessagePlayer(_AppAlertColors colors) {
    final hasAudio = _alertData.voiceMessageUrl != null &&
        _alertData.voiceMessageUrl!.isNotEmpty;
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Voice Message', Icons.mic_rounded, colors),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.divider),
          ),
          child: !hasAudio
              ? Row(
                  children: [
                    Icon(Icons.mic_off_rounded, color: colors.hint, size: 22),
                    const SizedBox(width: 12),
                    Text('No voice message attached',
                        style: TextStyle(color: colors.hint, fontSize: 14)),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: _WaveformVisual(
                        progress: progress,
                        activeColor: colors.primaryGreen,
                        inactiveColor: colors.divider,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                        activeTrackColor: colors.primaryGreen,
                        inactiveTrackColor: colors.divider,
                        thumbColor: colors.primaryGreen,
                        overlayColor: colors.primaryGreen.withOpacity(0.15),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds
                            .clamp(0, _duration.inMilliseconds)
                            .toDouble(),
                        max: _duration.inMilliseconds > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1,
                        onChanged: _seekTo,
                      ),
                    ),
                    Row(
                      children: [
                        Text(_formatTime(_position),
                            style: TextStyle(
                                color: colors.hint,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                        const Spacer(),
                        GestureDetector(
                          onTap: _togglePlayback,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.primaryGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primaryGreen.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _audioLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),
                        const Spacer(),
                        Text(_formatTime(_duration),
                            style: TextStyle(
                                color: colors.hint,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── Acknowledge button ────────────────────────────────────────────────────

  Widget _buildAcknowledgeButton(_AppAlertColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _acknowledged ? colors.success : colors.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_acknowledged ? colors.success : colors.primaryGreen)
                  .withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _acknowledged ? null : _acknowledge,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _acknowledged
                        ? Icons.check_circle_rounded
                        : Icons.check_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _acknowledged ? 'Acknowledged' : 'Acknowledge Alert',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon, _AppAlertColors colors) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primaryGreen),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Color helper ─────────────────────────────────────────────────────────────

class _AppAlertColors {
  final bool isDark;
  _AppAlertColors(this.isDark);

  Color get background =>
      isDark ? const Color(0xFF121614) : const Color(0xFFFAFAFA);
  Color get surface =>
      isDark ? const Color(0xFF1E2623) : const Color(0xFFFFFFFF);
  Color get onBackground =>
      isDark ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A);
  Color get onSurface =>
      isDark ? const Color(0xFFE8E8E8) : const Color(0xFF2C2C2C);
  Color get divider =>
      isDark ? const Color(0xFF3E4340) : const Color(0xFFE0E0E0);
  Color get hint => const Color(0xFF9E9E9E);
  Color get chipBg =>
      isDark ? const Color(0xFF2A2E2C) : const Color(0xFFF0F0F0);
  Color get sosRed => const Color(0xFFA74337);
  Color get primaryGreen => const Color(0xFF2F5249);
  Color get success => const Color(0xFF4CAF50);
}

// ─── Dark map style ────────────────────────────────────────────────────────────

const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1e2623"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1e2623"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2a2e2c"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3e4340"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#121614"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3e4340"}]},
{"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "on"}]},  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';

// ─── Waveform visual ──────────────────────────────────────────────────────────

class _WaveformVisual extends StatelessWidget {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _WaveformVisual({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    const bars = [
      0.3, 0.5, 0.8, 0.6, 1.0, 0.7, 0.4, 0.9, 0.5, 0.7,
      0.3, 0.6, 0.8, 0.4, 1.0, 0.6, 0.5, 0.9, 0.3, 0.7,
      0.5, 0.8, 0.4, 0.6, 1.0, 0.7, 0.3, 0.5, 0.8, 0.6,
      0.4, 0.9, 0.5, 0.7, 0.3, 0.6, 0.8, 0.4, 1.0, 0.6,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(bars.length, (i) {
        final isActive = (i / bars.length) <= progress;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 4,
          height: 40 * bars[i],
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}