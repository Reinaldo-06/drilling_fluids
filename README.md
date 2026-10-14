# drilling_fluids — Ingeniero de Fluidos

Juego 2D pixelado en **Godot 4.7.2** donde el jugador es un ingeniero de fluidos de perforación. Contexto completo, decisiones y documentos de diseño en [`CLAUDE.md`](CLAUDE.md) y [`docs/`](docs/).

## Estructura

| Carpeta | Contenido |
|---|---|
| `sim/` | Simulación pura (sin escena): fórmulas, estado del lodo, tanques. Se prueba sin abrir el juego |
| `data/` | Resources de datos: contaminantes, pruebas, sistemas de lodo, pozos |
| `game/` | Escenas y presentación: overworld, interfaz |
| `assets/` | Sprites, tiles, sonidos |
| `tests/` | Pruebas de la simulación |
| `docs/` | Diseño e investigación |

## Correr las pruebas

```
godot --headless --path . --script res://tests/run_tests.gd
```

Sale con código 0 si todo pasa y 1 si algo falla. Cada archivo `tests/test_*.gd` extiende `tests/test_case.gd` y define métodos `test_*`. Los casos de `test_formulas.gd` son los ejemplos numéricos de los documentos de `docs/`.
