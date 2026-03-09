import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_app/app/backend/api/lifterlms_api.dart';

class CmeCreditsScreen extends StatefulWidget {
  const CmeCreditsScreen({Key? key}) : super(key: key);

  @override
  State<CmeCreditsScreen> createState() => _CmeCreditsScreenState();
}

class _CmeCreditsScreenState extends State<CmeCreditsScreen>
    with SingleTickerProviderStateMixin {
  final LifterLMSApiService api = Get.find<LifterLMSApiService>();
  late TabController _tabController;

  static const _creditTypes = {
    'ama_pra_1': 'AMA PRA Category 1',
    'ama_pra_2': 'AMA PRA Category 2',
    'ancc': 'ANCC Contact Hours',
    'acpe': 'ACPE Credits',
    'aafp': 'AAFP Prescribed Credits',
    'aapa': 'AAPA Category 1 CME',
    'moc': 'MOC Points',
    'ce': 'CE Credits',
    'ceu': 'CEU Credits',
    'custom': 'Custom Credits',
  };

  bool isLoading = true;
  Map<String, dynamic> summary = {};
  List<dynamic> credits = [];
  String? errorMessage;

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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final results = await Future.wait([
      api.getCmeSummary(),
      api.getCmeCredits(),
    ]);

    final summaryResponse = results[0];
    final creditsResponse = results[1];

    setState(() {
      isLoading = false;
      if (summaryResponse.statusCode == 200) {
        summary = summaryResponse.body is Map<String, dynamic>
            ? summaryResponse.body
            : {};
      }
      if (creditsResponse.statusCode == 200) {
        credits = creditsResponse.body is List ? creditsResponse.body : [];
      }
      if (summaryResponse.statusCode != 200 &&
          creditsResponse.statusCode != 200) {
        errorMessage = 'Failed to load CME data.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CME Credits'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Credit History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCreditDialog(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildSummaryTab() {
    final activeCredits = summary['active_credits'] as List? ?? [];
    final totalHours = (summary['total_active_hours'] ?? 0).toDouble();
    final expiredCredits =
        summary['expired_credits'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    totalHours.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Text(
                    'Total Active Credit Hours',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (activeCredits.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No CME credits earned yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete courses or add credits manually.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          ...activeCredits.map<Widget>((credit) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.verified, color: Colors.blue.shade700),
                ),
                title: Text(credit['credit_type_label'] ?? ''),
                subtitle:
                    Text('${credit['total_activities']} activities completed'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(credit['total_hours'] ?? 0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('hours',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }),

          if (expiredCredits.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Expired Credits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...expiredCredits.entries.map<Widget>((entry) {
              final label = _creditTypes[entry.key] ?? entry.key;
              return Card(
                color: Colors.grey.shade100,
                child: ListTile(
                  leading: const Icon(Icons.schedule, color: Colors.orange),
                  title: Text(label),
                  trailing: Text(
                    '${entry.value} hrs (expired)',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (credits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No credit history',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddCreditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Credit'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: credits.length,
        itemBuilder: (context, index) {
          final credit = credits[index];
          final status = credit['status'] ?? 'active';
          final isExpired = status == 'expired';
          final isManual = credit['source'] == 'manual';
          final title = isManual
              ? (credit['activity_title'] ?? 'Manual Entry')
              : (credit['course_title'] ?? 'Unknown Course');
          final provider = credit['provider'] ?? '';

          return Card(
            child: ListTile(
              leading: Icon(
                isManual
                    ? Icons.edit_note
                    : (isExpired ? Icons.schedule : Icons.check_circle),
                color: isManual
                    ? Colors.blue
                    : (isExpired ? Colors.orange : Colors.green),
              ),
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credit['credit_type_label'] ?? ''),
                  if (provider.isNotEmpty)
                    Text('Provider: $provider',
                        style: const TextStyle(fontSize: 12)),
                  Text(
                    'Earned: ${_formatDate(credit['earned_date'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (credit['expiration_date'] != null)
                    Text(
                      'Expires: ${_formatDate(credit['expiration_date'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? Colors.orange : Colors.grey,
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(credit['credit_hours'] ?? 0).toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.orange : Colors.black,
                    ),
                  ),
                  const Text('hrs',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              isThreeLine: true,
              onTap: isManual ? () => _showEditCreditDialog(credit) : null,
              onLongPress:
                  isManual ? () => _confirmDeleteCredit(credit) : null,
            ),
          );
        },
      ),
    );
  }

  void _showAddCreditDialog() {
    _showCreditForm(context);
  }

  void _showEditCreditDialog(Map<String, dynamic> credit) {
    _showCreditForm(context, existing: credit);
  }

  Future<void> _showCreditForm(BuildContext context,
      {Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleController =
        TextEditingController(text: existing?['activity_title'] ?? '');
    final hoursController = TextEditingController(
        text: existing != null
            ? (existing['credit_hours'] ?? 0).toString()
            : '');
    final providerController =
        TextEditingController(text: existing?['provider'] ?? '');

    String selectedType = existing?['credit_type'] ?? 'ama_pra_1';
    DateTime earnedDate = existing?['earned_date'] != null
        ? (DateTime.tryParse(existing!['earned_date']) ?? DateTime.now())
        : DateTime.now();
    DateTime? expirationDate = existing?['expiration_date'] != null
        ? DateTime.tryParse(existing!['expiration_date'])
        : null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEdit ? 'Edit CME Credit' : 'Add CME Credit',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Activity Title *',
                      hintText: 'e.g., Annual CME Conference 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: providerController,
                    decoration: const InputDecoration(
                      labelText: 'Provider / Organization',
                      hintText: 'e.g., AMA, Mayo Clinic',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Credit Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: _creditTypes.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hoursController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Credit Hours *',
                      hintText: 'e.g., 1.5',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date Earned *'),
                    subtitle: Text(_formatDate(earnedDate.toIso8601String())),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: earnedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => earnedDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiration Date (optional)'),
                    subtitle: Text(expirationDate != null
                        ? _formatDate(expirationDate!.toIso8601String())
                        : 'None'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (expirationDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setModalState(() => expirationDate = null);
                            },
                          ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: expirationDate ?? earnedDate.add(const Duration(days: 365)),
                        firstDate: earnedDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() => expirationDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final hoursText = hoursController.text.trim();

                      if (title.isEmpty) {
                        Get.snackbar('Required', 'Activity title is required.');
                        return;
                      }

                      final hours = double.tryParse(hoursText);
                      if (hours == null || hours <= 0) {
                        Get.snackbar('Required', 'Enter valid credit hours.');
                        return;
                      }

                      final dateStr =
                          '${earnedDate.year}-${earnedDate.month.toString().padLeft(2, '0')}-${earnedDate.day.toString().padLeft(2, '0')}';
                      String? expStr;
                      if (expirationDate != null) {
                        expStr =
                            '${expirationDate!.year}-${expirationDate!.month.toString().padLeft(2, '0')}-${expirationDate!.day.toString().padLeft(2, '0')}';
                      }

                      Response response;
                      if (isEdit) {
                        response = await api.updateManualCmeCredit(
                          creditId: existing['id'],
                          activityTitle: title,
                          creditType: selectedType,
                          creditHours: hours,
                          earnedDate: dateStr,
                          expirationDate: expStr ?? '',
                          provider: providerController.text.trim(),
                        );
                      } else {
                        response = await api.addManualCmeCredit(
                          activityTitle: title,
                          creditType: selectedType,
                          creditHours: hours,
                          earnedDate: dateStr,
                          expirationDate: expStr,
                          provider: providerController.text.trim(),
                        );
                      }

                      if (response.statusCode == 200) {
                        Navigator.pop(ctx, true);
                      } else {
                        final msg = response.body is Map
                            ? response.body['message']
                            : 'Failed to save';
                        Get.snackbar('Error', msg ?? 'Failed to save');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(isEdit ? 'Update Credit' : 'Add Credit',
                        style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _confirmDeleteCredit(Map<String, dynamic> credit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Credit?'),
        content: Text(
            'Delete "${credit['activity_title'] ?? 'this entry'}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response =
          await api.deleteManualCmeCredit(creditId: credit['id']);
      if (response.statusCode == 200) {
        Get.snackbar('Deleted', 'Credit entry removed.');
        _loadData();
      } else {
        Get.snackbar('Error', 'Failed to delete entry.');
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
