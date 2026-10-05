import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import 'create_quotation_page.dart';

class QuotationListPage extends StatefulWidget {
  const QuotationListPage({super.key});

  @override
  State<QuotationListPage> createState() => _QuotationListPageState();
}

class _QuotationListPageState extends State<QuotationListPage> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  String? _error;
  List<dynamic> _quotations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.get(
        '/api/v1/quotations',
      );

      List<dynamic> rows = [];

      if (response is List) {
        rows = response;
      } else if (response is Map) {
        final data =
            response['items'] ?? response['quotations'] ?? response['data'];

        if (data is List) {
          rows = data;
        }
      }

      if (!mounted) return;

      setState(() {
        _quotations = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createQuotation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateQuotationPage(),
      ),
    );

    if (!mounted) return;

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Quotation'),
        backgroundColor: const Color(0xFF0B5C9E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createQuotation,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Quotation',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 46,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load quotations',
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_quotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.request_quote_outlined,
              size: 64,
              color: Color(0xFF0B5C9E),
            ),
            const SizedBox(height: 14),
            const Text(
              'No quotations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create the first quotation.',
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _createQuotation,
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Quotation',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _quotations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final q = _quotations[index];

          final number = '${q['quotation_no'] ?? '-'}';

          final customer = '${q['customer_name'] ?? '-'}';

          final type = '${q['quotation_type'] ?? ''}';

          final total = q['grand_total'];

          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(
                  Icons.request_quote,
                ),
              ),
              title: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                [
                  customer,
                  if (type.isNotEmpty) type,
                  if (total != null) '₹$total',
                ].join(' • '),
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
            ),
          );
        },
      ),
    );
  }
}
