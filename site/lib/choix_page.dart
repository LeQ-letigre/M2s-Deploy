// lib/choix_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'config.dart';
import 'theme_tiger.dart';
import 'confirmation_page.dart';
import 'main.dart'; // accès au themeNotifier global

/// 💻 Classe Machine : représente chaque machine venant de PocketBase
class Machine {
  final String id;
  final String nom;
  final String type;
  final String desc;
  final Map<String, dynamic> fields;

  Machine({
    required this.id,
    required this.nom,
    required this.type,
    required this.desc,
    required this.fields,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    final known = {
      "id",
      "Nom",
      "Type",
      "desc",
      "collectionId",
      "collectionName",
      "created",
      "updated",
    };
    final extra = <String, dynamic>{};
    for (final e in json.entries) {
      if (!known.contains(e.key)) extra[e.key] = e.value;
    }
    return Machine(
      id: json["id"],
      nom: json["Nom"] ?? "Inconnu",
      type: json["Type"]?.toString() ?? "",
      desc: json["desc"]?.toString() ?? "",
      fields: extra,
    );
  }
}

/// 🐯 Page principale TIGRES (sélection machines + génération conf)
class ChoixPage extends StatefulWidget {
  final bool teransible;
  const ChoixPage({super.key, required this.teransible});

  @override
  State<ChoixPage> createState() => _ChoixPageState();
}

class _ChoixPageState extends State<ChoixPage> {
  int _selectedIndex = 0;
  final Set<String> _checked = {};
  late Future<List<Machine>> _machines;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errors = {}; // erreurs par champ
  final TextEditingController _globalPassword = TextEditingController();

  bool _teransible = false;
  bool _teransibleSetupRequired = false;
  final TextEditingController _terrId = TextEditingController();
  final TextEditingController _terrPwd = TextEditingController();
  final TextEditingController _terrIpCidr = TextEditingController();
  final TextEditingController _terrGw = TextEditingController();
  final TextEditingController _terrDns = TextEditingController();
  final TextEditingController _terrBridge = TextEditingController(
    text: "vmbr0",
  );

  bool _windowsTemplateNeeded = false;
  bool _showPassword = false;

  // ---------- Helpers de validation ----------
  final RegExp _reIp = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$',
  );
  final RegExp _reIpCidr = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)/(?:[0-9]|[1-2][0-9]|3[0-2])$',
  );
  final RegExp _reDigits = RegExp(r'^\d+$');

  bool _isValidIp(String v) => _reIp.hasMatch(v.trim());
  bool _isValidIpCidr(String v) => _reIpCidr.hasMatch(v.trim());
  bool _isDigits(String v) => _reDigits.hasMatch(v.trim());

  // ----------

  @override
  void initState() {
    super.initState();
    _teransible = widget.teransible;
    _machines = _fetchMachines();
  }

  void _toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<List<Machine>> _fetchMachines() async {
    final url = Uri.parse(
      "${AppConfig.pocketBaseUrl}/api/collections/machine/records",
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("Erreur PocketBase: ${res.body}");
    }
    final items = (jsonDecode(res.body)["items"] as List)
        .map((e) => Machine.fromJson(e))
        .toList();
    return items;
  }

  String _key(String id, String field) => "$id::$field";
  TextEditingController _ctrl(String id, String field, String init) =>
      _controllers.putIfAbsent(
        _key(id, field),
        () => TextEditingController(text: init),
      );
  String _val(String id, String field, String fallback) {
    final k = _key(id, field);
    final c = _controllers[k];
    if (c == null) return fallback;
    return c.text.isNotEmpty ? c.text : fallback;
  }

  int _countBits(int x) {
    var v = x;
    var c = 0;
    while (v > 0) {
      c += v & 1;
      v >>= 1;
    }
    return c;
  }

  int _maskToPrefix(String mask) {
    try {
      final parts = mask.split('.').map(int.parse).toList();
      if (parts.length != 4) return 24;
      return parts.map(_countBits).reduce((a, b) => a + b);
    } catch (_) {
      return 24;
    }
  }

  String _ipWithCidrDefault(Machine m) {
    final ip = (m.fields["ip"]?.toString() ?? "").trim();
    final masque = (m.fields["masque"]?.toString() ?? "").trim();
    if (ip.isEmpty) return "";
    if (ip.contains('/')) return ip;
    if (masque.isEmpty) return ip;
    return "$ip/${_maskToPrefix(masque)}";
  }

  String _ostypeOf(Machine m) {
    final n = m.nom.toLowerCase();
    // Windows côté UI
    if (n.contains("windows") || n.contains("active directory"))
      return "windows";
    // Linux et services Linux
    if (n.contains("glpi") ||
        n.contains("adguard") ||
        n.contains("uptime kuma")) {
      return "linux";
    }
    return "linux";
  }

  String _serviceOf(Machine m) {
    final n = m.nom.toLowerCase();
    if (n.contains("réplication active directory") ||
        n.contains("replication active directory")) {
      return "replicationad";
    }
    if (n.contains("active directory")) {
      return "promotionad";
    }
    if (n.contains("glpi")) return "glpi";
    if (n.contains("adguard")) return "adguard";
    if (n.contains("uptime kuma")) return "uptimekuma";
    if (n.contains("windows") || n.contains("linux")) return "vm";
    final simplified = n
        .replaceAll(RegExp(r"[àáâãä]"), "a")
        .replaceAll(RegExp(r"[èéêë]"), "e")
        .replaceAll(RegExp(r"[ìíîï]"), "i")
        .replaceAll(RegExp(r"[òóôõö]"), "o")
        .replaceAll(RegExp(r"[ùúûü]"), "u")
        .replaceAll(RegExp(r"[ç]"), "c")
        .replaceAll(RegExp(r"[^a-z0-9]"), "");
    return simplified.isEmpty ? "vm" : simplified;
  }

  Map<String, dynamic> _merged(Machine m) {
    final d = Map<String, dynamic>.from(m.fields);
    String v(String f, [String fb = ""]) =>
        _val(m.id, f, (d[f]?.toString() ?? fb));
    final ipCidr = v("ip", _ipWithCidrDefault(m));
    return {
      "id_pb": m.id,
      "name": m.nom,
      "type": m.type,
      "custom_id": v("custom_id"),
      "ip_cidr": ipCidr,
      "gateway": v("gw"),
      "dns": v("dns"),
      "bridge": v("network_bridge", "vmbr0"),
      "cores": v("cores", d["coeurs"]?.toString() ?? ""),
      "ram": v("ram"),
      "capacite": v("capacite"),
      "ostype": _ostypeOf(m),
      "service": _serviceOf(m),
      "password": _globalPassword.text,
    };
  }

  bool _canGenerate() => _checked.isNotEmpty && _globalPassword.text.isNotEmpty;

  bool _validateSelected(List<Machine> selected) {
    for (final m in selected) {
      final d = _merged(m);
      final idStr = (d["custom_id"] ?? "").toString().trim();
      final ip = (d["ip_cidr"] ?? "").toString().trim();
      final gw = (d["gateway"] ?? "").toString().trim();
      final dns = (d["dns"] ?? "").toString().trim();

      if (!_isDigits(idStr)) return false;
      if (!_isValidIpCidr(ip)) return false;
      if (!_isValidIp(gw)) return false;
      if (!_isValidIp(dns)) return false;
    }
    return true;
  }

  Future<String> _buildTfvars(List<Machine> selected) async {
    final buf = StringBuffer();
    buf.writeln("# TIGRES conf confs.auto.tfvars");
    buf.writeln('terransible = ${_teransible ? "true" : "false"}');
    buf.writeln('mot_de_passe_global = "${_globalPassword.text}"');

    if (_teransibleSetupRequired) {
      buf.writeln("terransible_setup = {");
      buf.writeln('  id = "${_terrId.text.trim()}"');
      buf.writeln('  password = "${_terrPwd.text.trim()}"');
      buf.writeln('  ip_cidr = "${_terrIpCidr.text.trim()}"');
      buf.writeln('  gateway = "${_terrGw.text.trim()}"');
      buf.writeln('  dns = "${_terrDns.text.trim()}"');
      buf.writeln(
        '  bridge = "${_terrBridge.text.trim().isEmpty ? "vmbr0" : _terrBridge.text.trim()}"',
      );
      buf.writeln("}\\n");
    }

    buf.writeln(
      "windows_template_needed = ${_windowsTemplateNeeded ? "true" : "false"}\\n",
    );

    buf.writeln("vms = {");
    for (final m in selected) {
      final d = _merged(m);
      buf.writeln('  "${m.nom}" = {');
      buf.writeln('    lxc_id = ${d["custom_id"]}');
      buf.writeln('    name = "${d["name"]}"');
      buf.writeln('    ostype = "${d["ostype"]}"');
      buf.writeln('    service = "${d["service"]}"');
      buf.writeln('    ip_cidr = "${d["ip_cidr"]}"');
      buf.writeln('    gateway = "${d["gateway"]}"');
      buf.writeln('    dns = "${d["dns"]}"');
      buf.writeln('    bridge = "${d["bridge"]}"');
      if ((d["cores"] ?? "").toString().isNotEmpty) {
        buf.writeln('    cores = "${d["cores"]}"');
      }
      if ((d["ram"] ?? "").toString().isNotEmpty) {
        buf.writeln('    ram = "${d["ram"]}"');
      }
      if ((d["capacite"] ?? "").toString().isNotEmpty) {
        buf.writeln('    capacite = "${d["capacite"]}"');
      }
      buf.writeln('    password = "${_globalPassword.text}"');
      buf.writeln("  }");
    }
    buf.writeln("}\\n");
    return buf.toString();
  }

  Future<File> _writeTempTfvars(List<Machine> selected) async {
    final content = await _buildTfvars(selected);
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/confs.auto.tfvars");
    await file.writeAsString(content);
    return file;
  }

  Future<String> _uploadToPB(File file, List<Machine> selected) async {
    final url = Uri.parse(
      "${AppConfig.pocketBaseUrl}/api/collections/conf/records",
    );
    final req = http.MultipartRequest("POST", url)
      ..fields["teransible"] = _teransible.toString()
      ..fields["querry"] = jsonEncode({
        for (final m in selected) m.nom: _merged(m),
        "_meta": {
          "terransible_setup_required": _teransibleSetupRequired,
          "windows_template_needed": _windowsTemplateNeeded,
        },
      })
      ..files.add(await http.MultipartFile.fromPath("file", file.path));
    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    final rec = jsonDecode(body);
    return "${AppConfig.pocketBaseUrl}/api/files/${rec["collectionName"]}/${rec["id"]}/${rec["file"]}";
  }

  void _onGenerate(List<Machine> all) async {
    final selected = all.where((m) => _checked.contains(m.id)).toList();
    if (!_canGenerate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Sélectionne une machine + mot de passe."),
        ),
      );
      return;
    }
    if (!_validateSelected(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ ID numérique, IP/CIDR, passerelle et DNS valides requis.",
          ),
        ),
      );
      return;
    }

    final file = await _writeTempTfvars(selected);
    final url = await _uploadToPB(file, selected);
    final first = _merged(selected.first);
    final curl =
        "curl -k https://m2shelper.boisloret.fr/script/testdeploy | bash -s -- "
        "${_teransible ? 1 : 0} ${first["custom_id"]} ${_globalPassword.text} ip gw dns vmbr0 0 0 $url";
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationPage(
          fileUrl: url,
          curl: curl,
          querry: {for (final m in selected) m.nom: _merged(m)},
          teransible: _teransible,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: Tiger.tigerBackground(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: isDark
              ? Colors.black.withValues(alpha: .7)
              : Colors.orange.shade50.withValues(alpha: .8),
          title: const Text("🐅 TIGRES • Configurations"),
          actions: [
            IconButton(
              onPressed: _toggleTheme,
              icon: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: isDark ? Colors.orangeAccent : Colors.deepOrange,
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<Machine>>(
          future: _machines,
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orangeAccent),
              );
            }
            if (s.hasError) {
              return Center(child: Text("Erreur: ${s.error}"));
            }
            final machines = s.data ?? [];
            if (machines.isEmpty) {
              return const Center(child: Text("Aucune machine trouvée"));
            }
            _selectedIndex = _selectedIndex.clamp(0, machines.length - 1);
            final current = machines[_selectedIndex];
            return Row(
              children: [
                _buildSidebar(context, machines, isDark),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141414).withValues(alpha: .95)
                            : Colors.white.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.black.withValues(alpha: .4)
                              : Colors.orange.withValues(alpha: .3),
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: _buildMachineForm(current, isDark),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ——— BARRE LATÉRALE ———
  Widget _buildSidebar(
    BuildContext context,
    List<Machine> machines,
    bool isDark,
  ) {
    // Regroupements imposés
    bool isLinux(Machine m) {
      final n = m.nom.toLowerCase();
      return !(n.contains("windows") || n.contains("active directory"));
    }

    final linuxList = machines.where(isLinux).toList(growable: false);
    final windowsList = machines
        .where((m) => !isLinux(m))
        .toList(growable: false);

    Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );

    Widget itemTile(Machine mm) {
      final idx = machines.indexOf(mm);
      final selected = idx == _selectedIndex;
      final checked = _checked.contains(mm.id);
      final idOk = _isDigits(_val(mm.id, "custom_id", ""));
      return ListTile(
        dense: true,
        tileColor: selected
            ? Colors.orangeAccent.withValues(alpha: 0.08)
            : Colors.transparent,
        leading: Checkbox(
          value: checked,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _checked.add(mm.id);
                _selectedIndex = idx; // Aller sur la page de la VM
              } else {
                _checked.remove(mm.id);
              }
            });
          },
          activeColor: Colors.orangeAccent,
        ),
        title: Text(
          mm.nom,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Icon(
          idOk ? Icons.check_circle : Icons.error_outline,
          color: idOk ? Colors.green : Colors.redAccent,
        ),
        onTap: () => setState(() => _selectedIndex = idx),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(12),
      width: 320,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141414).withValues(alpha: .95)
            : Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.black.withValues(alpha: .5)
              : Colors.orange.withValues(alpha: .3),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _globalPassword,
            obscureText: !_showPassword,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: "Mot de passe global 🔒",
              labelStyle: const TextStyle(color: Colors.orangeAccent),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.orangeAccent,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
              filled: true,
              fillColor: isDark ? Colors.black : Colors.orange.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Requirement bloc
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: .5)
                  : Colors.orange.shade50.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white24
                    : Colors.orange.withValues(alpha: .4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Requirement",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const Divider(height: 14),
                const Text(
                  "L’installation des VM nécessite une VM “terransible”, faut-il l’installer ?",
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _teransible = true;
                            _teransibleSetupRequired = true;
                          });
                        },
                        style: Tiger.tigerButton(),
                        child: const Text("Oui mon tigre"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _teransible = true;
                            _teransibleSetupRequired = false;
                          });
                        },
                        child: const Text("Non, je l’ai déjà"),
                      ),
                    ),
                  ],
                ),
                if (_teransibleSetupRequired) ...[
                  const SizedBox(height: 10),
                  _miniField(_terrId, "Id de la VM terransible"),
                  _miniField(_terrPwd, "Mot de passe du LXC"),
                  _miniField(
                    _terrIpCidr,
                    'IP de la VM (ex: 1.2.3.4/24)',
                    validator: _isValidIpCidr,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _miniField(
                          _terrGw,
                          "Passerelle",
                          validator: _isValidIp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniField(
                          _terrDns,
                          "DNS",
                          validator: _isValidIp,
                        ),
                      ),
                    ],
                  ),
                  _miniField(_terrBridge, "Bridge réseau (vmbr0 par défaut)"),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                sectionTitle("Linuxs"),
                for (final m in linuxList) itemTile(m),
                sectionTitle("Windows"),
                for (final m in windowsList) itemTile(m),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _canGenerate() ? () => _onGenerate(machines) : null,
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Générer & envoyer"),
            style: Tiger.tigerButton(),
          ),
        ],
      ),
    );
  }

  Widget _miniField(
    TextEditingController c,
    String label, {
    bool Function(String)? validator,
  }) {
    String? err;
    if (validator != null && c.text.isNotEmpty && !validator(c.text)) {
      err = "Format invalide";
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          errorText:
              (validator != null && c.text.isNotEmpty && !validator(c.text))
              ? err
              : null,
          labelStyle: const TextStyle(color: Colors.orangeAccent),
          filled: true,
          fillColor: Colors.black.withValues(alpha: .06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Colors.orangeAccent, width: 1.4),
          ),
        ),
      ),
    );
  }

  // ——— FORMULAIRE MACHINE ———
  Widget _buildMachineForm(Machine m, bool isDark) {
    final isWindows = _ostypeOf(m) == "windows";
    final isWindowsServer =
        isWindows && (m.nom.toLowerCase().contains("serveur"));
    final defIp = _ipWithCidrDefault(m);
    final defBridge = m.fields["network_bridge"]?.toString() ?? "vmbr0";
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Text(
                m.nom,
                style: TextStyle(
                  fontSize: 22,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _field(
            m,
            "custom_id",
            m.fields["custom_id"]?.toString() ?? "",
            isDark: isDark,
            validator: _isDigits,
            hint: "ID numérique uniquement",
          ),
          _field(
            m,
            "ip",
            defIp,
            isDark: isDark,
            validator: _isValidIpCidr,
            hint: "Ex: 192.168.1.10/24",
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  m,
                  "gw",
                  m.fields["gw"]?.toString() ?? "",
                  isDark: isDark,
                  validator: _isValidIp,
                  hint: "Passerelle IPv4",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  m,
                  "dns",
                  m.fields["dns"]?.toString() ?? "",
                  isDark: isDark,
                  validator: _isValidIp,
                  hint: "DNS IPv4",
                ),
              ),
            ],
          ),
          _field(m, "network_bridge", defBridge, isDark: isDark),
          Row(
            children: [
              Expanded(
                child: _field(
                  m,
                  "cores",
                  m.fields["coeurs"]?.toString() ?? "",
                  isDark: isDark,
                  hint: "ex: 2",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  m,
                  "ram",
                  m.fields["ram"]?.toString() ?? "",
                  isDark: isDark,
                  hint: "ex: 2048",
                ),
              ),
            ],
          ),
          _field(
            m,
            "capacite",
            m.fields["capacite"]?.toString() ?? "",
            isDark: isDark,
            hint: "ex: 20G",
          ),
          if (isWindowsServer) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: .4)
                    : Colors.orange.shade50.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pour installer un Windows (serveur), il faut une template. Faut-il la télécharger ou l’as-tu déjà ?",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              setState(() => _windowsTemplateNeeded = true),
                          style: Tiger.tigerButton(),
                          child: const Text("Oui, il la faut"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _windowsTemplateNeeded = false),
                          child: const Text("Non, je l’ai déjà"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Note : Le mot de passe par défaut est "Formation13@"',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    Machine m,
    String f,
    String def, {
    required bool isDark,
    bool dense = false,
    bool Function(String)? validator,
    String? hint,
  }) {
    final c = _ctrl(m.id, f, def);
    final k = _key(m.id, f);

    // Validation live
    String? err;
    if (validator != null && c.text.isNotEmpty && !validator(c.text)) {
      err = "Format invalide";
    }
    _errors[k] = err;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: Colors.orangeAccent,
        decoration: InputDecoration(
          labelText: f,
          hintText: hint,
          errorText: _errors[k],
          labelStyle: const TextStyle(color: Colors.orangeAccent),
          filled: true,
          fillColor: isDark ? Colors.black : Colors.orange.shade50,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white24
                  : Colors.orange.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.orangeAccent, width: 1.6),
          ),
        ),
      ),
    );
  }
}
