1. [PERFORMANCE] Reduce BenchmarkRunner sample collection hitches
Labels

type: performance
area: benchmark
area: debug
priority: high
stage: optimization

Cel

Zmniejszyć koszt zbierania próbek benchmarku, ponieważ obecnie sam benchmark powoduje bardzo duże hitches i zniekształca wynik FPS.

Diagnoza

W benchmarku:

benchmark_sample_build_ms: ~1366-1455 ms
realtime_hitch_count: 34
max_realtime_delta_ms: 1686
max_frame_time_ms: 1673

To oznacza, że benchmark zbiera zbyt dużo danych naraz, prawdopodobnie budując ogromne, zagnieżdżone słowniki debugowe co próbkę.

Zakres
Dodać tryb lekkiego benchmarku.
Domyślnie zbierać tylko najważniejsze metryki.
Ciężkie dane debugowe przenieść za flagę deep_debug.
Nie pobierać pełnego world_debug przy każdym realtime hitchu.
Ograniczyć głębokość snapshotów w realtime_hitches.
Dodać osobną metrykę kosztu benchmarku:
benchmark_sample_collection_ms
benchmark_world_debug_collection_ms
benchmark_hitch_capture_ms
benchmark_report_build_ms
Acceptance Criteria
benchmark_sample_build_ms <= 10 ms w normalnym benchmarku.
realtime_hitches nie są generowane przez samo zbieranie danych.
Normalny benchmark nadal pokazuje:
FPS,
frame time,
hitches,
active collisions,
render attribution,
node count,
draw calls,
terrain surface stats.
Pełny zagnieżdżony raport dostępny tylko w deep_debug.
2. [BUG] Fix terrain surface refine stuck in pressure mode
Labels

type: bug
type: performance
area: world
area: rendering
area: terrain
priority: high
stage: optimization

Cel

Naprawić sytuację, w której terrain surface renderer nie kończy preview/refine i zostawia widoczne chunki bez tekstury.

Diagnoza

W benchmarku:

terrain_surface_refined_build_count: 0
terrain_surface_refine_jobs_started: 0
terrain_surface_refine_jobs_completed: 0
terrain_surface_refine_skipped_due_to_fps_count: 171+
terrain_surface_visible_chunks_without_texture: 3-4
terrain_surface_chunk_state_counts:
  PREVIEW_BUILDING: 3-4
  PREVIEW_READY: 0-1
  REFINED_READY: 0
terrain_surface_refine_pause_when_fps_below: 50
terrain_surface_max_build_ms_per_frame: 0.75

Renderer jest w trybie pressure, ale threshold 50 FPS blokuje refine praktycznie cały czas.

Zakres
Nie blokować refine całkowicie, gdy FPS jest niski.
Obniżyć terrain_refine_pause_when_fps_below w trybie pressure do 20–25.
Dopuścić minimum jeden refine job co kilka sekund, gdy kamera stoi.
Preview chunk powinien kończyć się szybko dla widocznych chunków.
Nie trzymać chunków w PREVIEW_BUILDING przez dziesiątki sekund.
Dodać watchdog dla chunków stuck in building state.
Acceptance Criteria
terrain_surface_refined_build_count > 0 po 60 sekundach.
terrain_surface_refine_jobs_completed > 0.
terrain_surface_visible_chunks_without_texture = 0 po ustabilizowaniu świata.
PREVIEW_BUILDING nie utrzymuje się stale dla widocznych chunków.
Brak spamu TERRAIN_SURFACE_SMOKE_TEST.
Teren nadal renderuje się poprawnie przy niskim FPS.
3. [PERFORMANCE] Optimize BiomeShapeMap and visual surface build
Labels

type: performance
area: world
area: biome
area: rendering
area: procedural-generation
priority: high
stage: optimization

Cel

Zmniejszyć koszt budowy BiomeShapeMap i biome_shape_visual_surface, które obecnie potrafią trwać kilka sekund.

Diagnoza

W benchmarku:

biome_shape_map_last_build_ms: 5826
biome_shape_visual_surface_last_build_ms: 1746
biome_shape_map_polygon_count: 440
biome_shape_map_rejected_polygon_count: 801
biome_shape_map_grid_size: 210x130
biome_shape_visual_surface_grid_size: 420x260

To jest za ciężkie na runtime i może powodować freeze podczas generowania świata albo pierwszego renderu mapy.

Zakres
Przenieść budowę shape mapy do etapów async / incremental.
Cache’ować wynik po seedzie i configu.
Nie przebudowywać shape mapy, jeśli shape_map_key się nie zmienił.
Ograniczyć liczbę odrzuconych polygonów.
Dodać budżet czasowy na budowanie polygonów.
Rozważyć niższą rozdzielczość visual surface dla runtime.
Oddzielić:
dokładną shape mapę dla full map/debug,
uproszczoną surface mapę dla renderowania świata.
Acceptance Criteria
biome_shape_map_last_build_ms < 500 ms albo build odbywa się inkrementalnie bez hitcha.
biome_shape_visual_surface_last_build_ms < 250 ms albo build odbywa się inkrementalnie.
Brak freeze przy starcie świata.
biome_shape_map_has_renderable_polygons = true.
Mapa nadal pokazuje wyspę i biomy poprawnie.
Shape map nie przebudowuje się bez zmiany seeda/configu.
4. [BUG] Fix misleading resource activation debug metrics
Labels

type: bug
area: debug
area: resources
area: performance
priority: medium
stage: cleanup

Cel

Naprawić mylące metryki aktywacji zasobów.

Diagnoza

Kolizje są już niskie:

active_resource_collisions: 2-3
inactive_resource_collisions: 256

ale debug pokazuje:

interactive_resource_node_count: 258
render_only_resource_count: 0
render_only_resources: 0

To wygląda tak, jakby wszystkie zasoby były interaktywne, mimo że aktywne kolizje są tylko dla kilku zasobów.

Zakres

Zmienić nazwy i sposób liczenia metryk.

Obecne:

interactive_resource_node_count
render_only_resource_count
resources_with_process_enabled
resources_with_physics_process_enabled

Docelowo:

total_resource_node_count
interaction_active_resource_count
collision_active_resource_count
collision_inactive_resource_count
render_only_visual_resource_count
harvestable_resource_count
ai_food_resource_count
actual_process_enabled_resource_count
actual_physics_process_enabled_resource_count
should_process_resource_count
Acceptance Criteria
interactive_resource_node_count nie oznacza wszystkich harvestable nodes.
Debug jasno pokazuje, ile zasobów ma aktywną kolizję.
Debug jasno pokazuje, ile zasobów jest tylko widoczne.
resources_with_process_enabled sprawdza realne is_processing().
resources_with_physics_process_enabled sprawdza realne is_physics_processing().
Benchmark nie sugeruje fałszywie, że 258 zasobów jest aktywnych.
5. [PERFORMANCE] Replace full resource activation scan with spatial-index query
Labels

type: performance
area: resources
area: world
area: spatial-index
priority: medium
stage: optimization

Cel

Zastąpić pełne skanowanie wszystkich zasobów przez query ze spatial index.

Diagnoza

W benchmarku:

registered_resources: 258
resource_activation_checked_count: 3930 -> 4446 już po kilku sekundach
spatial_index.resources_total: 258
resource_cells: 237
visible_resources: 6-8
active_resource_collisions: 2-3

Kolizje są naprawione, ale system nadal skanuje wszystkie zasoby cyklicznie.

Zakres
Aktywację zasobów oprzeć na spatial index.
Query dla:
zasobów blisko gracza,
zasobów w promieniu AI food query,
zasobów aktualnie targetowanych.
Dalekie zasoby sprawdzać rzadziej albo tylko przy zmianie chunków.
Zachować batch limit zmian aktywności.
Nie robić pełnego get_cached_group_nodes("resources") co interwał.
Acceptance Criteria
resource_activation_checked_count rośnie znacznie wolniej.
Aktywacja nadal działa przy podejściu do zasobu.
AI nadal znajduje jedzenie.
active_resource_collisions pozostaje poniżej limitu.
Brak regresji save/load.
Brak invalid freed instance przy usuwaniu zasobów.
6. [BUG] Fix terrain surface pressure config mismatch
Labels

type: bug
area: rendering
area: performance
area: config
priority: high
stage: cleanup

Cel

Ujednolicić konfigurację terrain surface między GameBalance, render governor i aktualnym trybem pressure.

Diagnoza

W kodzie bazowym GameBalance ma wartości łagodniejsze, ale benchmark pokazuje runtime pressure override:

terrain_build_budget_ms: 0.75
terrain_refine_pause_when_fps_below: 50
terrain_refined_texture_size: 96
terrain_max_refined_chunks_per_second: 2

Efekt:

terrain_surface_refine_skipped_due_to_fps_count: 171+
terrain_surface_refined_build_count: 0
Zakres
Sprawdzić, gdzie render governor nadpisuje wartości terrain surface.
Dodać debug pokazujący źródło configu:
base,
low_end,
pressure,
benchmark preset.
Pressure mode nie powinien blokować refine na zawsze.
Osobno ustawić budżety dla:
preview,
refine,
visibility,
draw.
Acceptance Criteria
Debug pokazuje finalny config i źródło override.
Pressure mode nie ustawia refine_pause_when_fps_below = 50, jeśli FPS jest stale poniżej 50.
Refine pipeline wykonuje minimalny postęp nawet przy render pressure.
Nie ma konfliktu między GameBalance.BIOME_TEXTURES a runtime governor.
7. [BUG] Restore / validate landmark generation for procedural island
Labels

type: bug
area: world
area: landmarks
area: procedural-generation
priority: medium
stage: validation

Cel

Sprawdzić, dlaczego benchmark raportuje brak landmarków mimo proceduralnej wyspy.

Diagnoza

W benchmarku:

landmark_count: 0
pond_count: 0
hill_count: 0
landmark_debug.generated: 0
landmark_debug.pond: 0
landmark_debug.hill: 0

Jednocześnie shape map raportuje pond terrain:

terrain:pond polygon_count: 1
terrain:pond cell_count: 70

To sugeruje rozjazd między nową topografią a starym systemem landmarków.

Zakres
Ustalić, czy landmarki mają być nadal generowane jako osobne obiekty.
Jeśli tak: naprawić generation pipeline.
Jeśli nie: zmienić metryki, żeby nie raportowały landmark_count = 0 jako problem.
Zmapować topography features na debug landmark counts.
Upewnić się, że full map/minimapa pokazują:
ponds,
hills,
old tree,
ruins, jeśli są dodane.
Acceptance Criteria
Debug jasno rozróżnia:
legacy landmarks,
topography features,
map markers.
Jeśli ponds istnieją w topografii, debug ich nie raportuje jako zero.
MapScreen i minimapa pokazują landmarki / topography markers zgodnie z docelowym systemem.
Brak fałszywych alertów o landmark_count = 0.
8. [BUG] Fix ecosystem biome state duplication
Labels

type: bug
area: ecosystem
area: biome
priority: medium
stage: validation

Cel

Naprawić sytuację, w której wszystkie biomy mają identyczny stan ekosystemu.

Diagnoza

W benchmarku każdy biom ma takie same wartości:

plant_biomass_percent: 95.21963565
food_stress: 0.0478036435
grazer_population: 6.5682606661975
small_prey_population: 13.441197267375
population_count: 20.0094579335725
current_niche: HERBIVORE

Dotyczy to:

hearth_meadow
redfang_wilds
south_thicket
stoneback_ridge
westwood

To wygląda jak kopiowanie jednego globalnego stanu do wszystkich biomów, a nie prawdziwy per-biome state.

Zakres
Sprawdzić EcosystemDirector.get_biome_state().
Sprawdzić inicjalizację biomów.
Upewnić się, że każdy biom ma osobne wartości:
biomass,
food stress,
populations,
predator pressure,
overgrazing.
Powiązać biom state z rzeczywistą dystrybucją zasobów i stworzeń.
Dodać debug ecosystem_state_source.
Acceptance Criteria
Różne biomy mogą mieć różne wartości biomass/population/stress.
Redfang Wilds nie ma automatycznie identycznego stanu jak Hearth Meadow.
most_stressed_biome wynika z realnych danych.
Save/load przywraca per-biome ecosystem state.
Test jednostkowy wykrywa, jeśli wszystkie biomy dostały tę samą referencję/stub.
9. [VALIDATION] Add benchmark scenario with opened Field Map
Labels

type: test
area: benchmark
area: map
area: minimap
priority: medium
stage: validation

Cel

Dodać benchmark / test walidacyjny, który faktycznie otwiera Field Map.

Diagnoza

W aktualnym benchmarku:

map_screen.redraw_count: 0
map_screen.texture_build_count: 0
map_screen.skipped_update_hidden_count: 236+
map_screen_first_open_ms: 0

To oznacza, że benchmark nie testuje realnego otwarcia mapy.

Zakres
Dodać osobny scenariusz:
start gry,
poczekaj aż świat gotowy,
otwórz Field Map,
trzymaj otwartą kilka sekund,
zamknij,
powtórz.
Mierzyć:
first open hitch,
texture build time,
redraw count,
shoreline build time,
marker cache build time.
Porównać full map z minimapą.
Acceptance Criteria
map_screen.redraw_count > 0.
map_screen_first_open_ms jest mierzone.
Otwarcie mapy nie powoduje hitcha powyżej ustalonego progu.
Field Map pokazuje tę samą wyspę i biomy co minimapa.
Benchmark może działać w trybach:
normal without map,
map open stress.
10. [WORLDGEN] Relax resource spawn constraints for procedural biomes
Labels

type: bug
area: world
area: resources
area: procedural-generation
priority: medium
stage: balancing

Cel

Zmniejszyć liczbę nieudanych spawnów zasobów w proceduralnych biomach.

Diagnoza

Z wcześniejszych logów i obecnego rozkładu zasobów wynika, że po proceduralnej wyspie część spawnów ma za mało poprawnych miejsc. Obecny benchmark pokazuje:

registered_resources: 258
bushes: 152
trees: 53
rocks: 24
edible_vegetation: 205
pond_vegetation: 4

Jednocześnie świat ma duże obszary shore/water/pond/highland i mocne filtry pozycji.

Zakres
Przejrzeć filtry:
water blocking,
hill blocking,
biome bounds,
min distance,
player safe distance.
Dodać fallback spawn near biome edge / valid land patch.
Dodać debug rejection reasons dla resource spawnów.
Oddzielić wymagania dla:
dużych drzew,
kamieni,
krzaków,
edible vegetation,
decorative visuals.
Nie spamować logów przy każdym nieudanym spawnie.
Acceptance Criteria
Spawn warningi nie spamują logów.
Każdy biom ma sensowną liczbę zasobów.
Zasoby nie spawnują się w wodzie.
Zasoby nie spawnują się poza mapą.
Nie ma pustych biomów, jeśli nie jest to zamierzone.
Debug pokazuje resource_spawn_rejection_by_reason.
Proponowana kolejność pracy

Najpierw zrobiłbym:

BenchmarkRunner sample collection hitches — bo obecny benchmark sam zanieczyszcza wyniki.
Terrain surface refine stuck — bo visible chunks bez tekstury i refine = 0 to realny problem renderu.
Pressure config mismatch — bo obecny governor blokuje refine.
BiomeShapeMap build optimization — bo 5.8s build to duży freeze risk.
Resource activation debug metrics — mały cleanup po udanej optymalizacji kolizji.
Field Map benchmark scenario — żeby w końcu testować mapę, nie tylko ukrytą mapę.
Landmark/topography debug cleanup.
Ecosystem per-biome state.
Resource spawn constraints.

Kolizje zasobów uznałbym za zamknięte jako główny performance problem. Teraz priorytetem jest benchmark overhead + terrain surface/refine pipeline.