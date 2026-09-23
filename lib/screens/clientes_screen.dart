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
                  subtitle: Text('${cliente.ubicacion} • Tel: ${cliente.telefono}'),
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
        onPressed: () => _mostrarDialogoNuevoCliente(context),
        child: const Icon(Icons.add_reaction, color: Colors.white),
      ),
    );
  }

  void _mostrarDialogoNuevoCliente(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String nombre = '';
    String telefono = '';
    String ubicacion = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo Cliente / Finca'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Nombre del Cliente'),
                  validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                  onSaved: (val) => nombre = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                  validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                  onSaved: (val) => telefono = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Ubicación / Vereda / Municipio'),
                  validator: (val) => val!.isEmpty ? 'Campo requerido' : null,
                  onSaved: (val) => ubicacion = val!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  FirebaseFirestore.instance.collection('clientes').add(
                    ClienteModel(nombre: nombre, telefono: telefono, ubicacion: ubicacion).toMap(),
                  );
                  Navigator.pop(context);
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