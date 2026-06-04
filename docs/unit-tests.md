Testy jednostkowe dla wersji v0.1
1. WorldConfig
Konfiguracja świata
test_default_world_size_is_valid
Sprawdza, czy domyślna szerokość i wysokość świata są większe od zera.
test_tile_size_is_valid
Sprawdza, czy rozmiar kafelka/mapy nie jest zerowy ani ujemny.
test_biome_config_exists
Sprawdza, czy konfiguracja biomów jest dostępna.
test_biome_weights_sum_is_valid
Sprawdza, czy wagi biomów są poprawne i nie są ujemne.
test_resource_spawn_config_exists
Sprawdza, czy istnieje konfiguracja spawnu zasobów.
test_creature_spawn_config_exists
Sprawdza, czy istnieje konfiguracja spawnu stworzeń.
test_debug_config_defaults_are_valid
Sprawdza, czy domyślne ustawienia debugowania są poprawne.
test_day_length_is_positive
Sprawdza, czy długość dnia w grze jest większa od zera.
test_resource_regeneration_config_is_valid
Sprawdza, czy czasy regeneracji zasobów są poprawne.
test_hunger_config_is_valid
Sprawdza, czy wartości głodu, spadku głodu i progów głodu są poprawne.
2. World
Generowanie świata
test_world_generates_with_valid_dimensions
Świat po wygenerowaniu ma oczekiwaną szerokość i wysokość.
test_world_generates_tiles
Po wygenerowaniu istnieją kafelki świata.
test_each_tile_has_biome
Każdy kafelek ma przypisany biom.
test_biome_generation_is_deterministic_with_seed
Ten sam seed generuje taki sam układ biomów.
test_different_seed_generates_different_world
Różne seedy generują inny układ świata.
test_world_bounds_are_correct
Granice świata odpowiadają konfiguracji.
test_position_inside_world_returns_true
Pozycja wewnątrz świata jest poprawnie rozpoznawana.
test_position_outside_world_returns_false
Pozycja poza światem jest poprawnie rozpoznawana.
test_clamp_position_to_world_bounds
Pozycja poza mapą zostaje poprawnie ograniczona do granic.
test_get_tile_at_valid_position_returns_tile
Pobranie kafelka dla poprawnej pozycji zwraca kafelek.
test_get_tile_at_invalid_position_returns_null
Pobranie kafelka poza mapą nie powoduje błędu.
test_world_can_return_biome_at_position
Świat potrafi zwrócić biom dla pozycji.
test_world_can_return_nearby_tiles
Świat poprawnie zwraca sąsiednie kafelki.
test_world_does_not_generate_empty_biome_map
Mapa biomów nie jest pusta po generacji.
test_world_generation_does_not_spawn_entities_outside_bounds
Żadna encja nie pojawia się poza mapą.
3. ResourceNode
Stan zasobów
test_resource_node_initializes_with_full_amount
Zasób startuje z poprawną ilością.
test_resource_node_has_resource_type
Zasób ma przypisany typ, np. krzak, mięso, drewno, roślina.
test_resource_node_can_be_harvested
Zasób można zebrać.
test_harvesting_reduces_resource_amount
Zebranie zasobu zmniejsza jego ilość.
test_resource_amount_never_goes_below_zero
Ilość zasobu nie spada poniżej zera.
test_empty_resource_cannot_be_harvested
Pustego zasobu nie można ponownie zebrać.
test_resource_node_reports_empty_when_depleted
Zasób poprawnie zgłasza stan pusty.
test_resource_node_reports_available_when_not_empty
Zasób poprawnie zgłasza dostępność.
Regeneracja zasobów
test_resource_node_starts_regeneration_after_depletion
Po wyczerpaniu zasobu rozpoczyna się regeneracja.
test_resource_node_regenerates_after_required_time
Zasób odnawia się po wymaganym czasie.
test_resource_node_regeneration_has_stages
Zasób przechodzi przez etapy regeneracji.
test_resource_node_does_not_regenerate_above_max
Zasób nie regeneruje się ponad maksimum.
test_resource_node_visual_stage_matches_regeneration_stage
Etap wizualny odpowiada etapowi regeneracji.
test_partial_regeneration_allows_partial_harvest_if_allowed
Jeżeli projekt to dopuszcza, częściowo odrośnięty zasób daje częściowy loot.
test_resource_node_save_data_contains_type_amount_and_stage
Dane zapisu zawierają typ, ilość i etap regeneracji.
test_resource_node_load_restores_state
Po wczytaniu zasób ma ten sam stan co przed zapisem.
4. HungerDiet
Głód
test_hunger_initializes_with_max_value
Głód startuje z maksymalną wartością.
test_hunger_decreases_over_time
Głód spada wraz z czasem.
test_hunger_does_not_go_below_zero
Głód nie spada poniżej zera.
test_hunger_does_not_exceed_max
Głód nie przekracza maksimum po jedzeniu.
test_is_hungry_returns_false_above_threshold
Stworzenie nie jest głodne powyżej progu.
test_is_hungry_returns_true_below_threshold
Stworzenie jest głodne poniżej progu.
test_is_starving_returns_true_at_critical_threshold
Stworzenie głoduje przy krytycznym poziomie głodu.
test_eating_valid_food_restores_hunger
Zjedzenie poprawnego pożywienia zwiększa głód/najedzenie.
test_eating_invalid_food_does_not_restore_hunger
Niepoprawny typ jedzenia nie działa.
test_diet_accepts_configured_food_types
Dieta rozpoznaje dozwolone typy pożywienia.
test_diet_rejects_unconfigured_food_types
Dieta odrzuca niedozwolone typy pożywienia.
test_hunger_state_can_be_serialized
Stan głodu można zapisać.
test_hunger_state_can_be_restored
Stan głodu można odtworzyć z zapisu.
5. Player
Ruch i granice świata
test_player_initial_position_is_inside_world
Gracz zaczyna w granicach mapy.
test_player_can_move
Gracz zmienia pozycję po ruchu.
test_player_cannot_move_outside_world_bounds
Gracz nie może wyjść poza mapę.
test_player_position_is_clamped_to_world
Pozycja gracza jest ograniczana do świata.
test_player_movement_speed_is_positive
Prędkość ruchu jest większa od zera.
Interakcje
test_player_can_detect_nearby_resource
Gracz wykrywa zasób w zasięgu interakcji.
test_player_cannot_interact_with_resource_out_of_range
Gracz nie może zebrać zasobu spoza zasięgu.
test_player_harvests_resource
Interakcja z zasobem zbiera go.
test_player_receives_resource_after_harvest
Po zebraniu zasobu trafia on do gracza/ekwipunku.
test_player_can_collect_meat
Gracz może zebrać mięso po zabitym stworzeniu.
test_player_cannot_collect_empty_resource
Gracz nie zbiera pustego zasobu.
Zdrowie i obrażenia
test_player_initial_health_is_max
Gracz zaczyna z pełnym zdrowiem.
test_player_takes_damage
Obrażenia zmniejszają zdrowie.
test_player_health_does_not_go_below_zero
Zdrowie nie spada poniżej zera.
test_player_dies_at_zero_health
Gracz umiera przy zerowym zdrowiu.
test_player_can_heal_near_campfire_if_implemented
Jeżeli ognisko daje regenerację, gracz regeneruje zdrowie w jego zasięgu.
test_player_does_not_heal_above_max_health
Zdrowie nie przekracza maksimum.
Atak / łuk
test_player_can_attack
Gracz może wykonać atak.
test_player_attack_has_damage_value
Atak ma poprawną wartość obrażeń.
test_player_bow_can_fire
Gracz może strzelić z łuku.
test_player_bow_has_infinite_ammo
Amunicja łuku nie spada albo nie jest sprawdzana.
test_projectile_spawns_in_correct_direction
Pocisk pojawia się i leci w poprawnym kierunku.
test_projectile_damages_creature
Pocisk zadaje obrażenia stworzeniu.
test_projectile_is_removed_after_hit
Pocisk znika po trafieniu.
test_projectile_is_removed_outside_world
Pocisk znika po opuszczeniu mapy.
6. SmallPrey
Podstawowy stan
test_small_prey_initializes_with_valid_health
Ma poprawne zdrowie startowe.
test_small_prey_initializes_inside_world
Startuje w granicach mapy.
test_small_prey_has_valid_movement_speed
Ma poprawną prędkość.
test_small_prey_has_hunger_component
Ma komponent głodu.
test_small_prey_has_diet
Ma przypisaną dietę.
Ruch
test_small_prey_can_wander
Potrafi poruszać się losowo.
test_small_prey_does_not_leave_world_bounds
Nie wychodzi poza mapę.
test_small_prey_changes_direction_after_timer
Zmienia kierunek po czasie.
test_small_prey_stops_or_redirects_at_world_edge
Na krawędzi mapy zatrzymuje się lub zawraca.
Głód i jedzenie
test_small_prey_hunger_decreases_over_time
Głód spada z czasem.
test_small_prey_searches_food_when_hungry
Gdy jest głodne, szuka jedzenia.
test_small_prey_ignores_food_when_not_hungry
Gdy nie jest głodne, nie przełącza się niepotrzebnie w tryb szukania.
test_small_prey_moves_toward_food
Głodne stworzenie idzie w stronę jedzenia.
test_small_prey_eats_valid_food
Zjada poprawny typ pożywienia.
test_small_prey_does_not_eat_invalid_food
Nie je niepoprawnego typu pożywienia.
test_small_prey_hunger_restored_after_eating
Głód poprawia się po jedzeniu.
Obrażenia i śmierć
test_small_prey_takes_damage
Otrzymuje obrażenia.
test_small_prey_dies_at_zero_health
Umiera przy zerowym zdrowiu.
test_small_prey_drops_meat_on_death
Po śmierci zostawia mięso.
test_small_prey_does_not_drop_meat_multiple_times
Mięso nie pojawia się wielokrotnie z jednego ciała.
test_small_prey_removed_from_ecosystem_after_death
Martwe stworzenie jest usuwane z aktywnej listy ekosystemu.
7. Grazer
Podstawowy stan
test_grazer_initializes_with_valid_health
Grazer startuje z poprawnym zdrowiem.
test_grazer_initializes_inside_world
Startuje w granicach mapy.
test_grazer_has_hunger_component
Ma komponent głodu.
test_grazer_has_herbivore_diet
Dieta zawiera rośliny/trawy/krzaki, zależnie od projektu.
test_grazer_has_valid_speed
Prędkość jest poprawna.
Zachowanie
test_grazer_can_wander
Potrafi poruszać się losowo.
test_grazer_does_not_leave_world_bounds
Nie wychodzi poza mapę.
test_grazer_searches_plants_when_hungry
Gdy jest głodny, szuka roślin.
test_grazer_moves_toward_nearest_food
Idzie w stronę najbliższego jedzenia.
test_grazer_eats_plant_resource
Zjada zasób roślinny.
test_grazer_does_not_eat_meat
Nie zjada mięsa.
test_grazer_hunger_restored_after_eating
Najedzenie wzrasta po jedzeniu.
test_grazer_returns_to_wandering_after_eating
Po jedzeniu wraca do wędrówki.
Obrażenia i śmierć
test_grazer_takes_damage
Przyjmuje obrażenia.
test_grazer_dies_at_zero_health
Umiera przy zerowym zdrowiu.
test_grazer_drops_meat_on_death
Po śmierci zostawia mięso.
test_grazer_removed_from_ecosystem_after_death
Jest usuwany z aktywnych stworzeń.
8. Varnak
Podstawowy stan
test_varnak_initializes_with_valid_health
Varnak startuje z poprawnym zdrowiem.
test_varnak_initializes_inside_world
Startuje w granicach mapy.
test_varnak_has_predator_diet
Dieta pozwala jeść mięso/ofiary.
test_varnak_has_hunger_component
Ma komponent głodu.
test_varnak_has_attack_damage
Ma poprawną wartość ataku.
test_varnak_has_detection_range
Ma poprawny zasięg wykrywania.
Zachowanie podstawowe
test_varnak_can_wander
Porusza się losowo, gdy nie poluje.
test_varnak_does_not_leave_world_bounds
Nie wychodzi poza mapę.
test_varnak_does_not_attack_when_not_hungry_if_configured
Jeśli tak zakładamy, nie atakuje bez głodu.
test_varnak_searches_prey_when_hungry
Głodny Varnak szuka ofiary.
test_varnak_detects_nearby_small_prey
Wykrywa małą ofiarę w zasięgu.
test_varnak_detects_nearby_grazer
Wykrywa Grazera w zasięgu.
test_varnak_detects_player_when_hungry
Głodny Varnak wykrywa gracza.
test_varnak_ignores_target_outside_detection_range
Ignoruje cel poza zasięgiem.
Polowanie
test_varnak_moves_toward_target
Porusza się w stronę celu.
test_varnak_attacks_target_in_range
Atakuje, gdy cel jest w zasięgu.
test_varnak_attack_reduces_target_health
Atak zmniejsza zdrowie celu.
test_varnak_attack_has_cooldown
Atak nie odpala się co klatkę.
test_varnak_cannot_attack_during_cooldown
Nie może atakować podczas cooldownu.
test_varnak_resumes_attack_after_cooldown
Po cooldownie może znowu zaatakować.
test_varnak_eats_meat_or_dead_prey
Zjada mięso albo martwą ofiarę.
test_varnak_hunger_restored_after_eating
Głód poprawia się po jedzeniu.
test_varnak_returns_to_wandering_after_eating
Po jedzeniu wraca do normalnego zachowania.
Śmierć
test_varnak_takes_damage
Przyjmuje obrażenia.
test_varnak_dies_at_zero_health
Umiera przy zerowym zdrowiu.
test_varnak_drops_meat_on_death
Po śmierci zostawia mięso.
test_varnak_removed_from_ecosystem_after_death
Zostaje usunięty z listy aktywnych stworzeń.
9. EcosystemDirector
Inicjalizacja
test_ecosystem_director_initializes
Director uruchamia się poprawnie.
test_ecosystem_has_world_reference
Ma referencję do świata.
test_ecosystem_has_spawn_config
Ma konfigurację spawnów.
test_ecosystem_initial_population_is_created
Tworzy początkową populację stworzeń.
test_initial_population_counts_are_correct
Liczby SmallPrey, Grazerów i Varnaków są zgodne z konfiguracją.
test_spawned_creatures_are_inside_world
Wszystkie stworzenia spawnują się w granicach świata.
test_spawned_creatures_have_valid_biome_if_required
Jeśli spawn zależy od biomu, stworzenia pojawiają się w poprawnym biomie.
Zarządzanie stworzeniami
test_ecosystem_registers_creature
Director potrafi zarejestrować stworzenie.
test_ecosystem_unregisters_creature
Director potrafi usunąć stworzenie.
test_dead_creatures_are_removed
Martwe stworzenia są usuwane z aktywnych list.
test_ecosystem_does_not_update_dead_creatures
Martwe stworzenia nie są aktualizowane.
test_ecosystem_counts_living_creatures
Poprawnie liczy żywe stworzenia.
test_ecosystem_counts_creatures_by_type
Poprawnie liczy stworzenia po typie.
test_ecosystem_can_find_nearest_food
Potrafi znaleźć najbliższe jedzenie.
test_ecosystem_can_find_nearest_prey
Potrafi znaleźć najbliższą ofiarę.
test_ecosystem_returns_null_when_no_food_exists
Zwraca null, gdy nie ma jedzenia.
test_ecosystem_returns_null_when_no_prey_exists
Zwraca null, gdy nie ma ofiar.
Wydajność / indeksy
test_ecosystem_uses_cached_resource_list
Sprawdza, czy korzysta z listy/cache zasobów, a nie pełnego skanu sceny.
test_ecosystem_updates_resource_cache_after_resource_spawn
Cache zasobów aktualizuje się po dodaniu zasobu.
test_ecosystem_updates_resource_cache_after_resource_removed
Cache aktualizuje się po usunięciu zasobu.
test_ecosystem_updates_creature_cache_after_spawn
Cache stworzeń aktualizuje się po spawnie.
test_ecosystem_updates_creature_cache_after_death
Cache stworzeń aktualizuje się po śmierci.
test_ecosystem_does_not_scan_entire_tree_each_frame
Test zabezpieczający przed używaniem pełnego skanowania sceny w każdej klatce.
test_nearest_search_limits_candidates_by_range
Wyszukiwanie najbliższego celu ogranicza kandydatów do zasięgu.
test_ecosystem_update_can_be_throttled
Director może aktualizować cięższe rzeczy rzadziej niż co klatkę.
Balans populacji
test_ecosystem_does_not_spawn_above_max_population
Nie spawnuje stworzeń ponad limit.
test_ecosystem_can_spawn_replacement_if_population_low
Może odtworzyć populację, gdy liczba spadnie poniżej progu.
test_ecosystem_respects_spawn_cooldown
Spawn ma cooldown.
test_ecosystem_does_not_spawn_when_world_not_ready
Nie spawnuje, gdy świat nie jest jeszcze wygenerowany.
10. Minimap
Dane minimapy
test_minimap_initializes_with_world_reference
Minimap posiada referencję do świata.
test_minimap_generates_from_world_data
Minimap tworzy dane na podstawie świata.
test_minimap_scale_is_valid
Skala minimapy jest większa od zera.
test_world_position_converts_to_minimap_position
Pozycja świata poprawnie zamienia się na pozycję na minimapie.
test_minimap_position_stays_inside_minimap_bounds
Marker nie wychodzi poza minimapę.
test_player_marker_updates_position
Marker gracza aktualizuje pozycję.
test_creature_marker_updates_position_if_enabled
Markery stworzeń aktualizują pozycję, jeśli są włączone.
test_resource_marker_updates_position_if_enabled
Markery zasobów aktualizują pozycję, jeśli są włączone.
test_minimap_handles_empty_world
Minimap nie crashuje przy pustym świecie.
test_minimap_handles_missing_player
Minimap nie crashuje przy braku gracza.
Wydajność
test_minimap_does_not_rebuild_static_biome_texture_every_frame
Tekstura biomów nie jest przebudowywana co klatkę.
test_minimap_rebuilds_only_when_world_changes
Minimap przebudowuje statyczną warstwę tylko po zmianie świata.
test_minimap_dynamic_markers_update_without_rebuilding_background
Markery aktualizują się bez przebudowy całej minimapy.
11. MapScreen
test_map_screen_opens
Ekran mapy może zostać otwarty.
test_map_screen_closes
Ekran mapy może zostać zamknięty.
test_map_screen_toggles_visibility
Przycisk/akcja poprawnie przełącza widoczność mapy.
test_map_screen_receives_world_data
Ekran mapy dostaje dane świata.
test_map_screen_displays_player_position
Pokazuje pozycję gracza.
test_map_screen_handles_missing_world
Nie crashuje przy braku świata.
test_map_screen_handles_missing_player
Nie crashuje przy braku gracza.
test_map_screen_does_not_pause_game_unless_configured
Mapa nie pauzuje gry, chyba że tak zakładamy.
test_map_screen_rebuilds_map_only_when_needed
Mapa nie przebudowuje się bez potrzeby.
12. DebugPanel
Widoczność i tryby
test_debug_panel_initializes_hidden_or_visible_based_on_config
Panel startuje zgodnie z konfiguracją.
test_debug_panel_can_toggle_visibility
Panel można pokazać/ukryć.
test_debug_panel_tabs_exist
Istnieją zakładki debugowania.
test_debug_panel_switches_tabs
Można zmienić zakładkę.
test_debug_panel_handles_missing_world
Nie crashuje przy braku świata.
test_debug_panel_handles_missing_ecosystem
Nie crashuje przy braku ekosystemu.
test_debug_panel_handles_missing_player
Nie crashuje przy braku gracza.
Dane debugowe
test_debug_panel_displays_player_position
Pokazuje pozycję gracza.
test_debug_panel_displays_player_health
Pokazuje zdrowie gracza.
test_debug_panel_displays_world_seed
Pokazuje seed świata.
test_debug_panel_displays_day_time
Pokazuje czas/dzień gry.
test_debug_panel_displays_creature_counts
Pokazuje liczbę stworzeń.
test_debug_panel_displays_resource_counts
Pokazuje liczbę zasobów.
test_debug_panel_displays_fps
Pokazuje licznik FPS w lewym górnym rogu albo w sekcji debug.
test_debug_panel_fps_value_updates
FPS aktualizuje się w czasie.
test_debug_panel_fps_is_numeric
FPS jest liczbą.
Wydajność
test_debug_panel_does_not_rebuild_text_every_frame_when_values_unchanged
Panel nie przebudowuje dużych tekstów co klatkę, jeśli dane się nie zmieniły.
test_debug_panel_uses_update_interval
Panel aktualizuje dane według interwału, np. kilka razy na sekundę.
test_debug_panel_marks_dirty_when_debug_data_changes
Panel oznacza dane jako zmienione po zmianie stanu.
test_debug_panel_clears_dirty_flag_after_update
Po aktualizacji flaga dirty zostaje zdjęta.
13. SaveSystem
Zapis
test_save_system_initializes
SaveSystem uruchamia się poprawnie.
test_save_data_contains_version
Dane zapisu zawierają wersję save’a.
test_save_data_contains_world_seed
Zapis zawiera seed świata.
test_save_data_contains_world_time
Zapis zawiera czas/dzień gry.
test_save_data_contains_player_state
Zapis zawiera stan gracza.
test_save_data_contains_player_position
Zapis zawiera pozycję gracza.
test_save_data_contains_player_health
Zapis zawiera zdrowie gracza.
test_save_data_contains_resources
Zapis zawiera zasoby.
test_save_data_contains_resource_regeneration_state
Zapis zawiera stan regeneracji zasobów.
test_save_data_contains_creatures
Zapis zawiera stworzenia.
test_save_data_contains_creature_type_position_health_and_hunger
Każde stworzenie ma typ, pozycję, zdrowie i głód.
test_save_data_contains_ecosystem_state
Zapis zawiera dane ekosystemu.
test_save_file_is_created
Plik zapisu zostaje utworzony.
test_save_file_is_valid_json_or_resource_format
Format pliku jest poprawny.
test_save_system_handles_missing_directory
System tworzy katalog zapisu, jeśli go brakuje.
test_save_system_reports_error_when_save_fails
System zgłasza błąd, jeśli zapis się nie uda.
Odczyt
test_load_restores_world_seed
Odczyt przywraca seed świata.
test_load_restores_world_time
Odczyt przywraca czas/dzień.
test_load_restores_player_position
Odczyt przywraca pozycję gracza.
test_load_restores_player_health
Odczyt przywraca zdrowie gracza.
test_load_restores_resources
Odczyt przywraca zasoby.
test_load_restores_resource_regeneration_state
Odczyt przywraca etap regeneracji zasobów.
test_load_restores_creatures
Odczyt przywraca stworzenia.
test_load_restores_creature_hunger
Odczyt przywraca głód stworzeń.
test_load_restores_creature_health
Odczyt przywraca zdrowie stworzeń.
test_load_restores_creature_positions_inside_world
Po odczycie stworzenia są w granicach mapy.
test_load_handles_missing_save_file
Brak pliku zapisu nie crashuje gry.
test_load_handles_corrupted_save_file
Uszkodzony zapis nie crashuje gry.
test_load_handles_old_save_version
Starsza wersja zapisu jest obsłużona albo odrzucona kontrolowanie.
test_load_ignores_unknown_fields
Nieznane pola w save nie psują odczytu.
test_load_uses_default_values_for_missing_optional_fields
Brak opcjonalnych pól używa wartości domyślnych.
14. Biome / Tile logic
test_biome_has_valid_id
Biom ma poprawny identyfikator.
test_biome_has_valid_display_name
Biom ma nazwę.
test_biome_has_valid_color_or_visual_data
Biom ma dane wizualne.
test_biome_supports_expected_resource_types
Biom pozwala na właściwe typy zasobów.
test_biome_rejects_invalid_resource_types
Biom nie pozwala na zasoby, które nie powinny tam występować.
test_biome_supports_expected_creature_types
Biom pozwala na właściwe typy stworzeń.
test_tile_has_world_position
Kafelek ma pozycję w świecie.
test_tile_has_grid_position
Kafelek ma pozycję w siatce.
test_tile_can_report_if_walkable
Kafelek potrafi zgłosić, czy można po nim chodzić.
test_water_tile_is_not_walkable_if_configured
Jeśli woda blokuje ruch, kafelek wodny jest nieprzechodni.
test_hill_tile_modifies_movement_if_configured
Jeśli wzgórza wpływają na ruch, kafelek wzgórza zmienia koszt ruchu.
15. Resource spawning
test_resource_spawner_creates_resources
Spawner tworzy zasoby.
test_resource_spawner_respects_world_bounds
Zasoby pojawiają się w granicach mapy.
test_resource_spawner_respects_biome_rules
Zasoby pojawiają się w odpowiednich biomach.
test_resource_spawner_does_not_spawn_on_invalid_tiles
Nie spawnuje na niedozwolonych kafelkach.
test_resource_spawner_respects_max_resource_count
Nie przekracza limitu zasobów.
test_resource_spawner_uses_seeded_randomness
Spawn jest deterministyczny przy tym samym seedzie.
test_resource_spawner_can_spawn_grass
Spawnuje trawę, jeśli jest dostępna.
test_resource_spawner_can_spawn_bushes
Spawnuje krzaki.
test_resource_spawner_can_spawn_meat
Potrafi dodać mięso jako zasób po śmierci stworzenia.
test_resource_spawner_registers_resources_in_ecosystem_cache
Nowe zasoby są rejestrowane w cache ekosystemu.
16. Creature spawning
test_creature_spawner_creates_small_prey
Spawner tworzy SmallPrey.
test_creature_spawner_creates_grazer
Spawner tworzy Grazera.
test_creature_spawner_creates_varnak
Spawner tworzy Varnaka.
test_creature_spawner_respects_world_bounds
Stworzenia pojawiają się w granicach świata.
test_creature_spawner_respects_biome_rules
Stworzenia pojawiają się w odpowiednich biomach.
test_creature_spawner_does_not_spawn_on_blocked_tiles
Nie spawnuje na nieprzechodnich kafelkach.
test_creature_spawner_respects_population_limits
Nie przekracza limitu populacji.
test_creature_spawner_assigns_ecosystem_reference
Stworzenie dostaje referencję do ekosystemu.
test_creature_spawner_assigns_world_reference
Stworzenie dostaje referencję do świata.
test_creature_spawner_registers_creature_in_ecosystem
Stworzenie trafia do list/cache ekosystemu.
17. Combat / damage system
test_damageable_entity_takes_damage
Encja otrzymuje obrażenia.
test_damageable_entity_health_reduces_by_damage_amount
Zdrowie spada o wartość obrażeń.
test_damageable_entity_health_clamped_to_zero
Zdrowie nie spada poniżej zera.
test_damageable_entity_dies_when_health_zero
Encja umiera przy zerowym zdrowiu.
test_damageable_entity_does_not_die_twice
Śmierć nie wywołuje się wielokrotnie.
test_dead_entity_cannot_take_more_effective_damage
Martwa encja nie przetwarza kolejnych obrażeń.
test_attack_range_is_respected
Atak działa tylko w zasięgu.
test_attack_outside_range_does_not_damage
Atak poza zasięgiem nie zadaje obrażeń.
test_attack_cooldown_is_respected
Cooldown ataku działa.
test_friendly_fire_rules_are_respected
Jeśli istnieją zasady frakcji, są respektowane.
18. Day / time system
test_day_time_initializes_at_zero_or_configured_value
Czas świata startuje poprawnie.
test_day_time_advances_with_delta
Czas przesuwa się z deltą.
test_day_increments_after_day_length
Po pełnym cyklu zwiększa się numer dnia.
test_day_time_wraps_after_full_day
Czas dnia resetuje się po pełnym dniu.
test_resource_regeneration_uses_day_time
Regeneracja zasobów korzysta z czasu gry.
test_save_system_stores_day_time
Czas gry jest zapisywany.
test_load_system_restores_day_time
Czas gry jest odtwarzany.
19. Camera / viewport, jeśli jest osobny skrypt
test_camera_follows_player
Kamera podąża za graczem.
test_camera_does_not_show_outside_world_if_clamped
Kamera nie wychodzi poza granice świata, jeśli jest clamp.
test_camera_zoom_has_min_and_max
Zoom ma poprawne limity.
test_camera_handles_missing_player
Brak gracza nie powoduje błędu.
20. Input handling
test_move_input_returns_direction
Input ruchu zwraca poprawny wektor.
test_no_move_input_returns_zero_vector
Brak inputu zwraca wektor zerowy.
test_interact_input_triggers_interaction
Input interakcji odpala interakcję.
test_attack_input_triggers_attack
Input ataku odpala atak.
test_map_input_toggles_map
Input mapy przełącza ekran mapy.
test_debug_input_toggles_debug_panel
Input debug przełącza panel debugowania.
test_save_input_triggers_save_if_enabled
Input zapisu uruchamia zapis.
test_load_input_triggers_load_if_enabled
Input odczytu uruchamia load.
Najważniejsze testy do zrobienia jako pierwsze

Na tym etapie nie robiłbym od razu wszystkich. Priorytetowo stworzyłbym te:

Priorytet 1 — stabilność gry
test_world_generates_with_valid_dimensions
test_world_generation_does_not_spawn_entities_outside_bounds
test_player_cannot_move_outside_world_bounds
test_small_prey_does_not_leave_world_bounds
test_grazer_does_not_leave_world_bounds
test_varnak_does_not_leave_world_bounds
test_resource_node_can_be_harvested
test_resource_node_regenerates_after_required_time
test_creature_dies_at_zero_health
test_creature_drops_meat_on_death
test_save_file_is_created
test_load_restores_player_position
test_load_restores_resources
test_load_restores_creatures
Priorytet 2 — ekosystem
test_hunger_decreases_over_time
test_is_hungry_returns_true_below_threshold
test_grazer_searches_plants_when_hungry
test_varnak_searches_prey_when_hungry
test_varnak_attacks_target_in_range
test_varnak_hunger_restored_after_eating
test_ecosystem_counts_creatures_by_type
test_ecosystem_can_find_nearest_food
test_ecosystem_can_find_nearest_prey
test_dead_creatures_are_removed
Priorytet 3 — performance i debug
test_ecosystem_does_not_scan_entire_tree_each_frame
test_ecosystem_uses_cached_resource_list
test_ecosystem_uses_cached_creature_list
test_debug_panel_does_not_rebuild_text_every_frame_when_values_unchanged
test_debug_panel_uses_update_interval
test_minimap_does_not_rebuild_static_biome_texture_every_frame
test_minimap_dynamic_markers_update_without_rebuilding_background
test_debug_panel_displays_fps
Minimalny pakiet testów na v0.1

Gdybyś chciał realistycznie zamknąć testy jednostkowe przed oddaniem v0.1 testerowi, zrobiłbym taki minimalny zestaw:

Obszar	Liczba testów
World / WorldConfig	10
ResourceNode	8
HungerDiet	8
Player	8
SmallPrey	6
Grazer	6
Varnak	8
EcosystemDirector	12
SaveSystem	12
DebugPanel / FPS	5
Minimap / MapScreen	5

Razem: około 88 testów jednostkowych.

To jest dużo, ale sensownie dla zamknięcia wersji 0.1, bo zabezpiecza najważniejsze rzeczy: świat, granice mapy, zasoby, głód, AI, śmierć stworzeń, mięso, zapis/odczyt i debug.

Proponowana struktura plików testowych
tests/
  unit/
    test_world_config.gd
    test_world.gd
    test_biome_logic.gd
    test_resource_node.gd
    test_resource_spawner.gd
    test_hunger_diet.gd
    test_player.gd
    test_small_prey.gd
    test_grazer.gd
    test_varnak.gd
    test_creature_spawner.gd
    test_ecosystem_director.gd
    test_combat.gd
    test_save_system.gd
    test_minimap.gd
    test_map_screen.gd
    test_debug_panel.gd
Moja rekomendacja

Na obecnym etapie nie pisałbym testów pod każdy detal wizualny. Skupiłbym się na testach, które bronią grę przed regresją:

nic nie wychodzi poza mapę,
zasoby da się zebrać i regenerują się,
zwierzęta głodnieją i reagują na jedzenie,
Varnaki polują tylko wtedy, kiedy powinny,
stworzenia umierają i zostawiają mięso,
save/load przywraca świat,
debug i minimapa nie robią ciężkich operacji co klatkę.

To będzie najlepsza baza pod v0.1.1 i kolejne refaktoryzacje.