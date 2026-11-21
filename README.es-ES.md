

# HotkeyLauncher

Lanzador de atajos de teclado nativo para macOS, construido con SwiftUI, AppKit y atajos globales de Carbon. Asigna un atajo global a cualquier aplicación y accede a ella desde cualquier lugar.

Requiere macOS 12 o posterior. La compilación desde el código fuente requiere Swift 5.7 o posterior.

![Ventana principal de HotkeyLauncher](./hotkey-launcher.png)

## Características

- Atajos globales a nivel del sistema registrados a través de Carbon
- Lista de atajos en la barra lateral con estado de registro en tiempo real
- Extra de la barra de menú para ejecutar atajos y volver a abrir la ventana principal
- Página de configuración con **Iniciar al inicio de sesión** y comportamiento de activación de ventanas
- Importación y exportación de atajos y configuraciones globales como un paquete JSON
- Comprobación de actualizaciones dentro de la aplicación y descarga desde GitHub Releases

## Instalación

Descarga el DMG más reciente desde [GitHub Releases](https://github.com/zjy4fun/HotkeyLauncher/releases), ábrelo y arrastra **HotkeyLauncher.app** a la carpeta **Aplicaciones**.

Las 1compilaciones de1 versión están firmadas de forma ad-hoc (sin Apple Developer ID), por lo que tras una descarga desde el navegador, Gatekeeper podría mostrar una advertencia indicando que el desarrollador no puede ser verificado. Haz clic derecho en la aplicación y selecciona **Abrir** una vez, o elimina la marca de cuarentena:

```bash
xattr -dr com.apple.quarantine /Applications/HotkeyLauncher.app
```

La actualización a través de la propia aplicación (Configuración → Actualizaciones → Descargar) no establece la marca de cuarentena, por lo que las actualizaciones dentro de la aplicación se abren sin mostrar la advertencia.

## Compilar y Ejecutar

```bash
./script/build_and_run.sh
```

La aplicación almacena los atajos en:

```text
~/Library/Application Support/HotkeyLauncher/shortcuts.json
```

Las configuraciones globales se almacenan en:

```text
~/Library/Application Support/HotkeyLauncher/settings.json
```

## Configuración

Activa **Nueva ventana cuando no hay ninguna visible** para aplicar el comportamiento a todos los atajos. Cuando una aplicación de destino ya está en ejecución pero no tiene ventanas regulares visibles, HotkeyLauncher la activa y envía `Command+N` para que aplicaciones como Chrome creen una ventana en lugar de parecer que no hacen nada. macOS podría requerir permisos de accesibilidad para que HotkeyLauncher pueda enviar esa tecla.

Usa **Importar** y **Exportar** en la página de configuración para transferir atajos y configuraciones globales entre equipos. El archivo exportado es un paquete JSON que contiene la lista de atajos más las configuraciones a nivel de aplicación.

La sección de Actualizaciones de la página de configuración muestra la versión actual de la aplicación y puede buscar en GitHub Releases una versión más nueva. Las 1compilaciones de1 versión generadas por el flujo de trabajo de1 GitHub incrustan la versión de la etiqueta, suben el DMG y publican metadatos `latest.json` para las comprobaciones de actualización. Las 1compilaciones de1 ramas suben el DMG generado como un artefacto de1 GitHub Actions.

## Atajos predeterminados

- `Option+Command+T` -> `/Applications/FlowDeck.app`
- `Option+Command+C` -> `/Applications/Google Chrome.app`
- `Option+Command+X` -> `/Applications/Codex.app`
- `Option+Command+F` -> `/Applications/Fork.app`
