import '../models/conversation.dart';
import '../models/delivery_record.dart';
import '../models/message.dart';
import 'conversation_service.dart';
import 'delivery_service.dart';

class ApiService {
  final ConversationService _conversationService;
  final DeliveryService _deliveryService;

  ApiService({ConversationService? conversationService})
      : _conversationService = conversationService ?? ConversationService(),
        _deliveryService = DeliveryService();

  Future<List<Conversation>> fetchConversations({int page = 0, int size = 50}) {
    return _conversationService.fetchConversations(page: page, size: size);
  }

  Future<List<Message>> fetchMessages(int conversationId, {int page = 0, int size = 100}) {
    return _conversationService.fetchMessages(
      conversationId,
      page: page,
      size: size,
    );
  }

  Future<Message> sendReply(int conversationId, String text) {
    return _conversationService.sendReply(conversationId, text);
  }

  Future<Message> sendReplyImage(
    int conversationId, {
    required String imageUrl,
    String? caption,
  }) {
    return _conversationService.sendReplyImage(
      conversationId,
      imageUrl: imageUrl,
      caption: caption,
    );
  }

  Future<Message> sendContactCard(int conversationId) {
    return _conversationService.sendContactCard(conversationId);
  }

  Future<Conversation> closeConversation(int conversationId) {
    return _conversationService.closeConversation(conversationId);
  }

  Future<int> clearAllMessages(int conversationId) {
    return _conversationService.clearAllMessages(conversationId);
  }

  Future<void> deleteMessage(int conversationId, int messageId) {
    return _conversationService.deleteMessage(conversationId, messageId);
  }

  Future<Map<String, dynamic>> deleteConversation(int conversationId) {
    return _conversationService.deleteConversation(conversationId);
  }

  Future<List<DeliveryRecord>> listDeliveries({
    int page = 0,
    int size = 50,
    DeliveryStatus? status,
    String sortBy = 'sentAt',
    String direction = 'desc',
  }) {
    return _deliveryService.list(
      page: page,
      size: size,
      status: status,
      sortBy: sortBy,
      direction: direction,
    );
  }

  Future<Map<String, DeliveryStatus>> lookupDeliveryStatuses(
    List<String> phones,
  ) {
    return _deliveryService.lookupByPhones(phones);
  }

  Future<List<DeliveryRecord>> getDeliveryByPhone(String phone) {
    return _deliveryService.getByPhone(phone);
  }

  Future<Map<String, int>> getDeliveryStats() {
    return _deliveryService.getStats();
  }

  Future<int> purgeOldDeliveries({int days = 2}) {
    return _deliveryService.purgeOlderThan(days: days);
  }
}