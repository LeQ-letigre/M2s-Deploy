import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'config.dart';

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
    };
    final extra = <String, dynamic>{};
    for (final e in json.entries) {
      if (!known.contains(e.key)) extra[e.key] = e.value;
    }
    return Machine(
      id: json["id"],
      nom: json["Nom"] ?? "Inconnu",
      type: json["Type"] ?? "",
      desc: json["desc"] ?? "",
      fields: extra,
    );
  }
}

class ChoixPage extends StatefulWidget {
  final bool teransible;
  const ChoixPage({super.key, required this.teransible});

  @override
  State<ChoixPage> createState() => _ChoixPageState();
}

class _ChoixPageState extends State<ChoixPage> {
  int _selectedIndex = 0;
  final Set<String> _checkedMachines = {};
  late Future<List<Machine>> _machines;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _dhcpEnabled = {}; // gère DHCP
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _machines = _fetchMachines();
  }

  Future<List<Machine>> _fetchMachines() async {
    final url = Uri.parse(
      "${AppConfig.pocketBaseUrl}/api/collections/machine/records",
    );
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception("Erreur ${res.body}");
    final data = (jsonDecode(res.body)["items"] as List)
        .map((e) => Machine.fromJson(e))
        .toList();

    // Initialise DHCP depuis PB si dispo
    for (final m in data) {
      if (m.fields.containsKey("dhcp")) {
        _dhcpEnabled[m.id] = m.fields["dhcp"] == true;
      } else {
        _dhcpEnabled[m.id] = false;
      }
    }
    return data;
  }

  String _key(String machineId, String field) => "$machineId::$field";

  TextEditingController _getController(
    String machineId,
    String field,
    String init,
  ) {
    final k = _key(machineId, field);
    if (_controllers[k] == null) {
      _controllers[k] = TextEditingController(text: init);
    }
    return _controllers[k]!;
  }

  String _currentValue(String machineId, String field, String fallback) {
    final k = _key(machineId, field);
    return _controllers[k]?.text.isNotEmpty == true
        ? _controllers[k]!.text
        : fallback;
  }

  Widget _field({
    required Machine m,
    required String field,
    required String defaultValue,
    bool requiredFlag = false,
    bool password = false,
  }) {
    final c = _getController(m.id, field, defaultValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        obscureText: password && !_showPassword,
        decoration: InputDecoration(
          labelText: "$field${requiredFlag ? ' *' : ''}",
          border: const OutlineInputBorder(),
          suffixIcon: password
              ? IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                )
              : null,
        ),
      ),
    );
  }

  Map<String, dynamic> _mergedData(Machine m) {
    final merged = <String, dynamic>{
      for (final e in m.fields.entries) e.key: e.value ?? "",
    };
    merged["name"] = m.nom;
    merged["type"] = m.type;

    final keys = Set<String>.from(merged.keys)
      ..add("custom_id")
      ..add("dhcp");
    for (final k in keys) {
      if (k == "dhcp") {
        merged["dhcp"] = _dhcpEnabled[m.id] ?? false;
      } else {
        final v = _currentValue(m.id, k, merged[k]?.toString() ?? "");
        if (v.isNotEmpty) merged[k] = v;
      }
    }
    return merged;
  }

  bool _canGenerate(List<Machine> machines) {
    final selected = machines
        .where((m) => _checkedMachines.contains(m.id))
        .toList();
    if (selected.isEmpty) return false;
    for (final m in selected) {
      final idVal = _currentValue(m.id, "custom_id", "");
      if (idVal.isEmpty) return false;
    }
    return true;
  }

  Future<String> _generateConfigString(List<Machine> machines) async {
    final buf = StringBuffer();
    final selected = machines
        .where((m) => _checkedMachines.contains(m.id))
        .toList();

    // Linux
    final linux = selected
        .where((m) => !m.nom.toLowerCase().contains("win"))
        .toList();
    if (linux.isNotEmpty) {
      buf.writeln("lxc_linux = {");
      for (final m in linux) {
        final d = _mergedData(m);
        buf.writeln('  "${m.nom}" = {');
        buf.writeln('    lxc_id = ${d["custom_id"]}');
        buf.writeln('    name = "${m.nom}"');
        if (d["cores"] != null) buf.writeln('    cores = ${d["coeurs"]}');
        if (d["ram"] != null) buf.writeln('    memory = ${d["ram"]}');
        if (d["dhcp"] == true) {
          buf.writeln('    ipconfig0 = "dhcp"');
        } else if (d["ip"] != null) {
          buf.writeln('    ipconfig0 = "${d["ip"]}/${d["masque"] ?? "24"}"');
          if (d["gw"] != null) buf.writeln('    gw = "${d["gw"]}"');
        }
        if (d["dns"] != null) buf.writeln('    dns = "${d["dns"]}"');
        if (d["capacite"] != null)
          buf.writeln('    disk_size = "${d["capacite"]}G"');
        buf.writeln('    network_bridge = "${d["network_bridge"] ?? "vmbr0"}"');
        buf.writeln("    }");
      }
      buf.writeln("}\n");
    }

    // Windows
    final windows = selected
        .where((m) => m.nom.toLowerCase().contains("win"))
        .toList();
    if (windows.isNotEmpty) {
      buf.writeln("win_srv = {");
      for (final m in windows) {
        final d = _mergedData(m);
        buf.writeln('  "${m.nom}" = {');
        buf.writeln('    name = "${m.nom}"');
        buf.writeln('    vmid = ${d["custom_id"]}');
        if (d["dhcp"] == true) {
          buf.writeln('    ipconfig0 = "ip=dhcp"');
        } else if (d["ip"] != null) {
          buf.writeln(
            '    ipconfig0 = "ip=${d["ip"]}/${d["masque"] ?? "24"},gw=${d["gw"] ?? "172.16.0.254"}"',
          );
        }
        if (d["dns"] != null) buf.writeln('    dns = "${d["dns"]}"');
        buf.writeln("    }");
      }
      buf.writeln("}\n");
    }

    return buf.toString();
  }

  Future<File> _generateTempFile(List<Machine> machines) async {
    final content = await _generateConfigString(machines);
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/machines_config.tf");
    await file.writeAsString(content);
    return file;
  }

  Future<void> _pushToPocketBase(File file, List<Machine> machines) async {
    final url = Uri.parse(
      "${AppConfig.pocketBaseUrl}/api/collections/conf/records",
    );
    final querry = {
      for (final m in machines.where((x) => _checkedMachines.contains(x.id)))
        m.nom: _mergedData(m),
    };

    final req = http.MultipartRequest("POST", url)
      ..fields["teransible"] = widget.teransible.toString()
      ..fields["querry"] = jsonEncode(querry)
      ..files.add(await http.MultipartFile.fromPath("file", file.path));

    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    print("📩 Réponse ${resp.statusCode}: $body");
  }

  Future<void> _onGenerate(List<Machine> all) async {
    final selected = all.where((m) => _checkedMachines.contains(m.id)).toList();
    if (!_canGenerate(all)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Remplis les ID des machines cochées")),
      );
      return;
    }
    final file = await _generateTempFile(selected);
    await _pushToPocketBase(file, selected);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Fichier envoyé dans PocketBase")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Choix (teransible=${widget.teransible})")),
      body: FutureBuilder<List<Machine>>(
        future: _machines,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text("Erreur: ${s.error}"));
          final machines = s.data ?? [];
          if (machines.isEmpty)
            return const Center(child: Text("Aucune machine"));

          final m = machines[_selectedIndex];

          return Row(
            children: [
              // --- Barre gauche en 2 parties ---
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(12),
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.deepOrange[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Liste en haut
                    Expanded(
                      child: ListView.builder(
                        itemCount: machines.length,
                        itemBuilder: (_, i) {
                          final mm = machines[i];
                          final selected = i == _selectedIndex;
                          final checked = _checkedMachines.contains(mm.id);
                          final idFilled = _currentValue(
                            mm.id,
                            "custom_id",
                            "",
                          ).isNotEmpty;

                          return ListTile(
                            tileColor: selected
                                ? Colors.orange[700]
                                : Colors.transparent,
                            leading: Checkbox(
                              activeColor: Colors.orangeAccent,
                              value: checked,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _checkedMachines.add(mm.id);
                                  } else {
                                    _checkedMachines.remove(mm.id);
                                  }
                                });
                              },
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mm.nom,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(
                                  idFilled ? Icons.check_circle : Icons.error,
                                  color: idFilled ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                              ],
                            ),
                            onTap: () => setState(() => _selectedIndex = i),
                          );
                        },
                      ),
                    ),

                    const Divider(color: Colors.white54),

                    // Bouton en bas
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ElevatedButton.icon(
                        onPressed: _canGenerate(machines)
                            ? () => _onGenerate(machines)
                            : null,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text("Générer & envoyer"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Formulaire à droite ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.nom,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          m: m,
                          field: "custom_id",
                          // Préremplit avec custom_id ou lxc_id de PocketBase si dispo
                          defaultValue:
                              m.fields["custom_id"]?.toString() ??
                              m.fields["lxc_id"]?.toString() ??
                              m.fields["lxcId"]?.toString() ??
                              "",
                          requiredFlag: true,
                        ),
                        CheckboxListTile(
                          title: const Text("DHCP"),
                          value: _dhcpEnabled[m.id] ?? false,
                          onChanged: (v) =>
                              setState(() => _dhcpEnabled[m.id] = v ?? false),
                        ),
                        if (!(_dhcpEnabled[m.id] ?? false)) ...[
                          _field(
                            m: m,
                            field: "ip",
                            defaultValue: m.fields["ip"]?.toString() ?? "",
                          ),
                          _field(
                            m: m,
                            field: "masque",
                            defaultValue: m.fields["masque"]?.toString() ?? "",
                            requiredFlag: false,
                          ),
                          _field(
                            m: m,
                            field: "gw",
                            defaultValue: m.fields["gw"]?.toString() ?? "",
                          ),
                        ],
                        _field(
                          m: m,
                          field: "dns",
                          defaultValue: m.fields["dns"]?.toString() ?? "",
                        ),
                        _field(
                          m: m,
                          field: "cores",
                          defaultValue: m.fields["coeurs"]?.toString() ?? "",
                        ),
                        _field(
                          m: m,
                          field: "ram",
                          defaultValue:
                              m.fields["ram"]?.toString() ??
                              m.fields["memory"]?.toString() ??
                              "",
                        ),
                        _field(
                          m: m,
                          field: "capacite",
                          defaultValue:
                              m.fields["capacite"]?.toString() ??
                              m.fields["disk_size"]?.toString() ??
                              m.fields["diskSize"]?.toString() ??
                              "",
                        ),
                        _field(
                          m: m,
                          field: "network_bridge",
                          defaultValue:
                              m.fields["network_bridge"]?.toString() ??
                              m.fields["bridge"]?.toString() ??
                              "vmbr0",
                        ),
                        _field(
                          m: m,
                          field: "mot_de_passe",
                          defaultValue:
                              m.fields["mot_de_passe"]?.toString() ??
                              m.fields["password"]?.toString() ??
                              "",
                          password: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
