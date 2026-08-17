# PixelDuel — prototipo técnico (v0.0.1)

Prototipo de duelo 1vs1 "pasa el móvil": un bucket de pruebas del que se
eligen N al azar. Cada jugador representa un equipo con varios
"participantes" (nº configurable antes de empezar) que juegan la misma
prueba por turnos; sus resultados se combinan según el tipo de la prueba
y se comparan contra el otro jugador.

## Cómo abrirlo

1. Instala Godot 4.3+ (https://godotengine.org/download).
2. Abre el editor → "Import" → selecciona la carpeta del proyecto (el
   fichero `project.godot`).
3. Pulsa Play (F5). `scenes/Main.tscn` es la escena principal.

No hay assets de arte reales: los minijuegos usan `ColorRect` como
placeholder. El aspecto "pixel" viene de la resolución base baja
(216x384, portrait, ver `project.godot`) con stretch mode `viewport` y
filtro de textura `Nearest` — cuando haya sprites reales, con pixel art a
esa resolución ya se verá correcto sin configuración extra.

## Estructura

```
project.godot
scripts/
  autoload/MatchManager.gd   # bucket, participantes, turnos, rondas (autoload singleton)
  minigames/MinigameBase.gd  # interfaz que debe extender cada prueba
  minigames/*.gd             # las 17 pruebas (ver tabla abajo)
  ui/Main.gd                 # máquina de estados + bucle de intentos por participante
scenes/
  Main.tscn
  minigames/*.tscn
```

## Cómo funciona una partida

1. **Participantes configurables** — de 1 a 5 por jugador, ajustable en
   el menú antes de empezar. Sus intentos se combinan según el tipo de
   la prueba (mejor, media, éxitos, suma).
2. **Semillas compartidas por ronda** — cada prueba de cada ronda se
   sortea una vez y se reutiliza para los dos jugadores y todos sus
   participantes, así el elemento aleatorio (si lo hay) es idéntico para
   todos: gana quien juegue mejor, no quien tuvo mejor suerte con el
   generador aleatorio.
3. **Handoff con resultado a batir** — al pasar el móvil del Jugador 1 al
   Jugador 2 se muestra el resultado que hay que superar en esa prueba.
4. **Duración exportable** — la duración de cada prueba cronometrada es
   un parámetro ajustable desde el editor (`@export var duration_max`),
   no un número fijo en el código.
5. **Selección sin repetir categoría** — de las 5 pruebas de una
   partida, el selector evita repetir categoría de mecánica mientras
   queden categorías libres (hay 10), para que una partida no se sienta
   "machaca la pantalla" varias veces seguidas.

## Los 4 tipos de agregación

Cada prueba declara su tipo con `get_aggregation_type()`. Con N
participantes por jugador, cada uno juega la prueba una vez y sus
resultados se combinan según el tipo:

| Tipo | Cómo se combinan los N intentos | Sensación |
|---|---|---|
| `best` | Se queda el mejor resultado (0-100) | Un crack puede salvar al equipo |
| `average` | Se promedian los resultados (0-100) | Premia que todo el equipo sea bueno |
| `success_count` | Cada intento es pasa/no pasa; se cuentan los éxitos | Todo o nada, tipo "cuántos cruzan" — dentro del intento suele haber varios pasos encadenados (troncos, obstáculos, ráfagas) y fallar uno solo ya lo acaba, para que no sea un único tap trivial |
| `collect_sum` | Cada intento aporta unidades; se suman todas | Recolección, tipo "cuántos objetos se cogen entre todos" |

## Las 10 categorías de mecánica

Un eje distinto al tipo: no es "cómo puntúa", es "qué gesto usas". Cada
prueba declara la suya con `get_mechanic_category()`.

| Categoría | Nº | Pruebas |
|---|---|---|
| `spam_toques` | 2 | Carrera de sacos, La cucaña |
| `carga_suelta` | 2 | La rana, Canastas |
| `reaccion` | 2 | El pañuelo, Caza al topo |
| `timing_objetivo` | 2 | Cruzar el río de troncos, Morder la manzana |
| `equilibrio` | 2 | Transporte del cubo de agua, Cuerda floja |
| `arrastre` | 2 | Huevo en la cuchara, Pesca de patos |
| `swipe` | 2 | Carrera de obstáculos, Bolos |
| `memoria` | 1 | Memoria de banderines |
| `ritmo` | 1 | Máquina de baile |
| `flippers` | 1 | Petaco |

## Pruebas en el bucket

| Prueba | Script | Tipo | Categoría | Duración | Mecánica |
|---|---|---|---|---|---|
| La rana | `FrogGame.gd` | `best` | `carga_suelta` | — | Cargar potencia (oscila) y soltar sobre un tablero con zonas de distinto valor (boca 50, molino 25, puente 10, resto 5) |
| El pañuelo | `Handkerchief.gd` | `best` | `reaccion` | — | Reacción con anticipación: esperar la señal sin tocar y tocar lo antes posible — falsa salida si tocas antes de tiempo |
| Carrera de sacos | `SackRace.gd` | `average` | `spam_toques` | 5s | Tap alterno izquierda/derecha, cuenta velocidad |
| Memoria de banderines | `FlagMemory.gd` | `average` | `memoria` | — | Repetir secuencia de colores, crece cada ronda (Simon) |
| Huevo en la cuchara | `EggAndSpoon.gd` | `average` | `arrastre` | 6s | Arrastrar para seguir un objetivo que se mueve solo |
| Transporte del cubo de agua | `WaterBucket.gd` | `average` | `equilibrio` | 8s | Tocar "estabilizar" con cooldown — el spam no ayuda |
| Cruzar el río de troncos | `RiverCrossing.gd` | `success_count` | `timing_objetivo` | — | Camino de 5 troncos seguidos, tocar en el pico de estabilidad de cada uno — fallar uno te cae al río y acaba el intento |
| Carrera de obstáculos | `ObstacleRun.gd` | `success_count` | `swipe` | — | Fila de 5 obstáculos cada vez más rápidos, swipe hacia arriba (salto de verdad) justo al cruzar la línea — un swipe flojo/torcido o mal timing te hace tropezar y acaba el intento |
| Cuerda floja | `TightropeWalk.gd` | `success_count` | `equilibrio` | 6s | Ráfagas de viento aleatorias, corregir tocando el lado opuesto a la inclinación |
| Caza al topo | `MoleWhack.gd` | `collect_sum` | `reaccion` | 7s | Tablero de 6 agujeros; un topo asoma al azar un instante, tócalo antes de que se esconda — importa dónde tocas, no solo cuántas veces |
| Pesca de patos | `DuckFishing.gd` | `collect_sum` | `arrastre` | 8s | Arrastrar cesta para atrapar patos que caen |
| La cucaña | `GreasyPole.gd` | `collect_sum` | `spam_toques` | 5s | Tocar sin parar para trepar y coger premios antes de resbalar |
| Morder la manzana | `AppleBite.gd` | `collect_sum` | `timing_objetivo` | 7s | Manzana que se balancea sola, tocar en el centro con cooldown por toque — cuenta los mordiscos conseguidos |
| Bolos | `Skittles.gd` | `collect_sum` | `swipe` | — | Swipe de lanzamiento: precisión del ángulo y potencia determinan cuántos bolos caen |
| Canastas | `Basketball.gd` | `collect_sum` | `carga_suelta` | 7s | Cargar potencia y soltar para tirar a un aro que cambia de sitio en cada tiro — encesta tantas veces como puedas antes de que se acabe el tiempo |
| Máquina de baile | `DanceMachine.gd` | `collect_sum` | `ritmo` | 8s | 4 carriles, las notas caen hacia una línea — toca el carril correcto justo cuando la cruzan. A diferencia de Memoria (memorizar y repetir después), aquí reaccionas en directo a varios carriles a la vez |
| Petaco | `Pinball.gd` | `collect_sum` | `flippers` | 14s | Cargar y soltar para lanzar la bola; mantén pulsado el lado izq./der. para levantar ese flipper y no dejarla caer por el hueco central. Única prueba con física de rebote de verdad (gravedad, topes, paredes) — el resto son temporizador + input |

Las 5 pruebas de fiestas de pueblo / recreativos clásicas (La rana, El
pañuelo, Morder la manzana, Bolos, Canastas) y las 2 de salón recreativo
(Máquina de baile, Petaco) están inspiradas en juegos populares reales de
España (tradición libre / género genérico de arcade, sin marca ni
copyright asociado).

La "Duración" es el `@export var duration_max` de cada script — se puede
ajustar por escena desde el Inspector de Godot sin tocar código; las que
no la tienen no se basan en un cronómetro fijo (terminan por otra
condición: falsa salida, cruzar todos los pasos, bola perdida, etc.).

## Semillas compartidas por ronda

`MatchManager` genera una `_round_seed` nueva cada vez que empieza una
ronda (`_start_round()`) y la expone vía `current_round_seed()`. Antes de
lanzar cada intento, `Main.gd` llama a
`instance.set_round_seed(MatchManager.current_round_seed())`, que
inicializa el `rng: RandomNumberGenerator` de `MinigameBase` con esa
seed. Las pruebas con algún elemento aleatorio (retraso de El pañuelo,
ráfagas de Cuerda floja, secuencia de Memoria de banderines, duración de
cada tronco en Río, posición de los patos/notas, fase del balanceo en
Huevo/Manzana, posición del aro en Canastas...) leen de `rng` en vez de
`randf()`/`randi()` globales — así los dos jugadores (y todos sus
participantes) se enfrentan exactamente al mismo patrón en esa ronda, y
la comparación es de habilidad, no de quién tuvo mejor suerte con el
generador aleatorio.

## Handoff con resultado a batir

La pantalla "pasa el móvil" entre el Jugador 1 y el Jugador 2 ahora
muestra el resultado agregado que dejó el Jugador 1 en esa prueba
(`MatchManager.get_round_score(1)`, formateado con el mismo
`_format_value()` que usa el resultado de ronda), para que el Jugador 2
sepa qué tiene que batir antes de empezar.

## Configuración de participantes

`MatchManager.participants_per_player` (por defecto 3, ajustable de 1 a 5
con los botones -/+ del menú) define cuántas veces juega cada jugador
cada prueba antes de combinarse en un resultado de ronda.

## Flujo de una partida

1. Menú → ajustar nº de participantes → "Jugar" → `MatchManager.start_match()`
   elige `ROUNDS_TOTAL` (5 de las 17 disponibles) pruebas del bucket, sin
   repetir categoría mientras queden libres.
2. Por cada ronda y jugador: pantalla "pasa el móvil al Jugador X" (con
   el resultado a batir si es el Jugador 2) → "Listo" → se repite
   `participants_per_player` veces: "Empezar"/"Siguiente participante" →
   se instancia la prueba (con la seed de la ronda) → llama a
   `_finish(valor)` → vuelve a la intro hasta agotar los intentos.
3. `Main.gd` combina los N valores según el tipo de la prueba y envía el
   resultado a `MatchManager.submit_score()`.
4. Se comparan los resultados agregados de la ronda, se muestra quién
   gana y se pulsa "Siguiente".
5. Al completar todas las rondas se muestra el marcador final (rondas
   ganadas por cada jugador).

## Añadir una prueba nueva al bucket

1. Crea `scripts/minigames/MiPrueba.gd` extendiendo `MinigameBase`.
2. Sobreescribe `get_aggregation_type()` (`"best"` / `"average"` /
   `"success_count"` / `"collect_sum"`) y, si es `collect_sum`,
   `get_unit_label()`.
3. Sobreescribe `get_mechanic_category()` con la etiqueta que mejor
   describa el gesto (reutiliza una de las 10 existentes si encaja, o
   añade una nueva si es un gesto realmente distinto).
4. Si tiene algo aleatorio, léelo de `rng` (heredado de `MinigameBase`,
   ya sembrado) en vez de `randf()`/`randi()` globales.
5. Si tiene un cronómetro fijo, expónlo como `@export var duration_max`
   en vez de una `const`, para poder ajustarlo desde el Inspector.
6. Implementa tu mecánica en `_ready()` / `_process()` / input, y llama a
   `_finish(valor)` una vez decidido el resultado de un único intento
   (0-100 para `best`/`average`, 1.0/0.0 para `success_count`, unidades
   sueltas para `collect_sum`).
7. Crea la escena `scenes/minigames/MiPrueba.tscn` igual que cualquiera
   de las existentes (nodo raíz `Control` con el script asignado, ver
   `scenes/minigames/SackRace.tscn` como plantilla).
8. Añade `preload("res://scenes/minigames/MiPrueba.tscn")` al array
   `bucket` en `scripts/autoload/MatchManager.gd`.

No hace falta tocar nada más: el selector aleatorio, el reparto de
categorías, la seed por ronda, el bucle de participantes y la agregación
ya cuentan la prueba nueva automáticamente.

## Pendiente para después de probar v0.0.1

Nada de esto bloquea la primera prueba de verdad en el móvil — son
ajustes que solo tienen sentido con feedback real de jugar.

- **Petaco — multitouch sin probar.** Los flippers usan multitouch real
  (un dedo por lado, vía `event.index`) — con ratón en el editor solo se
  puede probar un flipper cada vez. Hasta que no se pruebe en un móvil
  de verdad no se sabe si los dos responden bien a la vez.
- **Petaco — física a ojo.** Gravedad, fuerza de los flippers, tamaño de
  los topes: es la única prueba con simulación real en vez de
  temporizador + input, así que es la que más margen de desajuste tiene
  de las 17.
- **Mejor intento — zona objetivo.** La rana tiene zona (se podría
  estrechar la zona de más valor en el 2º/3er participante para que
  "quedarte con el mejor" no sea trivial a la primera). Canastas ya
  varía el aro de sitio en cada tiro, así que ya tiene su propia
  dificultad. El pañuelo queda fuera de ambas ideas: no tiene zona,
  tiene una ventana de tiempo.
- **Cuenta de éxitos.** El nº de pasos del camino (troncos, obstáculos)
  podría escalar con la ronda de la partida, para que las rondas finales
  aprieten más.
- **Balance general.** Los umbrales de las 17 pruebas (estabilidad
  mínima, ventana de acierto, velocidad de tambaleo, tiempo de reacción
  máximo…) están puestos a ojo — hace falta jugar de verdad en el móvil
  para ajustarlos.
- **Feedback.** Sonido y haptics ayudarían en toda la app, pero
  especialmente en El pañuelo (reacción pura sin señal auditiva es raro
  de jugar bien), Máquina de baile (un juego de ritmo sin música es un
  contrasentido) y los fallos de "cuenta de éxitos".

## Qué falta para dejar de ser un prototipo

- Arte pixel real (sprites/animaciones) en vez de `ColorRect`.
- Sonido/feedback (haptics al tocar, sonido de acierto/fallo).
- Pulido de UI (tipografía pixel, transiciones entre paneles).
- Exportar a Android/iOS (presets de exportación de Godot) y probar en
  dispositivo real — el input táctil está contemplado
  (`InputEventScreenTouch`) pero solo se ha podido probar la lógica, no
  el dispositivo.

## Aviso

Este prototipo se ha escrito directamente como proyecto Godot (código y
escenas en texto), pero no se ha podido ejecutar el editor de Godot para
probarlo en vivo. Revísalo abriendo el proyecto antes de darlo por
bueno — probablemente haga falta algún ajuste menor de layout/tamaños al
verlo en pantalla, y especialmente probar Petaco en un dispositivo real
por el tema del multitouch.
