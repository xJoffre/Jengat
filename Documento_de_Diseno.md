# Documento de Diseño — Jengat (app móvil)

*Versión 1.3 — 23 de junio de 2026*

> **Jengat** = Jenga + gato. El juego mezcla la mecánica clásica de la torre con una temática gatuna que le da identidad propia.

## Estado actual (23 de junio de 2026)

Juego **jugable de principio a fin**, pulido visualmente y **exportable a APK de Android**.

### Ubicación del proyecto

- **Carpeta del proyecto:** `C:\Users\jofre\OneDrive\Escritorio\Proyectos\Jengat`
- **APK de debug generado:** `build\jengat.apk` (≈41 MB, firmado con debug keystore)
- **Editor:** Godot 4.6.3 (`C:\Users\jofre\Downloads\Godot_v4.6.3-stable_win64.exe\…`)
- **Regenerar APK:** `Godot_..._console.exe --headless --path . --export-debug "Android" "build/jengat.apk"` (o botón de exportar en el editor)
- **Requisitos export ya configurados:** Android SDK (`…\AppData\Local\Android\Sdk`), JDK 21, debug keystore (`…\Roaming\Godot\keystores\debug.keystore`), preset `Android` en `export_presets.cfg`.

### Hecho

- **Físicas:** torre 18×3 de `RigidBody3D`, arrastre táctil, órbita de cámara, detección de caída, apilado automático. Ajustada para estabilidad (90 Hz, fricción 0.8, solver 20/8, amortiguación).
- **Lógica:** turnos, reto por bloque, fin de partida, **estadísticas de retos por jugador**.
- **Retos propios + 6 categorías:** pantalla "Mis retos" (añadir/borrar, persisten en `user://custom_challenges.json`); 6 categorías (trago/beso/atrevido/verdad/grupal/especial) con color, emoji e **icono propio** opcional (`assets/icons/<categoria>.png`); en "Mis retos" se listan también los base para no repetir. **Sin repetir retos** entre partidas hasta cerrar la app (pool de sesión en autoload `Custom`).
- **Interfaz:** Splash (sin logo de Godot) con *"powered by : LuchiniStore"*, menú, Configuración (jugadores, sonido, **volumen**), Cómo jugar, aviso +18. Tema oscuro `ui/theme.tres` + fuente **Arcane Nine**. Modal de reto rediseñado (Jugador → icono → categoría → texto → Hecho).
- **Mundo (Low Poly + Dark UI):** cielo nocturno con gradiente, **luna**, **estrellas**, niebla, bosque de pinos, suelo extendido. **4 fogatas** con luz, parpadeo, **brasas** y **humo**. Campamento: troncos para sentarse, rocas, barriles, cajas, arbustos, botellas.
- **Juego/feedback:** resaltado del bloque al agarrar, **polvo** al extraer, **sacudida de cámara** por tensión creciente, **vibración** (leve al extraer, fuerte al caer), **confeti** y "✔ RETO COMPLETADO" al cumplir.
- **Audio:** música/ambiente por escena + SFX cableados (autoload `Audio`), volumen sobre bus Master, pausa la música durante burlas.
- **Burlas al perder:** imagen o video `.ogv` al azar desde `assets/burlas/`.
- **Almacenamiento:** sonido y volumen en `user://settings.cfg`; retos propios en `user://custom_challenges.json`.
- **`challenges.json` re-etiquetado** con las 6 categorías reales (cada bloque lleva su campo `category`).
- **Navegación Android:** botón/gesto **Atrás** (cierra modales, vuelve al menú, confirma salida).
- **Render:** **Compatibility (OpenGL)** para evitar corrupción/lag en gama baja (a cambio, sin glow real).

### Pendiente

**Necesita archivos del usuario (ya cableado, solo soltar):**
- **Sonidos** en `assets/sounds/`: `remove.mp3`, `fall.mp3`, `challenge.mp3`, `reward.mp3` (ambiente y música del menú ya están). Opcionales: `select.mp3`, `creak.mp3` (pedir cableado).
- **Iconos** de categoría en `assets/icons/` (`trago/beso/atrevido/verdad/grupal/especial.png`) — si no, se usa el emoji.
- **Videos de burla** convertidos a `.ogv` (Godot no reproduce `.mp4`).

**Decisiones de contenido/técnicas:**
- **Glow real / nubes lentas** → exigirían volver al renderer Mobile (reaparece corrupción en gama baja).
- **Mascota gato animada** y detalles gatunos (Fase 4 del diseño original).
- Sonido en botones de UI; música de fogata opcional en el menú.

**Verificación/publicación:**
- Confirmar en **APK exportado** el escaneo de `assets/burlas/` y `assets/icons/` (en editor funciona).
- Afinar a ojo posiciones de props y la intensidad de partículas/sacudida en dispositivos reales.
- Publicación en Google Play (build release firmado con keystore propio, no el de debug).

## 1. Visión del proyecto

**Jengat** es una app móvil para juegos de fiesta que simula una torre de Jenga con físicas reales y una vuelta de tuerca gatuna. Los jugadores se turnan para sacar bloques de la torre; cada vez que se saca un bloque con éxito, la app muestra un reto o acción que el jugador debe cumplir. Si la torre se cae, la partida termina y ese jugador "pierde" (o paga la prenda final).

El juego está pensado para **un solo dispositivo que se pasa entre jugadores** por turnos. No hay multijugador en red ni cuentas de usuario: la app vive entera en el teléfono.

### Decisiones ya tomadas

- **Modo de juego:** un dispositivo, pasar el móvil por turnos.
- **Asignación de retos:** **reto fijo por bloque** (modo mixto). Cada uno de los 54 bloques tiene su reto grabado, como en un Jenga de beber real. Algunos bloques son **comodines** con efectos especiales (a salvo, vuelve a tirar, redirigir la bebida, hidrátate).
- **Torre:** 54 bloques clásicos = 18 niveles de 3. Cada nivel tiene un bloque izquierdo, uno central y uno derecho; el mazo (`data/challenges.json`) está organizado en esas tres columnas de 18 (25 retos, 23 tragos, 6 comodines).
- **Tono de los retos:** picante / solo adultos.
- **Estilo visual:** realista, bloques con textura de madera estilo Jenga clásico, con detalles gatunos (ver sección 1.1).
- **Almacenamiento:** archivo local en el dispositivo (poca información, ver sección 6).

### 1.1 Temática gatuna

El toque felino es lo que diferencia a **Jengat** de un Jenga normal. Ideas para integrarlo (a elegir y dosificar según cuánto protagonismo se le quiera dar):

- **Mascota gato.** Un gato presente en el menú y en la partida que reacciona: ronronea cuando sacas un bloque limpio, se asusta cuando la torre tiembla, y "tira" la torre con la patita en la pantalla de derrota.
- **Bloques con detalle gatuno.** Textura de madera realista con grabados de huellas, siluetas de gato o algún bloque especial marcado con una patita.
- **Bloque especial "garra".** De vez en cuando aparece un bloque marcado; sacarlo activa un reto gatuno especial o un comodín (ej. "elige a quién le toca beber").
- **Sonido y feedback.** Maullidos y ronroneos como efectos de sonido; un "miau" de alerta cuando la torre está a punto de caer.
- **Estética e idioma.** Logo de **Jengat** con orejas/bigotes de gato, y retos con vocabulario felino ("ronronea", "saca las garras", etc.).

Para la primera versión conviene empezar con lo barato y vistoso (logo gatuno + algún sonido) e ir añadiendo la mascota animada en la fase de arte.

## 2. Stack tecnológico

| Componente | Elección | Por qué |
|---|---|---|
| Motor | **Godot 4.6** | Gratuito y open source; integra render 3D, físicas, interfaz y exportación a móvil en una sola herramienta. |
| Lenguaje | **GDScript** | Sencillo de aprender (similar a Python), perfecto para empezar. Cubre físicas, interfaz y lógica con un solo lenguaje. |
| Motor de física | **Jolt** (integrado en Godot 4.6) | Motor moderno de cuerpos rígidos. Las pilas de bloques no tiemblan, ideal para una torre de Jenga estable y realista. |
| Almacenamiento | Archivo **JSON local** (`FileAccess` / `user://`) | Equivalente al almacenamiento por defecto del móvil. Suficiente para guardar retos y configuración. |
| Plataforma objetivo | **Android primero**, iOS después | Android es más fácil de exportar y probar al empezar. |

Todo el proyecto (torre 3D, interfaz, menús, lógica) se construye dentro del mismo editor de Godot. No se usan lenguajes ni herramientas externas.

## 3. Físicas de la torre

El reto técnico central del proyecto es que la torre se sienta como un Jenga real. Con el motor Jolt esto es muy abordable:

- La torre estándar son **54 bloques** apilados en 18 niveles de 3 bloques cada uno, alternando la orientación 90° en cada nivel.
- Cada bloque es un **cuerpo rígido** (`RigidBody3D`) con su forma de colisión, masa, fricción y rebote configurados para imitar la madera.
- El jugador **arrastra** un bloque con el dedo para sacarlo; el resto de la torre reacciona en tiempo real (puede ceder, inclinarse o caer).
- La detección de "torre caída" se hace midiendo cuántos bloques se han movido o caído por debajo de un umbral de altura, o detectando una caída brusca de varios bloques.

Recomendaciones de afinado (para la fase de pulido):

- Subir las *iteraciones de velocidad* de Jolt a 12–16 si la torre se nota poco estable.
- Ajustar fricción y masa hasta que sacar una pieza requiera "puntería" sin ser frustrante.
- Empezar con una torre que reacciona y se puede tumbar; refinar el realismo poco a poco. Una simulación perfecta es difícil incluso para estudios con experiencia, así que conviene iterar.

## 4. Estructura del proyecto

Organización de carpetas propuesta dentro del proyecto Godot:

```
Jengat/
├── project.godot
├── scenes/
│   ├── Splash.tscn          # pantalla de arranque (logo)
│   ├── MainMenu.tscn        # menú principal: Jugar, Configuración, Cómo jugar
│   ├── Game.tscn            # escena de partida (torre 3D + interfaz)
│   ├── Tower.tscn           # la torre y los 54 bloques
│   ├── Block.tscn           # un bloque individual (RigidBody3D)
│   └── GameOver.tscn        # pantalla de fin de partida
├── scripts/
│   ├── game_manager.gd      # turnos, estado de partida, fin de juego
│   ├── challenge_deck.gd    # carga el mazo y resuelve el reto fijo de cada bloque
│   ├── block.gd             # arrastre e interacción de cada bloque
│   ├── tower.gd             # construcción y chequeo de caída de la torre
│   └── storage.gd           # leer/escribir el archivo local (retos, config)
├── data/
│   └── challenges.json      # mazo de retos por defecto
├── assets/
│   ├── textures/            # textura de madera de los bloques
│   ├── sounds/              # efectos (caída, sacar bloque, ambiente)
│   └── ui/                  # imágenes de interfaz, logo
└── ui/
    └── theme.tres           # tema visual de la interfaz
```

## 5. Escenas y flujo de juego

El juego es una secuencia de escenas, todas dentro del mismo proyecto:

1. **Splash (arranque).** Logo del juego durante 1–2 segundos. Godot tiene un splash de arranque integrado además de esta pantalla personalizada.
2. **Menú principal.** Título, botón **Jugar**, **Configuración** (número de jugadores, sonido) y **Cómo jugar**. Aviso de "solo para adultos" por el tono de los retos.
3. **Partida.** En el fondo, la torre 3D de Jenga; encima, una capa de interfaz con el turno actual y los nombres de los jugadores. El jugador arrastra un bloque para sacarlo.
4. **Reto.** Al sacar un bloque con éxito, aparece una tarjeta con el reto **fijo de ese bloque**. Si es un bloque **comodín**, en vez de un reto se aplica su efecto especial (a salvo, vuelve a tirar, redirigir la bebida, hidrátate). El jugador cumple y pulsa "Hecho" para pasar el turno.
5. **Fin de partida.** Si la torre cae, se muestra quién la tiró y se ofrece "Jugar otra vez" o "Volver al menú".

Flujo de un turno:

```
Turno del jugador → arrastra y saca un bloque
   ├── la torre cae      → Fin de partida
   └── bloque fuera      → leer reto FIJO del bloque
         ├── tipo reto/trago → mostrar tarjeta → "Hecho" → siguiente jugador
         └── tipo comodín    → aplicar efecto especial → siguiente jugador
```

## 6. Modelo de datos y almacenamiento

Se guarda muy poca información de forma permanente. Todo cabe en un archivo de texto de unos pocos kilobytes en el almacenamiento del dispositivo (`user://` en Godot).

**Lo que se guarda (permanente):**

- El **mazo de retos** (texto de cada reto y su intensidad).
- **Configuración**: número de jugadores, nombres, sonido on/off, idioma.
- Opcional: **mazos personalizados** que cree el usuario.

**Lo que NO se guarda (vive solo en memoria durante la partida):**

- Estado de la torre (qué bloques se han sacado, posiciones).
- Turno actual.

Esto se reinicia en cada partida nueva, así que no ocupa almacenamiento. Si más adelante se quiere "reanudar partida", se guardaría un pequeño snapshot temporal, pero para un juego de fiesta normalmente no hace falta.

### Formato del mazo de retos (`challenges.json`)

El mazo asigna un reto **fijo** a cada bloque, organizado en tres columnas (izquierda / central / derecha) de 18, una por posición dentro de cada nivel. Cada bloque tiene un `type` (`trago`, `reto` o `comodin`); los comodines llevan además un campo `effect` con su mecánica.

```json
{
  "version": 3,
  "deck_name": "Jengat — Picante (adultos)",
  "assignment_mode": "mixto",
  "total_blocks": 54,
  "columns": {
    "izquierda": [
      { "pos": 1, "text": "Dale una nalgada a alguien", "type": "reto" },
      { "pos": 4, "text": "Derecha → bebe", "type": "comodin", "effect": "redirige_derecha" }
    ],
    "central":  [ { "pos": 1, "text": "Shot", "type": "trago" } ],
    "derecha":  [ { "pos": 12, "text": "¡Todos beben!", "type": "trago" } ]
  }
}
```

Efectos de los comodines: `vuelve_a_tirar` (turno extra), `redirige_derecha` / `redirige_izquierda` (otro bebe en tu lugar), `a_salvo` (sin penalización), `hidratate` (bebes agua). El archivo completo está en `data/challenges.json`.

## 7. Plan por fases

El proyecto se construye de forma incremental, validando lo más difícil (las físicas) primero.

**Fase 0 — Preparación.** Instalar Godot 4.6, crear el proyecto, configurar la exportación a Android. Probar un "hola mundo" en el teléfono.

**Fase 1 — Físicas (lo más importante).** Crear un bloque con física, montar la torre de 54 bloques, conseguir arrastrar y sacar un bloque con el dedo, y detectar cuándo la torre cae. Sin interfaz ni retos todavía; solo que la torre se sienta bien.

**Fase 2 — Lógica de juego.** Sistema de turnos, mostrar el turno actual, detectar bloque sacado, cargar el mazo y mostrar un reto al azar, pantalla de fin de partida.

**Fase 3 — Interfaz y pantallas.** Splash, menú principal, configuración (jugadores, sonido), pantalla de "cómo jugar", tarjeta de reto. Aviso de contenido adulto.

**Fase 4 — Arte y pulido (incluye lo gatuno).** Textura de madera realista con detalles felinos, logo de Jengat, mascota gato animada que reacciona, sonidos (sacar bloque, caída, maullidos/ronroneos), afinar las físicas, animaciones de transición.

**Fase 5 — Almacenamiento y extras.** Guardar configuración y mazos. Opcional: que el usuario añada sus propios retos.

**Fase 6 — Pruebas y publicación.** Probar en varios teléfonos, ajustar rendimiento, preparar la publicación en Google Play.

## 8. Riesgos y consideraciones

- **Realismo de las físicas:** es lo más difícil. Plan: empezar simple e iterar; Jolt facilita mucho la parte de estabilidad.
- **Control táctil:** sacar un bloque con el dedo debe sentirse preciso. Habrá que probar y ajustar la sensibilidad del arrastre.
- **Contenido adulto:** al ser picante/solo adultos, conviene una pantalla de aviso de edad y, para publicar en tiendas, marcar la clasificación de contenido adecuada.
- **Rendimiento en móviles modestos:** 54 cuerpos rígidos es poco para Jolt, pero hay que probar en teléfonos de gama baja.

## 9. Próximos pasos

1. Instalar Godot 4.6 y crear el proyecto vacío con esta estructura de carpetas.
2. Arrancar la **Fase 1**: el primer bloque con física y la torre.
3. Ir completando el mazo de retos (hay un mazo inicial de ejemplo junto a este documento).
```
