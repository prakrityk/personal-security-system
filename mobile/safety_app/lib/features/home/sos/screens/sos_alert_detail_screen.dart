// lib/features/home/sos/screens/sos_alert_detail_screen.dart
//
// Guardian's view when they tap an SOS notification.
// Shows: alert metadata, static location (from SOS event), voice message player.

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../services/sos_event_service.dart'; // ADD THIS

// ─── Data model passed into this screen ──────────────────────────────────────

enum SosTriggerType { manual, motion, voice }

class SosAlertData {
  final String dependentName;
  final String dependentAvatarUrl;
  final DateTime triggeredAt;
  final SosTriggerType triggerType;
  final double? latitude;
  final double? longitude;
  final String? voiceMessageUrl;
  final int sosEventId;

  const SosAlertData({
    required this.dependentName,
    required this.dependentAvatarUrl,
    required this.triggeredAt,
    required this.triggerType,
    required this.sosEventId,
    this.latitude,
    this.longitude,
    this.voiceMessageUrl,
  });

  // ✅ NEW: Create a copy with updated fields
  SosAlertData copyWith({
    String? dependentName,
    String? dependentAvatarUrl,
    DateTime? triggeredAt,
    SosTriggerType? triggerType,
    double? latitude,
    double? longitude,
    String? voiceMessageUrl,
    int? sosEventId,
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
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _audioLoading = false;

  // Pulse animation for the alert header
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Slide-in animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _acknowledged = false;
  
  // ✅ NEW: Local copy of alert data that can be updated
  late SosAlertData _alertData;
  
  // ✅ NEW: Service for fetching data
  final SosEventService _sosEventService = SosEventService();
  
  // ✅ NEW: Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Initialize with passed data
    _alertData = widget.alert;
    
    debugPrint('🎤 [SosAlertDetail] ========== SCREEN LOADED ==========');
    debugPrint('🎤 [SosAlertDetail] eventId: ${_alertData.sosEventId}');
    debugPrint('🎤 [SosAlertDetail] initial dependentName: ${_alertData.dependentName}');
    debugPrint('🎤 [SosAlertDetail] initial voiceMessageUrl: "${_alertData.voiceMessageUrl}"');
    
    // ✅ FETCH the full SOS data from backend
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

    // Audio listeners
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
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

  // ✅ NEW: Fetch SOS details from backend
  Future<void> _fetchSosDetails() async {
    try {
      setState(() => _isLoading = true);
      
      final eventId = _alertData.sosEventId;
      debugPrint('📡 Fetching SOS details for event $eventId');
      
      final data = await _sosEventService.getSosEventById(eventId);
      debugPrint('✅ Fetched SOS data: $data');
      
      // Parse trigger type
      SosTriggerType triggerType;
      switch (data['trigger_type']) {
        case 'motion':
          triggerType = SosTriggerType.motion;
          break;
        case 'voice':
          triggerType = SosTriggerType.voice;
          break;
        default:
          triggerType = SosTriggerType.manual;
      }
      
      // Parse latitude/longitude
      double? latitude = data['latitude'] != null 
          ? double.tryParse(data['latitude'].toString()) 
          : null;
      double? longitude = data['longitude'] != null 
          ? double.tryParse(data['longitude'].toString()) 
          : null;
      
      // Parse timestamp
      DateTime triggeredAt = DateTime.now();
      if (data['created_at'] != null) {
        try {
          triggeredAt = DateTime.parse(data['created_at']);
        } catch (e) {
          debugPrint('⚠️ Error parsing date: $e');
        }
      }
      
      // ✅ Update local data with fetched values
      setState(() {
        _alertData = _alertData.copyWith(
          dependentName: data['dependent_name'] ?? _alertData.dependentName,
          triggerType: triggerType,
          latitude: latitude,
          longitude: longitude,
          voiceMessageUrl: data['voice_message_url'],
          triggeredAt: triggeredAt,
        );
        _isLoading = false;
      });
      
      debugPrint('🎤 Updated voiceMessageUrl: "${_alertData.voiceMessageUrl}"');
      debugPrint('🎤 Has voice: ${_alertData.voiceMessageUrl != null && _alertData.voiceMessageUrl!.isNotEmpty}');
      
    } catch (e) {
      debugPrint('❌ Error fetching SOS details: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
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
    final target = Duration(milliseconds: value.toInt());
    await _audioPlayer.seek(target);
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
      case SosTriggerType.manual:
        return 'Manual SOS';
      case SosTriggerType.motion:
        return 'Motion Detected';
      case SosTriggerType.voice:
        return 'Voice Activated';
    }
  }

  IconData _triggerIcon(SosTriggerType t) {
    switch (t) {
      case SosTriggerType.manual:
        return Icons.pan_tool_alt_rounded;
      case SosTriggerType.motion:
        return Icons.sensors_rounded;
      case SosTriggerType.voice:
        return Icons.mic_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                    _buildAppBar(context, colors, isDark),
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
                            _buildVoiceMessagePlayer(colors, isDark),
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

  Widget _buildAppBar(
      BuildContext context, _AppAlertColors colors, bool isDark) {
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
    final alert = _alertData; // Use local copy

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
                        fontSize: 14,
                      ),
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
              const SizedBox(width: 10),
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
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSlot(_AppAlertColors colors, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Live Location', Icons.location_on_rounded, colors),
        const SizedBox(height: 12),
        Container(
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
                CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: _GridPainter(color: colors.gridColor),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.primaryGreen.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: colors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _alertData.latitude != null && _alertData.longitude != null
                            ? '📍 ${_alertData.latitude!.toStringAsFixed(4)}, '
                                '${_alertData.longitude!.toStringAsFixed(4)}'
                            : '📍 Location unavailable',
                        style: TextStyle(
                          color: colors.hint,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _alertData.latitude != null
                              ? '📍 Static location at SOS time'
                              : '📍 Map widget goes here',
                          style: TextStyle(
                            color: colors.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceMessagePlayer(_AppAlertColors colors, bool isDark) {
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
                    Text(
                      'No voice message attached',
                      style: TextStyle(color: colors.hint, fontSize: 14),
                    ),
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
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
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
                        Text(
                          _formatTime(_position),
                          style: TextStyle(
                              color: colors.hint,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                        ),
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
                                  color:
                                      colors.primaryGreen.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _audioLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
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
                        Text(
                          _formatTime(_duration),
                          style: TextStyle(
                              color: colors.hint,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

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

// ─── Color helper ─────────────────────────────────────────────────────

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
  Color get gridColor =>
      isDark ? const Color(0xFF2A2E2C) : const Color(0xFFEEEEEE);
  Color get sosRed => const Color(0xFFA74337);
  Color get primaryGreen => const Color(0xFF2F5249);
  Color get success => const Color(0xFF4CAF50);
}

// ─── Waveform visual widget ───────────────────────────────────────────────────

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
        final fraction = i / bars.length;
        final isActive = fraction <= progress;
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

// ─── Grid painter ────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}