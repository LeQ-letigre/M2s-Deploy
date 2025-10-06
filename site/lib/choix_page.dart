// lib/choix_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'config.dart';
import 'theme_tiger.dart';
import 'confirmation_page.dart';

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
  final Map<String, bool> _dhcpEnabled = {};
  final TextEditingController _globalPassword = TextEditingController();

  bool _teransible = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _teransible = widget.teransible;
    _machines = _fetchMachines();
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
        .map((e) => Machine.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final m in items) {
      _dhcpEnabled[m.id] = (m.fields["dhcp"] == true);
    }
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

  Map<String, dynamic> _merged(Machine m) {
    final d = Map<String, dynamic>.from(m.fields);
    d["name"] = m.nom;
    d["type"] = m.type;
    d["dhcp"] = _dhcpEnabled[m.id] ?? false;
    d["mot_de_passe"] = _globalPassword.text;

    String v(String f, [String fb = ""]) =>
        _val(m.id, f, (d[f]?.toString() ?? fb));

    d["custom_id"] = v("custom_id");
    d["ip"] = v("ip");
    d["masque"] = v("masque");
    d["gw"] = v("gw");
    d["dns"] = v("dns");
    d["network_bridge"] = v("network_bridge", "vmbr0");
    d["cores"] = v("cores", "");
    d["ram"] = v("ram", "");
    d["capacite"] = v("capacite", "");
    return d;
  }

  bool _canGenerate() {
    return _checked.isNotEmpty && _globalPassword.text.isNotEmpty;
  }

  Future<String> _buildTfvars(List<Machine> selected) async {
    final buf = StringBuffer();
    buf.writeln("# TIGRES conf auto.tfvars");
    buf.writeln('terransible = ${_teransible ? "true" : "false"}');
    buf.writeln('mot_de_passe_global = "${_globalPassword.text}"');

    final linux = selected
        .where((m) => !m.nom.toLowerCase().contains("win"))
        .toList();
    if (linux.isNotEmpty) {
      buf.writeln("lxc_linux = {");
      for (final m in linux) {
        final d = _merged(m);
        buf.writeln('  "${m.nom}" = {');
        buf.writeln(
          '    lxc_id = ${d["custom_id"].isEmpty ? 0 : d["custom_id"]}',
        );
        buf.writeln('    name = "${m.nom}"');
        buf.writeln('    dhcp = ${d["dhcp"] == true ? "true" : "false"}');
        buf.writeln('    password = "${_globalPassword.text}"');
        buf.writeln("  }");
      }
      buf.writeln("}\n");
    }
    return buf.toString();
  }

  Future<File> _writeTempTfvars(List<Machine> selected) async {
    final content = await _buildTfvars(selected);
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/tigres_conf.auto.tfvars");
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
          content: Text(
            "⚠️ Sélectionne au moins une machine et un mot de passe.",
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
        "${_teransible ? 1 : 0} ${first["custom_id"].isEmpty ? 0 : first["custom_id"]} "
        "${_globalPassword.text} dhcp dhcp dhcp vmbr0 0 0 $url";

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
    return TigerAnimatedBG(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(.7),
          title: const Text("🐅 TIGRES • Configurations"),
          actions: [
            Row(
              children: [
                const Text(
                  "Terransible",
                  style: TextStyle(color: Colors.white70),
                ),
                Switch(
                  value: _teransible,
                  activeThumbColor: Colors.orangeAccent,
                  onChanged: (v) => setState(() => _teransible = v),
                ),
                const SizedBox(width: 10),
              ],
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
            if (s.hasError) return Center(child: Text("Erreur: ${s.error}"));
            final machines = s.data ?? [];
            if (machines.isEmpty) {
              return const Center(child: Text("Aucune machine"));
            }
            final m = machines[_selectedIndex];

            return Row(
              children: [
                // --- Barre gauche ---
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(12),
                  width: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414).withOpacity(.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(.5)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _globalPassword,
                        obscureText: !_showPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Mot de passe global 🔒",
                          labelStyle: const TextStyle(
                            color: Colors.orangeAccent,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.orangeAccent,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: machines.length,
                          itemBuilder: (_, i) {
                            final mm = machines[i];
                            final selected = i == _selectedIndex;
                            final checked = _checked.contains(mm.id);
                            final idOk = _val(
                              mm.id,
                              "custom_id",
                              "",
                            ).isNotEmpty;
                            return ListTile(
                              tileColor: selected
                                  ? Colors.orangeAccent.withOpacity(0.1)
                                  : Colors.transparent,
                              leading: Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _checked.add(mm.id);
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
                                  color: Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: Icon(
                                idOk ? Icons.check_circle : Icons.error_outline,
                                color: idOk ? Colors.green : Colors.redAccent,
                              ),
                              onTap: () => setState(() => _selectedIndex = i),
                            );
                          },
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _canGenerate()
                            ? () => _onGenerate(machines)
                            : null,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text("Générer & envoyer"),
                        style: Tiger.tigerButton(),
                      ),
                    ],
                  ),
                ),

                // --- Formulaire machine ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414).withOpacity(.95),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: _buildMachineForm(m),
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

  Widget _buildMachineForm(Machine m) {
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
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
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
            required: true,
          ),
          _switchDHCP(m),
          if (!(_dhcpEnabled[m.id] ?? false)) ...[
            _field(m, "ip", m.fields["ip"]?.toString() ?? ""),
            _twoCols(
              left: _field(
                m,
                "masque",
                m.fields["masque"]?.toString() ?? "",
                dense: true,
              ),
              right: _field(
                m,
                "gw",
                m.fields["gw"]?.toString() ?? "",
                dense: true,
              ),
            ),
          ],
          _twoCols(
            left: _field(
              m,
              "dns",
              m.fields["dns"]?.toString() ?? "",
              dense: true,
            ),
            right: _field(
              m,
              "network_bridge",
              m.fields["network_bridge"]?.toString() ?? "vmbr0",
              dense: true,
            ),
          ),
          _twoCols(
            left: _field(
              m,
              "cores",
              m.fields["coeurs"]?.toString() ?? "",
              dense: true,
            ),
            right: _field(
              m,
              "ram",
              m.fields["ram"]?.toString() ?? "",
              dense: true,
            ),
          ),
          _field(m, "capacite", m.fields["capacite"]?.toString() ?? ""),
        ],
      ),
    );
  }

  Widget _switchDHCP(Machine m) {
    return SwitchListTile.adaptive(
      activeColor: Colors.orangeAccent,
      title: const Text("DHCP", style: TextStyle(color: Colors.white)),
      value: _dhcpEnabled[m.id] ?? false,
      onChanged: (v) => setState(() => _dhcpEnabled[m.id] = v),
    );
  }

  Widget _twoCols({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _field(
    Machine m,
    String f,
    String def, {
    bool required = false,
    bool dense = false,
  }) {
    final c = _ctrl(m.id, f, def);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
      child: TextField(
        controller: c,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: Colors.orangeAccent,
        decoration: InputDecoration(
          labelText: "$f${required ? ' *' : ''}",
          labelStyle: const TextStyle(color: Colors.orangeAccent),
          filled: true,
          fillColor: Colors.black,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.orangeAccent,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
