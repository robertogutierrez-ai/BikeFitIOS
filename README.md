# BikeFit iOS

Prototipo independiente de BikeFit Android, versión 0.1.0. Incluye grabación silenciosa guiada con la cámara trasera, revisión, análisis lateral en el dispositivo y rangos básicos de cuatro ángulos, además de un asistente manual de calas. Las grabaciones son temporales y se eliminan al terminar o repetir; iOS también puede borrar archivos temporales. No hay historial, exportación, sincronización ni análisis de vídeos de la galería.

La cámara muestra un marco con márgenes, una línea central, una cruz y una línea inferior como referencias; se pueden ocultar y no aparecen en la grabación. Estas guías son visuales: no localizan al ciclista ni comprueban automáticamente el encuadre. Hay que mantener visibles la bicicleta y el cuerpo completo durante toda la pedalada y comprobarlo en la revisión. El análisis utiliza Apple Vision a 5 muestras por segundo y selecciona el lado con más fotogramas válidos. La convención angular coincide con las fórmulas de Android: 0° aproximadamente para una articulación recta. Apple Vision es distinto de MediaPipe, por lo que las mediciones no son directamente equivalentes. Los resultados son orientativos, no constituyen un diagnóstico ni recomendaciones de ajuste y necesitan validación con vídeos reales.

## Asistente de calas

Fotografía cada suela con la cámara trasera, perpendicular a ella y manteniendo la orientación y el encuadre. En cada foto marca punta y talón de la zapatilla y después los extremos de la cala en el mismo orden. Puedes deshacer puntos o repetir la foto. La app muestra la rotación y los desplazamientos lateral y longitudinal como fracciones de la longitud del eje de la zapatilla; no son milímetros. El signo depende de la orientación y del orden de marcado. A diferencia de Android, los desplazamientos se normalizan por la longitud del eje de la zapatilla y no por el tamaño de la vista, por lo que sus valores no son directamente comparables.

Las mediciones dependen de la perspectiva y el marcado, no se han validado con un iPhone real y no son un diagnóstico ni una recomendación de ajuste. La app no guarda fotos ni resultados en un historial ni los envía a servidores.

## Compilar y probar en un Mac

### Requisitos

- Un Mac con macOS y Xcode compatibles, instalado desde el App Store, y un simulador de iPhone instalado desde Xcode. La app requiere iOS 16 o posterior.
- Git y [XcodeGen](https://github.com/yonaskolb/XcodeGen). Para instalar XcodeGen con [Homebrew](https://brew.sh/), ejecuta `brew install xcodegen` en Terminal.
- Para un iPhone físico: un iPhone compatible, un cable y una cuenta Apple. Una cuenta gratuita permite instalar para pruebas personales; no es necesario pagar la suscripción al Apple Developer Program.
- Si el repositorio es privado, el propietario debe invitarte y debes aceptar la invitación antes de descargarlo. Usa la autenticación de GitHub configurada en tu Mac; no compartas credenciales con el propietario.

### Descargar y generar el proyecto

En Terminal, desde el directorio donde quieras descargarlo:

```sh
git clone https://github.com/robertogutierrez-ai/BikeFitIOS.git
cd BikeFitIOS
xcodegen generate
open BikeFitIOS.xcodeproj
```

Si descargas el ZIP desde GitHub en lugar de clonar, descomprímelo y entra en su carpeta con `cd` antes de ejecutar `xcodegen generate`. El archivo `BikeFitIOS.xcodeproj` no está en el repositorio: XcodeGen lo crea a partir de `project.yml`. Vuelve a generarlo cuando cambie `project.yml` o se añadan o eliminen archivos fuente. Al regenerarlo pueden perderse cambios de configuración realizados directamente en Xcode, incluida la firma; vuelve a configurarlos si es necesario.

### Ejecutar en el simulador

1. En Xcode selecciona el esquema **BikeFitIOS** y un simulador de iPhone como destino.
2. Pulsa **Run** (▶) para compilar y abrir la app. Para ejecutar las pruebas, elige **Product > Test**.
3. La cámara y el análisis con grabaciones reales requieren probar la app en un iPhone físico.

También se puede comprobar la compilación para simulador desde Terminal, sin firma:

```sh
xcodebuild -project BikeFitIOS.xcodeproj -scheme BikeFitIOS -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### Instalar en un iPhone

1. En Xcode, abre **Xcode > Settings > Accounts** y añade tu cuenta Apple.
2. En el navegador del proyecto, selecciona el proyecto **BikeFitIOS** y el target **BikeFitIOS**. En **Signing & Capabilities**, activa **Automatically manage signing** y selecciona tu equipo; con una cuenta gratuita aparecerá como **Personal Team**.
3. Si Xcode indica que el identificador `com.bikefit.ios` no está disponible, cambia **Bundle Identifier** por uno único, por ejemplo `com.tunombre.bikefit`.
4. Conecta el iPhone al Mac, desbloquéalo y acepta los avisos de confianza que aparezcan. Si se solicita, activa **Modo desarrollador** en **Ajustes > Privacidad y seguridad** y reinicia el iPhone.
5. Selecciona el iPhone como destino del esquema **BikeFitIOS** y pulsa **Run** (▶). Acepta los permisos de cámara en el iPhone y comprueba la grabación, la revisión y el asistente de calas.

Con una cuenta gratuita, el perfil de instalación caduca a los siete días y hay que volver a compilar e instalar la app desde Xcode. Esta opción es para pruebas personales: no publica en App Store ni TestFlight. Consulta los límites actualizados en [Apple Developer](https://developer.apple.com/help/account/basics/about-your-developer-account/). No subas certificados, perfiles de firma ni claves al repositorio.

### GitHub Actions

El flujo `.github/workflows/ios.yml` genera el proyecto, compila para simulador y ejecuta las pruebas en un simulador de iPhone disponible. Se ejecuta al subir cambios y también puede iniciarse manualmente desde GitHub Actions. Este flujo **no firma ni crea un IPA instalable**, no publica en TestFlight y no necesita credenciales de Apple.

## Privacidad

El vídeo permanece en el almacenamiento temporal de la aplicación y el análisis se realiza localmente. Las fotos de calas se usan durante el asistente y no se añaden a un historial. No se envían imágenes a servidores desde este prototipo. No subir vídeos ni fotos de prueba, certificados ni claves privadas al repositorio.
