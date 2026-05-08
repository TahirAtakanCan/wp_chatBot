import '../models/conversation.dart';
import '../models/message.dart';
import 'conversation_service.dart';

class ApiService {
  final ConversationService _conversationService;

  ApiService({ConversationService? conversationService})
      : _conversationService = conversationService ?? ConversationService();

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

  Future<Message> sendContactCard(int conversationId) {
    return _conversationService.sendContactCard(conversationId);
  }

  Future<Conversation> closeConversation(int conversationId) {
    return _conversationService.closeConversation(conversationId);
  }
}