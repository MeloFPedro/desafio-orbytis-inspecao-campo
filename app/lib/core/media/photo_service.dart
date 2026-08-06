import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Captura, armazena e resolve fotos de evidência.
///
/// Recebe o diretório de documentos já resolvido para que [resolve] seja
/// síncrono — a UI precisa do caminho absoluto durante o build.
class PhotoService {
  PhotoService(this._documentsPath, {ImagePicker? picker, Uuid? uuid})
      : _picker = picker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid();

  static const folder = 'inspections';

  final String _documentsPath;
  final ImagePicker _picker;
  final Uuid _uuid;

  /// Abre a câmera e persiste a imagem. Devolve caminho **relativo**, ou nulo
  /// se o usuário cancelou.
  ///
  /// A cópia é essencial: o image_picker grava no cache do sistema, que o
  /// Android limpa quando quer. Guardar aquele caminho faria a inspeção
  /// sobreviver ao fechamento do app, mas não a foto — e a sincronização
  /// falharia dias depois, longe da causa.
  Future<String?> capture() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      // Redimensiona na captura: evita arquivo de vários MB e respeita o
      // limite de 8 MB do upload, sem biblioteca de processamento de imagem.
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );

    if (picked == null) return null;

    final directory = Directory(p.join(_documentsPath, folder));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final relativePath = p.join(folder, '${_uuid.v4()}.jpg');
    await File(picked.path).copy(p.join(_documentsPath, relativePath));

    return relativePath;
  }

  /// Caminho absoluto para exibir ou enviar.
  ///
  /// O banco guarda o caminho relativo porque o container do app muda entre
  /// reinstalações no Android: um caminho absoluto salvo hoje pode apontar
  /// para lugar nenhum depois.
  String resolve(String relativePath) => p.join(_documentsPath, relativePath);

  Future<void> delete(String relativePath) async {
    final file = File(resolve(relativePath));
    if (file.existsSync()) await file.delete();
  }
}
