import 'package:flutter/material.dart';

import '../../core/network_exceptions.dart';
import '../../main.dart';
import '../../models/http_check_models.dart';
import '../../viewmodels/http_checker_viewmodel.dart';

class HttpCheckerScreen extends StatefulWidget {
  final HttpCheckerViewModel viewModel;

  const HttpCheckerScreen({Key? key, required this.viewModel})
      : super(key: key);

  @override
  State<HttpCheckerScreen> createState() => _HttpCheckerScreenState();
}

class _HttpCheckerScreenState extends State<HttpCheckerScreen> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.viewModel.urlInput);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final result = vm.latestResult;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildRequestFormCard(vm),
              const SizedBox(height: 16),
              if (vm.inputError != null)
                _buildDiagnosticErrorCard(vm.inputError!)
              else if (result != null) ...<Widget>[
                if (result.error != null)
                  _buildDiagnosticErrorCard(
                    result.error!,
                    latencyMs: result.responseTimeMs,
                  )
                else
                  _buildStatusResultCard(result),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestFormCard(HttpCheckerViewModel vm) {
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
            'Endpoint Presets',
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
            children: HttpCheckerViewModel.presetUrls.map((url) {
              return ActionChip(
                backgroundColor: NocColors.surfaceElevated,
                side: const BorderSide(color: NocColors.border),
                label: Text(
                  url,
                  style: const TextStyle(
                    fontSize: 11,
                    color: NocColors.textPrimary,
                  ),
                ),
                onPressed: vm.isLoading
                    ? null
                    : () {
                        _urlController.text = url;
                        vm.updateUrl(url);
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('HEAD (Fast)'),
                selected: vm.method == HttpCheckMethod.head,
                selectedColor: NocColors.cyanAccent.withOpacity(0.2),
                onSelected: (_) => vm.setMethod(HttpCheckMethod.head),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('GET (Full)'),
                selected: vm.method == HttpCheckMethod.get,
                selectedColor: NocColors.cyanAccent.withOpacity(0.2),
                onSelected: (_) => vm.setMethod(HttpCheckMethod.get),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: vm.timeoutSeconds,
                dropdownColor: NocColors.surfaceElevated,
                items: const <int>[3, 5, 10].map((sec) {
                  return DropdownMenuItem<int>(
                    value: sec,
                    child: Text(
                      'Timeout: ${sec}s',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) vm.setTimeoutSeconds(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _urlController,
                  onChanged: vm.updateUrl,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: NocColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Server URL / WebFig / REST API',
                    hintText: 'https://one.one.one.one',
                    filled: true,
                    fillColor: NocColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      Icons.public,
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
                    backgroundColor: NocColors.cyanAccent,
                    foregroundColor: NocColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: vm.isLoading ? null : vm.runCheck,
                  icon: vm.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt),
                  label: Text(
                    vm.isLoading ? 'CHECKING' : 'CHECK',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusResultCard(HttpCheckResult result) {
    final badgeColor = _colorForCategory(result.category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(
                  'HTTP ${result.statusCode} ${result.reasonPhrase ?? ""}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: badgeColor,
                  ),
                ),
              ),
              Text(
                '${result.responseTimeMs} ms',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: NocColors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            HttpCheckResult.describeStatusCode(result.statusCode),
            style: const TextStyle(
              fontSize: 13,
              color: NocColors.textPrimary,
            ),
          ),
          const Divider(height: 24, color: NocColors.border),
          const Text(
            'RESPONSE HEADERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NocColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (result.headers.isEmpty)
            const Text(
              'Tidak ada header tambahan.',
              style: TextStyle(fontSize: 12, color: NocColors.textSecondary),
            )
          else
            ...result.headers.entries.take(8).map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 130,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: NocColors.cyanAccent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: NocColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDiagnosticErrorCard(
    NetworkDiagnosticError error, {
    int? latencyMs,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NocColors.crimsonError),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: NocColors.crimsonError,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    error.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: NocColors.crimsonError,
                    ),
                  ),
                ],
              ),
              if (latencyMs != null)
                Text(
                  '${latencyMs} ms',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: NocColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            error.message,
            style: const TextStyle(fontSize: 13, color: NocColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NocColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.build_circle_outlined,
                  size: 18,
                  color: NocColors.amberWarning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Troubleshooting Hint: ${error.troubleshootingHint}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: NocColors.amberWarning,
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

  Color _colorForCategory(HttpStatusCategory category) {
    switch (category) {
      case HttpStatusCategory.success:
        return NocColors.emeraldSuccess;
      case HttpStatusCategory.redirection:
        return NocColors.cyanAccent;
      case HttpStatusCategory.clientError:
        return NocColors.amberWarning;
      case HttpStatusCategory.serverError:
      case HttpStatusCategory.unknown:
        return NocColors.crimsonError;
      case HttpStatusCategory.informational:
        return NocColors.textSecondary;
    }
  }
}
