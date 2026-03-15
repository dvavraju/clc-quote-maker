class Quotation {
  final int? id;
  final String clientName;
  final String totalAmount;
  final int createdAt;
  final int updatedAt;

  Quotation({
    this.id,
    required this.clientName,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_name': clientName,
      'total_amount': totalAmount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Quotation.fromMap(Map<String, dynamic> map) {
    return Quotation(
      id: map['id'],
      clientName: map['client_name'],
      totalAmount: map['total_amount'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}

class QuotationEvent {
  final int? id;
  final int quotationId;
  final String eventName;
  final String? eventDate;
  final int displayOrder;

  QuotationEvent({
    this.id,
    required this.quotationId,
    required this.eventName,
    this.eventDate,
    required this.displayOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quotation_id': quotationId,
      'event_name': eventName,
      'event_date': eventDate,
      'display_order': displayOrder,
    };
  }

  factory QuotationEvent.fromMap(Map<String, dynamic> map) {
    return QuotationEvent(
      id: map['id'],
      quotationId: map['quotation_id'],
      eventName: map['event_name'],
      eventDate: map['event_date'],
      displayOrder: map['display_order'],
    );
  }
}

class EventService {
  final int? id;
  final int eventId;
  final String serviceName;

  EventService({
    this.id,
    required this.eventId,
    required this.serviceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'service_name': serviceName,
    };
  }

  factory EventService.fromMap(Map<String, dynamic> map) {
    return EventService(
      id: map['id'],
      eventId: map['event_id'],
      serviceName: map['service_name'],
    );
  }
}

class QuotationDeliverable {
  final int? id;
  final int quotationId;
  final String deliverableName;
  final int isSelected; // 1 for true, 0 for false
  final int displayOrder;

  QuotationDeliverable({
    this.id,
    required this.quotationId,
    required this.deliverableName,
    required this.isSelected,
    required this.displayOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quotation_id': quotationId,
      'deliverable_name': deliverableName,
      'is_selected': isSelected,
      'display_order': displayOrder,
    };
  }

  factory QuotationDeliverable.fromMap(Map<String, dynamic> map) {
    return QuotationDeliverable(
      id: map['id'],
      quotationId: map['quotation_id'],
      deliverableName: map['deliverable_name'],
      isSelected: map['is_selected'],
      displayOrder: map['display_order'],
    );
  }
}
