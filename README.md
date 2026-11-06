# BikeFit iOS

Prototipo independiente de BikeFit Android, versión 0.1.0. Incluye grabación silenciosa guiada con la cámara trasera, revisión, análisis lateral en el dispositivo y rangos básicos de cuatro ángulos. Las grabaciones son temporales y se eliminan al terminar o repetir; iOS también puede borrar archivos temporales. No hay historial, exportación, sincronización ni análisis de vídeos de la galería.

La cámara muestra un marco con márgenes, una línea central, una cruz y una línea inferior como referencias; se pueden ocultar y no aparecen en la grabación. Estas guías son visuales: no localizan al ciclista ni comprueban automáticamente el encuadre. Hay que mantener visibles la bicicleta y el cuerpo completo durante toda la pedalada y comprobarlo en la revisión. El análisis utiliza Apple Vision a 5 muestras por segundo y selecciona el lado con más fotogramas válidos. La convención angular coincide con las fórmulas de Android: 0° aproximadamente para una articulación recta. Apple Vision es distinto de MediaPipe, por lo que las mediciones no son directamente equivalentes. Los resultados son orientativos, no constituyen un diagnóstico ni recomendaciones de ajuste y necesitan validación con vídeos reales.

## Compilación

Para compilar se necesita macOS con Xcode y [XcodeGen](https://github.com/yonaskolb/XcodeGen). En un Mac:

```sh
xcodegen generate
xcodebuild -project BikeFitIOS.xcodeproj -scheme BikeFitIOS -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

El flujo `.github/workflows/ios.yml` genera el proyecto, compila para simulador y ejecuta las pruebas en un simulador de iPhone disponible. Se puede ejecutar manualmente desde GitHub Actions una vez que el contenido se suba a un repositorio autorizado. Este flujo **no firma ni crea un IPA instalable**, no publica en TestFlight y no necesita credenciales de Apple.

Para instalar en un iPhone o distribuir con TestFlight habrá que configurar un identificador de aplicación propio, firma y perfiles de Apple; la cuenta y el acceso al repositorio no están configurados todavía. La cámara requiere un iPhone físico para una prueba completa.

## Privacidad

El vídeo permanece en el almacenamiento temporal de la aplicación y el análisis se realiza localmente. No se envían imágenes a servidores desde este prototipo. No subir vídeos de prueba, certificados ni claves privadas al repositorio.
