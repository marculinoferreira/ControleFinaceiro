import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';
import 'repositorios.dart';

const String casaId = 'principal';

DocumentReference<Map<String, dynamic>> _casaDoc(FirebaseFirestore db) =>
    db.collection('casas').doc(casaId);

class CasaFirestore implements RepositorioCasa {
  final FirebaseFirestore db;
  CasaFirestore(this.db);

  @override
  Stream<Casa?> observar() => _casaDoc(db)
      .snapshots()
      .map((d) => d.exists ? Casa.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> criar(Casa casa) => _casaDoc(db).set(casa.toMap());
}

class PotesFirestore implements RepositorioPotes {
  final FirebaseFirestore db;
  PotesFirestore(this.db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db).collection('potes');

  @override
  Stream<List<Pote>> observar() => _col.orderBy('ordem').snapshots().map(
      (s) => s.docs.map((d) => Pote.fromMap(d.id, d.data())).toList());

  /// Substitui a configuracao inteira em uma unica escrita atomica:
  /// apaga os potes que sumiram e grava os atuais com a ordem corrente.
  @override
  Future<void> salvarTodos(List<Pote> potes) async {
    final atuais = await _col.get();
    final mantidos = potes.map((p) => p.id).toSet();
    final lote = db.batch();

    for (final doc in atuais.docs) {
      if (!mantidos.contains(doc.id)) lote.delete(doc.reference);
    }
    for (var i = 0; i < potes.length; i++) {
      final pote = potes[i].copyWith(ordem: i);
      final ref = pote.id.isEmpty ? _col.doc() : _col.doc(pote.id);
      lote.set(ref, pote.toMap());
    }
    await lote.commit();
  }

  @override
  Future<void> remover(String id) => _col.doc(id).delete();
}

class GanhosFirestore implements RepositorioGanhos {
  final FirebaseFirestore db;
  GanhosFirestore(this.db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db).collection('ganhos');

  @override
  Stream<List<Ganho>> observarMes(String mesRef) => _col
      .where('mesRef', isEqualTo: mesRef)
      .snapshots()
      .map((s) => s.docs.map((d) => Ganho.fromMap(d.id, d.data())).toList());

  @override
  Future<void> adicionar(Ganho ganho) => _col.add(ganho.toMap());

  @override
  Future<void> atualizar(Ganho ganho) =>
      _col.doc(ganho.id).update(ganho.toMap());

  @override
  Future<void> remover(String id) => _col.doc(id).delete();
}

class GastosFirestore implements RepositorioGastos {
  final FirebaseFirestore db;
  final Uuid _uuid = const Uuid();

  GastosFirestore(this.db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db).collection('gastos');

  @override
  Stream<List<Gasto>> observarMes(String mesRef) => _col
      .where('mesRef', isEqualTo: mesRef)
      .orderBy('criadoEm', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<Gasto>> observarParceladosDesde(String mesRef) => _col
      .where('parcelado', isEqualTo: true)
      .where('mesRef', isGreaterThanOrEqualTo: mesRef)
      .orderBy('mesRef')
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

  /// Ou entram todas as parcelas, ou nenhuma.
  @override
  Future<void> adicionar({
    required Gasto base,
    required int quantidadeParcelas,
  }) async {
    final novas = gerarParcelas(
      base: base,
      quantidade: quantidadeParcelas,
      compraId: _uuid.v4(),
    );
    final lote = db.batch();
    for (final g in novas) {
      lote.set(_col.doc(), g.toMap());
    }
    await lote.commit();
  }

  @override
  Future<void> atualizar(Gasto gasto) =>
      _col.doc(gasto.id).update(gasto.toMap());

  /// Le a compra inteira, planeja e grava tudo num lote so: ou a compra
  /// muda por completo, ou nao muda.
  @override
  Future<void> atualizarCompra({
    required Gasto editado,
    required ModoEdicao alcance,
    required int novaQuantidade,
  }) async {
    final compraId = editado.compraId;
    if (compraId == null) return atualizar(editado);

    final snap = await _col.where('compraId', isEqualTo: compraId).get();
    final existentes =
        snap.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList();

    final plano = planejarEdicaoCompra(
      existentes: existentes,
      editado: editado,
      alcance: alcance,
      novaQuantidade: novaQuantidade,
    );
    if (plano.vazio) return;

    final lote = db.batch();
    for (final g in plano.atualizar) {
      lote.update(_col.doc(g.id), g.toMap());
    }
    for (final id in plano.remover) {
      lote.delete(_col.doc(id));
    }
    for (final g in plano.criar) {
      lote.set(_col.doc(), g.toMap());
    }
    await lote.commit();
  }

  @override
  Future<void> removerUma(String id) => _col.doc(id).delete();

  @override
  Future<void> removerDesta(String compraId, int parcela) async {
    final alvo = await _col
        .where('compraId', isEqualTo: compraId)
        .where('parcela', isGreaterThanOrEqualTo: parcela)
        .get();
    await _apagarEmLote(alvo.docs);
  }

  @override
  Future<void> removerCompra(String compraId) async {
    final alvo = await _col.where('compraId', isEqualTo: compraId).get();
    await _apagarEmLote(alvo.docs);
  }

  /// Um WriteBatch aceita no maximo 500 operacoes.
  Future<void> _apagarEmLote(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (var i = 0; i < docs.length; i += 400) {
      final fatia = docs.skip(i).take(400);
      final lote = db.batch();
      for (final d in fatia) {
        lote.delete(d.reference);
      }
      await lote.commit();
    }
  }
}
