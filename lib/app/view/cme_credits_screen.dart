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
          // Total credits card
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
                      'Complete courses with CME credits to see them here.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Credits by type
          ...activeCredits.map<Widget>((credit) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child:
                      Icon(Icons.verified, color: Colors.blue.shade700),
                ),
                title: Text(credit['credit_type_label'] ?? ''),
                subtitle: Text(
                    '${credit['total_activities']} activities completed'),
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

          // Expired credits section
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
              final label = _creditTypeLabel(entry.key);
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No credit history',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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

          return Card(
            child: ListTile(
              leading: Icon(
                isExpired ? Icons.schedule : Icons.check_circle,
                color: isExpired ? Colors.orange : Colors.green,
              ),
              title: Text(credit['course_title'] ?? 'Unknown Course'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credit['credit_type_label'] ?? ''),
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
            ),
          );
        },
      ),
    );
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

  String _creditTypeLabel(String type) {
    const labels = {
      'ama_pra_1': 'AMA PRA Category 1',
      'ama_pra_2': 'AMA PRA Category 2',
      'ancc': 'ANCC Contact Hours',
      'acpe': 'ACPE Credits',
      'aafp': 'AAFP Prescribed Credits',
      'aapa': 'AAPA Category 1 CME',
      'moc': 'MOC Points',
      'ce': 'CE Credits',
      'ceu': 'CEU Credits',
    };
    return labels[type] ?? type;
  }
}
