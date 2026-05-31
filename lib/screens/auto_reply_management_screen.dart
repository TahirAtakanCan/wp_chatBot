import 'package:flutter/material.dart';

import '../models/auto_reply.dart';
import '../services/api_service.dart';
import '../theme/wa_colors.dart';

class AutoReplyManagementScreen extends StatefulWidget {
  const AutoReplyManagementScreen({super.key});

  @override
  State<AutoReplyManagementScreen> createState() =>
      _AutoReplyManagementScreenState();
}

class _AutoReplyManagementScreenState extends State<AutoReplyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AutoReply> _replies = [];
  AutoReplySettings? _settings;
  bool _isLoading = false;
  bool _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.fetchAutoReplies(),
        api.getAutoReplySettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _replies = results[0] as List<AutoReply>;
        _settings = results[1] as AutoReplySettings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceAll('Exception: ', '')),
        backgroundColor: WAColors.errorRed,
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: WAColors.accent,
      ),
    );
  }

  Future<void> _toggleReply(AutoReply reply) async {
    try {
      final updated = await ApiService().toggleAutoReply(reply.id);
      if (!mounted) return;
      setState(() {
        final idx = _replies.indexWhere((r) => r.id == reply.id);
        if (idx != -1) _replies[idx] = updated;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _deleteReply(AutoReply reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: Text('"${reply.category}" kategorisini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil', style: TextStyle(color: WAColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deleteAutoReply(reply.id);
      if (!mounted) return;
      setState(() => _replies.removeWhere((r) => r.id == reply.id));
      _showSuccess('Silindi');
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _updateSettings(AutoReplySettings updated) async {
    setState(() => _isSavingSettings = true);
    try {
      final saved = await ApiService().updateAutoReplySettings(updated);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _isSavingSettings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingSettings = false);
      _showError(e.toString());
    }
  }

  void _showEditDialog(AutoReply? existing) {
    showDialog(
      context: context,
      builder: (_) => _ReplyEditDialog(
        existing: existing,
        onSaved: _loadData,
      ),
    );
  }

  void _showTestDialog() {
    showDialog(
      context: context,
      builder: (_) => const _TestReplyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Otomatik Yanıtlar'),
        backgroundColor: WAColors.leftPanelHeader,
        actions: [
          if (_isSavingSettings)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Test Et',
            onPressed: _showTestDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Hazır Cevaplar (${_replies.length})'),
            const Tab(text: 'Ayarlar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRepliesTab(),
                _buildSettingsTab(),
              ],
            ),
    );
  }

  Widget _buildRepliesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: WAColors.accent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Cevap Ekle'),
              onPressed: () => _showEditDialog(null),
            ),
          ),
        ),
        Expanded(
          child: _replies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('Henüz hazır cevap yok',
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text('"Yeni Cevap Ekle" butonuna tıklayın',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _replies.length,
                  itemBuilder: (context, idx) =>
                      _buildReplyCard(_replies[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildReplyCard(AutoReply reply) {
    final keywords = reply.keywordList;
    final visibleKeywords = keywords.take(5).toList();
    final extraCount = keywords.length - visibleKeywords.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reply.category,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: reply.active,
                  activeThumbColor: WAColors.accent,
                  onChanged: (_) => _toggleReply(reply),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...visibleKeywords.map((k) => Chip(
                      label: Text(k,
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )),
                if (extraCount > 0)
                  Chip(
                    label: Text('+$extraCount',
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                reply.replyText,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.bar_chart,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${reply.matchCount} kez eşleşti',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showEditDialog(reply),
                  child: const Text('Düzenle'),
                ),
                TextButton(
                  onPressed: () => _deleteReply(reply),
                  child: const Text('Sil',
                      style: TextStyle(color: WAColors.errorRed)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    if (_settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = _settings!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Otomatik Yanıt Aktif'),
                  subtitle: const Text(
                      'Tüm hazır cevaplar otomatik olarak gönderilir'),
                  value: settings.enabled,
                  activeThumbColor: WAColors.accent,
                  onChanged: (val) =>
                      _updateSettings(settings.copyWith(enabled: val)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sadece Mesai Saatlerinde'),
                  subtitle: const Text(
                      'Saat aralığı dışında özel mesaj gönderilir'),
                  value: settings.useWorkingHours,
                  activeThumbColor: WAColors.accent,
                  onChanged: (val) => _updateSettings(
                      settings.copyWith(useWorkingHours: val)),
                ),
                if (settings.useWorkingHours) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Başlangıç',
                            value: settings.workingHoursStart,
                            onChanged: (v) => _updateSettings(
                                settings.copyWith(workingHoursStart: v)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            label: 'Bitiş',
                            value: settings.workingHoursEnd,
                            onChanged: (v) => _updateSettings(
                                settings.copyWith(workingHoursEnd: v)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _OutOfHoursField(
                      value: settings.outOfHoursMessage,
                      onChanged: (v) => _updateSettings(
                          settings.copyWith(outOfHoursMessage: v)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _CooldownField(
                value: settings.cooldownSeconds,
                onChanged: (v) =>
                    _updateSettings(settings.copyWith(cooldownSeconds: v)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Time Field ────────────────────────────────────────────────────────────────

class _TimeField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '09:00',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: (v) {
        final trimmed = v.trim();
        if (RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed)) {
          widget.onChanged(trimmed);
        }
      },
    );
  }
}

// ─── Out of hours message Field ────────────────────────────────────────────────

class _OutOfHoursField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _OutOfHoursField({required this.value, required this.onChanged});

  @override
  State<_OutOfHoursField> createState() => _OutOfHoursFieldState();
}

class _OutOfHoursFieldState extends State<_OutOfHoursField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Mesai Dışı Mesajı',
        hintText: 'Çalışma saatleri dışındasınız...',
        border: OutlineInputBorder(),
      ),
      onSubmitted: widget.onChanged,
    );
  }
}

// ─── Cooldown Field ────────────────────────────────────────────────────────────

class _CooldownField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CooldownField({required this.value, required this.onChanged});

  @override
  State<_CooldownField> createState() => _CooldownFieldState();
}

class _CooldownFieldState extends State<_CooldownField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aynı Kişiye Cevap Arası',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              SizedBox(height: 2),
              Text('Aynı kişiden gelen tekrar mesajlarda bekleme süresi',
                  style: TextStyle(fontSize: 12, color: WAColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              suffixText: 'sn',
            ),
            onSubmitted: (v) {
              final num = int.tryParse(v.trim());
              if (num != null && num > 0) widget.onChanged(num);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Edit Dialog ───────────────────────────────────────────────────────────────

class _ReplyEditDialog extends StatefulWidget {
  final AutoReply? existing;
  final VoidCallback onSaved;

  const _ReplyEditDialog({this.existing, required this.onSaved});

  @override
  State<_ReplyEditDialog> createState() => _ReplyEditDialogState();
}

class _ReplyEditDialogState extends State<_ReplyEditDialog> {
  late TextEditingController _categoryCtrl;
  late TextEditingController _keywordsCtrl;
  late TextEditingController _replyCtrl;
  late TextEditingController _priorityCtrl;
  bool _active = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categoryCtrl =
        TextEditingController(text: widget.existing?.category ?? '');
    _keywordsCtrl =
        TextEditingController(text: widget.existing?.keywords ?? '');
    _replyCtrl =
        TextEditingController(text: widget.existing?.replyText ?? '');
    _priorityCtrl =
        TextEditingController(text: '${widget.existing?.priority ?? 100}');
    _active = widget.existing?.active ?? true;
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _keywordsCtrl.dispose();
    _replyCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceAll('Exception: ', '')),
        backgroundColor: WAColors.errorRed,
      ),
    );
  }

  Future<void> _save() async {
    final category = _categoryCtrl.text.trim();
    final keywords = _keywordsCtrl.text.trim();
    final replyText = _replyCtrl.text.trim();

    if (category.isEmpty || keywords.isEmpty || replyText.isEmpty) {
      _showError('Kategori, anahtar kelimeler ve cevap metni zorunludur');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ApiService();
      final priority = int.tryParse(_priorityCtrl.text.trim()) ?? 100;

      if (widget.existing == null) {
        await api.createAutoReply(
          category: category,
          keywords: keywords,
          replyText: replyText,
          active: _active,
          priority: priority,
        );
      } else {
        await api.updateAutoReply(
          widget.existing!.id,
          category: category,
          keywords: keywords,
          replyText: replyText,
          active: _active,
          priority: priority,
        );
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isNew ? 'Yeni Cevap' : 'Cevabı Düzenle',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kategori adı *',
                  hintText: 'örn: Selam, Bağış, Konum',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keywordsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Anahtar kelimeler (virgülle ayrılmış) *',
                  hintText: 'selam, merhaba, hello, selamun aleyküm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: TextField(
                  controller: _replyCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Cevap metni *',
                    hintText: 'Gönderilecek mesajı yazın...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priorityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Öncelik (düşük = yüksek)',
                        hintText: '100',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:                     SwitchListTile(
                      title: const Text('Aktif'),
                      value: _active,
                      activeThumbColor: WAColors.accent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WAColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Test Dialog ───────────────────────────────────────────────────────────────

class _TestReplyDialog extends StatefulWidget {
  const _TestReplyDialog();

  @override
  State<_TestReplyDialog> createState() => _TestReplyDialogState();
}

class _TestReplyDialogState extends State<_TestReplyDialog> {
  final TextEditingController _ctrl = TextEditingController();
  Map<String, dynamic>? _result;
  bool _isTesting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _isTesting = true;
      _result = null;
    });
    try {
      final result = await ApiService().testAutoReplyMessage(msg);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isTesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = {'error': e.toString().replaceAll('Exception: ', '')};
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mesaj Test Et',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bir mesaj yazın ve hangi hazır cevabın tetikleneceğini görün.',
                style: TextStyle(fontSize: 13, color: WAColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  labelText: 'Test mesajı',
                  hintText: 'örn: Selamun aleyküm',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _test(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WAColors.accent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: Text(_isTesting ? 'Test ediliyor...' : 'Test Et'),
                onPressed: _isTesting ? null : _test,
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildResult(_result!),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    if (result.containsKey('error')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: WAColors.errorRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result['error'] as String,
                style: const TextStyle(color: WAColors.errorRed),
              ),
            ),
          ],
        ),
      );
    }

    final matched = result['matched'] == true;

    if (!matched) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.search_off, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Text('Eşleşme bulunamadı',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.orange)),
              ],
            ),
            if (result['normalized'] != null) ...[
              const SizedBox(height: 4),
              Text('Normalize edildi: ${result['normalized']}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: WAColors.accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Eşleşti: ${result['category'] ?? ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: WAColors.accentDark),
                ),
              ),
            ],
          ),
          if (result['keyword'] != null) ...[
            const SizedBox(height: 4),
            Text('Anahtar kelime: ${result['keyword']}',
                style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 8),
          const Text('Gönderilecek cevap:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Text(
              result['replyText'] as String? ?? '',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
