import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/seed_food_data.dart';
import '../../models/food_item.dart';
import '../../services/food_catalog_service.dart';
import '../../services/food_database_service.dart';

class AdminFoodCatalogScreen extends StatefulWidget {
  const AdminFoodCatalogScreen({super.key});

  @override
  State<AdminFoodCatalogScreen> createState() => _AdminFoodCatalogScreenState();
}

class _AdminFoodCatalogScreenState extends State<AdminFoodCatalogScreen> {
  static const List<String> _presetFoodCategories = [
    'Makanan pokok',
    'Kacang kacangan',
    'Sayuran',
    'Buah',
    'Daging dan olahan',
    'Seafood dan olahan',
    'Telur',
    'Susu dan olahan',
    'Minyak dan lemak',
    'Serba serbi',
    'Bumbu',
    'Olahan lain',
    'Cairan',
  ];
  static const String _otherCategoryOption = 'Lainnya';

  final FoodCatalogService _catalogService = FoodCatalogService();

  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _kategoriCtrl = TextEditingController();
  final TextEditingController _emojiCtrl = TextEditingController(text: '🍽️');
  final TextEditingController _satuanCtrl = TextEditingController();
  final TextEditingController _urtCtrl = TextEditingController();
  final TextEditingController _indeksGlikemikCtrl = TextEditingController();

  final TextEditingController _energiCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _lemakCtrl = TextEditingController();
  final TextEditingController _karboCtrl = TextEditingController();
  final TextEditingController _natriumCtrl = TextEditingController();
  final TextEditingController _kaliumCtrl = TextEditingController();
  final TextEditingController _fosforCtrl = TextEditingController();
  final TextEditingController _airCtrl = TextEditingController();
  final TextEditingController _seratCtrl = TextEditingController();

  final TextEditingController _searchCtrl = TextEditingController();

  final List<TextEditingController> _takaranLabelCtrls = [];
  final List<TextEditingController> _takaranGramCtrls = [];

  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'Semua';

  List<FoodItem> _foods = [];

  static final ButtonStyle _rowButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _namaCtrl.dispose();
    _kategoriCtrl.dispose();
    _emojiCtrl.dispose();
    _satuanCtrl.dispose();
    _urtCtrl.dispose();
    _indeksGlikemikCtrl.dispose();
    _energiCtrl.dispose();
    _proteinCtrl.dispose();
    _lemakCtrl.dispose();
    _karboCtrl.dispose();
    _natriumCtrl.dispose();
    _kaliumCtrl.dispose();
    _fosforCtrl.dispose();
    _airCtrl.dispose();
    _seratCtrl.dispose();
    _searchCtrl.dispose();
    _disposeTakaranControllers();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      FoodDatabaseService.clearCache();
      final allFoods = await FoodDatabaseService.getAll();
      if (!mounted) return;

      setState(() {
        _foods = allFoods
            .where((e) => e.id != FoodDatabaseService.waterItem.id)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat tabel makanan: $e';
        _isLoading = false;
      });
    }
  }

  List<FoodItem> get _filteredFoods {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _foods.where((item) {
      if (_selectedCategory != 'Semua' && item.kategori != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = '${item.nama} ${item.kategori} ${item.id}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<String> get _categoryOptions {
    final categories = _foods.map((e) => e.kategori).toSet().toList()..sort();
    return ['Semua', ...categories];
  }

  String _resolveFormCategoryValue(String value) {
    if (_presetFoodCategories.contains(value)) {
      return value;
    }
    return _otherCategoryOption;
  }

  Future<void> _startCreate() async {
    _clearForm();
    _idCtrl.text = _catalogService.createFoodId();
    await _openFoodForm();
  }

  Future<void> _startEdit(FoodItem item) async {
    _fillFormFromItem(item);
    await _openFoodForm(item: item);
  }

  void _clearForm() {
    _idCtrl.clear();
    _namaCtrl.clear();
    _kategoriCtrl.clear();
    _emojiCtrl.text = '🍽️';
    _satuanCtrl.clear();
    _urtCtrl.clear();
    _indeksGlikemikCtrl.clear();
    _energiCtrl.clear();
    _proteinCtrl.clear();
    _lemakCtrl.clear();
    _karboCtrl.clear();
    _natriumCtrl.clear();
    _kaliumCtrl.clear();
    _fosforCtrl.clear();
    _airCtrl.clear();
    _seratCtrl.clear();
    _setTakaranControllers(const []);
  }

  void _fillFormFromItem(FoodItem item) {
    _idCtrl.text = item.id;
    _namaCtrl.text = item.nama;
    _kategoriCtrl.text = item.kategori;
    _emojiCtrl.text = item.emoji;
    _satuanCtrl.text = item.satuanNama;
    _urtCtrl.text = item.urt;
    _indeksGlikemikCtrl.text = item.indeksGlikemik.toString();
    _energiCtrl.text = item.energi.toString();
    _proteinCtrl.text = item.protein.toString();
    _lemakCtrl.text = item.lemak.toString();
    _karboCtrl.text = item.karbohidrat.toString();
    _natriumCtrl.text = item.natrium.toString();
    _kaliumCtrl.text = item.kalium.toString();
    _fosforCtrl.text = item.fosfor.toString();
    _airCtrl.text = item.air.toString();
    _seratCtrl.text = item.serat.toString();
    _setTakaranControllers(item.takaranSaji);
  }

  String _resetFormForItem(FoodItem? item) {
    if (item == null) {
      _clearForm();
      _idCtrl.text = _catalogService.createFoodId();
      return _otherCategoryOption;
    }

    _fillFormFromItem(item);
    return _resolveFormCategoryValue(item.kategori);
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0.0;

  void _disposeTakaranControllers() {
    for (final ctrl in _takaranLabelCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _takaranGramCtrls) {
      ctrl.dispose();
    }
    _takaranLabelCtrls.clear();
    _takaranGramCtrls.clear();
  }

  void _addTakaranController({String label = '', String gram = ''}) {
    _takaranLabelCtrls.add(TextEditingController(text: label));
    _takaranGramCtrls.add(TextEditingController(text: gram));
  }

  void _setTakaranControllers(List<TakaranSaji> takaran) {
    _disposeTakaranControllers();
    if (takaran.isEmpty) {
      _addTakaranController();
      return;
    }

    for (final item in takaran) {
      _addTakaranController(label: item.label, gram: item.gram.toString());
    }
  }

  Future<void> _openFoodForm({FoodItem? item}) async {
    var isSaving = false;
    var selectedFormCategory = _resolveFormCategoryValue(
      _kategoriCtrl.text.trim(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item == null
                                    ? 'Tambah Makanan'
                                    : 'Edit Makanan',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final fieldWidth = constraints.maxWidth < 420
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 12) / 2;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        item == null
                                            ? 'ID dibuat otomatis saat makanan baru disimpan.'
                                            : 'ID makanan: ${item.id}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _numField(
                                          _namaCtrl,
                                          'Nama',
                                          width: fieldWidth,
                                          asText: true,
                                        ),
                                        SizedBox(
                                          width: fieldWidth,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: selectedFormCategory,
                                            items:
                                                [
                                                      ..._presetFoodCategories,
                                                      _otherCategoryOption,
                                                    ]
                                                    .map(
                                                      (category) =>
                                                          DropdownMenuItem(
                                                            value: category,
                                                            child: Text(
                                                              category,
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setModalState(() {
                                                selectedFormCategory = value;
                                                if (value !=
                                                    _otherCategoryOption) {
                                                  _kategoriCtrl.text = value;
                                                } else if (_presetFoodCategories
                                                    .contains(
                                                      _kategoriCtrl.text.trim(),
                                                    )) {
                                                  _kategoriCtrl.clear();
                                                }
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              labelText: 'Kategori',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        if (selectedFormCategory ==
                                            _otherCategoryOption)
                                          _numField(
                                            _kategoriCtrl,
                                            'Kategori lainnya',
                                            width: fieldWidth,
                                            asText: true,
                                          ),
                                        _numField(
                                          _emojiCtrl,
                                          'Emoji',
                                          width: fieldWidth,
                                          asText: true,
                                        ),
                                        _numField(
                                          _satuanCtrl,
                                          'Satuan Nama',
                                          width: fieldWidth,
                                          asText: true,
                                        ),
                                        _numField(
                                          _urtCtrl,
                                          'URT',
                                          width: fieldWidth,
                                          asText: true,
                                        ),
                                        _numField(
                                          _indeksGlikemikCtrl,
                                          'Indeks Glikemik',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _energiCtrl,
                                          'Energi',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _proteinCtrl,
                                          'Protein',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _lemakCtrl,
                                          'Lemak',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _karboCtrl,
                                          'Karbohidrat',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _natriumCtrl,
                                          'Natrium',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _kaliumCtrl,
                                          'Kalium',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _fosforCtrl,
                                          'Fosfor',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _airCtrl,
                                          'Air',
                                          width: fieldWidth,
                                        ),
                                        _numField(
                                          _seratCtrl,
                                          'Serat',
                                          width: fieldWidth,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Pilihan takaran saji',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: isSaving
                                              ? null
                                              : () => setModalState(() {
                                                  _addTakaranController(
                                                    label:
                                                        _satuanCtrl.text
                                                            .trim()
                                                            .isEmpty
                                                        ? ''
                                                        : _satuanCtrl.text
                                                              .trim(),
                                                  );
                                                }),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Tambah takaran'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(_takaranLabelCtrls.length, (
                                      index,
                                    ) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: TextField(
                                                controller:
                                                    _takaranLabelCtrls[index],
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Label takaran',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    _takaranGramCtrls[index],
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Gram',
                                                      suffixText: 'g',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: isSaving
                                                  ? null
                                                  : () => setModalState(() {
                                                      if (_takaranLabelCtrls
                                                              .length ==
                                                          1) {
                                                        _takaranLabelCtrls[index]
                                                            .clear();
                                                        _takaranGramCtrls[index]
                                                            .clear();
                                                        return;
                                                      }
                                                      _takaranLabelCtrls[index]
                                                          .dispose();
                                                      _takaranGramCtrls[index]
                                                          .dispose();
                                                      _takaranLabelCtrls
                                                          .removeAt(index);
                                                      _takaranGramCtrls
                                                          .removeAt(index);
                                                    }),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 16),
                                    LayoutBuilder(
                                      builder: (context, buttonConstraints) {
                                        if (buttonConstraints.maxWidth < 360) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: isSaving
                                                    ? null
                                                    : () => _submitFoodForm(
                                                        existingItem: item,
                                                        setModalState:
                                                            setModalState,
                                                        onSavingChanged:
                                                            (value) {
                                                              isSaving = value;
                                                            },
                                                      ),
                                                icon: isSaving
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.save_outlined,
                                                      ),
                                                label: Text(
                                                  item == null
                                                      ? 'Simpan Makanan'
                                                      : 'Simpan Perubahan',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              OutlinedButton(
                                                onPressed: isSaving
                                                    ? null
                                                    : () => setModalState(() {
                                                        selectedFormCategory =
                                                            _resetFormForItem(
                                                              item,
                                                            );
                                                      }),
                                                child: const Text('Reset Form'),
                                              ),
                                            ],
                                          );
                                        }

                                        return Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: isSaving
                                                    ? null
                                                    : () => _submitFoodForm(
                                                        existingItem: item,
                                                        setModalState:
                                                            setModalState,
                                                        onSavingChanged:
                                                            (value) {
                                                              isSaving = value;
                                                            },
                                                      ),
                                                icon: isSaving
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.save_outlined,
                                                      ),
                                                label: Text(
                                                  item == null
                                                      ? 'Simpan Makanan'
                                                      : 'Simpan Perubahan',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: isSaving
                                                    ? null
                                                    : () => setModalState(() {
                                                        selectedFormCategory =
                                                            _resetFormForItem(
                                                              item,
                                                            );
                                                      }),
                                                child: const Text('Reset Form'),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitFoodForm({
    required FoodItem? existingItem,
    required StateSetter setModalState,
    required ValueChanged<bool> onSavingChanged,
  }) async {
    if (_namaCtrl.text.trim().isEmpty ||
        _kategoriCtrl.text.trim().isEmpty ||
        _satuanCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama, kategori, dan satuan wajib diisi.'),
        ),
      );
      return;
    }

    setModalState(() => onSavingChanged(true));

    final foodId = existingItem?.id ?? _idCtrl.text.trim();

    final satuanNama = _satuanCtrl.text.trim();
    final takaran = <TakaranSaji>[];
    for (var i = 0; i < _takaranLabelCtrls.length; i++) {
      final label = _takaranLabelCtrls[i].text.trim();
      final gram = _num(_takaranGramCtrls[i]);
      if (label.isEmpty || gram <= 0) continue;
      takaran.add(
        TakaranSaji(ukuran: 'opsi_${i + 1}', label: label, gram: gram),
      );
    }

    final food = FoodItem(
      id: foodId,
      nama: _namaCtrl.text.trim(),
      kategori: _kategoriCtrl.text.trim(),
      urt: _urtCtrl.text.trim(),
      indeksGlikemik: _num(_indeksGlikemikCtrl),
      emoji: _emojiCtrl.text.trim().isEmpty ? '🍽️' : _emojiCtrl.text.trim(),
      satuanNama: satuanNama,
      energi: _num(_energiCtrl),
      protein: _num(_proteinCtrl),
      lemak: _num(_lemakCtrl),
      karbohidrat: _num(_karboCtrl),
      natrium: _num(_natriumCtrl),
      kalium: _num(_kaliumCtrl),
      fosfor: _num(_fosforCtrl),
      air: _num(_airCtrl),
      serat: _num(_seratCtrl),
      takaranSaji: takaran,
    );

    try {
      await _catalogService.upsertFood(
        food,
        markAsCustom: existingItem == null,
      );
      FoodDatabaseService.clearCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingItem == null
                ? 'Makanan berhasil ditambahkan.'
                : 'Makanan berhasil diperbarui.',
          ),
        ),
      );
      _clearForm();
      Navigator.of(context).pop();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan makanan: $e')));
    } finally {
      if (mounted) {
        setModalState(() => onSavingChanged(false));
      }
    }
  }

  Future<void> _delete(FoodItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus makanan'),
        content: Text('Yakin hapus "${item.nama}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await _catalogService.deleteFood(item.id);
      FoodDatabaseService.clearCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Makanan berhasil dihapus.')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  Future<void> _seedAllFoods() async {
    final existingIds = _foods.map((e) => e.id).toSet();
    final newItems =
        seedFoodItems.where((e) => !existingIds.contains(e.id)).toList();

    if (newItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua data seed sudah ada di database.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Data Makanan'),
        content: Text(
          'Akan menambahkan ${newItems.length} makanan baru dari data seed '
          '(${seedFoodItems.length} total, ${seedFoodItems.length - newItems.length} sudah ada).\n\n'
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Semua'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _catalogService.bulkUpsertFoods(newItems);
      FoodDatabaseService.clearCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newItems.length} makanan berhasil ditambahkan!'),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal seed data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFoods = _filteredFoods;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        title: const Text('Tabel Makanan (CRUD)'),
        backgroundColor: const Color(0xFFF2F5F9),
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final toolbarWidth = constraints.maxWidth;
                          final searchWidth = toolbarWidth < 360
                              ? toolbarWidth
                              : 320.0;
                          final filterWidth = toolbarWidth < 360
                              ? toolbarWidth
                              : 220.0;

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: searchWidth,
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Cari makanan',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  items: _categoryOptions
                                      .map(
                                        (category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(category),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _selectedCategory = value);
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Filter kategori',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _startCreate,
                                style: _rowButtonStyle,
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Baru'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _seedAllFoods,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Seed Data TKPI'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      if (filteredFoods.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            _searchCtrl.text.trim().isEmpty &&
                                    _selectedCategory == 'Semua'
                                ? 'Belum ada data makanan untuk ditampilkan.'
                                : 'Tidak ada makanan yang cocok dengan pencarian.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        Theme(
                          data: Theme.of(context).copyWith(
                            dataTableTheme: const DataTableThemeData(
                              headingTextStyle: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              dataTextStyle: TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 12,
                              columns: const [
                                DataColumn(label: Text('Kategori')),
                                DataColumn(label: Text('Nama')),
                                DataColumn(label: Text('Satuan')),
                                DataColumn(label: Text('URT')),
                                DataColumn(label: Text('IG')),
                                DataColumn(label: Text('Energi')),
                                DataColumn(label: Text('Protein')),
                                DataColumn(label: Text('Lemak')),
                                DataColumn(label: Text('Karbo')),
                                DataColumn(label: Text('Aksi')),
                              ],
                              rows: filteredFoods.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item.kategori)),
                                    DataCell(
                                      Row(
                                        children: [
                                          Text(item.emoji),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              item.nama,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(item.satuanNama)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          item.urt.isEmpty ? '-' : item.urt,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item.indeksGlikemik.toStringAsFixed(0),
                                      ),
                                    ),
                                    DataCell(
                                      Text(item.energi.toStringAsFixed(1)),
                                    ),
                                    DataCell(
                                      Text(item.protein.toStringAsFixed(1)),
                                    ),
                                    DataCell(
                                      Text(item.lemak.toStringAsFixed(1)),
                                    ),
                                    DataCell(
                                      Text(item.karbohidrat.toStringAsFixed(1)),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () => _startEdit(item),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _delete(item),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _numField(
    TextEditingController ctrl,
    String label, {
    double width = 120,
    bool asText = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        keyboardType: asText
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
