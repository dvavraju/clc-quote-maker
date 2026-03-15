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

  // --- Form State for New/Edit Quotation ---
  String clientName = '';
  String totalAmount = '';
  
  // Maps to store selections
  // Key: Event Name
  final Map<String, ({String? date, Set<String> services})> selectedEvents = {};
  final Set<String> selectedDeliverables = {};

  void resetForm() {
    clientName = '';
    totalAmount = '';
    selectedEvents.clear();
    selectedDeliverables.clear();
    // Default deliverables (all pre-selected as per prompt)
    selectedDeliverables.addAll(defaultDeliverables);
    notifyListeners();
  }

  void toggleEvent(String eventName) {
    if (selectedEvents.containsKey(eventName)) {
      selectedEvents.remove(eventName);
    } else {
      selectedEvents[eventName] = (date: null, services: {});
    }
    notifyListeners();
  }

  void updateEventDate(String eventName, String? date) {
    if (selectedEvents.containsKey(eventName)) {
      selectedEvents[eventName] = (date: date, services: selectedEvents[eventName]!.services);
      notifyListeners();
    }
  }

  void toggleService(String eventName, String serviceName) {
    if (selectedEvents.containsKey(eventName)) {
      final services = selectedEvents[eventName]!.services;
      if (services.contains(serviceName)) {
        services.remove(serviceName);
      } else {
        services.add(serviceName);
      }
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

  final List<String> defaultDeliverables = [
    'Engagement Teaser - 4K',
    'Cinematic Wedding Film - 4K',
    'Main Highlights Edited Photos',
    'Traditional Edited Video including all events - 4K',
    'Pre Wedding Edited Video Song',
    'Pre Wedding Edited Photos',
    'Save the Date Video',
    'Engagement Album',
    '12x36 Wedding Album - 2 Copies'
  ];

  String generateWhatsAppMessage() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('*The Story Book by CLC*');
    buffer.writeln();

    // Events
    for (var eventName in eventList) {
      if (selectedEvents.containsKey(eventName)) {
        final data = selectedEvents[eventName]!;
        if (data.date != null && data.date!.trim().isNotEmpty) {
          buffer.writeln('*$eventName - ${data.date!.trim()}*');
        } else {
          buffer.writeln('*$eventName*');
        }

        for (var service in serviceList) {
          if (data.services.contains(service)) {
            buffer.writeln('- $service');
          }
        }
        buffer.writeln();
      }
    }

    // Deliverables
    buffer.writeln('*Deliveries:*');
    int count = 1;
    for (var deliverable in defaultDeliverables) {
      if (selectedDeliverables.contains(deliverable)) {
        buffer.writeln('$count. $deliverable');
        count++;
      }
    }
    buffer.writeln();

    // Total Amount
    buffer.writeln('*Total Package: $totalAmount/-*');
    buffer.writeln();

    // Fixed terms
    buffer.writeln('30% On Booking Confirmation');
    buffer.writeln('50% After Wedding');
    buffer.writeln('20% On Album Delivery');
    buffer.writeln();
    buffer.writeln('Thankyou');
    buffer.writeln('*Team Story Book by CLC*');
    buffer.writeln();
    buffer.writeln('*Note:*');
    buffer.writeln('1. Any Event or Outdoor Shoot Outside Visakhapatnam Client has to provide Travel and Accommodation');
    buffer.writeln();
    buffer.writeln('*FOR FURTHER DETAILS*');
    buffer.writeln('CONTACT US - +917013328284');
    buffer.writeln();
    buffer.writeln('InstagramID-https://www.instagram.com/thestorybookbyclc?igsh=N3hheHI5dWoyOXRy');
    buffer.writeln();
    buffer.writeln('Website-thestorybookbyclc.smugmug.com');

    return buffer.toString();
  }

  Future<void> saveQuotation({int? id}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final quotationMap = {
      'client_name': clientName,
      'total_amount': totalAmount,
      'updated_at': now,
    };

    int qId;
    if (id == null) {
      quotationMap['created_at'] = now;
      qId = await db.insert('quotations', quotationMap);
    } else {
      qId = id;
      await db.update(
        'quotations',
        quotationMap,
        where: 'id = ?',
        whereArgs: [id],
      );
      // Delete old events and deliverables to re-insert fresh ones
      // CASCADE delete on events will also delete services
      await db.delete('quotation_events', where: 'quotation_id = ?', whereArgs: [id]);
      await db.delete('quotation_deliverables', where: 'quotation_id = ?', whereArgs: [id]);
    }

    // Save Events & Services
    int eventOrder = 0;
    for (var eventName in eventList) {
      if (selectedEvents.containsKey(eventName)) {
        final data = selectedEvents[eventName]!;
        final eventId = await db.insert('quotation_events', {
          'quotation_id': qId,
          'event_name': eventName,
          'event_date': data.date,
          'display_order': eventOrder++,
        });

        for (var service in data.services) {
          await db.insert('event_services', {
            'event_id': eventId,
            'service_name': service,
          });
        }
      }
    }

    // Save Deliverables
    int dOrder = 0;
    for (var dName in defaultDeliverables) {
      await db.insert('quotation_deliverables', {
        'quotation_id': qId,
        'deliverable_name': dName,
        'is_selected': selectedDeliverables.contains(dName) ? 1 : 0,
        'display_order': dOrder++,
      });
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
