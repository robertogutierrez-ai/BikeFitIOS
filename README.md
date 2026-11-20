# BikeFit iOS

Prototipo independiente de BikeFit Android, versión 0.1.0. Incluye grabación silenciosa guiada con la cámara trasera o frontal, selección de vídeos de la fototeca, revisión, análisis lateral en el dispositivo y rangos básicos de cuatro ángulos articulares y dos inclinaciones, además de un asistente manual de calas. Las grabaciones y las copias importadas son temporales y se eliminan al terminar o repetir; iOS también puede borrar archivos temporales. No hay sincronización propia de la app.

La cámara muestra un marco con márgenes, una línea central, una cruz y una línea inferior como referencias; se pueden ocultar y no aparecen en la grabación. Estas guías son visuales: no localizan al ciclista ni comprueban automáticamente el encuadre. Hay que mantener visibles la bicicleta y el cuerpo completo durante toda la pedalada y comprobarlo en la revisión. El análisis utiliza Apple Vision o, opcionalmente, MediaPipe a 5 muestras por segundo y selecciona el lado con más fotogramas válidos. Los ángulos articulares siguen las fórmulas de Android: 0° aproximadamente para una articulación recta. Las inclinaciones de espalda y muslo se expresan entre 0° y 90° respecto a la horizontal. Apple Vision es distinto de MediaPipe, por lo que las mediciones no son directamente equivalentes. Los resultados son orientativos, no constituyen un diagnóstico ni recomendaciones de ajuste y necesitan validación con vídeos reales.

En la cámara guiada puedes alternar entre la cámara trasera y la frontal antes de grabar. No se puede cambiar de cámara durante la grabación ni mientras se está finalizando. La vista previa frontal puede aparecer reflejada, pero el vídeo se graba sin reflejar para el análisis. Es necesario comprobar esta función y la orientación del vídeo en un iPhone real.

Para analizar un vídeo existente, pulsa **Analizar vídeo de la fototeca**, selecciónalo y revísalo antes de iniciar el análisis. La app crea una copia temporal: al cerrar, finalizar o repetir se elimina esa copia, no el vídeo original. Los vídeos alojados en iCloud pueden necesitar descarga y espacio disponible. El selector solo entrega a la app el vídeo elegido.

En la revisión puedes elegir **Analizar con MediaPipe (experimental)**. Usa el modelo Full de pose en el dispositivo y, cuando la punta del pie tiene suficiente visibilidad y presencia, calcula el ángulo rodilla-tobillo-punta y la inclinación tobillo-punta respecto a la horizontal. Ambos son estimaciones 2D; la inclinación es de 0° a 90° y no distingue punta arriba de punta abajo, a diferencia del ángulo dirigido de Android. No se inventan valores cuando falta la punta; se muestra la cantidad de fotogramas disponibles. El modo en directo y el vídeo anotado siguen usando Vision; el vídeo anotado no está disponible para resultados MediaPipe. Los motores no deben mezclarse como si fueran equivalentes y es necesario validar las mediciones con vídeos e iPhone reales.

En **Análisis en directo (experimental)** la cámara muestra valores instantáneos calculados con Apple Vision en el dispositivo, sin grabar ni guardar vídeo o resultados. Se puede cambiar entre cámaras trasera y frontal; la vista previa frontal puede mostrarse reflejada, pero el análisis usa la imagen sin reflejar. Se analizan hasta cinco fotogramas por segundo y se muestra el lado izquierdo si es válido, o el derecho en caso contrario; el lado puede cambiar durante el seguimiento. Si no se detecta una postura completa se ocultan los valores. Son medidas orientativas sin validación clínica y no sustituyen al análisis de un vídeo ni ofrecen grabación anotada. Esta función requiere comprobación en un iPhone real, incluida la orientación y el cambio de cámara.

En **Análisis frontal (experimental)** coloca la cámara fija frente a la bicicleta, con ambas rodillas y tobillos visibles. La app muestra por separado la distancia horizontal absoluta entre rodilla y tobillo de cada lado como porcentaje del ancho de la imagen, solo cuando ambos puntos de ese lado tienen suficiente confianza. Las guías son visuales, no validan el encuadre. No se graban ni guardan los resultados. No se mide una distancia real ni se determina dirección, alineación correcta o asimetría clínica: la perspectiva, el encuadre y la fase del pedaleo cambian los valores. El seguimiento y la orientación deben probarse en un iPhone.

Desde la revisión de un vídeo frontal, **Comparar siluetas frontales** permite seleccionar dos fotogramas y comparar el porcentaje de imagen ocupado por la persona segmentada con Apple Vision. Usa cámara fija y zoom constante; si la silueta detectada toca el borde o no hay persona, la comparación se rechaza. Los fotogramas y el resultado no se guardan. La segmentación y las condiciones de grabación pueden cambiar el resultado: no es una medición de área real, CdA, resistencia aerodinámica ni vatios, y no está validada en iPhone.

Durante el análisis se muestra el progreso aproximado de los instantes procesados. Se puede cancelar: la operación se detiene después del fotograma en curso y no se guardan resultados parciales. El porcentaje no representa la calidad de detección.

El resultado muestra también el porcentaje de fotogramas con seguimiento válido y un recuento experimental de ciclos basado en cambios del ángulo de rodilla. Una interrupción larga del seguimiento no cuenta como ciclo. Se detecta una fase flexionada por encima de 90° y otra extendida por debajo de 70°, según la convención de la app (0° corresponde a una rodilla recta). Con cinco muestras por segundo o movimientos que no atraviesan estos umbrales, el recuento puede omitir ciclos: no es una medida de calidad del ajuste ni ha sido validado en iPhone.

Los resultados incluyen una gráfica de puntos de la métrica elegida para las muestras válidas del lado seleccionado; los huecos no son mediciones. El tiempo mostrado es el instante solicitado al vídeo, aproximadamente cada 0,2 segundos.

En los resultados y en el historial con muestras disponibles se pueden consultar la media, la desviación estándar poblacional y la amplitud (máximo menos mínimo) de cada ángulo. Se calculan sobre las muestras válidas, sin interpolar los huecos. Describen los datos observados: no son puntuaciones de calidad, regularidad de pedaleo ni recomendaciones de ajuste.

Desde los resultados, **Crear vídeo anotado (experimental)** vuelve a procesar cada fotograma localmente y permite previsualizar y compartir un MP4 temporal con el esqueleto y los cuatro ángulos articulares del lado seleccionado. Si ese lado no se detecta completo, el fotograma queda sin anotaciones; las mediciones de fotogramas individuales pueden diferir de los resúmenes muestreados. La exportación puede tardar y se puede cancelar; el archivo temporal se elimina al volver a los resultados, aunque iOS también puede borrar archivos temporales. Si el vídeo original contiene audio, el MP4 exportado lo conserva: compruébalo antes de compartir. La persona que lo comparte decide dónde guardarlo o enviarlo. La orientación, sincronización, rendimiento y resultados deben validarse en un iPhone real; no son clínicos.

Tras el análisis puedes guardar explícitamente los resultados en el historial de sesiones, consultarlos y eliminarlos desde el inicio. Selecciona dos sesiones para comparar sus rangos; las diferencias no indican por sí solas una mejora y pueden depender del lado y del encuadre. Se almacenan los rangos, el lado, los recuentos de fotogramas y las muestras para la gráfica, no el vídeo. Las sesiones antiguas pueden no contener todas las métricas ni una gráfica. A diferencia de Android, el guardado no es automático.

El historial también permite elegir una comparación **antes/después** o **bilateral**, seleccionando dos sesiones guardadas en el orden indicado. Antes/después exige el mismo lado; bilateral exige lados opuestos, grabados por separado. Ambos exigen el mismo motor y muestran diferencias de rangos y, cuando hay muestras, de medias y su número de muestras. La fecha es la de guardado, no necesariamente la de grabación. Son comparaciones descriptivas: no detectan fatiga ni asimetrías clínicas y dependen de la posición de cámara y las condiciones de grabación.

Desde los resultados o una sesión guardada, **Compartir informe PDF** genera un informe con fecha, lado, fotogramas válidos y rangos disponibles. No incluye el vídeo. Se abre el menú de compartir del sistema y el usuario decide si lo guarda o lo envía; cualquier copia compartida queda bajo su control. La app elimina su archivo temporal al cerrar el menú, aunque iOS también puede borrar archivos temporales.

En **Perfiles y referencias** puedes crear, editar, activar y eliminar perfiles locales con rangos que tú introduzcas; no se proporciona ningún rango clínico predeterminado. Los resultados incluyen una puntuación experimental de coincidencia con el perfil activo: es la media de los porcentajes de muestras en cada rango, ponderando por igual las métricas del perfil. Solo se muestra con al menos 15 fotogramas muestreados y al menos un 80 % de muestras disponibles para cada referencia; estas condiciones son heurísticas, no validan ni garantizan la fiabilidad de la puntuación. No es un diagnóstico, una medida de calidad del ajuste ni una recomendación. Las referencias y la puntuación no se guardan en la sesión ni en el PDF. Los presets de Android no se importan automáticamente porque las mediciones de ambos motores no son directamente equivalentes.

## Asistente de calas

Fotografía cada suela con la cámara trasera, perpendicular a ella y manteniendo la orientación y el encuadre. En cada foto marca punta y talón de la zapatilla y después los extremos de la cala en el mismo orden. Puedes deshacer puntos o repetir la foto. La app muestra la rotación y los desplazamientos lateral y longitudinal como fracciones de la longitud del eje de la zapatilla; no son milímetros. El signo depende de la orientación y del orden de marcado. A diferencia de Android, los desplazamientos se normalizan por la longitud del eje de la zapatilla y no por el tamaño de la vista, por lo que sus valores no son directamente comparables.

Las mediciones dependen de la perspectiva y el marcado, no se han validado con un iPhone real y no son un diagnóstico ni una recomendación de ajuste. Si el usuario lo elige, la app guarda localmente hasta 10 resultados con fecha, comodidad, síntoma y nota; permite compararlos con la última medición y eliminar registros. Las fotos no se guardan ni se envían a servidores.

## KOPS manual experimental

Desde el inicio puedes seleccionar una fotografía lateral y marcar los extremos de una referencia de longitud conocida, un punto de la rodilla y el centro del eje del pedal. La referencia debe estar en el mismo plano y la cámara nivelada y perpendicular; usa una foto con la biela aproximadamente horizontal. La app estima el desplazamiento horizontal en milímetros, positivo hacia la derecha de la imagen. No identifica la anatomía ni la fase del pedaleo, no indica automáticamente delante o detrás, y no aplica la escala al análisis de vídeo. La perspectiva y el marcado pueden introducir errores importantes; el resultado no es clínico ni una recomendación de ajuste. La foto y el resultado no se guardan en el historial. Esta función no se ha validado en iPhone.

En la revisión de vídeo, **Calibrar y analizar KOPS en vídeo** permite elegir un fotograma del mismo vídeo, marcar los extremos de una referencia y escribir su longitud. Indica hacia qué lado de la imagen avanza la bicicleta. MediaPipe selecciona el lado con más fotogramas válidos y estima el eje del pedal como el punto medio entre tobillo y punta, como aproximación; no detecta el eje real. Se muestra el desplazamiento de la rodilla en el fotograma muestreado donde el tobillo está más adelantado, el instante y el número de muestras disponibles. Si no se detecta la punta, el resultado no está disponible. Positivo indica hacia la dirección de avance elegida. El vídeo debe mantener cámara y referencia fijas y la referencia debe estar en el mismo plano; perspectiva, seguimiento y frecuencia de muestreo pueden alterar el resultado. No es una medición validada ni una recomendación. El resultado se guarda solo si se guarda la sesión y no se incluye en el PDF.

## Sensores Bluetooth experimentales

Desde **Conectar sensor** puedes buscar y conectar un sensor Bluetooth LE que anuncie los servicios estándar Cycling Power, Cycling Speed and Cadence o Heart Rate. Se conecta uno cada vez y se muestran las últimas lecturas de potencia, cadencia de biela o pulso compatibles; una lectura puede quedar desactualizada si el sensor deja de enviar datos. La búsqueda dura 15 segundos y solo encuentra sensores que anuncien esos servicios. Al salir o pasar la app a segundo plano se desconecta; las mediciones no se guardan ni se incorporan al análisis. Requiere permiso Bluetooth y comprobación con sensores e iPhone reales.

## Medición AR experimental

**Medir dos puntos con AR** permite apuntar con la cruz y marcar dos puntos sobre superficies detectables con la cámara trasera de un iPhone compatible con ARKit. Se muestra una distancia 3D aproximada en milímetros; si el seguimiento es limitado o no se detecta una superficie, la app impide marcar el punto. La medición se borra al salir o pasar la app a segundo plano y no detecta automáticamente ni sigue los componentes de la bicicleta. No es una medición de precisión: la iluminación, textura, movimiento y posición del teléfono pueden producir errores importantes. Requiere validación en un iPhone real.

## Compilar y probar en un Mac

### Requisitos

- Un Mac con macOS y Xcode compatibles, instalado desde el App Store. La app requiere iOS 16 o posterior. El paquete de MediaPipe incluido solo contiene arquitectura ARM64 para el simulador: para ejecutar pruebas en simulador se necesita un Mac con Apple Silicon. En un Mac Intel no está disponible esta compilación para simulador; la compilación para un iPhone físico ARM64 se mantiene como objetivo, pendiente de comprobar.
- Git y [XcodeGen](https://github.com/yonaskolb/XcodeGen). Para instalar XcodeGen con [Homebrew](https://brew.sh/), ejecuta `brew install xcodegen` en Terminal.
- Conexión a Internet al compilar por primera vez para resolver el paquete Swift de MediaPipe y sus binarios. El modelo Full se incluye en el proyecto; procede de [MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker) y está cubierto por la licencia Apache 2.0, incluida en `BikeFitIOS/Resources/MediaPipe-APACHE-2.0.txt`. Consulta también la [ficha del modelo](https://storage.googleapis.com/mediapipe-assets/Model%20Card%20BlazePose%20GHUM%203D.pdf). La app realiza la detección localmente y no descarga ni envía los vídeos.
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

La prueba de exportación del vídeo anotado usa un detector simulado para comprobar la orientación y la propagación de errores, ya que el simulador de CI puede carecer del modelo de pose de Apple Vision. No valida la detección real ni sustituye las pruebas en un iPhone.

## Privacidad

El vídeo permanece en el almacenamiento temporal de la aplicación y el análisis se realiza localmente. Las fotos de calas y KOPS solo se usan durante sus asistentes y no se guardan en la app; la fotografía original de la fototeca no se modifica. El historial de calas, los perfiles y los resultados de sesiones guardados se almacenan localmente; el sistema puede incluirlos en las copias de seguridad del dispositivo. No se envían imágenes a servidores desde este prototipo. No subir vídeos ni fotos de prueba, certificados ni claves privadas al repositorio.
