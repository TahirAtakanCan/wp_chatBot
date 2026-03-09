import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  String _getToken() {
    return context.read<AuthProvider>().token ?? '';
  }

  Future<void> _loadUsers() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseHost}/api/users'),
            headers: AppConfig.authHeaders(_getToken()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _users = data.cast<Map<String, dynamic>>();
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcılar yüklenemedi.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(dynamic userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcıyı Sil'),
        content:
            const Text('Bu kullanıcıyı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http
          .delete(
            Uri.parse('${AppConfig.baseHost}/api/users/$userId'),
            headers: AppConfig.authHeaders(_getToken()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı silindi.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı silinemedi.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _createUser(
    String username,
    String password,
    String sessionId,
    String role,
  ) async {
    try {
      final body = {
        'username': username,
        'password': password,
        'role': role,
      };
      if (sessionId.isNotEmpty) {
        body['sessionId'] = sessionId;
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseHost}/api/users'),
            headers: AppConfig.authHeaders(_getToken()),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _loadUsers();
        if (mounted) {
          _showCredentialsDialog(username, password);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı oluşturulamadı.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _showCredentialsDialog(String username, String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcı Bilgileri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanıcı başarıyla oluşturuldu. Bilgileri kopyalayıp paylaşabilirsiniz.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text('Kullanıcı Adı:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 4),
            SelectableText(
              username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Şifre:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 4),
            SelectableText(
              password,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Kullanıcı Adı: $username\nŞifre: $password',
              ));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Bilgiler kopyalandı!')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Kopyala'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final sessionCtrl = TextEditingController();
    String selectedRole = 'USER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Kullanıcı Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı Adı',
                    hintText: 'Örn: ahmet',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sessionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Session ID',
                    hintText: 'Örn: wp_ahmet',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'USER', child: Text('USER')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedRole = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final username = usernameCtrl.text.trim();
                final password = passwordCtrl.text.trim();
                final sessionId = sessionCtrl.text.trim();
                if (username.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Kullanıcı adı ve şifre zorunludur.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _createUser(username, password, sessionId, selectedRole);
              },
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Yeni Kullanıcı Ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz kullanıcı bulunmuyor.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sağ alttaki butona basarak yeni kullanıcı ekleyin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _UserCard(
                      user: user,
                      onDelete: () => _deleteUser(
                        user['id'] ?? user['_id'] ?? '',
                      ),
                    );
                  },
                ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username'] ?? '-';
    final role = user['role'] ?? 'USER';
    final sessionId = user['sessionId'];
    final isAdmin = role == 'ADMIN';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Kullanıcı ikonu
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isAdmin
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: isAdmin
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 16),

            // Kullanıcı bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (sessionId != null &&
                          sessionId.toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.link,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          sessionId.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Sil butonu
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Kullanıcıyı Sil',
              style: IconButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
