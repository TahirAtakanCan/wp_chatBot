import '../models/conversation.dart';
import '../models/delivery_record.dart';
import '../models/export_options.dart';
import '../models/failure_category.dart';
import '../models/meta_template.dart';
import '../models/message.dart';
import '../models/template_preset.dart';
import 'conversation_service.dart';
import 'delivery_service.dart';
import 'template_service.dart';

class ApiService {
  final ConversationService _conversationService;
  final DeliveryService _deliveryService;
  final TemplateService _templateService;

  ApiService({ConversationService? conversationService})
      : _conversationService = conversationService ?? ConversationService(),
        _deliveryService = DeliveryService(),
        _templateService = TemplateService();

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

  Future<Message> sendReplyVideo(
    int conversationId, {
    required String mediaUrl,
    String? caption,
  }) {
    return _conversationService.sendReplyVideo(
      conversationId,
      mediaUrl: mediaUrl,
      caption: caption,
    );
  }

  Future<Message> sendReplyDocument(
    int conversationId, {
    required String mediaUrl,
    required String filename,
    String? caption,
  }) {
    return _conversationService.sendReplyDocument(
      conversationId,
      mediaUrl: mediaUrl,
      filename: filename,
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

  Future<void> downloadDeliveryExcel({DeliveryStatus? status, int? days}) {
    return _deliveryService.downloadExcel(status: status, days: days);
  }

  Future<List<FailureCategory>> fetchFailureCategories() {
    return _deliveryService.fetchFailureCategories();
  }

  Future<void> downloadExcelWithOptions(ExportOptions options) {
    return _deliveryService.downloadExcelWithOptions(options);
  }

  Future<List<MetaTemplate>> fetchMetaTemplates() {
    return _templateService.fetchMetaTemplates();
  }

  Future<List<MetaTemplate>> refreshMetaTemplates() {
    return _templateService.refreshMetaTemplates();
  }

  Future<List<TemplatePreset>> fetchTemplatePresets() {
    return _templateService.fetchPresets();
  }

  Future<TemplatePreset> createTemplatePreset({
    required String displayName,
    required String metaTemplateName,
    String language = 'tr',
    String? mediaType,
    String? mediaUrl,
    String? mediaFilename,
    int? mediaSizeBytes,
    String? mimeType,
  }) {
    return _templateService.createPreset(
      displayName: displayName,
      metaTemplateName: metaTemplateName,
      language: language,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaFilename: mediaFilename,
      mediaSizeBytes: mediaSizeBytes,
      mimeType: mimeType,
    );
  }

  Future<TemplatePreset> updateTemplatePreset(
    int id, {
    required String displayName,
    String? mediaType,
    String? mediaUrl,
    String? mediaFilename,
    int? mediaSizeBytes,
    String? mimeType,
    String? metaTemplateName,
    String language = 'tr',
  }) {
    return _templateService.updatePreset(
      id,
      displayName: displayName,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaFilename: mediaFilename,
      mediaSizeBytes: mediaSizeBytes,
      mimeType: mimeType,
      metaTemplateName: metaTemplateName,
      language: language,
    );
  }

  Future<void> deleteTemplatePreset(int id) {
    return _templateService.deletePreset(id);
  }
}