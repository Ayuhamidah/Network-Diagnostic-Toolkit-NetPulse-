import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/subnet_models.dart';
import '../../viewmodels/subnet_viewmodel.dart';

class SubnetScreen extends StatefulWidget {
  final SubnetViewModel viewModel;

  const SubnetScreen({Key? key, required this.viewModel}) : super(key: key);

  @override
  State<SubnetScreen> createState() => _SubnetScreenState();
}

class _SubnetScreenState extends State<SubnetScreen> {
  late final TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.viewModel.ipInput);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final info = vm.subnetInfo;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildInputCard(vm),
              const SizedBox(height: 16),
              if (vm.error != null)
                _buildErrorBanner(vm.error!.title, vm.error!.message)
              else if (info != null) ...<Widget>[
                _buildAddressingCard(info),
                const SizedBox(height: 16),
                _buildBinaryCard(info),
                const SizedBox(height: 16),
                _buildCliSnippetsCard(info),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputCard(SubnetViewModel vm) {
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
          TextField(
            controller: _ipController,
            onChanged: vm.updateIpInput,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              color: NocColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'IPv4 Address',
              hintText: '192.168.88.1 atau 10.0.0.1',
              filled: true,
              fillColor: NocColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: const Icon(
                Icons.lan_outlined,
                color: NocColors.cyanAccent,
              ),
              suffixText: '/${vm.prefixLength}',
              suffixStyle: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: NocColors.cyanAccent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'CIDR Prefix: /${vm.prefixLength}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: NocColors.textPrimary,
                ),
              ),
              if (vm.subnetInfo != null)
                Text(
                  '${vm.subnetInfo!.usableHosts} Usable Hosts',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: NocColors.emeraldSuccess,
                  ),
                ),
            ],
          ),
          Slider(
            value: vm.prefixLength.toDouble(),
            min: 0,
            max: 32,
            divisions: 32,
            activeColor: NocColors.cyanAccent,
            label: '/${vm.prefixLength}',
            onChanged: (val) => vm.updatePrefixLength(val.round()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CidrPreset.commonPresets.map((preset) {
              final selected = vm.prefixLength == preset.prefix;
              return ActionChip(
                backgroundColor: selected
                    ? NocColors.cyanAccent.withOpacity(0.2)
                    : NocColors.surfaceElevated,
                side: BorderSide(
                  color: selected ? NocColors.cyanAccent : NocColors.border,
                ),
                label: Text(
                  preset.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? NocColors.cyanAccent
                        : NocColors.textPrimary,
                  ),
                ),
                onPressed: () => vm.applyPreset(prefix: preset.prefix),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressingCard(SubnetInfo info) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'SUBNET & ROUTING DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NocColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: info.isPrivateRfc1918
                      ? NocColors.emeraldSuccess.withOpacity(0.18)
                      : NocColors.amberWarning.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${info.ipClass} • ${info.isPrivateRfc1918 ? "RFC 1918 Private" : "Public / Special"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: info.isPrivateRfc1918
                        ? NocColors.emeraldSuccess
                        : NocColors.amberWarning,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: NocColors.border),
          _buildKeyValueRow('Network CIDR', info.networkCidr, isHighlight: true),
          _buildKeyValueRow('Subnet Mask', info.subnetMask),
          _buildKeyValueRow(
            'Wildcard Mask (OSPF/ACL)',
            info.wildcardMask,
            isHighlight: true,
          ),
          _buildKeyValueRow('Broadcast Address', info.broadcastAddress),
          _buildKeyValueRow(
            'Usable Host Range',
            '${info.firstUsableHost} - ${info.lastUsableHost}',
          ),
          _buildKeyValueRow(
            'Total / Usable Hosts',
            '${info.totalAddresses} total (${info.usableHosts} usable)',
          ),
          _buildKeyValueRow('Address Scope', info.scopeDescription),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: NocColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: isHighlight
                    ? NocColors.cyanAccent
                    : NocColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinaryCard(SubnetInfo info) {
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
          const Text(
            '32-BIT BINARY BOUNDARY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NocColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildBinaryLine('IP Binary     ', info.ipBinaryDotted),
          const SizedBox(height: 6),
          _buildBinaryLine('Subnet Mask   ', info.maskBinaryDotted),
          const SizedBox(height: 6),
          _buildBinaryLine('Network Bits  ', info.networkBinaryDotted),
        ],
      ),
    );
  }

  Widget _buildBinaryLine(String label, String dottedBinary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: NocColors.textSecondary,
            ),
          ),
          Text(
            dottedBinary,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: NocColors.emeraldSuccess,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCliSnippetsCard(SubnetInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NocColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'READY-TO-USE ROUTER CLI SNIPPETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NocColors.cyanAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'MikroTik RouterOS:',
            style: TextStyle(fontSize: 11, color: NocColors.textSecondary),
          ),
          const SizedBox(height: 4),
          SelectableText(
            info.mikrotikAddressSnippet,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: NocColors.emeraldSuccess,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Cisco IOS OSPF:',
            style: TextStyle(fontSize: 11, color: NocColors.textSecondary),
          ),
          const SizedBox(height: 4),
          SelectableText(
            info.ciscoOspfSnippet,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: NocColors.amberWarning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NocColors.crimsonError.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NocColors.crimsonError),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: NocColors.crimsonError,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: NocColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
