import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_config.dart';
import '../routing/ai_policy_store.dart';
import '../routing/conscious_router.dart';
import '../services/api_history_provider.dart';
import '../services/service_locator.dart';
import '../widgets/app_drawer.dart';

// ────────────────────────────────────────────────────────────────────────────
// Data model for a protocol card
// ────────────────────────────────────────────────────────────────────────────
class _ProtocolEntry {
  final String id;
  final String label;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final bool isAiPowered;

  const _ProtocolEntry({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    this.isAiPowered = false,
  });
}

const _protocols = [
  _ProtocolEntry(
    id: 'rest',
    label: 'REST',
    subtitle: 'Traditional HTTP',
    description:
        'All calls use standard REST endpoints. The baseline protocol for head-to-head energy comparison.',
    icon: Icons.api_rounded,
    color: Color(0xFF4FC3F7),
  ),
  _ProtocolEntry(
    id: 'graphql',
    label: 'GraphQL',
    subtitle: 'Declarative Queries',
    description:
        'Fetches only requested fields. Reduces over-fetching for medium and large payloads.',
    icon: Icons.hub_rounded,
    color: Color(0xFFCE93D8),
  ),
  _ProtocolEntry(
    id: 'default',
    label: 'Benchmark',
    subtitle: 'Dual-Protocol Runner',
    description:
        'Fires both REST & GraphQL in parallel for every request. Populates the energy matrix.',
    icon: Icons.compare_arrows_rounded,
    color: Color(0xFFFFD54F),
  ),
  _ProtocolEntry(
    id: 'heuristic',
    label: 'Heuristic',
    subtitle: 'Rule-Based Routing',
    description:
        'Learns from historical latency data and routes to the faster protocol per task type.',
    icon: Icons.auto_graph_rounded,
    color: Color(0xFF80CBC4),
  ),
  _ProtocolEntry(
    id: 'ai_power',
    label: 'AI Conscious',
    subtitle: 'Gemini-Driven',
    description:
        'Gemini evaluates context, battery state, and latency to pick the optimal protocol in real time.',
    icon: Icons.psychology_rounded,
    color: Color(0xFFF48FB1),
    isAiPowered: true,
  ),
];

const _operatingModes = [
  (id: 'balanced', label: 'Balanced', icon: Icons.scale_rounded, color: Color(0xFF90A4AE)),
  (id: 'green', label: 'Green', icon: Icons.eco_rounded, color: Color(0xFF81C784)),
  (id: 'performance', label: 'Performance', icon: Icons.bolt_rounded, color: Color(0xFF64B5F6)),
];

const _availableModels = [
  (value: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash'),
  (value: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash'),
  (value: 'gemini-2.5-flash-lite', label: 'Gemini 2.5 Flash-Lite'),
  (value: 'gemini-3-flash-preview', label: 'Gemini 3 Flash (Preview)'),
  (value: 'gemini-3.1-flash-lite-preview', label: 'Gemini 3.1 Flash-Lite (Preview)'),
  (value: 'gemini-3.1-pro-preview', label: 'Gemini 3.1 Pro (Preview)'),
  (value: 'CUSTOM', label: '✎ Manual ID Entry'),
];

// ────────────────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────────────────
class ProtocolSelectionScreen extends StatefulWidget {
  const ProtocolSelectionScreen({super.key});

  @override
  State<ProtocolSelectionScreen> createState() =>
      _ProtocolSelectionScreenState();
}

class _ProtocolSelectionScreenState extends State<ProtocolSelectionScreen>
    with SingleTickerProviderStateMixin {
  late String _activeProtocol;
  late String _activeMode;
  late String _selectedModel;

  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  bool _apiKeyObscured = true;

  late final AnimationController _pulseCtrl;
  bool _isVerifyingKey = false;
  bool _isManualModel = false;
  late final TextEditingController _manualModelController;

  @override
  void initState() {
    super.initState();
    _activeProtocol = currentRoutingStrategy;
    _activeMode = currentOperatingMode;

    // Ensure selected model is always one of the known values
    final knownValues = _availableModels.map((m) => m.value).toSet();
    if (knownValues.contains(AppConfig.geminiModel)) {
      _selectedModel = AppConfig.geminiModel;
    } else {
      _selectedModel = 'gemini-1.5-flash';
      _isManualModel = true;
    }

    _urlController = TextEditingController(text: AppConfig.backendUrl);
    _apiKeyController = TextEditingController(text: AppConfig.geminiApiKey);
    _manualModelController = TextEditingController(text: AppConfig.geminiModel);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _manualModelController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Routing logic ──────────────────────────────────────────────────────────
  void _selectProtocol(String id) {
    setState(() => _activeProtocol = id);

    if (id == 'ai_power') {
      currentRoutingStrategy = 'ai_power';
      currentOperatingMode = _activeMode;
    } else {
      currentRoutingStrategy = id;
    }
    syncLegacyCurrentApiMode();
    ApiHistoryProvider.instance.addSessionMarker(id);

    _showSnack('Protocol → ${_labelFor(id)}', _colorFor(id));
  }

  void _selectMode(String id) {
    setState(() => _activeMode = id);
    currentOperatingMode = id;
    syncLegacyCurrentApiMode();
    _showSnack('Mode → ${ _modeLabel(id)}', _modeColor(id));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _labelFor(String id) =>
      _protocols.firstWhere((p) => p.id == id).label;
  Color _colorFor(String id) =>
      _protocols.firstWhere((p) => p.id == id).color;

  String _modeLabel(String id) =>
      _operatingModes.firstWhere((m) => m.id == id).label;
  Color _modeColor(String id) =>
      _operatingModes.firstWhere((m) => m.id == id).color;

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color.withValues(alpha: 0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white70),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Protocol Selection',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [_buildStatusChip()],
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildActiveHero(),
          const SizedBox(height: 24),
          _buildSectionHeader('Choose Protocol', Icons.settings_ethernet_rounded),
          const SizedBox(height: 12),
          ..._protocols.map(_buildProtocolCard),
          const SizedBox(height: 28),
          // Operating mode — only relevant for AI conscious
          AnimatedOpacity(
            opacity: _activeProtocol == 'ai_power' ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Operating Mode',
                  Icons.tune_rounded,
                  subtitle: _activeProtocol == 'ai_power'
                      ? 'Sets the optimization objective for AI routing'
                      : 'Active only in AI Conscious mode',
                ),
                const SizedBox(height: 12),
                _buildModeSelector(),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader('Server & AI Configuration', Icons.settings_rounded),
          const SizedBox(height: 12),
          _buildConfigPanel(),
        ],
      ),
    );
  }

  // ── Status chip (top-right) ────────────────────────────────────────────────
  Widget _buildStatusChip() {
    final proto = _protocols.firstWhere((p) => p.id == _activeProtocol,
        orElse: () => _protocols.first);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (child, child2) {
          final glow = _pulseCtrl.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: proto.color.withValues(alpha: 0.12 + glow * 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: proto.color.withValues(alpha: 0.4 + glow * 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: proto.color,
                    boxShadow: [
                      BoxShadow(
                        color: proto.color.withValues(alpha: 0.6),
                        blurRadius: 6 + glow * 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  proto.label,
                  style: TextStyle(
                    color: proto.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Hero banner ────────────────────────────────────────────────────────────
  Widget _buildActiveHero() {
    final proto = _protocols.firstWhere((p) => p.id == _activeProtocol,
        orElse: () => _protocols.first);
    final isAi = _activeProtocol == 'ai_power';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                proto.color.withValues(alpha: 0.18 + _pulseCtrl.value * 0.04),
                proto.color.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: proto.color.withValues(alpha: 0.3 + _pulseCtrl.value * 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: proto.color.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: proto.color.withValues(alpha: 0.3 + _pulseCtrl.value * 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(proto.icon, color: proto.color, size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ACTIVE PROTOCOL',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isAi) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: proto.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 9,
                                color: proto.color,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proto.label,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: proto.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      proto.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                    if (isAi) ...[
                      const SizedBox(height: 8),
                      _buildModePill(_activeMode),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModePill(String mode) {
    final entry = _operatingModes.firstWhere((m) => m.id == mode,
        orElse: () => _operatingModes.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: entry.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(entry.icon, size: 12, color: entry.color),
          const SizedBox(width: 5),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 11,
              color: entry.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white30),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Protocol card ──────────────────────────────────────────────────────────
  Widget _buildProtocolCard(_ProtocolEntry entry) {
    final isSelected = _activeProtocol == entry.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? entry.color.withValues(alpha: 0.12)
              : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? entry.color.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: entry.color.withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectProtocol(entry.id),
            splashColor: entry.color.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: entry.color.withValues(
                          alpha: isSelected ? 0.22 : 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(entry.icon, color: entry.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color:
                                    isSelected ? entry.color : Colors.white,
                              ),
                            ),
                            if (entry.isAiPowered) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: entry.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'GEMINI',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: entry.color,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? entry.color.withValues(alpha: 0.7)
                                : Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entry.description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Selection indicator
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Container(
                            key: const ValueKey('check'),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: entry.color,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: Colors.black),
                          )
                        : Container(
                            key: const ValueKey('empty'),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white12),
                            ),
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

  // ── Operating mode selector ────────────────────────────────────────────────
  Widget _buildModeSelector() {
    return Row(
      children: _operatingModes.map((m) {
        final isSelected = _activeMode == m.id;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: m.id != _operatingModes.last.id ? 8 : 0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? m.color.withValues(alpha: 0.18)
                    : const Color(0xFF161616),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? m.color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.07),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectMode(m.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(m.icon,
                            color: isSelected ? m.color : Colors.white38,
                            size: 22),
                        const SizedBox(height: 6),
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? m.color : Colors.white38,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Config panel ───────────────────────────────────────────────────────────
  Widget _buildConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backend URL
          _buildConfigLabel('Backend URL', Icons.dns_rounded, Colors.tealAccent),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _urlController,
            hint: 'e.g., http://192.168.1.5:5005',
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: 'Update Server & Reconnect',
            color: Colors.tealAccent,
            onPressed: () {
              updateBackendUrl(_urlController.text);
              _showSnack('Server URL updated!', Colors.tealAccent);
            },
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Gemini API Key
          _buildConfigLabel('Gemini API Key', Icons.vpn_key_rounded, const Color(0xFF4FC3F7)),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _apiKeyController,
            hint: 'AIza...',
            obscure: _apiKeyObscured,
            suffixIcon: IconButton(
              icon: Icon(
                _apiKeyObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.white38,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _apiKeyObscured = !_apiKeyObscured),
            ),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: _isVerifyingKey ? 'Verifying...' : 'Verify & Save Key',
            color: const Color(0xFF4FC3F7),
            onPressed: _isVerifyingKey ? null : () async {
              final rawKey = _apiKeyController.text.trim();
              if (rawKey.isEmpty) {
                _showSnack('Please enter a key', Colors.orange);
                return;
              }

              setState(() => _isVerifyingKey = true);
              
              // Temporarily set it to test
              await AppConfig.setApiKey(rawKey);
              final error = await ConsciousRouter.instance.testConnection();
              
              setState(() => _isVerifyingKey = false);

              if (error == null) {
                updateGeminiApiKey(rawKey);
                _showSnack('Gemini API key verified & saved!', Colors.greenAccent);
              } else {
                _showSnack('Verify Failed: $error', Colors.redAccent);
              }
            },
          ),
          const SizedBox(height: 10),
          // Models reference link
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://ai.google.dev/gemini-api/docs/models'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF4FC3F7)),
                SizedBox(width: 5),
                Text(
                  'Browse available Gemini model names',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4FC3F7),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF4FC3F7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // AI Model
          _buildConfigLabel('AI Routing Model', Icons.memory_rounded, const Color(0xFFCE93D8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              dropdownColor: const Color(0xFF1A1A1A),
              iconEnabledColor: const Color(0xFFCE93D8),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.memory_rounded,
                    color: Color(0xFFCE93D8), size: 18),
              ),
              items: _availableModels
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.value,
                      child: Text(
                        m.label,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                if (val == 'CUSTOM') {
                  setState(() => _isManualModel = true);
                } else {
                  setState(() {
                    _selectedModel = val;
                    _isManualModel = false;
                    _manualModelController.text = val;
                  });
                  updateGeminiModel(val);
                  _showSnack('AI model set to $val', const Color(0xFFCE93D8));
                }
              },
            ),
          ),
          if (_isManualModel) ...[
            const SizedBox(height: 12),
            _buildTextField(
              controller: _manualModelController,
              hint: 'e.g. gemini-3.1-flash-lite-preview',
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              label: 'Save Manual Model ID',
              color: const Color(0xFFCE93D8),
              onPressed: () {
                final val = _manualModelController.text.trim();
                if (val.isEmpty) return;
                setState(() => _selectedModel = val);
                updateGeminiModel(val);
                _showSnack('Custom model ID saved!', const Color(0xFFCE93D8));
              },
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Cache management
          _buildConfigLabel('AI Routing Cache', Icons.cached_rounded, Colors.orangeAccent),
          const SizedBox(height: 4),
          const Text(
            'Cached decisions survive restarts. Clear after changing API key or model.',
            style: TextStyle(fontSize: 11, color: Colors.white30, height: 1.4),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: '🗑  Clear AI Policy Cache',
            color: Colors.orangeAccent,
            onPressed: () async {
              await AiPolicyStore.instance.clear();
              _showSnack('AI routing cache cleared!', Colors.orangeAccent);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.black26,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.35)),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
