Darwinian Ecosystem Prototype
Zadania do GitHub Issues dla prototypu ekosystemu i ewolucji

Cel milestone'u
Dodać pierwszy działający model ekosystemu, w którym biom ma ograniczoną roślinność, zwierzęta mają głód i preferencje żywieniowe, a średni gatunek roślinożerny może stopniowo przesuwać się w stronę wszystkożerności pod presją braku pożywienia.
Założenie produkcyjne: obecny prototyp ma już fundamenty takie jak World, biomy, EvolutionDirector, DayNightSystem, SaveSystem, HUD, debug panel, crafting, Varnaki i EventBus. Ekosystem powinien być dokładany jako nowy moduł, a nie jako przebudowa całej gry.
Proponowane etykiety
Główne etykiety
type: feature
type: refactor
type: balancing
type: debug
type: save-load
type: documentation
Obszary systemu
area: ecosystem
area: world
area: creatures
area: ai
area: evolution
area: ui
area: save-system
area: data
Priorytety
priority: high
priority: medium
priority: low
Etapy
milestone: darwinian-ecosystem
stage: foundation
stage: simulation
stage: polish

Issue 1: Add EcosystemDirector system  [type: feature | area: ecosystem | area: world | priority: high | stage: foundation | milestone: darwinian-ecosystem]
Labels
type: feature, area: ecosystem, area: world, priority: high, stage: foundation, milestone: darwinian-ecosystem


Cel
Dodać nowy system EcosystemDirector, który będzie centralnym modułem zarządzającym stanem ekosystemu na poziomie biomów. System nie powinien jeszcze implementować pełnej ewolucji; ma przechowywać i aktualizować podstawowe dane środowiskowe.
Zakres
Utworzyć scripts/systems/ecosystem_director.gd.
Dodać node EcosystemDirector do scenes/main.tscn.
Podłączyć go w GameManager podobnie jak EvolutionDirector, DayNightSystem, World, SaveSystem i HUD.
Dane zarządzane przez system
biome_id
plant_biomass
max_plant_biomass
plant_regrowth_rate
overgrazing_pressure
small_prey_population
grazer_population
predator_pressure
Wymagania
EcosystemDirector ma metodę inicjalizacji biomów na podstawie WorldConfig.
System aktualizuje dane w ticku symulacyjnym, np. raz na kilka sekund, nie co klatkę.
System emituje zdarzenia przez EventBus, gdy biomasa roślinności spada poniżej istotnych progów.
Na tym etapie dane mogą być tylko liczbowe, bez widocznego wpływu na świat.
Acceptance Criteria
Po uruchomieniu gry EcosystemDirector istnieje w głównej scenie.
Każdy biom ma własny stan ekosystemu.
Dane biomów można odczytać z debug logów lub tymczasowego printa.
System nie powoduje błędów przy starcie gry.
System jest gotowy do podłączenia do debug panelu i save/load.

Issue 2: Add biome plant biomass model  [type: feature | area: ecosystem | area: world | priority: high | stage: foundation | milestone: darwinian-ecosystem]
Labels
type: feature, area: ecosystem, area: world, priority: high, stage: foundation, milestone: darwinian-ecosystem


Cel
Dodać model biomasy roślinnej dla każdego biomu. Biomasa ma reprezentować abstrakcyjny poziom dostępnej roślinności, z której korzystają roślinożercy. Nie symulujemy każdej rośliny osobno.
Zakres
Każdy biom przechowuje plant_biomass, max_plant_biomass, plant_regrowth_rate, plant_consumption_pressure i overgrazing_level.
Plant_biomass odnawia się z czasem do max_plant_biomass.
Populacje roślinożerne zmniejszają plant_biomass.
Progi statusu biomu
70-100%: healthy
30-69%: stressed
10-29%: depleted
0-9%: collapsing
Eventy
ecosystem_biome_stressed
ecosystem_biome_depleted
ecosystem_biome_collapsing
Wymagania
Dodać metodę aktualizacji biomasy w EcosystemDirector.
Dodać helper do pobierania aktualnego statusu biomu.
Przy niskiej biomasie wysłać event przez EventBus.
Acceptance Criteria
Biomasa odnawia się z czasem.
Biomasa maleje, gdy istnieje populacja roślinożerców.
Biom zmienia status zależnie od poziomu biomasy.
Eventy są emitowane przy zmianie statusu.
System działa niezależnie od widocznych resource node’ów.

Issue 3: Add ecosystem state to debug panel  [type: debug | area: ecosystem | area: ui | priority: high | stage: foundation | milestone: darwinian-ecosystem]
Labels
type: debug, area: ecosystem, area: ui, priority: high, stage: foundation, milestone: darwinian-ecosystem


Cel
Rozszerzyć debug panel o podgląd stanu ekosystemu. Bez tego trudno będzie ocenić, czy symulacja działa poprawnie.
Zakres
W DebugPanel dodać sekcję Ecosystem.
Dla każdego biomu pokazywać nazwę, biomasę roślin, status, populacje SmallPrey/Grazer, predator pressure i overgrazing level.
Przykład widoku
Ecosystem

Westwood
Plant biomass: 82%
Status: healthy
Small prey: 14
Grazers: 6
Predator pressure: 0.2
Overgrazing: 0.1
Wymagania
HUD/debug panel powinien dostać referencję do EcosystemDirector.
Dane powinny odświeżać się tak jak inne dane debugowe.
Brak EcosystemDirector nie powinien crashować HUD-a.
Acceptance Criteria
Debug panel pokazuje stan ekosystemu.
Widać osobne dane dla każdego biomu.
Zmiany biomasy są widoczne w czasie.
Panel działa razem z istniejącymi informacjami o graczu, Varnakach i dniu/nocy.

Issue 4: Add small prey creature species  [type: feature | area: creatures | area: ai | area: ecosystem | priority: high | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: creatures, area: ai, area: ecosystem, priority: high, stage: simulation, milestone: darwinian-ecosystem


Cel
Dodać pierwszy gatunek małej ofiary, który będzie podstawą łańcucha pokarmowego. Gatunek ma jeść roślinność, uciekać przed graczem i większymi zwierzętami oraz być pożywieniem dla Varnaków i przyszłych drapieżników.
Zakres
Utworzyć scenes/creatures/small_prey.tscn.
Utworzyć scripts/creatures/small_prey.gd.
Utworzyć data/species/small_prey.json.
AI states
IDLE
WANDER
EAT
FLEE
DEAD
Minimalne cechy
health
speed
fear
hunger
plant_consumption_rate
reproduction_value
Eventy
small_prey_killed_by_player
small_prey_killed_by_varnak
small_prey_consumed_plants
Wymagania
SmallPrey losowo wędruje po biomie.
Okresowo je roślinność z biomu.
Ucieka, gdy gracz lub Varnak jest blisko.
Może zginąć po otrzymaniu obrażeń.
Informuje EcosystemDirector o śmierci.
Acceptance Criteria
SmallPrey pojawia się w świecie.
SmallPrey porusza się samodzielnie.
SmallPrey ucieka przed graczem.
SmallPrey ucieka przed Varnakiem.
SmallPrey może zostać zabity.
Śmierć SmallPrey wpływa na populację w EcosystemDirector.

Issue 5: Spawn small prey based on biome ecosystem state  [type: feature | area: world | area: ecosystem | area: creatures | priority: high | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: world, area: ecosystem, area: creatures, priority: high, stage: simulation, milestone: darwinian-ecosystem


Cel
Połączyć widoczne zwierzęta z abstrakcyjnym stanem populacji biomu. EcosystemDirector trzyma populację w tle, a World spawnuje reprezentantów tej populacji w pobliżu gracza lub w aktywnych biomach.
Zakres
Dodać do World obsługę spawnowania SmallPrey.
Spawn zależy od small_prey_population, plant_biomass, danger biomu, odległości od gracza i max visible prey count.
Wymagania
Więcej SmallPrey w biomach z wysoką biomasą.
Mniej SmallPrey w biomach wyeksploatowanych.
SmallPrey nie spawnuje się bezpośrednio na graczu.
Liczba widocznych SmallPrey jest limitowana.
Acceptance Criteria
SmallPrey spawnuje się w świecie.
Spawn zależy od danych biomu.
W biomach z niską biomasą pojawia się mniej SmallPrey.
System nie tworzy nieskończonej liczby node’ów.
Po śmierci SmallPrey populacja biomu jest aktualizowana.

Issue 6: Add adaptive grazer creature species  [type: feature | area: creatures | area: ai | area: evolution | area: ecosystem | priority: high | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: creatures, area: ai, area: evolution, area: ecosystem, priority: high, stage: simulation, milestone: darwinian-ecosystem


Cel
Dodać średnie zwierzę roślinożerne, które będzie pierwszym gatunkiem zdolnym do zmiany niszy żywieniowej. Na początku działa jak roślinożerca, ale przy niedoborze roślinności zaczyna korzystać z alternatywnego pożywienia.
Zakres
Utworzyć scenes/creatures/grazer.tscn.
Utworzyć scripts/creatures/grazer.gd.
Utworzyć data/species/grazer.json.
AI states
IDLE
WANDER
EAT_PLANTS
SEEK_FOOD
FLEE
SCAVENGE
HUNT_SMALL_PREY
DEAD
Cechy
health
speed
fear
aggression
hunger
plant_diet
meat_diet
scavenger_diet
size
reproduction_rate
Początkowy profil
plant_diet = 0.85
meat_diet = 0.05
scavenger_diet = 0.10
aggression = 0.15
fear = 0.70
Wymagania
Jeśli biom ma dużo roślinności, Grazer je rośliny.
Jeśli biomasa jest niska, Grazer szuka alternatyw.
Jeśli głód jest wysoki, Grazer może jeść padlinę.
Jeśli głód jest bardzo wysoki, Grazer może próbować polować na SmallPrey.
Grazer nadal powinien bać się Varnaków i gracza, chyba że jego agresja w przyszłości wzrośnie.
Acceptance Criteria
Grazer pojawia się w świecie.
Grazer normalnie je roślinność.
Grazer reaguje na niski poziom biomasy.
Grazer może przejść w tryb szukania alternatywnego pożywienia.
Grazer może zaatakować SmallPrey w warunkach głodu.
Zachowanie Grazera jest widoczne w debug panelu lub logach.

Issue 7: Add hunger and diet system for ecosystem creatures  [type: feature | area: creatures | area: ai | area: ecosystem | priority: high | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: creatures, area: ai, area: ecosystem, priority: high, stage: simulation, milestone: darwinian-ecosystem


Cel
Dodać wspólny model głodu i preferencji żywieniowych dla stworzeń ekosystemu. System ma być prosty i możliwy do rozszerzenia na Varnaki oraz inne gatunki.
Zakres
Dodać hunger, max_hunger, hunger_growth_rate, energy, diet preferences i food target selection.
Każdy gatunek może posiadać plant_diet, meat_diet i scavenger_diet.
Wymagania
Głód rośnie z czasem.
Jedzenie obniża głód.
Wysoki głód zwiększa skłonność do ryzykownego zachowania.
Diet traits wpływają na wybór jedzenia.
Rozważyć komponenty hunger_component.gd i diet_component.gd albo prosty zestaw współdzielonych metod.
Acceptance Criteria
SmallPrey ma działający głód.
Grazer ma działający głód.
Głód wpływa na decyzje AI.
Diet traits wpływają na wybór jedzenia.
Głód i dieta są widoczne w debug danych stworzenia.

Issue 8: Add grazer niche shift from herbivore to omnivore  [type: feature | area: evolution | area: ecosystem | area: ai | priority: high | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: evolution, area: ecosystem, area: ai, priority: high, stage: simulation, milestone: darwinian-ecosystem


Cel
Dodać pierwszy model zmiany niszy ekologicznej. Grazer zaczyna jako roślinożerca, ale gdy przez dłuższy czas brakuje roślinności, populacja stopniowo przesuwa się w stronę wszystkożerności.
Zakres
W EcosystemDirector śledzić average_plant_diet, average_meat_diet, average_scavenger_diet, average_aggression, current_niche i generations_under_food_stress.
Na tym etapie obsłużyć zmianę HERBIVORE -> OMNIVORE.
Nisze
HERBIVORE
OMNIVORE
PREDATOR
Przykładowy próg
if average_meat_diet + average_scavenger_diet > 0.45:
    current_niche = OMNIVORE
Wymagania
Jeśli przez kilka cykli plant_biomass < 30%, grazer_population > 0, small_prey_population > 0 i Grazery przeżywają dzięki nie-roślinnemu jedzeniu, to plant_diet spada, meat_diet/scavenger_diet rosną, a aggression lekko rośnie.
Po przekroczeniu progu current_niche zmienia się na OMNIVORE.
Emitować event grazer_niche_shifted z biome_id, old_niche, new_niche i średnimi cechami.
Acceptance Criteria
Grazer startuje jako HERBIVORE.
Niski poziom roślinności przez dłuższy czas wpływa na cechy populacji.
Populacja może zmienić niszę na OMNIVORE.
Zmiana niszy emituje event.
Debug panel pokazuje aktualną niszę Grazera.

Issue 9: Allow Varnaks to hunt ecosystem creatures  [type: feature | area: creatures | area: ai | area: ecosystem | area: evolution | priority: medium | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: creatures, area: ai, area: ecosystem, area: evolution, priority: medium, stage: simulation, milestone: darwinian-ecosystem


Cel
Rozszerzyć zachowanie Varnaków tak, aby nie istniały wyłącznie jako przeciwnik gracza. Varnaki powinny móc polować na SmallPrey i Grazery, dzięki czemu staną się częścią ekosystemu.
Zakres
Zmodyfikować scripts/creatures/varnak.gd.
Dodać wybór celu między player, small_prey i grazer.
Opcjonalnie dodać uproszczony głód Varnaka.
Wymagania
Varnak preferuje gracza, jeśli gracz jest blisko, Varnak jest agresywny, już ściga gracza albo jest noc i ma wysoką aktywność nocną.
Varnak poluje na zwierzęta, jeśli gracz jest daleko, Varnak jest głodny, w pobliżu jest łatwa ofiara albo biom ma wystarczającą populację ofiar.
Emitować varnak_hunted_small_prey i varnak_hunted_grazer.
Acceptance Criteria
Varnak potrafi wykryć SmallPrey.
Varnak potrafi wykryć Grazera.
Varnak może zabić stworzenie ekosystemu.
Zabicie stworzenia zmniejsza populację odpowiedniego biomu.
Varnak nadal działa poprawnie jako zagrożenie dla gracza.

Issue 10: Add ecosystem population simulation per biome  [type: feature | area: ecosystem | area: world | priority: high | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: ecosystem, area: world, priority: high, stage: simulation, milestone: darwinian-ecosystem


Cel
Dodać abstrakcyjną symulację populacji na poziomie biomów. Widoczne obiekty w świecie są tylko reprezentacją populacji; prawdziwy stan ekosystemu istnieje w EcosystemDirector.
Zakres
Dla każdego biomu symulować small_prey_population, grazer_population, varnak_ecosystem_pressure, plant_biomass i food_stress.
Wymagania
SmallPrey rośnie liczebnie, jeśli jest dużo roślinności; maleje przy presji drapieżników albo krytycznie niskiej biomasie.
Grazer rośnie liczebnie przy wystarczającej roślinności; maleje przy braku roślinności; może przetrwać lepiej przy wyższej wszystkożerności.
Varnak pressure zależy od liczby Varnaków w biomie i wpływa negatywnie na SmallPrey oraz Grazery.
Acceptance Criteria
Populacje zmieniają się w czasie.
Roślinność wpływa na populacje roślinożerców.
Drapieżnictwo wpływa na populacje ofiar.
Populacje nie spadają poniżej zera.
Debug panel pokazuje zmiany populacji.

Issue 11: Connect resource gathering to biome biomass pressure  [type: feature | area: ecosystem | area: world | priority: medium | stage: simulation | milestone: darwinian-ecosystem]
Labels
type: feature, area: ecosystem, area: world, priority: medium, stage: simulation, milestone: darwinian-ecosystem


Cel
Sprawić, żeby działania gracza wpływały na stan ekosystemu. Zbieranie zasobów z roślinności powinno obniżać biomasę biomu lub zwiększać presję eksploatacji.
Zakres
Zmodyfikować ResourceNode i/lub World, aby przy zebraniu zasobu roślinnego zgłaszać event do EcosystemDirector.
Dotyczy conifer_tree, leafy_tree, bush i dry_bush. Nie dotyczy rock.
Wymagania
Event plant_resource_harvested powinien zawierać resource_type, biome_id, position i biomass_impact.
Ścięcie drzewa powinno mieć większy wpływ niż zebranie krzewu.
Zbieranie suchego krzewu może mieć mały albo zerowy wpływ na biomasę.
Wpływ powinien być konfigurowalny w GameBalance.
Acceptance Criteria
Zbieranie drzew obniża biomasę biomu.
Zbieranie krzewów może obniżać biomasę biomu.
Skały nie wpływają na biomasę.
Debug panel pokazuje zmianę po zbieraniu.
Wpływ gracza na ekosystem jest zauważalny, ale nie zbyt gwałtowny.

Issue 12: Add ecosystem events and HUD messages  [type: feature | area: ecosystem | area: ui | priority: medium | stage: polish | milestone: darwinian-ecosystem]
Labels
type: feature, area: ecosystem, area: ui, priority: medium, stage: polish, milestone: darwinian-ecosystem


Cel
Dodać podstawową informację zwrotną dla gracza, że ekosystem reaguje na zmiany. Nie chodzi jeszcze o rozbudowane UI; wystarczą krótkie komunikaty przez istniejący system wiadomości HUD.
Zakres
Obsłużyć eventy ecosystem_biome_stressed, ecosystem_biome_depleted, ecosystem_biome_collapsing, grazer_niche_shifted, small_prey_population_declining i grazer_population_declining.
Przykładowe komunikaty
Roślinność w Westwood zaczyna się przerzedzać.
Zwierzęta w South Thicket mają coraz mniej pożywienia.
Grazery w Redfang Wilds zaczynają polować na mniejsze zwierzęta.
Populacja małych ofiar w Hearth Meadow spada.
Wymagania
Komunikaty nie powinny spamować gracza.
Ten sam komunikat nie powinien pojawiać się co kilka sekund.
Dodać cooldown dla wiadomości ekosystemu.
Acceptance Criteria
HUD pokazuje komunikaty o ważnych zmianach ekosystemu.
Komunikaty są czytelne.
Komunikaty nie spamują.
Zmiana niszy Grazera jest komunikowana graczowi.

Issue 13: Save and load ecosystem state  [type: save-load | area: ecosystem | area: save-system | priority: high | stage: foundation | milestone: darwinian-ecosystem]
Labels
type: save-load, area: ecosystem, area: save-system, priority: high, stage: foundation, milestone: darwinian-ecosystem


Cel
Rozszerzyć SaveSystem, aby zapisywał i odczytywał stan ekosystemu. Ekosystem powinien zostać dodany do procesu zapisu obok gracza, świata, budynków, Varnaków, dnia/nocy i ewolucji.
Zakres
Zapisywać biome ecosystem states, plant_biomass, plant status, small_prey_population, grazer_population, grazer average traits, grazer current niche, generations_under_food_stress i ewentualne cooldowny wiadomości.
Wymagania
Dodać do EcosystemDirector metody get_save_data() -> Dictionary oraz load_save_data(data: Dictionary) -> void.
Zmodyfikować SaveSystem, aby wywoływał te metody.
Brak danych ekosystemu w starszym save’ie nie może crashować gry.
Acceptance Criteria
Stan biomasy zapisuje się poprawnie.
Populacje zapisują się poprawnie.
Nisza Grazera zapisuje się poprawnie.
Po wczytaniu gry debug panel pokazuje te same wartości.
Brak danych ekosystemu w starszym save’ie nie crashuje gry.

Issue 14: Add ecosystem balancing constants to GameBalance  [type: balancing | area: ecosystem | area: data | priority: medium | stage: foundation | milestone: darwinian-ecosystem]
Labels
type: balancing, area: ecosystem, area: data, priority: medium, stage: foundation, milestone: darwinian-ecosystem


Cel
Dodać wartości balansujące ekosystem do GameBalance, aby uniknąć magic numbers w kodzie. Ekosystem powinien korzystać z tego samego podejścia co crafting, gracz, pochodnia, ognisko, noc, adaptacja, pułapki i walka.
Zakres
Dodać sekcję const ECOSYSTEM = { ... } w GameBalance.
Przenieść progi, tempa i mnożniki ekosystemu do jednej sekcji konfiguracyjnej.
Przykładowe wartości
const ECOSYSTEM = {
    "simulation_tick_seconds": 5.0,
    "default_plant_biomass": 100.0,
    "max_plant_biomass": 100.0,
    "plant_regrowth_rate": 1.5,
    "stressed_threshold": 70.0,
    "depleted_threshold": 30.0,
    "collapsing_threshold": 10.0,
    "tree_biomass_impact": 5.0,
    "bush_biomass_impact": 1.0,
    "small_prey_plant_consumption": 0.2,
    "grazer_plant_consumption": 0.6,
    "grazer_food_stress_threshold": 30.0,
    "grazer_niche_shift_threshold": 0.45,
    "diet_shift_rate": 0.02
}
Wymagania
Ekosystem używa wartości z GameBalance.
Brak magic numbers w głównych metodach symulacji.
Progi biomasy są łatwe do strojenia.
Tempo zmiany niszy można łatwo dostosować.
Acceptance Criteria
Ekosystem używa wartości z GameBalance.
Brak magic numbers w głównych metodach symulacji.
Progi biomasy są łatwe do strojenia.
Tempo zmiany niszy można łatwo dostosować.

Issue 15: Create species data files for ecosystem creatures  [type: feature | area: data | area: creatures | area: ecosystem | priority: medium | stage: foundation | milestone: darwinian-ecosystem]
Labels
type: feature, area: data, area: creatures, area: ecosystem, priority: medium, stage: foundation, milestone: darwinian-ecosystem


Cel
Dodać pliki danych dla nowych gatunków ekosystemu. Nowe gatunki powinny mieć definicje podobne do species_varnak.json, aby łatwiej było je balansować i rozszerzać.
Zakres
Utworzyć data/species/small_prey.json.
Utworzyć data/species/grazer.json.
Opcjonalne przeniesienie species_varnak.json do data/species/varnak.json zostawić na osobny refactor.
small_prey.json - przykład
{
  "id": "small_prey",
  "display_name": "Small Prey",
  "tier": 1,
  "base_traits": {
    "health": 20,
    "speed": 90,
    "fear": 0.9,
    "hunger_rate": 0.2,
    "plant_diet": 1.0,
    "meat_diet": 0.0,
    "scavenger_diet": 0.0,
    "reproduction_rate": 0.6
  }
}
grazer.json - przykład
{
  "id": "grazer",
  "display_name": "Grazer",
  "tier": 2,
  "base_traits": {
    "health": 45,
    "speed": 70,
    "fear": 0.7,
    "aggression": 0.15,
    "hunger_rate": 0.3,
    "plant_diet": 0.85,
    "meat_diet": 0.05,
    "scavenger_diet": 0.10,
    "reproduction_rate": 0.35
  },
  "evolution": {
    "mutation_rate": 0.03,
    "diet_shift_rate": 0.02
  }
}
Wymagania
Pliki JSON istnieją.
Dane są ładowane przez odpowiednie systemy lub przygotowane do ładowania.
Nowe gatunki nie mają hardkodowanych wszystkich wartości w skryptach.
Format danych jest spójny z kierunkiem dalszego rozwoju.
Acceptance Criteria
Pliki JSON istnieją.
Dane są ładowane przez odpowiednie systemy lub przygotowane do ładowania.
Nowe gatunki nie mają hardkodowanych wszystkich wartości w skryptach.
Format danych jest spójny z kierunkiem dalszego rozwoju.

Issue 16: Add ecosystem test controls to debug panel  [type: debug | area: ecosystem | area: ui | priority: medium | stage: polish | milestone: darwinian-ecosystem]
Labels
type: debug, area: ecosystem, area: ui, priority: medium, stage: polish, milestone: darwinian-ecosystem


Cel
Dodać przyciski testowe do debug panelu, aby łatwo symulować presję ekologiczną bez czekania wielu cykli.
Zakres
Dodać przyciski: Reduce plant biomass, Restore plant biomass, Add small prey, Remove small prey, Add grazers, Remove grazers, Force grazer food stress, Force grazer niche shift check, Advance ecosystem tick.
Wymagania
Przyciski powinny działać na aktualnym biomie gracza albo na wybranym biomie.
Jeśli wybór biomu jest zbyt kosztowny, pierwsza wersja może działać na biomie, w którym znajduje się gracz.
Akcje powinny być widoczne natychmiast w debug panelu.
Acceptance Criteria
Można ręcznie obniżyć biomasę biomu.
Można ręcznie przywrócić biomasę biomu.
Można zwiększyć/zmniejszyć populację SmallPrey.
Można zwiększyć/zmniejszyć populację Grazerów.
Można wymusić tick symulacji.
Można szybciej przetestować zmianę niszy Grazera.

Issue 17: Document Darwinian ecosystem prototype rules  [type: documentation | area: ecosystem | priority: medium | stage: polish | milestone: darwinian-ecosystem]
Labels
type: documentation, area: ecosystem, priority: medium, stage: polish, milestone: darwinian-ecosystem


Cel
Dodać dokumentację opisującą pierwszy model ekosystemu i ewolucji. Dokumentacja ma pomóc w dalszym rozwoju projektu oraz w tworzeniu kolejnych issues.
Zakres
Utworzyć docs/darwinian-ecosystem-prototype.md.
Wymagania
Dokument opisuje założenia systemu, poziomy troficzne, biomasę roślinności, SmallPrey, Grazera, Varnaki jako drapieżnika szczytowego, głód, preferencje żywieniowe, zmianę niszy i wpływ gracza.
W sekcji Not in scope zaznaczyć: brak pełnej genetyki osobników, migracji między biomami, wielu gatunków drapieżników, sezonów, chorób, rozmnażania osobnik po osobniku i pełnego 3D.
Acceptance Criteria
Dokument istnieje.
Opisuje aktualną wersję systemu.
Wskazuje, co jest poza zakresem.
Może być używany jako punkt odniesienia dla kolejnych milestone’ów.

Issue 18: Add manual test checklist for ecosystem prototype  [type: documentation | type: debug | area: ecosystem | priority: medium | stage: polish | milestone: darwinian-ecosystem]
Labels
type: documentation, type: debug, area: ecosystem, priority: medium, stage: polish, milestone: darwinian-ecosystem


Cel
Dodać checklistę manualnego testowania ekosystemu. Projekt ma już dokumenty testowe dla pochodni i debug panelu, więc ekosystem powinien dostać podobną checklistę.
Zakres
Utworzyć docs/ecosystem-manual-test.md.
Wymagania
Checklist powinna obejmować: start nowej gry, sprawdzenie biomasy biomów, obniżenie biomasy przez debug panel, obniżenie biomasy przez zbieranie roślin, spawn SmallPrey, zachowanie SmallPrey, spawn Grazera, Grazer jedzący roślinność, Grazer w warunkach głodu, Grazer polujący na SmallPrey, zmiana niszy z HERBIVORE na OMNIVORE, Varnak polujący na SmallPrey/Grazera, save/load ecosystem state.
Acceptance Criteria
Plik checklisty istnieje.
Checklistę da się wykonać ręcznie w grze.
Testy obejmują główne elementy milestone’u.
Checklist pokazuje, czy model ekosystemu faktycznie działa.

Sugerowana kolejność realizacji
Fundament
Add EcosystemDirector system
Add ecosystem balancing constants to GameBalance
Add biome plant biomass model
Add ecosystem state to debug panel
Create species data files for ecosystem creatures
Pierwsze stworzenia
Add small prey creature species
Spawn small prey based on biome ecosystem state
Add adaptive grazer creature species
Add hunger and diet system for ecosystem creatures
Właściwa ewolucja niszy
Add grazer niche shift from herbivore to omnivore
Allow Varnaks to hunt ecosystem creatures
Add ecosystem population simulation per biome
Connect resource gathering to biome biomass pressure
Stabilizacja
Save and load ecosystem state
Add ecosystem events and HUD messages
Add ecosystem test controls to debug panel
Document Darwinian ecosystem prototype rules
Add manual test checklist for ecosystem prototype
Absolutne minimum na start
Add EcosystemDirector system
Add biome plant biomass model
Add ecosystem state to debug panel
Add small prey creature species
Add adaptive grazer creature species
Te pięć zadań da pierwszy namacalny efekt: świat zacznie mieć własną bazę pokarmową i pierwsze zwierzęta zależne od jej stanu. Dopiero potem warto dodawać pełniejszą zmianę niszy i zachowanie drapieżników.
