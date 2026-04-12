import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/quotation_provider.dart';
import '../db/database_helper.dart';
import '../widgets/custom_chips.dart';

class QuotationScreen extends StatefulWidget {
  final int? quotationId;
  const QuotationScreen({super.key, this.quotationId});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.quotationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<QuotationProvider>().resetForm();
      });
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final provider = context.read<QuotationProvider>();
    final db = await DatabaseHelper.instance.database;

    final results = await db.query(
      'quotations',
      where: 'id = ?',
      whereArgs: [widget.quotationId],
    );
    if (results.isEmpty || !mounted) return;

    final q = results.first;
    provider.clientName = q['client_name'] as String;
    provider.totalAmount = q['total_amount'] as String;
    _clientController.text = provider.clientName;
    _amountController.text = provider.totalAmount;

    // Load events — ordered by display_order = selection order
    final events = await DatabaseHelper.instance
        .getEventsForQuotation(widget.quotationId!);
    provider.selectedEvents.clear();
    for (final ev in events) {
      final services =
          await DatabaseHelper.instance.getServicesForEvent(ev.id!);
      provider.selectedEvents[ev.eventName] = (
        date: ev.eventDate,
        services: services.map((s) => s.serviceName).toSet(),
      );
    }

    // Load deliverables — selected ones first, ordered by display_order
    final deliverables = await DatabaseHelper.instance
        .getDeliverablesForQuotation(widget.quotationId!);
    provider.selectedDeliverables.clear();
    for (final d in deliverables) {
      if (d.isSelected == 1) {
        provider.selectedDeliverables.add(d.deliverableName);
      }
    }

    if (mounted) provider.notifyListeners();
  }

  // ── Date picker helper ─────────────────────────────────────────
  DateTime _parseStoredDate(String? stored) {
    if (stored == null || stored.isEmpty) return DateTime.now();
    try {
      return DateFormat('d MMM yyyy').parse(stored);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuotationProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? shouldSave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Save changes?'),
            content:
                const Text('Do you want to save or discard your changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('Discard', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Save', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
        if (shouldSave == null || !mounted) return;
        if (shouldSave) await provider.saveQuotation(id: widget.quotationId);
        if (mounted) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/logo.png', width: 32, height: 32),
              const SizedBox(width: 10),
              Text(
                widget.quotationId == null ? 'New Quotation' : 'Edit Quotation',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Scrollable Form ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Name
                    _sectionLabel('CLIENT NAME'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clientController,
                      decoration: InputDecoration(
                        hintText: 'Enter client name',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onChanged: (val) => provider.clientName = val,
                    ),
                    const SizedBox(height: 32),

                    // ── Events ──────────────────────────────────
                    _sectionLabel('SELECT EVENTS'),
                    const SizedBox(height: 4),
                    Text(
                      'Events appear in the message in the order you select them',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: QuotationProvider.eventList.map((e) {
                        final isSelected =
                            provider.selectedEvents.containsKey(e);
                        return AppChip(
                          label: e,
                          isSelected: isSelected,
                          onTap: () => provider.toggleEvent(e),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Expanded event panels — in SELECTION ORDER
                    for (final eventName in provider.selectedEvents.keys)
                      _buildEventPanel(context, eventName, provider),

                    const SizedBox(height: 32),

                    // ── Deliverables ─────────────────────────────
                    _sectionLabel('DELIVERABLES'),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to select. Numbers show the order they appear in the message.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: QuotationProvider.allDeliverables.map((d) {
                        final selIdx =
                            provider.selectedDeliverables.indexOf(d);
                        final isSelected = selIdx != -1;
                        return AppChip(
                          label: d,
                          isSelected: isSelected,
                          selectionOrder:
                              isSelected ? selIdx + 1 : null,
                          onTap: () => provider.toggleDeliverable(d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // ── Amount ───────────────────────────────────
                    _sectionLabel('TOTAL PACKAGE AMOUNT'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 3,10,000',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        prefixIcon:
                            const Icon(Icons.currency_rupee, size: 18),
                      ),
                      onChanged: (val) => provider.totalAmount = val,
                    ),
                    const SizedBox(height: 40),

                    // ── Live Preview Panel (Now inline, not sticky) ──
                    _buildPreviewPanel(context, provider),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildEventPanel(
      BuildContext context, String eventName, QuotationProvider provider) {
    final data = provider.selectedEvents[eventName]!;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.event_note, size: 18, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eventName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => provider.toggleEvent(eventName),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date picker ─────────────────────────────────
                const Text(
                  'EVENT DATE (optional)',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _parseStoredDate(data.date),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.black,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null && mounted) {
                            provider.updateEventDate(
                              eventName,
                              DateFormat('d MMM yyyy').format(picked),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 16, color: Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (data.date?.isNotEmpty == true)
                                      ? data.date!
                                      : 'Select event date',
                                  style: TextStyle(
                                    color: (data.date?.isNotEmpty ==
                                            true)
                                        ? Colors.black87
                                        : Colors.black38,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Clear date button
                    if (data.date?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.clear,
                            size: 18, color: Colors.black38),
                        onPressed: () =>
                            provider.updateEventDate(eventName, null),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Services ─────────────────────────────────────
                const Text(
                  'SERVICES',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: QuotationProvider.serviceList.map((s) {
                    final isSvc = data.services.contains(s);
                    return AppChip(
                      label: s,
                      isSelected: isSvc,
                      compact: true,
                      onTap: () =>
                          provider.toggleService(eventName, s),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(
      BuildContext context, QuotationProvider provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'LIVE PREVIEW',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: SelectableText(
              provider.generateWhatsAppMessage(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () async {
                final message = provider.generateWhatsAppMessage();
                await Clipboard.setData(ClipboardData(text: message));
                await provider.saveQuotation(id: widget.quotationId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Message copied and quotation saved!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  context.go('/');
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'COPY MESSAGE & SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
