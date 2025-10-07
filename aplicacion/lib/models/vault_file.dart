import 'dart:convert';

class VaultFileMeta {
  final String id;
  final String originalName;
  final String mimeType;
  final int originalSize;
  final DateTime createdAt;
  final String dekWrappedB64; // DEK encrypted with KEK (AES-GCM)
  final String dekWrapIvB64;  // IV used to wrap DEK (AES-GCM)
  final String fileIvB64;     // IV used to encrypt file content (AES-GCM)

  const VaultFileMeta({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.originalSize,
    required this.createdAt,
    required this.dekWrappedB64,
    required this.dekWrapIvB64,
    required this.fileIvB64,
  }) : assert(id != '', 'ID cannot be empty'),
       assert(originalName != '', 'Original name cannot be empty'),
       assert(mimeType != '', 'MIME type cannot be empty'),
       assert(originalSize >= 0, 'Original size cannot be negative'),
       assert(dekWrappedB64 != '', 'DEK wrapped cannot be empty'),
       assert(dekWrapIvB64 != '', 'DEK wrap IV cannot be empty'),
       assert(fileIvB64 != '', 'File IV cannot be empty');

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalName': originalName,
        'mimeType': mimeType,
        'originalSize': originalSize,
        'createdAt': createdAt.toIso8601String(),
        'dekWrappedB64': dekWrappedB64,
        'dekWrapIvB64': dekWrapIvB64,
        'fileIvB64': fileIvB64,
      };

  factory VaultFileMeta.fromJson(Map<String, dynamic> j) {
    try {
      return VaultFileMeta(
        id: j['id'] as String? ?? '',
        originalName: j['originalName'] as String? ?? '',
        mimeType: j['mimeType'] as String? ?? '',
        originalSize: (j['originalSize'] as num?)?.toInt() ?? 0,
        createdAt: j['createdAt'] != null 
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        dekWrappedB64: j['dekWrappedB64'] as String? ?? '',
        dekWrapIvB64: j['dekWrapIvB64'] as String? ?? '',
        fileIvB64: j['fileIvB64'] as String? ?? '',
      );
    } catch (e) {
      throw FormatException('Error parsing VaultFileMeta from JSON: $e');
    }
  }

  String toPrettyString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Retorna el tamaño del archivo formateado en una unidad legible
  String get formattedSize {
    if (originalSize < 1024) {
      return '$originalSize B';
    } else if (originalSize < 1024 * 1024) {
      return '${(originalSize / 1024).toStringAsFixed(1)} KB';
    } else if (originalSize < 1024 * 1024 * 1024) {
      return '${(originalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(originalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Retorna la extensión del archivo basada en el nombre original
  String get fileExtension {
    final lastDot = originalName.lastIndexOf('.');
    return lastDot != -1 ? originalName.substring(lastDot + 1).toLowerCase() : '';
  }

  /// Verifica si el archivo es una imagen
  bool get isImage => mimeType.startsWith('image/');

  /// Verifica si el archivo es un documento
  bool get isDocument => mimeType.startsWith('application/') || 
                        mimeType.startsWith('text/') ||
                        mimeType.contains('document') ||
                        mimeType.contains('pdf');

  /// Verifica si el archivo es un video
  bool get isVideo => mimeType.startsWith('video/');

  /// Verifica si el archivo es audio
  bool get isAudio => mimeType.startsWith('audio/');

  /// Retorna un icono apropiado basado en el tipo de archivo
  String get iconName {
    if (isImage) return 'image';
    if (isDocument) return 'description';
    if (isVideo) return 'videocam';
    if (isAudio) return 'audiotrack';
    return 'insert_drive_file';
  }

  /// Crea una copia del objeto con algunos campos modificados
  VaultFileMeta copyWith({
    String? id,
    String? originalName,
    String? mimeType,
    int? originalSize,
    DateTime? createdAt,
    String? dekWrappedB64,
    String? dekWrapIvB64,
    String? fileIvB64,
  }) {
    return VaultFileMeta(
      id: id ?? this.id,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      originalSize: originalSize ?? this.originalSize,
      createdAt: createdAt ?? this.createdAt,
      dekWrappedB64: dekWrappedB64 ?? this.dekWrappedB64,
      dekWrapIvB64: dekWrapIvB64 ?? this.dekWrapIvB64,
      fileIvB64: fileIvB64 ?? this.fileIvB64,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultFileMeta &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VaultFileMeta(id: $id, name: $originalName, size: $formattedSize)';
}
