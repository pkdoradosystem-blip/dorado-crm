import '../core/network/api_client.dart';
import '../models/form_schema_model.dart';
import '../models/menu_item_model.dart';


// =========================================================
// MENU SERVICE
// =========================================================

class MenuService {
  final ApiClient api;

  MenuService(this.api);

  Future<List<MenuItemModel>> loadMenus() async {
    final data = await api.get('/api/v1/menus');

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => MenuItemModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}


// =========================================================
// FORM SERVICE
// =========================================================

class FormService {
  final ApiClient api;

  FormService(this.api);

  Future<FormSchema> loadForm(String code) async {
    final data = await api.get(
      '/api/v1/forms/$code',
    );

    return FormSchema.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<Map<String, dynamic>> submitForm(
    String endpoint,
    Map<String, dynamic> values,
  ) async {
    final data = await api.post(
      endpoint,
      values,
    );

    return Map<String, dynamic>.from(data);
  }
}


// =========================================================
// LEAD SERVICE
// =========================================================

class LeadService {
  final ApiClient api;

  LeadService(this.api);

  // -------------------------------------------------------
  // GET ALL LEADS
  // -------------------------------------------------------

  Future<List<Map<String, dynamic>>> load() async {
    final data = await api.get(
      '/api/v1/data/leads',
    );

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }


  // -------------------------------------------------------
  // GET SINGLE LEAD
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getLead(
    int leadId,
  ) async {
    final data = await api.get(
      '/api/v1/data/leads/$leadId',
    );

    return Map<String, dynamic>.from(data);
  }


  // -------------------------------------------------------
  // CREATE LEAD
  // -------------------------------------------------------

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> values,
  ) async {
    final data = await api.post(
      '/api/v1/data/leads',
      values,
    );

    return Map<String, dynamic>.from(data);
  }


  // -------------------------------------------------------
  // UPDATE LEAD
  // -------------------------------------------------------

  Future<Map<String, dynamic>> update(
    int leadId,
    Map<String, dynamic> values,
  ) async {
    final data = await api.put(
      '/api/v1/data/leads/$leadId',
      values,
    );

    return Map<String, dynamic>.from(data);
  }


  // -------------------------------------------------------
  // DELETE LEAD
  // -------------------------------------------------------

  Future<void> delete(
    int leadId,
  ) async {
    await api.delete(
      '/api/v1/data/leads/$leadId',
    );
  }


  // -------------------------------------------------------
  // FOLLOW-UP LEADS
  // -------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      loadFollowUps() async {
    final data = await api.get(
      '/api/v1/data/follow-ups',
    );

    if (data is! List) {
      return [];
    }

    return data
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }


  // -------------------------------------------------------
  // MARKETING REPORT
  // -------------------------------------------------------

  Future<Map<String, dynamic>>
      loadMarketingReport() async {
    final data = await api.get(
      '/api/v1/reports/marketing',
    );

    return Map<String, dynamic>.from(data);
  }
}