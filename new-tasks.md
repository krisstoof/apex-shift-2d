Zadania GitHub Issues
Issue 1: [WORLD] Expand world size for ecosystem gameplay
Labels: type: feature, area: world, area: ecosystem, priority: high, stage: foundation
Cel
Powiększyć grywalną mapę, aby zwierzęta, roślinność, Varnaki i przyszłe zależności ekosystemu miały więcej przestrzeni do działania.
Zakres
world_bounds
resource spawn ranges
varnak spawn points
biome polygons
safe spawn distances
Acceptance Criteria
Świat jest większy niż obecnie.
Gracz ma więcej przestrzeni do eksploracji.
Varnaki i zwierzęta nie są zbyt ciasno rozmieszczone.
Minimap i full map działają poprawnie po zmianie rozmiaru świata.
World bounds nadal ograniczają ruch gracza.
Issue 2: [BALANCE] Add living world constants to GameBalance
Labels: type: balancing, area: world, area: ecosystem, area: data, priority: high, stage: foundation
Cel
Dodać wartości balansujące dla większego świata, roślinności, ruchu zwierząt, łuku, Varnak hunting, landmarków i odrastania zasobów do GameBalance.
Zakres
vegetation density
grass food value
bush food value
animal hunger thresholds
animal food search radius
varnak hunger thresholds
bow damage
bow cooldown
arrow speed
arrow lifetime
pond vegetation bonus
landmark spawn values
resource regrowth stages
days per growth stage
yield by growth stage
grass regrowth time
bush regrowth time
tree regrowth time
Acceptance Criteria
Nowe systemy używają wartości z GameBalance.
Brak magic numbers w AI, łuku, generatorze roślinności i odrastaniu zasobów.
Balans można łatwo zmieniać z jednego miejsca.
Wartości są opisane komentarzami.
Issue 3: [DEBUG] Organize debug panel with tabs and action buttons
Labels: type: debug, area: ui, area: debug, area: ecosystem, priority: high, stage: foundation
Cel
Uporządkować debug panel, aby ograniczyć chaos informacyjny po dodaniu ekosystemu, większej mapy, roślinności, głodu zwierząt, Varnak hunting, landmarków, łuku i odrastania zasobów.
Zakładki
Overview
Player
World
Ecosystem
Creatures
Evolution
Combat
Events
Tools
Overview
Day / time / phase
Player health / hunger / stamina / rest
Current biome
Live Varnaks
Small prey population total
Grazer population total
Current ecosystem warnings
Current generation
Tools
Add wood / stone / fiber / meat / torch
Give spear / give bow
Spawn aggressive Varnak / SmallPrey / Grazer
Reduce / restore plant biomass
Force ecosystem tick
Force grazer food stress
Force niche shift check
Advance resource growth by 1 day
Force full vegetation regrowth
Reset resource growth
Teleport out-of-bounds creatures back into world
Acceptance Criteria
Debug panel ma zakładki albo zwijane sekcje.
Dane gracza, świata, ekosystemu, stworzeń i ewolucji są rozdzielone.
Przyciski debugowe są przeniesione do Tools.
Overview pokazuje tylko najważniejsze informacje.
Panel nadal obsługuje istniejące funkcje debugowe.
Brak któregoś systemu nie powoduje crasha.
Issue 4: [BUG] Prevent animals from leaving world bounds
Labels: type: bug, area: creatures, area: ai, area: world, priority: critical, stage: foundation
Problem
Zwierzęta wychodzą poza obszar gry. To psuje ekosystem, liczniki populacji i testowanie AI.
Cel
Wszystkie stworzenia ekosystemu i Varnaki muszą pozostawać w granicach świata.
Zakres
SmallPrey
Grazer
Varnak
future ecosystem creatures
Proponowane rozwiązanie
AI nie powinno wybierać celu poza mapą.
Ruch powinien być clampowany do world bounds.
Przy granicy zwierzę powinno wybrać nowy kierunek do środka mapy.
Food targety poza mapą muszą być ignorowane.
Flee direction nie może wypchnąć zwierzęcia poza mapę na stałe.
Debug
Dodać creatures_out_of_bounds_count.
Opcjonalnie dodać przycisk: Teleport out-of-bounds creatures back into world.
Acceptance Criteria
SmallPrey, Grazer i Varnak nie wychodzą poza obszar gry.
Zwierzęta przy granicy mapy zawracają albo wybierają nowy cel.
AI nie generuje celów ruchu poza mapą.
Po 5-10 minutach testu żadne stworzenie nie znajduje się poza world bounds.
Debug panel pokazuje creatures_out_of_bounds_count = 0.
Issue 5: [WORLD] Replace sleep resource respawn with gradual multi-day regrowth
Labels: type: feature, area: world, area: ecosystem, area: resources, priority: high, stage: simulation
Cel
Usunąć natychmiastowy respawn zasobów po śnie i zastąpić go stopniowym odrastaniem zasobów w czasie.
Problem
Sen nie powinien magicznie resetować świata. Powinien tylko przesuwać czas, a zasoby powinny odrastać zgodnie z upływem dni.
Model wzrostu
growth_stage
max_growth_stage
days_to_next_stage
growth_progress
resource_yield_by_stage
can_be_harvested
biome_id
position
Przykład drzewa
Stage 0: stump / empty spot
Stage 1: sapling
Stage 2: medium tree
Stage 3: mature tree

Day 0: tree harvested
Day 1: sapling
Day 2: medium tree
Day 3: mature tree
Yield według etapu
sapling: 1 wood
medium tree: 2 wood
mature tree: 4 wood
Sen
Sen nie respawnuje zasobów bezpośrednio.
Sen przesuwa czas do rana.
Sen aktualizuje growth_progress zasobów.
Zasoby przechodzą do kolejnych etapów, jeśli minął odpowiedni czas.
Save/load
Zapisywać resource kind, position, biome_id, growth_stage, growth_progress, days_since_harvested, is_harvested.
Po wczytaniu gry zasoby powinny wrócić w tym samym etapie wzrostu.
Acceptance Criteria
Zasoby nie respawnują natychmiast po śnie.
Drzewo odrasta etapami przez około 3 dni.
Małe, średnie i duże drzewo mają różny wygląd albo przynajmniej różny debug/state.
Ilość surowca zależy od etapu wzrostu.
Krzaki i trawy odrastają szybciej niż drzewa.
Stan wzrostu zapisuje się i odczytuje przez SaveSystem.
System współpracuje z biomasą ekosystemu.
Issue 6: [WORLD] Add landmark generation to WorldConfig
Labels: type: feature, area: world, area: terrain, priority: medium, stage: foundation
Cel
Dodać do WorldConfig konfigurację punktów krajobrazowych, takich jak wzgórza i stawy.
Struktura danych
landmarks = [
  {
    id,
    type,
    position,
    radius,
    biome_id,
    gameplay_tags
  }
]
Typy
hill
pond
Acceptance Criteria
WorldConfig zawiera definicje landmarków.
World potrafi utworzyć wzgórza i stawy na podstawie konfiguracji.
Landmarki są widoczne w świecie.
Landmarki są gotowe do rozszerzenia o wpływ na ekosystem.
Issue 7: [WORLD] Add hills as terrain landmarks
Labels: type: feature, area: world, area: terrain, priority: medium, stage: polish
Cel
Dodać wzgórza jako punkty krajobrazowe i element nawigacyjny.
Mechanika pierwszej wersji
Wizualny obszar.
Lekka przeszkoda albo obszar z innym ruchem.
Miejsce z ograniczonym spawnem roślin.
Potencjalne miejsce lepszej widoczności w przyszłości.
Acceptance Criteria
Na mapie pojawiają się wzgórza.
Wzgórza są widoczne wizualnie.
Wzgórza nie psują pathingu/ruchu.
Wzgórza mogą być użyte jako punkty orientacyjne.
Issue 8: [WORLD] Add ponds as terrain landmarks and water sources
Labels: type: feature, area: world, area: terrain, area: ecosystem, priority: medium, stage: polish
Cel
Dodać stawy jako punkty krajobrazowe oraz potencjalne źródła wody dla przyszłych systemów ekosystemu.
Mechanika pierwszej wersji
Staw może blokować ruch albo spowalniać wejście.
Staw może zwiększać lokalną ilość roślinności.
Staw może zwiększać spawn traw i krzaków wokół.
W przyszłości staw może przyciągać zwierzęta jako źródło wody.
Acceptance Criteria
Na mapie pojawiają się stawy.
Stawy są widoczne wizualnie.
Gracz i zwierzęta poprawnie reagują na kolizję lub obszar.
Wokół stawów może pojawiać się więcej roślinności.
Stawy są gotowe do późniejszego wykorzystania jako źródło wody.
Issue 9: [WORLD] Increase vegetation density with grasses and bushes
Labels: type: feature, area: world, area: ecosystem, area: vegetation, priority: high, stage: simulation
Cel
Dodać więcej roślinności do świata, w tym trawy i krzaki, które będą pełniły rolę pożywienia dla roślinożerców.
Nowe typy roślinności
grass_patch
small_bush
berry_bush
dense_grass
Wymagania
Roślinność powinna mieć wartość pokarmową dla roślinożerców.
Roślinność powinna być przypisana do biomu.
Nie każda roślina musi być interaktywna dla gracza.
Nowe typy roślinności muszą wspierać growth_stage albo growth_progress.
Trawy i krzaki mogą mieć krótszy cykl odrastania niż drzewa.
Acceptance Criteria
Na mapie pojawia się więcej traw i krzaków.
Roślinożercy mogą traktować roślinność jako pożywienie.
Roślinność jest zagęszczona zależnie od biomu.
Zwiększenie roślinności nie psuje czytelności mapy.
Roślinność może zostać podpięta pod odrastanie i wyjadanie.
Issue 10: [ECOSYSTEM] Add edible vegetation nodes for herbivores
Labels: type: feature, area: ecosystem, area: creatures, area: vegetation, priority: high, stage: simulation
Cel
Dodać roślinność, którą roślinożercy mogą wykrywać, wybierać jako cel i zjadać.
Właściwości roślin
food_value
regrowth_time
is_edible_by_herbivores
biome_id
growth_stage
growth_progress
Mechanika
Zwierzę z głodem wyszukuje najbliższe jadalne rośliny.
Po zjedzeniu roślina może zniknąć, zmniejszyć etap wzrostu albo przejść w stan wyjedzony.
Zjadanie roślin wpływa na biomasę biomu.
Roślinność nie respawnuje natychmiast po śnie.
Acceptance Criteria
Roślinożerca potrafi znaleźć jadalną roślinę.
Roślinożerca może podejść do rośliny i ją zjeść.
Zjedzenie rośliny zmniejsza głód zwierzęcia.
Zjedzenie rośliny wpływa na stan biomu.
Roślina może odrosnąć albo zostać odtworzona przez system regrowth.
Issue 11: [ECOSYSTEM] Make vegetation denser around ponds
Labels: type: feature, area: ecosystem, area: world, area: vegetation, priority: medium, stage: simulation
Cel
Sprawić, żeby stawy wpływały na lokalne zagęszczenie roślinności i tworzyły naturalne punkty koncentracji życia.
Reguły
W pobliżu stawów pojawia się więcej traw i krzewów.
Zwierzęta roślinożerne mogą częściej szukać jedzenia w takich miejscach.
W przyszłości stawy mogą przyciągać zwierzęta również jako źródła wody.
Acceptance Criteria
Wokół stawów pojawia się więcej roślinności.
Roślinność przy stawach jest widocznie gęstsza niż w suchych miejscach.
Zwierzęta mogą wykorzystać tę roślinność jako pożywienie.
System nie tworzy zbyt dużego zagęszczenia nodeów.
Issue 12: [AI] Add free roaming movement for ecosystem animals
Labels: type: feature, area: ai, area: creatures, area: ecosystem, priority: high, stage: simulation
Cel
Zwierzęta powinny poruszać się swobodnie po mapie, a ich ruch powinien wynikać ze stanu: głodu, strachu, poszukiwania pożywienia, ucieczki lub eksploracji.
Zachowania
wander
seek_food
flee_threat
avoid_obstacle
return_to_biome
idle
Wymagania
Zwierzęta swobodnie przemieszczają się po biomie.
Mogą przekraczać granice biomów, ale preferują swój aktualny biom.
Nie uciekają poza mapę.
Unikają prostych przeszkód, np. ścian, stawów lub dużych wzgórz.
Acceptance Criteria
Zwierzęta poruszają się po mapie bez ręcznego sterowania.
Zwierzęta nie opuszczają world bounds.
Zwierzęta potrafią zmienić kierunek ruchu.
Zwierzęta potrafią przejść w tryb szukania pożywienia.
Zwierzęta potrafią uciekać przed zagrożeniem.
Issue 13: [AI] Make hunger drive animal food seeking behavior
Labels: type: feature, area: ai, area: ecosystem, area: creatures, priority: high, stage: simulation
Cel
Sprawić, aby spadający głód realnie wpływał na zachowanie zwierząt. Zwierzęta powinny kierować się w stronę pożywienia, gdy zaczynają być głodne.
Progi głodu
comfortable
hungry
starving
desperate
Zachowanie
comfortable: zwierzę głównie wędruje.
hungry: zwierzę szuka preferowanego jedzenia.
starving: zwierzę podejmuje większe ryzyko.
desperate: zwierzę może zmienić strategię, np. roślinożerca może zjeść padlinę albo zaatakować mniejszą ofiarę.
Acceptance Criteria
Głód wzrasta z czasem.
Zwierzęta zmieniają zachowanie przy wysokim głodzie.
Zwierzęta potrafią znaleźć pożywienie.
Zwierzęta kierują się w stronę pożywienia.
Po jedzeniu głód spada.
Issue 14: [AI] Make Varnaks hunt when hungry or when player is nearby
Labels: type: feature, area: ai, area: creatures, area: ecosystem, area: evolution, priority: high, stage: simulation
Cel
Varnaki powinny polować jako część ekosystemu, a nie tylko jako przeciwnicy gracza.
Warunki ataku
Varnak jest głodny.
W pobliżu jest ofiara.
Gracz wejdzie mu w drogę.
Gracz znajdzie się w zasięgu wykrywania.
Reguły wyboru celu
hunger level
distance to player
distance to prey
aggression
night_activity
current threat
fire/torch avoidance
Acceptance Criteria
Varnak ma głód albo uproszczony poziom potrzeby polowania.
Varnak może polować na zwierzęta ekosystemu.
Varnak nadal potrafi atakować gracza.
Varnak reaguje na gracza, jeśli gracz znajdzie się na jego drodze.
Polowanie Varnaka wpływa na populację ofiar.
Issue 15: [CREATURES] Make killed animals drop meat
Labels: type: feature, area: creatures, area: ecosystem, area: resources, priority: high, stage: simulation
Cel
Sprawić, aby zwierzęta po śmierci zostawiały mięso, które gracz może zebrać.
Zakres
SmallPrey
Grazer
Varnak - opcjonalnie do ujednolicenia z obecnym systemem nagród
Mechanika
Po śmierci zwierzę zostawia meat_drop w miejscu śmierci.
Meat drop można zebrać przez E.
Zebranie dodaje meat do inventory gracza.
Drop znika po zebraniu.
Opcjonalnie drop znika po kilku dniach lub po pewnym czasie.
Ilość mięsa
SmallPrey: 1 meat
Grazer: 2-3 meat
Varnak: 2-4 meat
Eventy
animal_dropped_meat
meat_collected
Acceptance Criteria
Zabity SmallPrey zostawia mięso.
Zabity Grazer zostawia mięso.
Mięso można zebrać przez interakcję.
Zebranie mięsa dodaje meat do inventory.
Ilość mięsa zależy od typu zwierzęcia.
Loot drop nie pojawia się poza world bounds.
Wartości lootu są konfigurowalne w GameBalance.
System nie duplikuje mięsa przy wielokrotnym wywołaniu śmierci tego samego zwierzęcia.
Issue 16: [COMBAT] Add ranged projectile damage handling
Labels: type: feature, area: combat, area: player, area: creatures, priority: high, stage: simulation
Cel
Dodać podstawową obsługę obrażeń od pocisków, potrzebną dla łuku i przyszłych broni dystansowych.
Pliki
scenes/projectiles/arrow_projectile.tscn
scripts/projectiles/arrow_projectile.gd
Mechanika
Pocisk porusza się w linii prostej.
Pocisk ma maksymalny zasięg albo czas życia.
Pocisk znika po trafieniu.
Pocisk zadaje obrażenia obiektom z metodą take_damage.
Pocisk nie rani gracza, jeśli został wystrzelony przez gracza.
Acceptance Criteria
Arrow projectile pojawia się po strzale z łuku.
Arrow projectile porusza się w kierunku kursora.
Arrow projectile znika po trafieniu.
Arrow projectile zadaje obrażenia Varnakowi.
Arrow projectile zadaje obrażenia zwierzętom ekosystemu.
Arrow projectile nie zostaje w świecie bez końca.
Issue 17: [WEAPON] Add craftable bow with infinite ammo
Labels: type: feature, area: player, area: combat, area: crafting, priority: high, stage: simulation
Cel
Dodać nową broń dla gracza: łuk. Na tym etapie łuk powinien mieć nieskończoną amunicję, aby szybciej przetestować walkę dystansową i polowanie.
Zakres
bow crafting recipe
has_bow flag
ranged attack input
arrow projectile
basic damage
cooldown
HUD/skill bar status
Crafting - propozycja
wood: 3
fiber: 4
bone: 1
Mechanika
Gracz może wytworzyć łuk.
Po wytworzeniu łuk zostaje jako wyposażenie.
Strzał leci w kierunku kursora.
Amunicja jest nieskończona w tym etapie.
Łuk zadaje mniejsze obrażenia niż włócznia, ale działa z dystansu.
Strzał ma cooldown.
Acceptance Criteria
Gracz może stworzyć łuk.
HUD pokazuje posiadanie łuku.
Gracz może strzelać z łuku.
Pocisk trafia Varnaki lub zwierzęta.
Trafienie zadaje obrażenia.
Amunicja nie jest zużywana.
Wartości łuku są w GameBalance.
Issue 18: [WORLD] Smooth biome transitions with gradient or mesh blending
Labels: type: feature, area: world, area: biome, area: visuals, priority: medium, stage: polish
Cel
Poprawić sposób przechodzenia między biomami. Dla większej mapy i bardziej naturalnego świata przejścia powinny być łagodniejsze.
Techniki do rozważenia
gradient blending
mesh-based biome overlay
noise-based transition zone
soft polygon edges
Acceptance Criteria
Przejścia między biomami wyglądają łagodniej.
Nadal można ustalić, w którym biomie znajduje się gracz.
Spawn zasobów i zwierząt nadal zależy od biomu.
Full map pokazuje biomy w czytelny sposób.
Issue 19: [MAP] Update minimap and full map for larger world and landmarks
Labels: type: feature, area: ui, area: map, area: world, priority: medium, stage: polish
Cel
Zaktualizować minimapę i pełną mapę, aby poprawnie obsługiwały większy świat, łagodniejsze biomy oraz nowe punkty krajobrazowe.
Nowe elementy mapy
hills
ponds
dense vegetation zones
possibly animal hotspots
Acceptance Criteria
Minimap działa z większym światem.
Full map działa z większym światem.
Wzgórza są widoczne na mapie.
Stawy są widoczne na mapie.
Łagodne biomy nadal są czytelne.
Mapa nie jest przeładowana markerami.
Sugerowana kolejność realizacji
[WORLD] Expand world size for ecosystem gameplay
[BALANCE] Add living world constants to GameBalance
[DEBUG] Organize debug panel with tabs and action buttons
[BUG] Prevent animals from leaving world bounds
[WORLD] Replace sleep resource respawn with gradual multi-day regrowth
[WORLD] Add landmark generation to WorldConfig
[WORLD] Add hills as terrain landmarks
[WORLD] Add ponds as terrain landmarks and water sources
[WORLD] Increase vegetation density with grasses and bushes
[ECOSYSTEM] Add edible vegetation nodes for herbivores
[ECOSYSTEM] Make vegetation denser around ponds
[AI] Add free roaming movement for ecosystem animals
[AI] Make hunger drive animal food seeking behavior
[AI] Make Varnaks hunt when hungry or when player is nearby
[CREATURES] Make killed animals drop meat
[COMBAT] Add ranged projectile damage handling
[WEAPON] Add craftable bow with infinite ammo
[WORLD] Smooth biome transitions with gradient or mesh blending
[MAP] Update minimap and full map for larger world and landmark
