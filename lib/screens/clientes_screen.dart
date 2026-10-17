import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';

class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay clientes registrados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var cliente = ClienteModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);

              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cliente.activo ? Colors.green : Colors.grey,
                    child: Icon(cliente.activo ? Icons.person : Icons.person_off, color: Colors.white),
                  ),
                  title: Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${cliente.cedula.isNotEmpty ? "C.C./NIT: ${cliente.cedula} • " : ""}${cliente.ubicacion} • Tel: ${cliente.telefono}',
                  ),
                  onTap: () => _mostrarDialogoCliente(context, clienteExistente: cliente),
                  trailing: Switch(
                    value: cliente.activo,
                    activeThumbColor: const Color(0xFF2E7D32),
                    onChanged: (val) {
                      FirebaseFirestore.instance.collection('clientes').doc(cliente.id).update({'activo': val});
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () => _mostrarDialogoCliente(context),
        child: const Icon(Icons.add_reaction, color: Colors.white),
      ),
    );
  }

  void _mostrarDialogoCliente(BuildContext context, {ClienteModel? clienteExistente}) {
    final formKey = GlobalKey<FormState>();
    String nombre = clienteExistente?.nombre ?? '';
    String cedula = clienteExistente?.cedula ?? '';
    String telefono = clienteExistente?.telefono ?? '';
    String ubicacion = clienteExistente?.ubicacion ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(clienteExistente == null ? 'Nuevo Cliente / Finca' : 'Editar Cliente'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre del Cliente'),
                    validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                    onSaved: (val) => nombre = val!.trim(),
                  ),
                  TextFormField(
                    initialValue: cedula,
                    decoration: const InputDecoration(labelText: 'Cédula / NIT'),
                    keyboardType: TextInputType.text,
                    onSaved: (val) => cedula = val?.trim() ?? '',
                  ),
                  TextFormField(
                    initialValue: telefono,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                    validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                    onSaved: (val) => telefono = val!.trim(),
                  ),
                  TextFormField(
                    initialValue: ubicacion,
                    decoration: const InputDecoration(labelText: 'Ubicación / Vereda / Municipio'),
                    validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                    onSaved: (val) => ubicacion = val!.trim(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  if (clienteExistente == null) {
                    await FirebaseFirestore.instance.collection('clientes').add(
                      ClienteModel(
                        nombre: nombre,
                        cedula: cedula,
                        telefono: telefono,
                        ubicacion: ubicacion,
                      ).toMap(),
                    );
                  } else if (clienteExistente.id != null) {
                    await FirebaseFirestore.instance.collection('clientes').doc(clienteExistente.id).update({
                      'nombre': nombre,
                      'cedula': cedula,
                      'telefono': telefono,
                      'ubicacion': ubicacion,
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}