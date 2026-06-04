[TESTS] Add integration tests for living world flows

Labels:
type: test, area: tests, area: world, area: ecosystem, area: ai, priority: high, stage: validation

Cel

Dodać zestaw testów integracyjnych lub scenariuszy automatycznych dla głównych przepływów żywego świata, aby zabezpieczyć wersję v0.1 przed regresją w obszarach:

generowania świata,
spawnu roślin i zwierząt,
zachowania AI,
głodu i jedzenia,
śmierci zwierząt i dropu mięsa,
odrastania zasobów,
zapisu i odczytu ekosystemu,
minimapy.
Proponowana struktura testów
tests/
  integration/
    test_living_world_startup.gd
    test_spawn_rules.gd
    test_animal_bounds.gd
    test_hunger_food_flows.gd
    test_predator_flows.gd
    test_death_and_meat_drop.gd
    test_resource_regrowth_flow.gd
    test_save_load_ecosystem.gd
    test_minimap_landmarks.gd
  docs/
    living_world_smoke_test_checklist.md
Testy integracyjne
1. New game starts with ecosystem initialized
test_new_game_starts_with_ecosystem_initialized

Cel:
Sprawdzić, czy po rozpoczęciu nowej gry świat oraz ekosystem są poprawnie zainicjalizowane.

Warunki testu:

uruchomienie nowej gry,
wygenerowanie świata,
utworzenie EcosystemDirector,
stworzenie początkowych zasobów i zwierząt.

Sprawdzenia:

świat istnieje,
mapa ma poprawne rozmiary,
istnieje EcosystemDirector,
istnieją zasoby roślinne,
istnieją zwierzęta,
liczba zwierząt nie przekracza limitów,
wszystkie encje mają pozycje w granicach świata.

Przykładowe asercje:

assert_not_null(world)
assert_not_null(ecosystem_director)
assert_gt(ecosystem_director.get_creature_count(), 0)
assert_gt(ecosystem_director.get_resource_count(), 0)
assert_true(world.is_position_inside_world(player.global_position))
2. Vegetation does not spawn in pond water
test_vegetation_does_not_spawn_in_pond_water

Cel:
Wykrywać przypadki, w których trawa, krzaki albo inne rośliny spawnują się na wodzie/stawie.

Warunki testu:

wygenerować świat z biomami i stawami,
wymusić spawn roślinności,
pobrać wszystkie zasoby typu roślinnego.

Sprawdzenia:

żadna trawa nie znajduje się na kafelku wody,
żaden krzak nie znajduje się na kafelku wody,
żaden jadalny zasób roślinny nie znajduje się w stawie.

Przykładowe asercje:

for resource in ecosystem_director.get_resources():
    if resource.is_vegetation():
        var tile = world.get_tile_at_world_position(resource.global_position)
        assert_false(tile.is_water())
        assert_false(tile.is_pond())
3. Animals do not spawn in pond water
test_animals_do_not_spawn_in_pond_water

Cel:
Wykrywać przypadki, w których zwierzęta startują na wodzie.

Warunki testu:

uruchomić nową grę,
wygenerować świat,
utworzyć początkową populację zwierząt.

Sprawdzenia:

SmallPrey nie startuje na wodzie,
Grazer nie startuje na wodzie,
Varnak nie startuje na wodzie,
żadne zwierzę nie startuje na nieprzechodnim kafelku.

Przykładowe asercje:

for animal in ecosystem_director.get_creatures():
    var tile = world.get_tile_at_world_position(animal.global_position)
    assert_false(tile.is_water())
    assert_true(tile.is_walkable())
4. Animals remain inside world bounds
test_animals_remain_inside_world_bounds_after_simulation

Cel:
Sprawdzić, czy zwierzęta nie wychodzą poza mapę podczas symulacji.

Warunki testu:

uruchomić świat,
stworzyć populację zwierząt,
symulować kilka-kilkanaście sekund ruchu,
najlepiej wymusić ruch w pobliżu krawędzi mapy.

Sprawdzenia:

każde zwierzę pozostaje w granicach świata,
żadne zwierzę nie ma pozycji NaN,
żadne zwierzę nie ma pozycji ujemnej poza dozwolonym obszarem,
żadne zwierzę nie przekracza maksymalnej szerokości/wysokości świata.

Przykładowe asercje:

simulate_seconds(20.0)

for animal in ecosystem_director.get_creatures():
    assert_true(world.is_position_inside_world(animal.global_position))

Dodatkowy wariant:

test_animals_near_world_edge_do_not_leave_bounds

Cel:
Wymusić najgorszy przypadek — zwierzę startuje blisko granicy mapy i próbuje iść poza świat.

5. Small prey searches for food when hungry
test_small_prey_searches_for_food_when_hungry

Cel:
Sprawdzić przepływ: głód → znalezienie jedzenia → ruch w stronę jedzenia.

Warunki testu:

stworzyć SmallPrey,
ustawić niski poziom głodu,
umieścić poprawne jedzenie w zasięgu,
uruchomić aktualizację AI.

Sprawdzenia:

SmallPrey przechodzi w stan szukania jedzenia,
wybiera poprawny zasób jako cel,
porusza się w stronę jedzenia,
nie wybiera zasobów niezgodnych z dietą.

Przykładowe asercje:

small_prey.hunger.set_value(10)
simulate_seconds(2.0)

assert_true(small_prey.is_hungry())
assert_eq(small_prey.current_state, small_prey.State.SEARCHING_FOOD)
assert_not_null(small_prey.current_food_target)
6. Grazer eats plants when hungry
test_grazer_eats_plants_when_hungry

Cel:
Sprawdzić przepływ: głodny Grazer znajduje roślinę, podchodzi do niej i je.

Warunki testu:

stworzyć Grazera,
ustawić niski głód,
dodać jadalną roślinę blisko Grazera,
zasymulować czas.

Sprawdzenia:

Grazer wykrywa roślinę,
Grazer podchodzi do rośliny,
roślina zostaje częściowo lub całkowicie zużyta,
poziom głodu Grazera poprawia się,
Grazer wraca do normalnego zachowania po jedzeniu.

Przykładowe asercje:

var hunger_before = grazer.hunger.get_value()

simulate_seconds(5.0)

assert_gt(grazer.hunger.get_value(), hunger_before)
assert_true(plant_resource.is_depleted() or plant_resource.amount < plant_resource.max_amount)
7. Grazer can eat meat when desperate
test_grazer_can_eat_meat_when_desperate

Cel:
Sprawdzić awaryjne zachowanie Grazera: przy skrajnym głodzie może zjeść mięso.

Warunki testu:

stworzyć Grazera,
ustawić bardzo niski poziom głodu,
nie umieszczać roślin w pobliżu,
umieścić mięso w zasięgu,
zasymulować czas.

Sprawdzenia:

Grazer przy zwykłym głodzie preferuje rośliny,
przy desperackim głodzie może wybrać mięso,
mięso zostaje zużyte,
głód Grazera wzrasta,
po jedzeniu Grazer nie pozostaje w stanie desperacji.

Przykładowe asercje:

grazer.hunger.set_value(grazer.hunger.desperate_threshold - 1)

simulate_seconds(5.0)

assert_true(meat_resource.is_depleted())
assert_gt(grazer.hunger.get_value(), grazer.hunger.desperate_threshold)

Warto dodać też test zabezpieczający:

test_grazer_does_not_eat_meat_when_only_mildly_hungry

Cel:
Grazer nie powinien jeść mięsa, jeśli nie jest w stanie desperacji.

8. Varnak hunts prey when hungry
test_varnak_hunts_prey_when_hungry

Cel:
Sprawdzić pełny przepływ polowania: głód → wykrycie ofiary → pościg → atak.

Warunki testu:

stworzyć Varnaka,
ustawić niski poziom głodu,
stworzyć ofiarę w zasięgu wykrywania,
zasymulować czas.

Sprawdzenia:

Varnak wykrywa ofiarę,
wybiera ją jako cel,
przechodzi w stan polowania,
porusza się w stronę ofiary,
atakuje, gdy znajdzie się w zasięgu,
zdrowie ofiary spada.

Przykładowe asercje:

var prey_health_before = prey.health

simulate_seconds(8.0)

assert_eq(varnak.current_state, varnak.State.HUNTING)
assert_eq(varnak.current_target, prey)
assert_lt(prey.health, prey_health_before)

Dodatkowe warianty:

test_varnak_does_not_hunt_when_not_hungry
test_varnak_prefers_nearest_valid_prey
test_varnak_can_hunt_player_when_hungry_if_configured
9. Animal death creates meat drop
test_animal_death_creates_meat_drop

Cel:
Wykrywać regresję, w której po śmierci zwierzęcia nie pojawia się mięso.

Warunki testu:

stworzyć zwierzę,
zadać mu śmiertelne obrażenia,
poczekać jedną klatkę albo krótki czas na przetworzenie śmierci.

Sprawdzenia:

zwierzę jest martwe,
zwierzę zostało usunięte z aktywnej populacji,
w miejscu śmierci pojawia się zasób typu mięso,
mięso jest zarejestrowane w EcosystemDirector,
mięso nie pojawia się wielokrotnie.

Przykładowe asercje:

var death_position = animal.global_position

animal.take_damage(999)
await get_tree().process_frame

assert_true(animal.is_dead())

var meat = ecosystem_director.find_nearest_resource_of_type("meat", death_position, 32.0)
assert_not_null(meat)
assert_true(meat.is_meat())

Dodatkowy test:

test_animal_death_does_not_create_duplicate_meat_drops

Cel:
Ponowne wywołanie śmierci nie powinno tworzyć kolejnych dropów.

10. Resource regrowth advances after day progression
test_resource_regrowth_advances_after_day_progression

Cel:
Sprawdzić, czy zasoby odrastają wraz z upływem dni.

Warunki testu:

stworzyć zasób roślinny,
zebrać go do zera,
przesunąć czas gry o jeden lub kilka dni,
sprawdzić etap odrostu.

Sprawdzenia:

po zebraniu zasób jest pusty,
po upływie części czasu zmienia etap odrostu,
po pełnym czasie zasób jest ponownie dostępny,
zasób nie przekracza maksymalnej ilości,
stan wizualny odpowiada etapowi regeneracji.

Przykładowe asercje:

plant.harvest_all()
assert_true(plant.is_depleted())

world_time.advance_days(1)
plant.update_regrowth()

assert_gt(plant.regrowth_stage, 0)

world_time.advance_days(3)
plant.update_regrowth()

assert_true(plant.is_available())
assert_eq(plant.amount, plant.max_amount)
11. Save/load restores ecosystem state
test_save_load_restores_ecosystem_state

Cel:
Sprawdzić, czy zapis i odczyt poprawnie przywracają żywy świat.

Warunki testu:

uruchomić świat,
zmienić stan ekosystemu:
przesunąć gracza,
zmienić liczbę zwierząt,
zabić jedno zwierzę,
stworzyć mięso,
wyczerpać zasób,
zmienić poziom głodu zwierzęcia,
zapisać grę,
wyczyścić aktualny świat,
wczytać save.

Sprawdzenia:

seed świata jest przywrócony,
dzień/czas gry jest przywrócony,
gracz ma poprawną pozycję,
populacja zwierząt jest przywrócona,
zdrowie zwierząt jest przywrócone,
głód zwierząt jest przywrócony,
martwe zwierzę nie wraca jako żywe, jeśli było zapisane jako martwe/usunięte,
mięso po śmierci nadal istnieje,
stan zasobów i odrostu jest przywrócony.

Przykładowe asercje:

save_system.save_game("integration_test_save")

clear_current_world()

save_system.load_game("integration_test_save")

assert_eq(loaded_world.seed, original_seed)
assert_eq(loaded_ecosystem.get_creature_count(), expected_creature_count)
assert_not_null(loaded_ecosystem.find_resource_by_id(meat_id))
assert_eq(loaded_resource.regrowth_stage, expected_regrowth_stage)

Dodatkowe testy:

test_save_load_restores_meat_drop_after_animal_death
test_save_load_restores_hungry_animal_state
test_save_load_restores_depleted_resource_regrowth_state
12. Minimap renders with landmarks
test_minimap_renders_with_landmarks

Cel:
Sprawdzić, czy minimapa renderuje się z ważnymi punktami świata.

Warunki testu:

uruchomić świat,
wygenerować biomy, stawy, zasoby i gracza,
uruchomić minimapę.

Sprawdzenia:

minimapa istnieje,
minimapa ma wygenerowane tło,
minimapa pokazuje gracza,
minimapa pokazuje stawy/landmarki,
minimapa nie crashuje przy pustych danych,
landmarki są przeliczone z pozycji świata na pozycję minimapy.

Przykładowe asercje:

minimap.rebuild(world)

assert_true(minimap.has_background_texture())
assert_true(minimap.has_player_marker())
assert_gt(minimap.get_landmark_marker_count(), 0)

Dodatkowy test:

test_minimap_landmark_positions_are_inside_minimap_bounds
Smoke-test checklist jako alternatywa albo dodatek

Jeżeli pełne testy integracyjne są trudne na tym etapie, można dodać checklistę smoke-testów do dokumentacji.

Plik:

docs/testing/living_world_smoke_test_checklist.md

Treść:

# Living World Smoke Test Checklist

## Cel

Sprawdzić ręcznie lub półautomatycznie główne przepływy żywego świata przed zamknięciem wersji v0.1.

## Checklist

### Start nowej gry

- [ ] Nowa gra uruchamia się bez błędów.
- [ ] Świat generuje się poprawnie.
- [ ] Gracz pojawia się w granicach mapy.
- [ ] Ekosystem jest zainicjalizowany.
- [ ] Na mapie istnieją zasoby.
- [ ] Na mapie istnieją zwierzęta.

### Spawn roślinności

- [ ] Roślinność pojawia się na lądzie.
- [ ] Roślinność nie pojawia się w stawach.
- [ ] Krzaki nie pojawiają się na wodzie.
- [ ] Trawa nie pojawia się na wodzie.

### Spawn zwierząt

- [ ] SmallPrey nie spawnuje się na wodzie.
- [ ] Grazer nie spawnuje się na wodzie.
- [ ] Varnak nie spawnuje się na wodzie.
- [ ] Zwierzęta pojawiają się tylko na przechodnich kafelkach.

### Granice świata

- [ ] Gracz nie wychodzi poza mapę.
- [ ] SmallPrey nie wychodzi poza mapę.
- [ ] Grazer nie wychodzi poza mapę.
- [ ] Varnak nie wychodzi poza mapę.
- [ ] Zwierzęta przy krawędzi mapy zawracają albo zatrzymują się.

### Głód i jedzenie

- [ ] SmallPrey szuka jedzenia, gdy jest głodne.
- [ ] Grazer szuka roślin, gdy jest głodny.
- [ ] Grazer zjada rośliny.
- [ ] Grazer może zjeść mięso w stanie desperacji.
- [ ] Po jedzeniu głód zwierzęcia wzrasta.

### Polowanie

- [ ] Varnak szuka ofiary, gdy jest głodny.
- [ ] Varnak goni ofiarę.
- [ ] Varnak zadaje obrażenia ofierze.
- [ ] Varnak nie atakuje bez przerwy co klatkę.
- [ ] Varnak może doprowadzić do śmierci ofiary.

### Śmierć i mięso

- [ ] Zwierzę może umrzeć.
- [ ] Martwe zwierzę znika z aktywnej populacji.
- [ ] Po śmierci zwierzęcia pojawia się mięso.
- [ ] Mięso pojawia się w miejscu śmierci.
- [ ] Mięso nie duplikuje się wielokrotnie z jednego zwierzęcia.

### Odrastanie zasobów

- [ ] Zasób można zebrać.
- [ ] Zebrany zasób przechodzi w stan pusty.
- [ ] Po upływie dnia zasób przechodzi do kolejnego etapu odrostu.
- [ ] Po pełnym czasie zasób jest ponownie dostępny.

### Save/load

- [ ] Można zapisać grę.
- [ ] Można wczytać grę.
- [ ] Po wczytaniu pozycja gracza jest zachowana.
- [ ] Po wczytaniu liczba zwierząt jest zachowana.
- [ ] Po wczytaniu głód zwierząt jest zachowany.
- [ ] Po wczytaniu stan zasobów jest zachowany.
- [ ] Po wczytaniu mięso po śmierci zwierzęcia nadal istnieje.
- [ ] Po wczytaniu odrost zasobów jest na tym samym etapie.

### Minimap

- [ ] Minimapka się renderuje.
- [ ] Minimapka pokazuje pozycję gracza.
- [ ] Minimapka pokazuje stawy albo landmarki.
- [ ] Markery minimapy są w granicach minimapy.
- [ ] Minimapka nie przebudowuje całego tła co klatkę bez potrzeby.
Acceptance Criteria — doprecyzowane

Issue można zamknąć, gdy:

Istnieje zestaw testów integracyjnych dla living world albo smoke-test checklist.
Testy uruchamiają nową grę i sprawdzają inicjalizację ekosystemu.
Testy wykrywają spawn roślinności w wodzie.
Testy wykrywają spawn zwierząt w wodzie.
Testy sprawdzają, czy zwierzęta pozostają w granicach świata.
Testy sprawdzają podstawowy przepływ głodu i jedzenia.
Testy sprawdzają, czy Varnak poluje na ofiary, gdy jest głodny.
Testy wykrywają brak dropu mięsa po śmierci zwierzęcia.
Testy sprawdzają odrastanie zasobów po progresji dnia.
Testy sprawdzają zapis i odczyt stanu ekosystemu.
Testy sprawdzają, czy minimapa renderuje się z landmarkami.
Dokumentacja projektu opisuje, jak uruchomić testy albo jak wykonać checklistę smoke-testów.
Definition of Done
 Dodano pliki testów integracyjnych w tests/integration/.
 Dodano lub zaktualizowano dokumentację testów.
 Testy można uruchomić lokalnie.
 Testy przechodzą na świeżej grze.
 Testy failują, jeśli roślinność spawnuje się w wodzie.
 Testy failują, jeśli zwierzęta spawnują się w wodzie.
 Testy failują, jeśli zwierzęta wychodzą poza mapę.
 Testy failują, jeśli po śmierci zwierzęcia nie pojawia się mięso.
 Testy failują, jeśli save/load nie przywraca ekosystemu.
 Smoke-test checklist znajduje się w dokumentacji projektu.
Priorytet implementacji

Na start zrobiłbym testy w tej kolejności:

test_new_game_starts_with_ecosystem_initialized
test_vegetation_does_not_spawn_in_pond_water
test_animals_do_not_spawn_in_pond_water
test_animals_remain_inside_world_bounds_after_simulation
test_animal_death_creates_meat_drop
test_save_load_restores_ecosystem_state
test_resource_regrowth_advances_after_day_progression
test_grazer_eats_plants_when_hungry
test_varnak_hunts_prey_when_hungry
test_minimap_renders_with_landmarks

To będzie najmocniejszy pakiet walidacyjny dla obecnego etapu. Najważniejsze jest, żeby te testy nie sprawdzały pojedynczych klas w izolacji, tylko faktyczny przepływ: świat → spawn → AI → interakcja → zmiana stanu → zapis/odczyt.