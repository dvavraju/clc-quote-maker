import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class QuotationProvider with ChangeNotifier {
  List<Quotation> _quotations = [];
  bool _isLoading = false;

  List<Quotation> get quotations => _quotations;
  bool get isLoading => _isLoading;

  Future<void> loadQuotations() async {
    _isLoading = true;
    notifyListeners();
    _quotations = await DatabaseHelper.instance.getAllQuotations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteQuotation(int id) async {
    await DatabaseHelper.instance.deleteQuotation(id);
    await loadQuotations();
  }

  // --- Form State ---
  String clientName = '';
  String totalAmount = '';

  // Map preserves insertion order = SELECTION ORDER for events
  final Map<String, ({String? date, Set<String> services})> selectedEvents = {};

  // List preserves insertion order = SELECTION ORDER for deliverables
  final List<String> selectedDeliverables = [];

  void resetForm() {
    clientName = '';
    totalAmount = '';
    selectedEvents.clear();
    selectedDeliverables.clear();
    // No pre-population — user selects what they need
    notifyListeners();
  }

  void toggleEvent(String eventName) {
    if (selectedEvents.containsKey(eventName)) {
      selectedEvents.remove(eventName);
    } else {
      selectedEvents[eventName] = (date: null, services: <String>{});
    }
    notifyListeners();
  }

  void updateEventDate(String eventName, String? date) {
    if (selectedEvents.containsKey(eventName)) {
      final current = selectedEvents[eventName]!;
      selectedEvents[eventName] = (date: date, services: current.services);
      notifyListeners();
    }
  }

  void toggleService(String eventName, String serviceName) {
    if (selectedEvents.containsKey(eventName)) {
      final current = selectedEvents[eventName]!;
      final updatedServices = Set<String>.from(current.services);
      if (updatedServices.contains(serviceName)) {
        updatedServices.remove(serviceName);
      } else {
        updatedServices.add(serviceName);
      }
      selectedEvents[eventName] = (date: current.date, services: updatedServices);
      notifyListeners();
    }
  }

  void toggleDeliverable(String deliverableName) {
    if (selectedDeliverables.contains(deliverableName)) {
      selectedDeliverables.remove(deliverableName);
    } else {
      selectedDeliverables.add(deliverableName);
    }
    notifyListeners();
  }

  // ── Full deliverables list (v1.2) ──────────────────────────────
  static const List<String> allDeliverables = [
    'Cinematic Wedding Film 4K',
    'Traditional Edited Video including all events 4K',
    'Main Highlights Edited Photos',
    'Pre Wedding Video Song 4K',
    'Pre Wedding Edited Photos',
    'Save the Date Video 4K',
    '12x36 Wedding Album 2 Copies (60 Sheets Each)',
    '15x24 Album 25 Sheets',
    '12x36 Premium Album 2 Copies (60 Sheets Each)',
    'Engagement Teaser 4K',
    'Wedding Teaser 4K',
    'Reception Teaser 4K',
    'Haldi Teaser 4K',
    'Sangeet Teaser 4K',
    'Birthday Teaser 4K',
  ];

  // ── WhatsApp Message Generator ─────────────────────────────────
  String generateWhatsAppMessage() {
    final buffer = StringBuffer();
    buffer.writeln('*The Story Book by CLC*');
    buffer.writeln();

    // Events in SELECTION ORDER (Map preserves insertion order)
    for (final eventName in selectedEvents.keys) {
      final data = selectedEvents[eventName]!;
      final trimmedDate = data.date?.trim();
      if (trimmedDate != null && trimmedDate.isNotEmpty) {
        buffer.writeln('*$eventName - $trimmedDate*');
      } else {
        buffer.writeln('*$eventName*');
      }
      for (final service in serviceList) {
        if (data.services.contains(service)) {
          buffer.writeln('- $service');
        }
      }
      buffer.writeln();
    }

    // Deliverables in SELECTION ORDER (List preserves insertion order)
    buffer.writeln('*Deliveries:*');
    for (int i = 0; i < selectedDeliverables.length; i++) {
      buffer.writeln('${i + 1}. ${selectedDeliverables[i]}');
    }
    buffer.writeln();

    buffer.writeln('*Total Package: $totalAmount/-*');
    buffer.writeln();
    buffer.writeln('30% On Booking Confirmation');
    buffer.writeln('50% After Wedding');
    buffer.writeln('20% On Album Delivery');
    buffer.writeln();
    buffer.writeln('Thankyou');
    buffer.writeln('*Team Story Book by CLC*');
    buffer.writeln();
    buffer.writeln('*Note:*');
    buffer.writeln(
        '1. Any Event or Outdoor Shoot Outside Visakhapatnam Client has to provide Travel and Accommodation');
    buffer.writeln();
    buffer.writeln('*FOR FURTHER DETAILS*');
    buffer.writeln('CONTACT US - +917013328284');
    buffer.writeln();
    buffer.writeln(
        'InstagramID-https://www.instagram.com/thestorybookbyclc?igsh=N3hheHI5dWoyOXRy');
    // SmugMug link removed per v1.2

    return buffer.toString();
  }

  // ── Save / Update ──────────────────────────────────────────────
  Future<void> saveQuotation({int? id}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    int qId;
    if (id == null) {
      qId = await db.insert('quotations', {
        'client_name': clientName,
        'total_amount': totalAmount,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      qId = id;
      await db.update(
        'quotations',
        {'client_name': clientName, 'total_amount': totalAmount, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      // Cascade delete via FK; we re-insert fresh
      await db.delete('quotation_events', where: 'quotation_id = ?', whereArgs: [id]);
      await db.delete('quotation_deliverables', where: 'quotation_id = ?', whereArgs: [id]);
    }

    // Save events in SELECTION ORDER
    int eventOrder = 0;
    for (final eventName in selectedEvents.keys) {
      final data = selectedEvents[eventName]!;
      final eventId = await db.insert('quotation_events', {
        'quotation_id': qId,
        'event_name': eventName,
        'event_date': data.date,
        'display_order': eventOrder++,
      });
      for (final service in data.services) {
        await db.insert('event_services', {
          'event_id': eventId,
          'service_name': service,
        });
      }
    }

    // Save selected deliverables in SELECTION ORDER (lowest display_order)
    for (int i = 0; i < selectedDeliverables.length; i++) {
      await db.insert('quotation_deliverables', {
        'quotation_id': qId,
        'deliverable_name': selectedDeliverables[i],
        'is_selected': 1,
        'display_order': i,
      });
    }

    // Save remaining unselected deliverables for completeness
    int unselOrder = selectedDeliverables.length;
    for (final dName in allDeliverables) {
      if (!selectedDeliverables.contains(dName)) {
        await db.insert('quotation_deliverables', {
          'quotation_id': qId,
          'deliverable_name': dName,
          'is_selected': 0,
          'display_order': unselOrder++,
        });
      }
    }

    await loadQuotations();
  }

  static const List<String> eventList = [
    'Bride Making & Haldi',
    'Groom Making & Haldi',
    'Couple Haldi',
    'Wedding Day',
    'Bride Haldi',
    'Groom Haldi',
    'Bride Making',
    'Groom Making',
    'Sangeet',
    'Pre Wedding',
    'Outdoor Shoot',
    'Birthday Event',
    'Upanayanam',
    'Maternity Shoot',
    'Indoor Studio Shoot',
    'Portfolio Shoot',
  ];

  static const List<String> serviceList = [
    'Candid Photo',
    'Candid Video',
    'Traditional Photos',
    'Traditional Video',
    'Drone',
    'LED Wall',
    'YT Live',
  ];
}
