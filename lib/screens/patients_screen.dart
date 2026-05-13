import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/patient_provider.dart';
import '../providers/scan_provider.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchCtrl = TextEditingController();
  Patient? _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PatientProvider>();
    final scan = context.watch<ScanProvider>();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Patient list ────────────────────────────────
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pazienti',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Cerca paziente…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: pp.search,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showPatientDialog(context, null, pp),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuovo Paziente'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: pp.patients.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = pp.patients[i];
                      final isSelected = _selected?.id == p.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor:
                            AppTheme.primary.withOpacity(0.07),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppTheme.primary
                              : AppTheme.cardBorder,
                          child: Text(
                            p.name.isNotEmpty
                                ? p.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: p.age != null
                            ? Text('${p.age} anni · ${p.sex.label}')
                            : Text(p.sex.label),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _showPatientDialog(context, p, pp);
                            } else if (v == 'delete') {
                              _confirmDelete(context, p, pp);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Modifica')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Elimina',
                                    style: TextStyle(
                                        color: Colors.red))),
                          ],
                        ),
                        onTap: () => setState(() => _selected = p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 28),

          // ─── Patient detail ───────────────────────────────
          Expanded(
            child: _selected == null
                ? const Center(
                    child: Text('Seleziona un paziente per vederne il dettaglio',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : _PatientDetail(
                    patient: _selected!,
                    results: scan.resultsFor(_selected!.id),
                  ),
          ),
        ],
      ),
    );
  }

  void _showPatientDialog(
      BuildContext context, Patient? existing, PatientProvider pp) {
    showDialog(
      context: context,
      builder: (_) => _PatientDialog(
        existing: existing,
        onSave: (p) {
          if (existing == null) {
            pp.addPatient(p);
          } else {
            pp.updatePatient(p);
          }
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, Patient p, PatientProvider pp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Paziente'),
        content: Text(
            'Vuoi eliminare definitivamente ${p.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () {
              pp.removePatient(p.id);
              if (_selected?.id == p.id) {
                setState(() => _selected = null);
              }
              Navigator.pop(context);
            },
            child: const Text('Elimina',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _PatientDetail extends StatelessWidget {
  final Patient patient;
  final List results;

  const _PatientDetail({required this.patient, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  patient.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  if (patient.age != null)
                    Text('${patient.age} anni · ${patient.sex.label}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  if (patient.email.isNotEmpty)
                    Text(patient.email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Text('${results.length} analisi',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Storico Analisi',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('Nessuna analisi eseguita',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = results[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.scoreColor(r.averageScore)
                                  .withOpacity(0.15),
                          child: Text(
                            r.averageScore.toStringAsFixed(1),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.scoreColor(
                                    r.averageScore)),
                          ),
                        ),
                        title: Text(DateFormat('dd/MM/yyyy HH:mm')
                            .format(r.measDate)),
                        subtitle: Text(
                            'Media: ${r.averageScore.toStringAsFixed(1)} / 9.9'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _PatientDialog extends StatefulWidget {
  final Patient? existing;
  final void Function(Patient) onSave;

  const _PatientDialog({this.existing, required this.onSave});

  @override
  State<_PatientDialog> createState() => _PatientDialogState();
}

class _PatientDialogState extends State<_PatientDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _remarkCtrl;
  Sex _sex = Sex.nonSpecificato;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(text: p?.telephone ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _remarkCtrl = TextEditingController(text: p?.remark ?? '');
    _sex = p?.sex ?? Sex.nonSpecificato;
    _birthday = p?.birthday;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'Nuovo Paziente' : 'Modifica Paziente'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nome e Cognome *',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Sex>(
                value: _sex,
                decoration: const InputDecoration(
                    labelText: 'Sesso',
                    prefixIcon: Icon(Icons.wc)),
                items: Sex.values
                    .map((s) => DropdownMenuItem(
                        value: s, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() => _sex = v ?? Sex.nonSpecificato),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(
                    labelText: 'Note',
                    prefixIcon: Icon(Icons.notes)),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final patient = widget.existing != null
                ? widget.existing!.copyWith(
                    name: _nameCtrl.text.trim(),
                    sex: _sex,
                    telephone: _phoneCtrl.text.trim(),
                    email: _emailCtrl.text.trim(),
                    remark: _remarkCtrl.text.trim(),
                  )
                : Patient(
                    name: _nameCtrl.text.trim(),
                    sex: _sex,
                    telephone: _phoneCtrl.text.trim(),
                    email: _emailCtrl.text.trim(),
                    remark: _remarkCtrl.text.trim(),
                    birthday: _birthday,
                  );
            widget.onSave(patient);
            Navigator.pop(context);
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
