# Caja Segura (Flutter)

App tipo "caja fuerte digital" para Android/iOS. Mantiene archivos en **almacenamiento interno cifrado**, accesibles solo tras **biometría/PIN**.

## Funcionalidades del MVP
- 🔐 Cifrado por archivo con **AES-256-GCM** (DEK por archivo envuelta con KEK).
- 🧩 KEK guardada en **Android Keystore / iOS Keychain** via `biometric_storage`.
- 👆 **Biometría** para desbloqueo (BiometricPrompt / LAContext).
- 🗃️ Importación de archivos desde el sistema; exportación solo tras reautenticación.
- 🛡️ **FLAG_SECURE** (Android) bloquea screenshots y vista en el conmutador.
- 🚫 Sin backups (Android) para evitar subir datos a la nube.

> ⚠️ **Si se desinstala la app o se pierde la clave, los datos no se pueden recuperar.** Guarde una copia cifrada si es crítico.

## Cómo usar
1. Cree un proyecto Flutter vacío o use este esqueleto:
   ```bash
   flutter create caja_segura
   ```
2. Reemplace la carpeta `lib/` y `pubspec.yaml` con los de este paquete.
3. Copie `android/app/src/main/AndroidManifest.xml` y `android/app/src/main/res/xml/backup_rules.xml` dentro de su proyecto (ajuste el `package`).
4. Instale dependencias y ejecute:
   ```bash
   flutter pub get
   flutter run
   ```

## Notas técnicas
- **Cifrado**: `cryptography` (AES-GCM 256). DEK (32 bytes) aleatoria por archivo, envuelta con KEK almacenada en keystore/secure enclave mediante `biometric_storage`.
- **Vault**: Archivos en `getApplicationSupportDirectory()/vault`: `<id>.enc` (cipher+tag) y `<id>.json` (metadatos + IVs + DEK envuelta).
- **Timeout de sesión**: 5 minutos por defecto. Al pasar a background se bloquea.
- **Windows/Mac/Linux**: Puede compilar, pero la seguridad fuerte está pensada para Android/iOS.

## Camuflado (Android opcional)
- Se pueden definir **launcher aliases** en `AndroidManifest.xml` para publicar con otro nombre/ícono (p. ej., “Calculadora”). Este esqueleto no lo habilita por defecto. ⚠️ Play Store puede rechazar apps disfrazadas; como APK local no hay problema técnico.

## Mejoras sugeridas
- Thumbnails cifrados y vista previa segura.
- “Cofre señuelo” y PIN de coacción.
- Exportación como **paquete cifrado** (.vault) en vez de archivos en claro.
- Wipe tras N intentos fallidos (con confirmación).
- Reemplazar RNG placeholder en `LockManager` por una fuente CSPRNG (p. ej., `Random.secure()` desde platform channel o `package:cryptography` cuando ofrezca una API directa).

## Licencia
MIT
