import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../services/admin_service.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  String? _error;
  List<EducationPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final posts = await _adminService.getEducationPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final isPermissionDenied =
          e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED';
      setState(() {
        _error = isPermissionDenied
            ? 'Konten edukasi belum bisa diakses pada mode guest. Silakan login untuk membuka materi edukasi.'
            : 'Gagal memuat edukasi: ${e.message ?? e.code}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat edukasi: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edukasi Kesehatan'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadPosts)
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: _posts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 160),
                            _EmptyView(),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 2 : 1,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: isWide ? 1.5 : 1.2,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            return _EducationPostCard(
                              post: post,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _EducationDetailPage(post: post),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class _EducationPostCard extends StatelessWidget {
  final EducationPost post;
  final VoidCallback onTap;

  const _EducationPostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = _resolvePreview(post.sourceUrl, post.previewType);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: preview != null && (preview.type == 'image' || preview.thumbnailUrl != null)
                      ? Image.network(
                          preview.thumbnailUrl ?? preview.url,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _previewFallbackBox(preview.type),
                        )
                      : _previewFallbackBox(preview?.type),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('dd MMM yyyy', 'id_ID').format(post.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewFallbackBox(String? type) {
    final icon = switch (type) {
      'pdf' => Icons.picture_as_pdf,
      'link' => Icons.link,
      _ => Icons.menu_book_outlined,
    };
    return Container(
      color: const Color(0xFFF0F4FA),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary, size: 36),
    );
  }
}

class _EducationDetailPage extends StatelessWidget {
  final EducationPost post;

  const _EducationDetailPage({required this.post});

  @override
  Widget build(BuildContext context) {
    final preview = _resolvePreview(post.sourceUrl, post.previewType);
    final controller = _buildReadOnlyController(post);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Edukasi'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            post.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd MMMM yyyy', 'id_ID').format(post.createdAt),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (preview != null)
            _OpenablePreview(preview: preview)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: quill.QuillEditor.basic(
              controller: controller,
              config: const quill.QuillEditorConfig(
                showCursor: false,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  quill.QuillController _buildReadOnlyController(EducationPost post) {
    if (post.contentDelta != null) {
      try {
        final parsed = jsonDecode(post.contentDelta!);
        final document = quill.Document.fromJson(parsed as List<dynamic>);
        return quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {
        // Fallback below.
      }
    }

    final doc = quill.Document()..insert(0, post.content);
    return quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }
}

class _PreviewInfo {
  final String type;
  final String url;
  final String? thumbnailUrl;

  const _PreviewInfo({required this.type, required this.url, this.thumbnailUrl});
}

class _OpenablePreview extends StatelessWidget {
  final _PreviewInfo preview;

  const _OpenablePreview({required this.preview});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPreviewUrl(preview.url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview.type == 'image' || preview.thumbnailUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  preview.thumbnailUrl ?? preview.url,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fileLikePreview(),
                ),
              )
            else
              _fileLikePreview(),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview.type == 'pdf'
                          ? 'Tap untuk buka preview PDF'
                          : preview.type == 'link'
                              ? 'Tap untuk buka sumber link'
                              : 'Tap untuk buka preview media',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileLikePreview() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F4FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Icon(
        preview.type == 'pdf' ? Icons.picture_as_pdf : Icons.image_outlined,
        color: AppColors.primary,
        size: 42,
      ),
    );
  }
}

bool _looksLikeImageUrl(String value) {
  final lower = value.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.contains('.jpg?') ||
      lower.contains('.jpeg?') ||
      lower.contains('.png?') ||
      lower.contains('.gif?') ||
      lower.contains('.webp?');
}

bool _looksLikePdfUrl(String value) {
  final lower = value.toLowerCase();
  return lower.endsWith('.pdf') || lower.contains('.pdf?');
}

String _inferPreviewType(String rawUrl, String previewType) {
  if (previewType != 'auto') return previewType;
  if (_looksLikePdfUrl(rawUrl)) return 'pdf';
  if (_looksLikeImageUrl(rawUrl)) return 'image';
  return 'link';
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.menu_book,
            color: Colors.teal.withValues(alpha: 0.75),
            size: 56,
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada konten edukasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

_PreviewInfo? _resolvePreview(String? sourceUrl, String previewType) {
  final raw = sourceUrl?.trim();
  if (raw == null || raw.isEmpty) return null;

  final gdriveId = _extractGoogleDriveFileId(raw);
  final effectiveType = _inferPreviewType(raw, previewType);

  if (gdriveId != null) {
    final thumbnailUrl = 'https://drive.google.com/thumbnail?id=$gdriveId&sz=w1600';
    if (effectiveType == 'pdf') {
      return _PreviewInfo(
        type: 'pdf',
        url: 'https://drive.google.com/file/d/$gdriveId/preview',
        thumbnailUrl: thumbnailUrl,
      );
    }
    if (effectiveType == 'image') {
      return _PreviewInfo(
        type: 'image',
        url: thumbnailUrl,
      );
    }
    return _PreviewInfo(type: 'link', url: raw, thumbnailUrl: thumbnailUrl);
  }

  return _PreviewInfo(type: effectiveType, url: raw);
}

Future<void> _openPreviewUrl(String url) async {
  if (kIsWeb) {
    html.window.open(url, '_blank');
    return;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String? _extractGoogleDriveFileId(String url) {
  final filePattern = RegExp(r'/file/d/([^/]+)');
  final fileMatch = filePattern.firstMatch(url);
  if (fileMatch != null) {
    return fileMatch.group(1);
  }

  final idPattern = RegExp(r'[?&]id=([^&]+)');
  final idMatch = idPattern.firstMatch(url);
  if (idMatch != null) {
    return idMatch.group(1);
  }

  return null;
}
