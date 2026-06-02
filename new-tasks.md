Ecosystem Stabilization & Unified Creature Simulation
GitHub Issues — nowy zestaw zadań
Milestone
Ecosystem Stabilization & Unified Creature Simulation
Cel: ustabilizować działanie żywego świata: poprawić spawn roślin i zwierząt względem wody, uporządkować AI, ujednolicić statystyki osobnicze i populacyjne, rozszerzyć ewolucję na wszystkie stworzenia, poprawić mapy/debug, a następnie oczyścić kod i dodać testy.
Analiza dokumentacji i nowych uwag
Projekt ma już rozszerzony fundament: większy świat, biomy, roślinność, stawy, wzgórza, SmallPrey, Grazery, Varnaki, łuk, mięso, głód, dietę, biomasę, odrastanie zasobów i debug panel.
Dokumentacja wskazuje, że stan ekosystemu powinien pozostawać w EcosystemDirector, widoczne zasoby i encje w World, balans w GameBalance, a UI/debug w skryptach interfejsu.
Nowe uwagi są głównie stabilizacyjne: spawn w wodzie, czytelność mapy, rozróżnienie danych osobnika i populacji, ujednolicenie Varnaków z resztą zwierząt, ewolucja wszystkich gatunków oraz testy.
To nie jest moment na dokładanie dużej warstwy contentu. To jest moment na porządkowanie biologicznego modelu gry i technicznej stabilności.
Priorytet realizacji
1.  Naprawić spawn roślin w wodzie.
2.  Naprawić spawn zwierząt w wodzie.
3.  Poprawić widoczność wzgórz i stawów.
4.  Uporządkować minimapę i pełną mapę.
5.  Złagodzić tint biomasy.
6.  Poprawić regenerację staminy przy ognisku.
7.  Rozdzielić statystyki osobnicze i populacyjne.
8.  Dodać jedzenie mięsa przez głodne zwierzęta.
9.  Ujednolicić Varnaki jako pełnoprawne zwierzęta ekosystemu.
10.  Rozszerzyć ewolucję/generacje na wszystkie stworzenia.
11.  Przeprowadzić audyt AI.
12.  Wyczyścić i zoptymalizować kod.
13.  Dodać testy jednostkowe i integracyjne.
Issue 1: [BUG] Prevent vegetation from spawning inside pond water
Labels: type: bug, area: world, area: vegetation, area: landmarks, priority: critical, stage: stabilization
Cel
Naprawić problem, w którym roślinność, szczególnie drzewa, nadal pojawia się pośrodku stawów.
Problem
Dokumentacja zakłada, że roślinność nie powinna pojawiać się wewnątrz widocznego kształtu wody oraz że roślinność wokół stawów ma być rozkładana po obwodzie i odrzucana, jeśli trafia do środka wody. Aktualnie według uwag drzewa nadal rosną pośrodku stawu.
Zakres
tree
conifer_tree
leafy_tree
bush
small_bush
berry_bush
grass_patch
dense_grass
dry_bush
Wymagania
Dodać jedno wspólne sprawdzanie, czy pozycja znajduje się wewnątrz wody.
Wykorzystać ten sam kształt stawu do renderowania, spawnu roślin, spawnu zwierząt oraz ruchu gracza i zwierząt.
Roślinność może pojawiać się wokół stawu, ale nie w jego środku.
Drzewa powinny mieć dodatkowy margines od wody, większy niż trawy.
Acceptance Criteria
Drzewa nie spawnują się w środku stawów.
Krzaki nie spawnują się w środku stawów.
Trawy nie spawnują się w środku stawów.
Roślinność przy stawie nadal pojawia się wokół brzegu.
Spawn zachowuje się poprawnie po save/load.
Debug/spawn test nie generuje roślin wewnątrz wody.

Issue 2: [BUG] Prevent animals from spawning inside pond water
Labels: type: bug, area: creatures, area: world, area: ai, area: landmarks, priority: critical, stage: stabilization
Cel
Naprawić spawn zwierząt tak, aby nie pojawiały się w wodzie.
Zakres
SmallPrey
Grazer
Varnak
future creatures
Wymagania
Spawn zwierzęcia powinien sprawdzać world_bounds, odległość od gracza, minimalny dystans od innych zwierząt oraz to, czy punkt nie znajduje się w głębokiej wodzie.
Zwierzęta mogą wejść na płyciznę, ale nie powinny startować pośrodku stawu.
Varnaki również powinny respektować te zasady, ponieważ mają być traktowane jak zwierzęta ekosystemu.
Acceptance Criteria
SmallPrey nie spawnuje się w wodzie.
Grazer nie spawnuje się w wodzie.
Varnak nie spawnuje się w wodzie.
Spawn przy brzegu stawu jest możliwy, jeśli punkt jest poza wodą lub na płyciźnie.
Debug spawn również respektuje reguły wody.

Issue 3: [WORLD] Add shallow water zones for creature movement
Labels: type: feature, area: world, area: ai, area: creatures, area: landmarks, priority: high, stage: stabilization
Cel
Dodać rozróżnienie między głęboką wodą a płycizną. Zwierzęta nie powinny spawnować się w wodzie, ale mogą wchodzić na płyciznę.
Zakres
deep_water
shallow_water
shore
Zachowanie
deep_water: blokuje spawn i mocno ogranicza albo blokuje ruch.
shallow_water: pozwala przejść, ale wolniej.
shore: normalny ruch, większa szansa na roślinność.
Acceptance Criteria
Zwierzęta nie wchodzą do głębokiej wody.
Zwierzęta mogą przechodzić przez płyciznę.
Ruch na płyciźnie może być wolniejszy.
Logika płycizny jest wspólna dla SmallPrey, Grazerów i Varnaków.
Gracz i zwierzęta korzystają ze spójnej definicji stawu.

Issue 4: [VISUALS] Improve hill readability and elevation visuals
Labels: type: feature, area: world, area: visuals, area: landmarks, priority: high, stage: polish
Cel
Sprawić, aby wzgórza były bardziej widoczne i rozróżnialne jako wypiętrzenia terenu.
Problem
Według uwag wzgórza są za mało czytelne.
Zakres
bardziej wyraźny kształt
warstwy wysokości
delikatny cień
kontur lub gradient wysokości
różnica koloru względem biomu
Acceptance Criteria
Wzgórze jest łatwo zauważalne w widoku gry.
Wzgórze różni się od zwykłego biomu.
Wzgórze jest czytelne na minimapie i pełnej mapie.
Efekt nie wygląda jak nienaturalny łuk lub artefakt.

Issue 5: [BUG] Remove unwanted arc artifacts around ponds and hills
Labels: type: bug, area: visuals, area: world, area: landmarks, priority: high, stage: stabilization
Cel
Usunąć dziwny łuk/artefakt wizualny przy stawach i wzgórzach.
Zakres
pond shapes
hill shapes
landmark overlays
biome blended texture
minimap landmark drawing
full map landmark drawing
Acceptance Criteria
Przy stawach nie pojawia się dziwny łuk.
Przy wzgórzach nie pojawia się dziwny łuk.
Renderowanie landmarków jest stabilne po odświeżeniu mapy.
Poprawka nie psuje biome blendingu.

Issue 6: [MAP] Increase minimap size by 2x
Labels: type: feature, area: ui, area: map, priority: medium, stage: polish
Cel
Powiększyć minimapę dwukrotnie, aby była czytelniejsza w większym świecie.
Zakres
scripts/ui/minimap.gd
scenes/ui/hud.tscn
Wymagania
Minimapa ma być około 2x większa niż obecnie.
Nie powinna zasłaniać kluczowych elementów HUD.
Markery gracza, Varnaków, zwierząt i landmarków powinny być odpowiednio przeskalowane.
Przy większej minimapie warto ograniczyć liczbę nieistotnych markerów.
Acceptance Criteria
Minimapa jest 2x większa.
Minimapa pozostaje czytelna.
Markery nie są zbyt małe ani zbyt duże.
HUD nadal jest używalny.

Issue 7: [MAP] Hide non-interactive vegetation from minimap
Labels: type: feature, area: ui, area: map, area: vegetation, priority: high, stage: polish
Cel
Usunąć z minimapy nieinteraktywną roślinność, aby ograniczyć szum informacyjny.
Zasada
Minimapa powinna pokazywać: gracza, ważne zasoby interaktywne, Varnaki, ważniejsze zwierzęta lub hotspoty, stawy, wzgórza i biomy.
Minimapa nie powinna pokazywać: każdej trawy, każdej nieinteraktywnej rośliny ani gęstej roślinności dekoracyjnej.
Acceptance Criteria
Nieinteraktywne trawy nie są pokazywane na minimapie.
Nieinteraktywne krzaki/dekoracje nie są pokazywane na minimapie.
Interaktywne zasoby nadal mogą być widoczne.
Minimapa jest mniej chaotyczna.
Pełna mapa może pokazywać więcej informacji niż minimapa.

Issue 8: [VISUALS] Soften biomass depletion tint
Labels: type: polish, area: world, area: ecosystem, area: visuals, priority: medium, stage: polish
Cel
Złagodzić tint wskazujący spadek biomasy, ponieważ przy biomasie 0 wszystkie tereny wyglądają zbyt podobnie.
Problem
Tint biomasy jest za mocny i powoduje, że różne biomy tracą własną tożsamość wizualną, szczególnie przy niskiej biomasie.
Wymagania
Biom przy 0 biomasy nadal powinien wyglądać jak ten sam biom, tylko bardziej wyjałowiony.
Tint nie powinien całkowicie nadpisywać koloru biomu.
Różne biomy muszą pozostać rozróżnialne.
Wartości powinny trafić do GameBalance.
Acceptance Criteria
Przy niskiej biomasie biomy nadal różnią się od siebie.
Efekt wyjałowienia jest widoczny, ale łagodniejszy.
Przejście między stanami biomasy jest płynne.
Minimap/full map pozostają czytelne.

Issue 9: [MAP] Add ponds and hills to full map and minimap
Labels: type: feature, area: ui, area: map, area: landmarks, priority: high, stage: polish
Cel
Dodać stawy i wzgórza do minimapy oraz pełnej mapy.
Zakres
scripts/ui/minimap.gd
scripts/ui/map_screen.gd
Acceptance Criteria
Stawy są widoczne na minimapie.
Wzgórza są widoczne na minimapie.
Stawy są widoczne na pełnej mapie.
Wzgórza są widoczne na pełnej mapie.
Mapa ma legendę lub czytelne rozróżnienie symboli.
Markery landmarków nie zlewają się z markerami zasobów.

Issue 10: [CREATURES] Add individual creature stats separate from population stats
Labels: type: feature, area: creatures, area: ecosystem, area: ai, priority: critical, stage: architecture
Cel
Rozdzielić statystyki pojedynczego zwierzęcia od statystyk populacji.
Problem
Głód, zmęczenie i podobne wartości powinny należeć do konkretnego osobnika, a nie tylko do abstrakcyjnej populacji.
Statystyki osobnika
health
hunger
energy
fatigue/rest
age opcjonalnie
diet preferences
current target
current AI state
last food source
fitness_score
Statystyki populacji
population_count
average_hunger
average_energy
average_plant_diet
average_meat_diet
average_aggression
birth_rate
death_rate
predation_pressure
starvation_pressure
Wymagania
EcosystemDirector trzyma stan populacyjny.
Widoczne stworzenia trzymają stan osobniczy.
Śmierć, jedzenie i głód osobnika powinny wpływać na statystyki populacyjne.
Debug panel powinien pokazywać nearest creature stats i population aggregate stats.
Acceptance Criteria
SmallPrey ma własny głód i energię.
Grazer ma własny głód i energię.
Varnak ma własny głód i energię.
Populacja nadal ma statystyki zbiorcze.
Debug rozróżnia dane osobnika i populacji.
Save/load zachowuje stan osobników, jeśli są zapisane jako aktywne stworzenia.

Issue 11: [AI] Allow hungry animals to eat meat and carcasses
Labels: type: feature, area: ai, area: creatures, area: ecosystem, priority: high, stage: simulation
Cel
Zwierzęta powinny móc jeść mięso, gdy są głodne, zgodnie ze swoimi preferencjami żywieniowymi.
Zakres
Grazer
Varnak
future omnivores
future scavengers
Mechanika
Meat drop albo carcass powinien być wykrywany jako źródło pożywienia.
Zwierzę wybiera mięso, jeśli jest głodne, ma wystarczająco wysokie meat_diet lub scavenger_diet i mięso znajduje się w zasięgu wykrywania.
Zjedzenie mięsa obniża głód.
Zjedzenie mięsa może usunąć meat drop albo zmniejszyć jego ilość.
Acceptance Criteria
Głodny Grazer może zjeść mięso, jeśli jego dieta i stan głodu na to pozwalają.
Varnak może zjeść mięso po zabiciu ofiary.
Zwierzęta nie jedzą mięsa, jeśli ich dieta tego nie dopuszcza.
Meat drop nie duplikuje się po zjedzeniu.
Jedzenie mięsa wpływa na głód osobnika.

Issue 12: [CREATURES] Treat Varnaks as full ecosystem animals
Labels: type: refactor, area: creatures, area: ecosystem, area: ai, area: evolution, priority: critical, stage: architecture
Cel
Ujednolicić Varnaki z resztą ekosystemu.
Problem
Varnaki są głównymi przeciwnikami i mają własną adaptację, ale zgodnie z założeniem powinny być traktowane jako zwierzęta ekosystemu.
Varnak powinien mieć
individual hunger
individual energy/rest
diet profile
food target selection
meat/carcass consumption
fitness score
species/population reference
generation data
Wymagania
Nie usuwać unikalnych cech Varnaków: agresji, strachu przed ogniem, reakcji na pochodnię, nocnej aktywności.
Przenieść wspólne mechaniki do helperów/komponentów, gdzie ma to sens.
Varnak nadal powinien być szczególnym, inteligentniejszym drapieżnikiem, ale opartym na tym samym modelu biologicznym.
Acceptance Criteria
Varnak ma głód osobniczy.
Varnak może jeść mięso.
Varnak może polować, bo jest głodny, nie tylko dlatego, że gracz jest celem.
Varnak ma dane potrzebne do populacyjnej ewolucji.
Varnak nadal reaguje na ogień, pochodnię, noc, pułapki i gracza.

Issue 13: [EVOLUTION] Extend generation and evolution system to all creature species
Labels: type: feature, area: evolution, area: ecosystem, area: creatures, priority: critical, stage: architecture
Cel
Rozszerzyć system generacji/ewolucji na wszystkie stworzenia, nie tylko Varnaki.
Problem
Ewolucja/generacja ma dotyczyć wszystkich stworzeń. Obecnie dokumentacja nadal mocno wyróżnia Varnaki jako główne stworzenia adaptacyjne, a Grazery mają głównie niszę/diet shift.
Zakres
SmallPrey
Grazer
Varnak
future predators
Wspólny model gatunku/populacji
species_id
generation
population_traits
individual_traits
mutation_rate
selection_pressure
fitness_rules
niche
Mechanika
Każdy gatunek ma generację.
Osobniki mają cechy.
Populacje mają średnie cechy.
Osobniki zbierają fitness.
Nowe generacje przesuwają średnie cechy na podstawie przeżycia i rozmnażania.
Mutacja dodaje niewielką losową zmienność.
Acceptance Criteria
SmallPrey ma generację.
Grazer ma generację.
Varnak ma generację.
Debug pokazuje generacje wszystkich gatunków.
Zmiany cech wynikają z presji środowiska, nie tylko z ręcznego bonusu.
Save/load zapisuje generacje i populacyjne cechy gatunków.

Issue 14: [AI] Audit and improve creature decision-making
Labels: type: refactor, area: ai, area: creatures, area: ecosystem, priority: high, stage: stabilization
Cel
Przeprowadzić analizę i poprawki AI wszystkich stworzeń.
Zakres
wander
seek food
eat
hunt
flee
avoid water
avoid hills
avoid walls
avoid world edge
target switching
return to biome
react to player
react to fire/torch
Problemy do wykrycia
Zwierzę zmienia cel zbyt często.
Zwierzę ignoruje jedzenie.
Zwierzę ucieka w wodę.
Zwierzę blokuje się na przeszkodzie.
Zwierzę wychodzi poza biome/world bounds.
Varnak wybiera gracza zbyt często lub zbyt rzadko.
Grazer za szybko przechodzi w drapieżnictwo.
Zwierzęta jedzą, mimo że nie są głodne.
Acceptance Criteria
AI ma opisane priorytety decyzji.
Każdy stan ma jasne wejście i wyjście.
Zwierzęta nie migają chaotycznie między stanami.
Głód realnie wpływa na szukanie jedzenia.
Strach realnie wpływa na ucieczkę.
Debug pokazuje aktualny cel i powód decyzji przynajmniej dla najbliższego stworzenia.

Issue 15: [BUG] Fix campfire stamina regeneration behavior
Labels: type: bug, area: player, area: campfire, area: survival, priority: high, stage: stabilization
Cel
Poprawić regenerację staminy przy ognisku.
Problem
Wcześniej planowaliśmy, że przy ognisku gracz powinien szybciej regenerować staminę/rest, ale nowa uwaga wskazuje, że regeneracja staminy przy ognisku nadal wymaga poprawki.
Zakres
czy gracz jest w zasięgu aktywnego ogniska
czy ognisko jest aktywne
czy stamina regen multiplier jest stosowany
czy efekt nie stackuje się od wielu ognisk
czy HUD/debug pokazuje aktywny efekt
Acceptance Criteria
Stamina regeneruje się szybciej przy aktywnym ognisku.
Po odejściu od ogniska regeneracja wraca do normalnej.
Kilka ognisk nie mnoży efektu.
Debug pokazuje campfire_regen_active.
Wartości są konfigurowalne w GameBalance.

Issue 16: [PERFORMANCE] Cleanup and optimize living world systems
Labels: type: refactor, type: performance, area: world, area: ecosystem, area: ai, priority: high, stage: cleanup
Cel
Wyczyścić i zoptymalizować kod po rozbudowie ekosystemu.
Zakres
World
WorldConfig
EcosystemDirector
ResourceNode
SmallPrey
Grazer
Varnak
HungerDiet
Minimap
MapScreen
DebugPanel
SaveSystem
Szczególne ryzyka
Performance-sensitive są: renderowanie biomów, mapy, pętle zasobów/stworzeń i debug text.
Wymagania
Ograniczyć pełne skanowanie świata co klatkę.
Używać cache, grup i indeksów tam, gdzie ma to sens.
Debug panel nie powinien przebudowywać dużej ilości tekstu co klatkę bez potrzeby.
AI nie powinno wykonywać kosztownych globalnych wyszukiwań co frame.
Mapy powinny używać cache danych landmarków/biomów.
Acceptance Criteria
Smoke test działa stabilnie.
Gra nie przycina przy większej liczbie roślin i zwierząt.
Debug panel pozostaje responsywny.
Brak oczywistych duplikacji kodu między SmallPrey, Grazerem i Varnakiem.
Najczęstsze magic numbers są przeniesione do GameBalance.

Issue 17: [TESTS] Add unit tests for ecosystem and creature helpers
Labels: type: test, area: tests, area: ecosystem, area: creatures, priority: high, stage: validation
Cel
Dodać testy jednostkowe dla logiki ekosystemu i pomocniczych systemów stworzeń.
Zakres testów
HungerDiet
biomass status calculation
diet preference food choice
resource regrowth stage progression
population update calculations
niche shift threshold
world bounds helper
water/pond position helper
loot drop calculation
Acceptance Criteria
Istnieją testy jednostkowe dla HungerDiet.
Istnieją testy dla progów głodu.
Istnieją testy dla statusu biomasy.
Istnieją testy dla przechodzenia etapów odrastania zasobów.
Istnieją testy dla wyboru jedzenia według diety.
Testy można uruchomić lokalnie jako część procesu walidacji.

Issue 18: [TESTS] Add integration tests for living world flows
Labels: type: test, area: tests, area: world, area: ecosystem, area: ai, priority: high, stage: validation
Cel
Dodać testy integracyjne lub scenariusze automatyczne dla głównych przepływów żywego świata.
Zakres testów
new game starts with ecosystem initialized
vegetation does not spawn in pond water
animals do not spawn in pond water
animals remain inside world bounds
small prey searches for food when hungry
grazer eats plants when hungry
grazer can eat meat when desperate
varnak hunts prey when hungry
animal death creates meat drop
resource regrowth advances after day progression
save/load restores ecosystem state
minimap renders with landmarks
Acceptance Criteria
Istnieje zestaw testów integracyjnych albo smoke-test checklist dla living world.
Testy wykrywają spawn roślin w wodzie.
Testy wykrywają spawn zwierząt w wodzie.
Testy wykrywają brak mięsa po śmierci zwierzęcia.
Testy sprawdzają save/load ekosystemu.
Testy są opisane w dokumentacji projektu.

Issue 19: [DOCS] Update application overview after ecosystem stabilization
Labels: type: documentation, area: docs, area: ecosystem, priority: medium, stage: validation
Cel
Zaktualizować dokumentację po wdrożeniu stabilizacji ekosystemu.
Zakres
water spawn rules
shallow water rules
hill visual rules
minimap visibility rules
individual vs population stats
Varnaks as ecosystem animals
multi-species generation model
AI decision priorities
campfire regeneration behavior
test coverage
Acceptance Criteria
Dokumentacja opisuje aktualne działanie systemów.
Nowe reguły są spójne z kodem.
Dokumentacja rozróżnia stan obecny od planowanego.
Można jej użyć do kolejnego milestone’u.

Sugerowana kolejność realizacji
Faza 1 — pilne bugfixy świata
1.  [BUG] Prevent vegetation from spawning inside pond water
2.  [BUG] Prevent animals from spawning inside pond water
3.  [WORLD] Add shallow water zones for creature movement
4.  [BUG] Remove unwanted arc artifacts around ponds and hills
5.  [VISUALS] Improve hill readability and elevation visuals
Faza 2 — czytelność mapy i świata
1.  [MAP] Increase minimap size by 2x
2.  [MAP] Hide non-interactive vegetation from minimap
3.  [MAP] Add ponds and hills to full map and minimap
4.  [VISUALS] Soften biomass depletion tint
Faza 3 — ujednolicenie stworzeń
1.  [CREATURES] Add individual creature stats separate from population stats
2.  [AI] Allow hungry animals to eat meat and carcasses
3.  [CREATURES] Treat Varnaks as full ecosystem animals
4.  [EVOLUTION] Extend generation and evolution system to all creature species
5.  [AI] Audit and improve creature decision-making
Faza 4 — poprawki survivalowe i techniczne
1.  [BUG] Fix campfire stamina regeneration behavior
2.  [PERFORMANCE] Cleanup and optimize living world systems
Faza 5 — walidacja
1.  [TESTS] Add unit tests for ecosystem and creature helpers
2.  [TESTS] Add integration tests for living world flows
3.  [DOCS] Update application overview after ecosystem stabilization
Najważniejsze zadania z całego zestawu
1.  [BUG] Prevent vegetation from spawning inside pond water
2.  [CREATURES] Add individual creature stats separate from population stats
3.  [CREATURES] Treat Varnaks as full ecosystem animals
4.  [EVOLUTION] Extend generation and evolution system to all creature species
Te zadania zdecydują, czy projekt pozostanie survivalem z dodatkowymi zwierzętami, czy faktycznie pójdzie w stronę darwinowskiego ekosystemu działającego na poziomie osobników, populacji i gatunków.
Źródła wejściowe
application-overview.md — aktualna dokumentacja prototypu Apex Shift 2D
uwagi 2.06.2026.docx — nowe uwagi projektowe użytkownika
