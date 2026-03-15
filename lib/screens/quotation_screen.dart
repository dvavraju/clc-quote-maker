import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
      _loadInitialData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<QuotationProvider>().resetForm();
      });
    }
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<QuotationProvider>();
    final db = await DatabaseHelper.instance.database;
    
    // Fetch individual quotation
    final results = await db.query('quotations', where: 'id = ?', whereArgs: [widget.quotationId]);
    if (results.isEmpty) return;
    
    final q = results.first;
    provider.clientName = q['client_name'] as String;
    provider.totalAmount = q['total_amount'] as String;
    _clientController.text = provider.clientName;
    _amountController.text = provider.totalAmount;

    // Load Events & Services
    final events = await DatabaseHelper.instance.getEventsForQuotation(widget.quotationId!);
    provider.selectedEvents.clear();
    for (var ev in events) {
      final services = await DatabaseHelper.instance.getServicesForEvent(ev.id!);
      provider.selectedEvents[ev.eventName] = (
        date: ev.eventDate,
        services: services.map((s) => s.serviceName).toSet(),
      );
    }

    // Load Deliverables
    final deliverables = await DatabaseHelper.instance.getDeliverablesForQuotation(widget.quotationId!);
    provider.selectedDeliverables.clear();
    for (var d in deliverables) {
      if (d.isSelected == 1) {
        provider.selectedDeliverables.add(d.deliverableName);
      }
    }
    provider.notifyListeners();
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
          builder: (context) => AlertDialog(
            title: const Text('Save changes?'),
            content: const Text('Do you want to save or discard your changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Discard
                child: const Text('Discard', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), // Save
                child: const Text('Save', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null), // Cancel
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );

        if (shouldSave == null) return;
        if (shouldSave) {
          await provider.saveQuotation(id: widget.quotationId);
        }
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLIENT NAME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (val) => provider.clientName = val,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'SELECT EVENTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: QuotationProvider.eventList.map((e) {
                        final isSelected = provider.selectedEvents.containsKey(e);
                        return AppChip(
                          label: e,
                          isSelected: isSelected,
                          onTap: () => provider.toggleEvent(e),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Expandable Event Details
                    ...provider.selectedEvents.entries.map((entry) {
                      final eventName = entry.key;
                      final data = entry.value;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(top: 8, bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_note, size: 18, color: Colors.black),
                                  const SizedBox(width: 8),
                                  Text(
                                    eventName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const Spacer(),
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
                                  TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Event Date (optional)',
                                      hintText: 'e.g. Mar 15th 26',
                                      labelStyle: const TextStyle(fontSize: 12),
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    controller: TextEditingController(text: data.date)
                                      ..selection = TextSelection.collapsed(offset: data.date?.length ?? 0),
                                    onChanged: (val) => provider.updateEventDate(eventName, val),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'SERVICES',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: QuotationProvider.serviceList.map((s) {
                                      final isSSelected = data.services.contains(s);
                                      return AppChip(
                                        label: s,
                                        isSelected: isSSelected,
                                        compact: true,
                                        onTap: () => provider.toggleService(eventName, s),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 32),
                    Text(
                      'DELIVERABLES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.defaultDeliverables.map((d) {
                        final isSelected = provider.selectedDeliverables.contains(d);
                        return AppChip(
                          label: d,
                          isSelected: isSelected,
                          onTap: () => provider.toggleDeliverable(d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'TOTAL PACKAGE AMOUNT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        placeholder: 'e.g. 3,10,000',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                      ),
                      onChanged: (val) => provider.totalAmount = val,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // Live Preview Panel
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
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
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          provider.generateWhatsAppMessage(),
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final message = provider.generateWhatsAppMessage();
                        await Clipboard.setData(ClipboardData(text: message));
                        await provider.saveQuotation(id: widget.quotationId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message copied and quotation saved!'),
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
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
