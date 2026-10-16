import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/ping_models.dart';
import '../../viewmodels/ping_viewmodel.dart';

class PingScreen extends StatefulWidget {
  final PingViewModel viewModel;

  const PingScreen({Key? key, required this.viewModel}) : super(key: key);

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  late final TextEditingController _hostController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.viewModel.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final stats = vm.stats;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildControlCard(vm),
              const SizedBox(height: 16),
              _buildMetricsRow(stats),
              const SizedBox(height: 16),
              _buildConsoleCard(vm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlCard(PingViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NocColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _buildModeChip(
                  title: 'ICMP Echo',
                  subtitle: 'Layer 3 Ping',
                  selected: vm.mode == PingMode.icmp,
                  onTap: () => vm.setMode(PingMode.icmp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModeChip(
                  title: 'TCP Port Probe',
                  subtitle: 'Winbox / SSH / HTTP',
                  selected: vm.mode == PingMode.tcpPort,
                  onTap: () => vm.setMode(PingMode.tcpPort),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Quick Target Presets',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: NocColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HostPreset.defaultPresets.map((preset) {
              final isSelected = vm.host == preset.host;
              return ActionChip(
                backgroundColor: isSelected
                    ? NocColors.cyanAccent.withOpacity(0.2)
                    : NocColors.surfaceElevated,
                side: BorderSide(
                  color: isSelected ? NocColors.cyanAccent : NocColors.border,
                ),
                label: Text(
                  '${preset.label} (${preset.host})',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? NocColors.cyanAccent
                        : NocColors.textPrimary,
                  ),
                ),
                onPressed: vm.isRunning
                    ? null
                    : () {
                        _hostController.text = preset.host;
                        vm.selectHostPreset(preset);
                      },
              );
            }).toList(),
          ),
          if (vm.mode == PingMode.tcpPort) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              'Router / Server Port Preset',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NocColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PortPreset.defaultPresets.map((portPreset) {
                final isSelected = vm.selectedPort == portPreset.port;
                return ChoiceChip(
                  selected: isSelected,
                  selectedColor: NocColors.emeraldSuccess.withOpacity(0.22),
                  backgroundColor: NocColors.surfaceElevated,
                  side: BorderSide(
                    color: isSelected
                        ? NocColors.emeraldSuccess
                        : NocColors.border,
                  ),
                  label: Text(
                    portPreset.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? NocColors.emeraldSuccess
                          : NocColors.textPrimary,
                    ),
                  ),
                  onSelected: vm.isRunning
                      ? null
                      : (_) => vm.setPort(portPreset.port),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _hostController,
                  enabled: !vm.isRunning,
                  onChanged: vm.updateHost,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: NocColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Target IP / Hostname',
                    hintText: '192.168.88.1 atau 1.1.1.1',
                    filled: true,
                    fillColor: NocColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      Icons.dns_outlined,
                      color: NocColors.cyanAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vm.isRunning
                        ? NocColors.crimsonError
                        : NocColors.cyanAccent,
                    foregroundColor: NocColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: vm.isRunning ? vm.stopPing : vm.startPing,
                  icon: Icon(vm.isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    vm.isRunning ? 'STOP' : 'PING',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          if (vm.validationError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              vm.validationError!,
              style: const TextStyle(
                color: NocColors.crimsonError,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? NocColors.cyanAccent.withOpacity(0.15)
              : NocColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? NocColors.cyanAccent : NocColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? NocColors.cyanAccent : NocColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: NocColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(PingSummaryStats stats) {
    final avgText = stats.avgRttMs != null
        ? '${stats.avgRttMs!.toStringAsFixed(1)} ms'
        : '--';
    final jitterText = stats.jitterMs != null
        ? '${stats.jitterMs!.toStringAsFixed(1)} ms'
        : '--';
    final lossText = '${stats.lossPercentage.toStringAsFixed(0)}%';

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _buildStatTile(
                label: 'AVG LATENCY',
                value: avgText,
                subvalue: stats.minRttMs != null
                    ? 'Min ${stats.minRttMs!.toStringAsFixed(1)} / Max ${stats.maxRttMs!.toStringAsFixed(1)}'
                    : 'Waiting stream...',
                accentColor: NocColors.cyanAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                label: 'JITTER',
                value: jitterText,
                subvalue: stats.linkQualityLabel,
                accentColor: NocColors.emeraldSuccess,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                label: 'PACKET LOSS',
                value: lossText,
                subvalue: 'Tx: ${stats.transmitted} / Rx: ${stats.received}',
                accentColor: stats.lossPercentage > 0
                    ? NocColors.crimsonError
                    : NocColors.emeraldSuccess,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required String subvalue,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NocColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NocColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: NocColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subvalue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: NocColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleCard(PingViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NocColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: vm.isRunning
                          ? NocColors.emeraldSuccess
                          : NocColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vm.mode == PingMode.icmp
                        ? 'LIVE ICMP STREAM TERMINAL'
                        : 'LIVE TCP PORT PROBE (PORT ${vm.selectedPort})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: NocColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (vm.packets.isNotEmpty)
                TextButton(
                  onPressed: vm.clearResults,
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontSize: 12, color: NocColors.cyanAccent),
                  ),
                ),
            ],
          ),
          const Divider(color: NocColors.border),
          if (vm.packets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Tekan tombol PING untuk memulai streaming paket secara real-time.',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: NocColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vm.packets.length,
              itemBuilder: (context, index) {
                final pkt = vm.packets[vm.packets.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    pkt.toCliLogLine(),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: pkt.isSuccess
                          ? NocColors.emeraldSuccess
                          : NocColors.crimsonError,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
