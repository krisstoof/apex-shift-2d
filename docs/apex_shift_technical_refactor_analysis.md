# Apex Shift 2D — analiza techniczna, uproszczenie architektury i plan optymalizacji FPS/stutteringu

## 1. Cel dokumentu

Ten dokument jest analizą techniczną obecnego prototypu **Apex Shift 2D** na podstawie przekazanego przeglądu aplikacji. Skupia się na trzech obszarach:

1. znalezieniu słabych punktów architektury,
2. uproszczeniu systemów tak, aby zyskać modularność,
3. rozwiązaniu problemów z niskim FPS i stutteringiem.

Najważniejszy wniosek: obecny prototyp jest funkcjonalny, ale zaczyna mieć typowy problem rosnącego projektu Godot — zbyt wiele systemów samodzielnie odpytuje świat, skanuje grupy, przebudowuje cache, robi `queue_redraw()` i synchronizuje stan po swojemu. Nie wygląda to jak jeden błąd wydajnościowy, tylko jak suma powtarzalnych kosztów wykonywanych w wielu miejscach.

---

## 2. Diagnoza wysokiego poziomu

Obecna aplikacja ma dobrą bazę gameplayową, ale architektura jest już blisko punktu, w którym dalsze dodawanie funkcji będzie coraz droższe. Największe ryzyka to:

- `World` jest jednocześnie generatorem świata, rendererem, hostem symulacji, właścicielem zasobów, synchronizatorem stworzeń, punktem zapisu/odczytu i pośrednikiem dla UI.
- `Player` robi nie tylko ruch i walkę, ale też crafting, interakcje, odczyty świata, aktualizację survival stats, skanowanie ognisk i emisję eventów.
- `HUD`, `Minimap`, `MapScreen` i `DebugPanel` każdy na własną rękę odczytuje część świata i buduje własne cache.
- `EcosystemDirector` i `World` mają dualny model rzeczywistości: ekosystem abstrakcyjny oraz widzialne obiekty. To jest sensowne projektowo, ale obecnie synchronizacja idzie zarówno eventami, jak i okresowymi skanami.
- Systemy UI i debugowe działają zbyt często jak na dane, które nie muszą odświeżać się w każdej klatce.
- Część zależności idzie przez node path, część przez autoloady, część przez `get_tree().current_scene`, część przez grupy. To utrudnia refaktor i zwiększa koszt lookupów.

W skrócie: gra potrzebuje **warstwy pośredniej między światem a konsumentami danych** oraz **twardego rozdzielenia symulacji, renderingu i prezentacji**.

---

## 3. Najbardziej prawdopodobne źródła niskiego FPS i stutteringu

### 3.1. Zbyt dużo pracy w `_process()` i `_physics_process()`

W przeglądzie widać, że kilka systemów działa co klatkę albo prawie co klatkę:

- `Player._physics_process()` co tick fizyki: ruch, zapytania o teren/wodę, skan ognisk, survival stats.
- `World._process()` co klatkę: spawn timery, sync stworzeń, redraw świata.
- `HUD._process()` co klatkę, rebuild tekstu co 0.10 s.
- `DebugPanel._process()` co klatkę, rebuild tekstu co 0.15 s.
- `Minimap._process()` redraw co 0.20 s, resource cache co 0.5 s.
- `MapScreen._process()` redraw każdej klatki, gdy mapa jest otwarta.

To oznacza, że gra nie ma jednego budżetu na klatkę. Każdy system bierze trochę czasu dla siebie, ale suma tych drobnych kosztów może powodować spadki FPS i mikroprzycięcia.

**Rekomendacja:** wprowadzić centralny `UpdateScheduler`, który kontroluje, jak często systemy mogą wykonywać kosztowne prace.

Docelowe kadencje:

| Obszar | Obecnie | Docelowo |
|---|---:|---:|
| Ruch gracza | physics tick | zostawić |
| Survival stats | physics tick | zostawić lub 5–10 Hz, jeśli nie wymaga ticka fizyki |
| Skan ognisk | physics tick | 2–4 Hz albo event/collision area |
| HUD główny | co 0.10 s | event-driven + fallback 4 Hz |
| FPS label | co 0.25–0.5 s | 2–4 Hz |
| Debug panel | co 0.15 s | 1–2 Hz, tylko gdy panel widoczny |
| Minimap | co 0.20 s | 2–3 Hz albo tylko po zmianie gracza/świata |
| Full map | każda klatka | redraw tylko po otwarciu i po zmianach danych |
| Ecosystem tick | 5 s | zostawić, ale agregacje rozłożyć na porcje |
| Visible creature sync | w `World._process()` | scheduler / chunked update |

---

### 3.2. Powtarzane skany grup

Najbardziej podejrzany przykład to `Player._update_campfire_regen_state()`, który skanuje pełną grupę `campfires` w każdym physics ticku. Nawet jeśli ognisk jest mało, taki wzorzec łatwo rozlewa się na kolejne systemy.

W przeglądzie pojawia się też cache grup w `World.get_cached_group_nodes()` z TTL 0.12 s, ale jednocześnie wiele systemów nadal wykonuje równoległe odczyty tych samych grup. To znaczy, że cache częściowo maskuje problem, ale go nie rozwiązuje.

**Rekomendacja:** zastąpić skany grup rejestrami domenowymi.

Proponowane rejestry:

```text
WorldRegistry
├── resources_by_kind
├── resources_by_biome
├── creatures_by_type
├── creatures_by_biome
├── buildings_by_type
├── campfires
├── landmarks
└── dirty_flags
```

Zamiast:

```gdscript
get_tree().get_nodes_in_group("campfires")
```

lepiej mieć:

```gdscript
world_registry.get_campfires_near(player_position, radius)
```

Jeszcze lepiej: dla ognisk użyć `Area2D` wokół campfire i sygnałów `body_entered/body_exited`, dzięki czemu gracz nie musi skanować niczego co klatkę.

---

### 3.3. UI samodzielnie odczytuje świat

`HUD`, `Minimap`, `MapScreen` i `DebugPanel` tworzą własne cache oraz wykonują własne odczyty. To zwiększa niezależność UI, ale koszt wydajnościowy rośnie wraz z liczbą widoków.

Problem nie jest tylko wydajnościowy. To także problem architektoniczny: każdy widok zaczyna mieć własną interpretację świata.

**Rekomendacja:** dodać jedną warstwę `WorldSnapshotService` albo `PresentationModel`.

Przykład:

```text
World / Ecosystem / Player
        ↓
WorldSnapshotService
        ↓
HUDViewModel
MinimapViewModel
MapScreenViewModel
DebugViewModel
```

`WorldSnapshotService` raz na określoną kadencję buduje dane prezentacyjne:

- pozycja gracza,
- lista widocznych zasobów uproszczona do markerów,
- lista stworzeń uproszczona do markerów,
- landmarks,
- stan biome/ecosystem,
- liczby do debug panelu,
- statystyki do HUD.

UI nie powinno skanować świata. UI powinno konsumować gotowy snapshot.

---

### 3.4. Full map odświeża się każdą klatkę

`MapScreen` redrawuje każdą klatkę, gdy jest widoczny. To jest bardzo prawdopodobne źródło stutteringu, szczególnie jeśli mapa rysuje:

- biomy,
- zasoby,
- stworzenia,
- landmarki,
- legendę,
- teksty,
- statystyki,
- Varnak profile.

**Rekomendacja:** mapa powinna być prawie statyczna.

Docelowy model:

- po otwarciu mapy: jeden pełny redraw,
- jeśli gracz się porusza: aktualizować tylko marker gracza,
- jeśli zmieniły się zasoby/stworzenia: aktualizować tylko warstwę markerów,
- jeśli zmienił się teren/landmarki: aktualizować warstwę tła,
- jeśli mapa jest zamknięta: zero pracy.

Podział mapy na warstwy:

```text
MapScreen
├── TerrainLayer        # biomy, ponds, hills — rzadko zmieniane
├── ResourceLayer       # zasoby — zmieniane okresowo/event-driven
├── CreatureLayer       # stworzenia — zmieniane 1–2 Hz
├── PlayerLayer         # marker gracza — częściej, ale tani
└── TextLayer           # legenda/statystyki — tylko po zmianie
```

---

### 3.5. Minimap i mapa mają osobne cache

Minimap i full map przechowują osobne cache zasobów i osobno czytają landmarki. To tworzy podwójną pracę i ryzyko niespójności.

**Rekomendacja:** `MapDataProvider` jako wspólne źródło danych dla minimapy i mapy.

```text
WorldSnapshotService
      ↓
MapDataProvider
  ├── get_minimap_data()
  └── get_full_map_data()
```

Minimap i mapa powinny różnić się tylko zakresem i poziomem szczegółowości, nie sposobem pozyskiwania danych.

---

### 3.6. `World` robi zbyt wiele rzeczy

`World` jest obecnie największym ryzykiem architektonicznym. Pełni zbyt wiele ról:

- generuje teren,
- tworzy landmarki,
- rysuje biomy,
- rysuje/wspiera ponds/hills,
- spawnuje zasoby,
- zarządza ResourceNode,
- synchronizuje widzialne stworzenia,
- obsługuje vegetation sync,
- obsługuje save/load danych świata,
- dostarcza zapytania dla gracza, UI i AI.

To jest naturalne w prototypie, ale na tym etapie warto go rozbić.

**Proponowany podział:**

```text
WorldRoot
├── WorldConfigProvider
├── TerrainService
├── LandmarkService
├── ResourceService
├── CreatureSpawnService
├── WorldQueryService
├── WorldRenderController
├── WorldRegistry
└── WorldSaveAdapter
```

Minimalna wersja refaktoru nie musi przenosić wszystkiego naraz. Najpierw warto wyciągnąć tylko:

1. `WorldQueryService`,
2. `WorldRegistry`,
3. `MapDataProvider`,
4. `WorldRenderController`.

To od razu ograniczy lookupi i ułatwi dalszy podział.

---

## 4. Słabe punkty modularności

### 4.1. Mieszanie zależności

Aktualnie systemy komunikują się przez:

- bezpośrednie referencje node,
- autoloady,
- `EventBus`,
- `get_tree().current_scene`,
- grupy,
- lokalne cache w UI.

To utrudnia przewidywanie, kto od kogo zależy. Refaktor powinien wprowadzić jedną regułę:

> Systemy gameplayowe nie powinny szukać innych systemów w drzewie sceny w trakcie działania. Referencje powinny być wstrzyknięte na starcie albo pobierane przez jawny service locator tylko raz.

Proponowany wariant dla obecnego etapu:

```text
GameManager bootuje runtime dependencies:
- world
- player
- ecosystem
- day_night
- save_system
- ui_root

Następnie przekazuje je do RuntimeContext.
```

Przykład:

```gdscript
class_name RuntimeContext

var world: World
var player: Player
var ecosystem: EcosystemDirector
var day_night: DayNightSystem
var registry: WorldRegistry
var snapshot_service: WorldSnapshotService
var query_service: WorldQueryService
```

Potem systemy nie robią:

```gdscript
get_tree().current_scene.get_node_or_null("World")
```

Tylko dostają zależność przy inicjalizacji.

---

### 4.2. Dualny stan ekosystemu i świata widzialnego

To jest jeden z najważniejszych punktów. Sam pomysł jest dobry:

- `EcosystemDirector` trzyma abstrakcyjny model biomów,
- `World` trzyma widzialne zasoby i stworzenia.

Problem pojawia się wtedy, gdy oba systemy mogą zmieniać stan przez eventy i przez okresowe skany. To zwiększa ryzyko podwójnego naliczenia efektu.

**Rekomendacja:** wprowadzić zasadę jednokierunkowej synchronizacji.

Proponowany model:

```text
Widzialna akcja gracza/stworzenia
        ↓
EcosystemCommand / Event
        ↓
EcosystemDirector aktualizuje abstrakcyjny stan
        ↓
EcosystemDirector wystawia EcosystemDelta
        ↓
WorldVegetationSync aplikuje widzialne zmiany w porcjach
```

Czyli `World` nie powinien sam interpretować abstrakcyjnych zasad ekosystemu. Powinien tylko stosować delta/komendy:

```text
Biome westwood:
- reduce visible grass target by 4
- restore bush stage for 2 nodes
- spawn max 3 new plant nodes this sync
```

---

### 4.3. EventBus używany jako transport i logika gameplayowa

`EventBus` jest dobry do luźnych powiadomień, ale nie powinien być podstawowym mechanizmem utrzymywania spójności krytycznego stanu.

Podział:

| Typ komunikacji | Mechanizm |
|---|---|
| Wiadomość do gracza | `EventBus.post_message()` |
| Efekt UI | `EventBus` albo `NotificationService` |
| Krytyczna zmiana gameplayowa | jawna komenda/metoda domenowa |
| Aktualizacja ekosystemu | `EcosystemCommand` |
| Save/load | adaptery stanu, nie eventy |
| Debug | Debug service, nie bezpośredni chaos eventów |

Przykład zamiast samego eventu:

```gdscript
EcosystemCommands.plant_harvested(resource_id, biome_id, biomass_impact)
```

Event do UI może być emitowany później, ale nie powinien być jedynym nośnikiem prawdy.

---

### 4.4. Zbyt duże skrypty domenowe

`Player`, `World`, `EcosystemDirector`, `DebugPanel` prawdopodobnie będą rosły coraz bardziej. Warto stosować zasadę:

> Node scenowy obsługuje życie w drzewie sceny, ale logika powinna siedzieć w małych klasach usługowych lub komponentach.

Przykład podziału `Player`:

```text
Player
├── PlayerMovementController
├── PlayerCombatController
├── PlayerCraftingController
├── PlayerInteractionController
├── PlayerTorchController
├── PlayerStats
└── PlayerInventoryAdapter
```

Nie trzeba robić pełnej architektury ECS. Wystarczy proste rozbicie odpowiedzialności.

---

## 5. Proponowana architektura uproszczona

### 5.1. Warstwy aplikacji

Docelowo projekt można uprościć do pięciu warstw:

```text
1. Runtime orchestration
   GameManager, RuntimeContext, SaveSystem

2. Domain simulation
   PlayerStats, Inventory, EcosystemDirector, HungerDiet, CreatureBrain

3. World services
   TerrainService, LandmarkService, ResourceService, CreatureService, WorldQueryService

4. Presentation data
   WorldSnapshotService, MapDataProvider, HudViewModel, DebugViewModel

5. Views / Nodes
   WorldRenderer, ResourceNode, Creature nodes, HUD, Minimap, MapScreen, DebugPanel
```

Najważniejsza zasada:

> Views/Nody mogą rysować i odbierać input, ale nie powinny samodzielnie agregować całego świata.

---

### 5.2. Nowe moduły do dodania najpierw

#### `WorldRegistry`

Cel: centralna lista aktywnych obiektów świata bez skanowania grup.

Odpowiada za:

- rejestrowanie zasobów,
- wyrejestrowywanie zasobów,
- rejestrowanie stworzeń,
- rejestrowanie budynków,
- szybkie listy po typie i biomie,
- dirty flags dla UI.

Minimalne API:

```gdscript
func register_resource(node: ResourceNode) -> void
func unregister_resource(node: ResourceNode) -> void
func get_resources() -> Array
func get_resources_by_kind(kind: String) -> Array
func get_resources_by_biome(biome_id: String) -> Array

func register_creature(node: Node, creature_type: String, biome_id: String) -> void
func unregister_creature(node: Node) -> void
func get_creatures_by_type(creature_type: String) -> Array
func get_creatures_by_biome(biome_id: String) -> Array

func register_building(node: Node, building_type: String) -> void
func get_campfires() -> Array
```

#### `WorldQueryService`

Cel: wszystkie zapytania przestrzenne przez jedno miejsce.

Odpowiada za:

- `is_position_in_water(position)`,
- `get_terrain_speed_multiplier(position)`,
- `get_biome_at(position)`,
- `is_position_blocked_by_hill(position)`,
- `get_nearest_food(position, filters)`,
- `get_nearest_threat(position, filters)`,
- `get_campfires_near(position, radius)`.

Dzięki temu `Player`, AI i UI nie muszą znać szczegółów `World`.

#### `WorldSnapshotService`

Cel: jeden snapshot danych dla HUD, minimapy, mapy i debug panelu.

Przykładowe dane:

```gdscript
var snapshot = {
    "player": {
        "position": player.global_position,
        "health": player.stats.health,
        "hunger": player.stats.hunger,
        "stamina": player.stats.stamina,
        "rest": player.stats.rest,
        "inventory": player.inventory.to_dict()
    },
    "world": {
        "landmarks": landmark_service.get_landmarks(),
        "visible_resource_markers": resource_service.get_map_markers(),
        "visible_creature_markers": creature_service.get_map_markers()
    },
    "ecosystem": ecosystem_director.get_summary(),
    "time": day_night.get_summary()
}
```

#### `UpdateScheduler`

Cel: kontrola częstotliwości drogich aktualizacji.

Przykład:

```text
fast_ui_tick      0.25 s
slow_ui_tick      1.00 s
map_marker_tick   0.50 s
debug_tick        1.00 s
ecosystem_tick    5.00 s
spawn_tick        1.00–3.00 s
```

---

## 6. Plan optymalizacji FPS i stutteringu

### Faza 0 — pomiar przed zmianami

Przed refaktorem trzeba mieć baseline. W przeglądzie jest `BenchmarkRunner`, który zbiera FPS, frame time, physics time, draw calls, node counts, world counts i ecosystem state.

Zalecane scenariusze pomiarowe:

1. nowa gra, gracz stoi 60 s,
2. gracz biegnie przez biomy 60 s,
3. otwarta minimapa 60 s,
4. otwarta pełna mapa 60 s,
5. otwarty debug panel 60 s,
6. noc + torch + Varnaki 60 s,
7. po kilku dniach symulacji ekosystemu 60 s.

Metryki do porównania:

| Metryka | Cel |
|---|---|
| średni FPS | wzrost |
| 1% low FPS | duży wzrost |
| max frame time | spadek |
| liczba draw calls | spadek lub stabilizacja |
| liczba node | kontrolowana |
| liczba skanów grup / s | mocny spadek |
| liczba redraw mapy / s | mocny spadek |
| czas `_process` UI | spadek |
| czas `_process` World | spadek |

---

### Faza 1 — szybkie poprawki o największym zwrocie

#### 1. Wyłączyć pracę DebugPanel, gdy panel jest niewidoczny

Debug panel powinien robić **zero** kosztownych odczytów, gdy jest zamknięty.

```gdscript
func _process(delta):
    if not visible:
        return
```

Dodatkowo rebuild debug text maksymalnie 1–2 razy na sekundę.

#### 2. Zmienić full map redraw

`MapScreen` nie powinien redrawować każdej klatki.

Nowe zasady:

- `queue_redraw()` przy otwarciu,
- `queue_redraw()` po dirty flag `map_data_changed`,
- marker gracza aktualizować osobnym lekkim node,
- brak redraw, gdy mapa zamknięta.

#### 3. Ograniczyć skan campfire

Najlepiej przez `Area2D` przy ognisku. Minimalna poprawka:

- skan co 0.25–0.5 s zamiast physics tick,
- korzystanie z `WorldRegistry.campfires`, nie z grupy.

#### 4. Zmniejszyć częstotliwość minimapy

Minimap może odświeżać markery 2 razy na sekundę. Tło mapy powinno być cache’owane.

#### 5. UI aktualizować tylko po zmianie wartości

HUD nie musi przebudowywać wszystkich labeli co 0.10 s. Można trzymać ostatnie wartości i aktualizować tylko, gdy liczba się zmieni po zaokrągleniu.

Przykład:

```gdscript
var last_health_label := ""
var new_health_label := str(roundi(player.stats.health))
if new_health_label != last_health_label:
    health_label.text = new_health_label
    last_health_label = new_health_label
```

---

### Faza 2 — usunięcie powtarzanych odczytów świata

#### 1. Dodać `WorldSnapshotService`

To powinien być pierwszy większy refaktor.

UI pobiera dane z snapshotu, a nie z `World`, `Player`, `EcosystemDirector` i grup jednocześnie.

#### 2. Dodać `MapDataProvider`

Minimap i full map używają tego samego źródła:

```text
MapDataProvider
├── terrain_cache
├── landmark_cache
├── resource_marker_cache
├── creature_marker_cache
└── dirty flags
```

#### 3. Dodać dirty flags

Przykładowe flagi:

```gdscript
enum DirtyFlag {
    TERRAIN,
    LANDMARKS,
    RESOURCES,
    CREATURES,
    PLAYER_STATS,
    INVENTORY,
    ECOSYSTEM,
    TIME
}
```

Jeśli zbierasz drewno, ustawiasz:

```text
RESOURCES dirty
INVENTORY dirty
ECOSYSTEM dirty, jeśli resource wpływa na biomass
```

HUD aktualizuje inventory, mapa aktualizuje zasoby, debug aktualizuje ecosystem. Reszta nie robi nic.

---

### Faza 3 — rozbicie `World`

Najbezpieczniejszy podział:

1. `WorldQueryService` — zapytania o teren, wodę, biomy, przeszkody.
2. `LandmarkService` — landmarki i ich geometria.
3. `ResourceService` — spawn, restore, regrowth, resource markers.
4. `CreatureService` — widzialne stworzenia, spawn/sync, save data.
5. `WorldRenderController` — cache terrain/biome/landmark redraw.
6. `WorldSaveAdapter` — save/load danych świata.

`World` zostaje jako fasada:

```gdscript
class_name World

var query_service: WorldQueryService
var landmark_service: LandmarkService
var resource_service: ResourceService
var creature_service: CreatureService
var render_controller: WorldRenderController
var save_adapter: WorldSaveAdapter
```

Wtedy stare API może nadal działać:

```gdscript
func is_position_in_water(pos):
    return query_service.is_position_in_water(pos)
```

To pozwala refaktorować bez natychmiastowego przepisywania całej gry.

---

### Faza 4 — porządkowanie ekosystemu

Cel: uniknąć podwójnych efektów i kosztownych synchronizacji.

Proponowana zasada:

- widzialne akcje wysyłają komendy do ekosystemu,
- ekosystem aktualizuje model abstrakcyjny,
- ekosystem wystawia delty,
- świat aplikuje delty w porcjach.

Przykład delty:

```gdscript
class_name EcosystemDelta

var biome_id: String
var vegetation_target_delta: int
var biomass_percent_before: float
var biomass_percent_after: float
var status_changed: bool
var new_status: String
```

Vegetation sync powinien mieć limit pracy na klatkę:

```gdscript
const MAX_VEGETATION_CHANGES_PER_FRAME := 6
```

To ograniczy stutter przy gwałtownych zmianach biomasy.

---

## 7. Konkretne antywzorce do usunięcia

### Antywzorzec 1: UI pyta świat bezpośrednio

**Problem:** wiele widoków dubluje zapytania.

**Zamiana:** UI czyta `WorldSnapshotService`.

---

### Antywzorzec 2: scan group jako mechanizm gameplayowy

**Problem:** `get_nodes_in_group()` jest wygodne, ale drogie, gdy jest powtarzane często.

**Zamiana:** rejestry + dirty flags + eventy rejestracji.

---

### Antywzorzec 3: `queue_redraw()` jako reakcja na zbyt wiele eventów

**Problem:** kilka systemów może wymusić redraw w krótkim czasie.

**Zamiana:** batching redraw.

```gdscript
func request_redraw(reason: String) -> void:
    redraw_requested = true
    redraw_reasons[reason] = true

func _process(delta):
    if redraw_requested and redraw_cooldown <= 0:
        queue_redraw()
        redraw_requested = false
        redraw_cooldown = 0.2
```

---

### Antywzorzec 4: event jako jedyne źródło zmiany stanu

**Problem:** eventy są trudne do śledzenia i mogą powodować podwójne naliczanie.

**Zamiana:** jawne komendy domenowe + eventy tylko jako powiadomienie.

---

### Antywzorzec 5: duże klasy node robiące wszystko

**Problem:** `World`, `Player`, `DebugPanel` będą coraz mniej czytelne.

**Zamiana:** małe serwisy/komponenty, node jako fasada.

---

## 8. Priorytety techniczne

### Priorytet P0 — szybkie FPS/stutter fixes

1. `MapScreen`: nie redrawować każdej klatki.
2. `DebugPanel`: nie aktualizować, gdy niewidoczny; ograniczyć do 1–2 Hz.
3. `Player`: usunąć skan `campfires` z physics tick.
4. `Minimap`: wspólny cache markerów, niższa kadencja.
5. `HUD`: aktualizacja labeli tylko po zmianie wartości.

### Priorytet P1 — modularność i wspólne dane

1. Dodać `WorldRegistry`.
2. Dodać `WorldSnapshotService`.
3. Dodać `MapDataProvider`.
4. Dodać dirty flags.
5. Przestać używać `get_tree().current_scene` w systemach runtime.

### Priorytet P2 — większy refaktor

1. Rozbić `World` na serwisy.
2. Rozbić `Player` na kontrolery.
3. Wprowadzić `EcosystemCommand` i `EcosystemDelta`.
4. Rozłożyć vegetation sync na porcje.
5. Uporządkować save/load przez adaptery.

### Priorytet P3 — dalsza optymalizacja

1. Spatial partitioning dla zasobów i stworzeń.
2. Object pooling dla strzał, meat dropów i efektów wizualnych.
3. LOD symulacji stworzeń daleko od gracza.
4. Tani tryb AI dla stworzeń poza ekranem.
5. Chunk-based world update.

---

## 9. Proponowane GitHub issues

### Issue 1 — `[PERFORMANCE] Stop full map redraw every frame`

**Cel:** Pełna mapa nie powinna wykonywać pełnego redraw każdej klatki.

**Zakres:**

- Dodać dirty flagi dla danych mapy.
- Redraw mapy tylko przy otwarciu, zmianie danych albo wymuszeniu debugowym.
- Marker gracza przenieść do osobnej lekkiej warstwy.
- Upewnić się, że zamknięta mapa nie wykonuje kosztownych odczytów.

**Acceptance Criteria:**

- `MapScreen` nie wykonuje pełnego redraw w każdej klatce.
- Otwarta mapa nadal pokazuje aktualną pozycję gracza.
- Zasoby/stworzenia aktualizują się z opóźnieniem maksymalnie 0.5–1.0 s.
- Benchmark z otwartą mapą pokazuje niższy frame time.

---

### Issue 2 — `[PERFORMANCE] Remove campfire group scan from player physics tick`

**Cel:** Gracz nie powinien skanować grupy `campfires` w każdym physics ticku.

**Zakres:**

- Dodać `WorldRegistry.campfires` albo `CampfireArea`.
- Aktualizować stan regeneracji ogniska eventowo albo 2–4 razy na sekundę.
- Zachować `campfire_regen_active` i `campfire_regen_distance` w `PlayerStats`.

**Acceptance Criteria:**

- Brak pełnego skanu `campfires` w `_physics_process`.
- Regeneracja przy ognisku działa poprawnie.
- Oddalenie od ogniska wyłącza regenerację.
- Benchmark pokazuje mniejszy physics/update cost przy większej liczbie ognisk.

---

### Issue 3 — `[REFACTOR] Add WorldRegistry for resources, creatures and buildings`

**Cel:** Ograniczyć użycie `get_nodes_in_group()` i przygotować fundament pod modularność.

**Zakres:**

- Dodać `WorldRegistry`.
- Rejestrować zasoby przy spawn/restore.
- Wyrejestrowywać zasoby przy usunięciu.
- Rejestrować stworzenia i budynki.
- Udostępnić listy po typie i biomie.

**Acceptance Criteria:**

- Nowe zasoby i stworzenia trafiają do rejestru.
- Usunięte obiekty nie zostają w rejestrze jako martwe referencje.
- Minimap/MapScreen mogą pobierać markery z rejestru lub serwisu opartego o rejestr.
- Stare grupy mogą zostać jako kompatybilność, ale nie są główną ścieżką odczytu.

---

### Issue 4 — `[REFACTOR] Add WorldSnapshotService for HUD, minimap, map and debug panel`

**Cel:** Zmniejszyć liczbę równoległych odczytów świata przez UI.

**Zakres:**

- Dodać snapshot danych gracza, świata, ekosystemu i czasu.
- HUD czyta dane ze snapshotu.
- Minimap i MapScreen czytają markery ze snapshotu/providerów.
- DebugPanel czyta summary ze snapshotu.

**Acceptance Criteria:**

- UI nie musi bezpośrednio skanować grup zasobów/stworzeń.
- Dane HUD pozostają aktualne.
- Minimap i mapa pokazują spójne landmarki i markery.
- DebugPanel nadal pokazuje potrzebne dane testowe.

---

### Issue 5 — `[PERFORMANCE] Gate DebugPanel updates by visibility and low frequency refresh`

**Cel:** DebugPanel nie powinien kosztować FPS, gdy nie jest używany.

**Zakres:**

- Brak aktualizacji, jeśli panel niewidoczny.
- Rebuild tekstu maksymalnie 1–2 razy na sekundę.
- Selected creature refresh osobno od tekstów globalnych.
- Ograniczyć overlay refresh.

**Acceptance Criteria:**

- Zamknięty DebugPanel ma zerowy lub marginalny koszt.
- Otwarty DebugPanel działa stabilnie.
- Brak błędów po despawnie wybranego stworzenia.
- Benchmark z zamkniętym panelem pokazuje poprawę frame time.

---

### Issue 6 — `[REFACTOR] Split World responsibilities into services`

**Cel:** Zmniejszyć odpowiedzialność `world.gd` i przygotować kod pod dalszą rozbudowę.

**Zakres:**

- Wyciągnąć `WorldQueryService`.
- Wyciągnąć `LandmarkService`.
- Wyciągnąć `ResourceService`.
- Wyciągnąć `WorldRenderController`.
- Zostawić kompatybilne metody fasadowe w `World`.

**Acceptance Criteria:**

- Player i AI mogą pytać o wodę/teren przez `WorldQueryService`.
- Landmarki są zarządzane poza głównym `World`.
- Resource spawn/regrowth można testować osobno.
- `World` pozostaje punktem integracji, ale ma mniej logiki bezpośredniej.

---

### Issue 7 — `[REFACTOR] Introduce EcosystemCommand and EcosystemDelta flow`

**Cel:** Uporządkować synchronizację między widzialnym światem a abstrakcyjnym ekosystemem.

**Zakres:**

- Dodać komendy dla harvest, plant consumed, creature death, meat consumed.
- `EcosystemDirector` przelicza model i wystawia delty.
- `World` aplikuje delty widzialnej roślinności porcjami.
- Zabezpieczyć przed podwójnym naliczaniem eventów.

**Acceptance Criteria:**

- Harvest rośliny wpływa na inventory, widzialny node i biomass dokładnie raz.
- Zjedzenie rośliny przez zwierzę wpływa na biomass dokładnie raz.
- Zmiana biomasy może aktualizować widzialną roślinność bez spike’u FPS.
- Debug biomass nadal daje widoczny efekt.

---

## 10. Kolejność wdrożenia rekomendowana dla obecnego projektu

Najbezpieczniejsza kolejność:

1. **Benchmark baseline** — bez tego trudno ocenić, czy refaktor pomógł.
2. **MapScreen redraw fix** — bardzo prawdopodobny szybki zysk.
3. **DebugPanel visibility/frequency gate** — szybki zysk i małe ryzyko.
4. **Campfire scan fix** — małe ryzyko, dobry wzorzec dla przyszłych zmian.
5. **Minimap cache/provider** — zmniejsza powtarzane odczyty.
6. **WorldRegistry** — fundament pod dalszą optymalizację.
7. **WorldSnapshotService** — największy zysk architektoniczny dla UI.
8. **Rozbicie `World`** — dopiero po ustabilizowaniu rejestru/snapshotów.
9. **EcosystemCommand/Delta** — większa zmiana, robić po pomiarach i testach.
10. **Spatial partitioning / LOD AI** — gdy liczba stworzeń/zasobów będzie dalej rosła.

---

## 11. Kryteria sukcesu refaktoru

Refaktor można uznać za udany, jeśli:

- FPS jest stabilniejszy, a nie tylko średnio wyższy.
- 1% low FPS rośnie.
- Otwarcie mapy nie powoduje dużego spadku FPS.
- Zamknięty debug panel praktycznie nic nie kosztuje.
- Liczba pełnych skanów grup na sekundę mocno spada.
- UI nie buduje tych samych danych w kilku miejscach.
- `World` ma mniej odpowiedzialności.
- Zmiany ekosystemu nie powodują nagłych spike’ów przez masowe sync/redraw.
- Save/load nadal działa w tej samej kolejności zależności przestrzennych.

---

## 12. Najważniejsza rekomendacja strategiczna

Nie zaczynałbym od dużego przepisywania całej architektury. Najpierw warto usunąć najbardziej podejrzane źródła stutteringu:

1. full map redraw każdej klatki,
2. debug panel działający zbyt często,
3. skany grup w physics ticku,
4. powielone cache minimapy/mapy,
5. częste przebudowy HUD.

Dopiero potem warto robić większy refaktor modularny: `WorldRegistry`, `WorldSnapshotService`, `WorldQueryService` i rozbicie `World` na serwisy.

Najlepszy kierunek architektoniczny dla Apex Shift 2D to nie pełne ECS ani duży framework, tylko prosta modularna architektura usług:

```text
World jako fasada
+ rejestr obiektów
+ query service
+ snapshot service
+ provider danych mapy
+ scheduler aktualizacji
+ dirty flags
```

To powinno dać największy stosunek efektu do ryzyka i pozwolić dalej rozwijać prototyp bez pogłębiania chaosu w `World`, UI i ekosystemie.
