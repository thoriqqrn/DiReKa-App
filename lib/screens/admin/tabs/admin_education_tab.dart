import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../services/admin_service.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminEducationTab extends StatefulWidget {
  final AdminService adminService;
  const AdminEducationTab({super.key, required this.adminService});

  @override
  State<AdminEducationTab> createState() => _AdminEducationTabState();
}

class _AdminEducationTabState extends State<AdminEducationTab> {
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  List<EducationPost> _posts = [];
  
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _sourceUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _sourceUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await widget.adminService.getEducationPosts();
      if (!mounted) return;
      setState(() {
        _posts = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _upload() async {
    if (_titleCtrl.text.isEmpty || _contentCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan Konten wajib diisi.'))
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      await widget.adminService.uploadEducationPost(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        sourceUrl: _sourceUrlCtrl.text.trim(),
      );
      _titleCtrl.clear();
      _contentCtrl.clear();
      _sourceUrlCtrl.clear();
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _delete(EducationPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Konten'),
        content: Text('Hapus konten "${post.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.adminService.deleteEducationPost(post.id);
      _loadData();
    }
  }

  void _edit(EducationPost post) {
    final editTitleCtrl = TextEditingController(text: post.title);
    final editContentCtrl = TextEditingController(text: post.content);
    final editSourceUrlCtrl = TextEditingController(text: post.sourceUrl ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Edit Konten Edukasi'),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () async {
                    if (editTitleCtrl.text.isEmpty || editContentCtrl.text.isEmpty) return;
                    setLocal(() => isSaving = true);
                    try {
                      await widget.adminService.updateEducationPost(
                        postId: post.id,
                        title: editTitleCtrl.text.trim(),
                        content: editContentCtrl.text.trim(),
                        sourceUrl: editSourceUrlCtrl.text.trim(),
                      );
                      await _loadData();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                    } finally {
                      if (ctx.mounted) setLocal(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: editTitleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Edukasi', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: editContentCtrl,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Isi Konten', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: editSourceUrlCtrl,
                  decoration: const InputDecoration(labelText: 'Link Sumber (URL)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return AdminErrorView(message: _error!, onRetry: _loadData);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload Konten Edukasi', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Edukasi', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Isi Konten', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sourceUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Link Sumber (URL)', 
                    hintText: 'https://...',
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _upload,
                    icon: _isUploading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded),
                    label: Text(_isUploading ? 'Mengupload...' : 'Upload Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          const Text('Konten Terupload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          
          if (_posts.isEmpty)
            const AdminEmptyView(message: 'Belum ada konten edukasi.')
          else
            ..._posts.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(p.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(DateFormat('dd MMM yyyy').format(p.createdAt), 
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                      onPressed: () => _edit(p),
                      tooltip: 'Edit Konten',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                      onPressed: () => _delete(p),
                      tooltip: 'Hapus Konten',
                    ),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
