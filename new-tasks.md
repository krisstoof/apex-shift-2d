Issue 1: Add craftable torch item
Title

Add craftable torch item

Description

Dodać brakującą pochodnię jako craftowalny item w istniejącym systemie craftingu.

Projekt ma już zaimplementowany crafting oraz integrację itemów takich jak campfire, spear, cooked_meat i basic_trap. Nie należy przebudowywać istniejącego systemu craftingu, tylko dodać nowy item.

Scope
Dodać item torch.
Dodać recepturę craftingu.
Zintegrować pochodnię z istniejącym inventory.
Upewnić się, że HUD/inventory pokazuje pochodnię po stworzeniu.
Recipe
torch = wood + plant_fiber
Acceptance Criteria
Gracz może stworzyć torch.
Crafting sprawdza, czy gracz ma wood i plant_fiber.
Po stworzeniu pochodni zasoby są odejmowane.
torch trafia do inventory albo listy crafted items.
HUD albo inventory UI aktualizuje się po stworzeniu pochodni.
Nie powstaje drugi, równoległy system craftingu.
Notes

Nie implementować jeszcze rozbudowanego systemu światła ani slotów ekwipunku.

Issue 2: Add torch activation
Title

Add torch activation

Description

Dodać możliwość aktywowania pochodni przez gracza.

Pochodnia powinna być aktywowalnym itemem. Po aktywacji zaczyna działać jej efekt, a liczba pochodni w inventory powinna się zmniejszyć albo pochodnia powinna przejść w stan aktywny, zależnie od istniejącego modelu inventory.

Scope
Dodać akcję aktywacji pochodni.
Podłączyć aktywację do inputu albo prostego UI.
Dodać stan torch_active.
Zapewnić, że tylko jedna pochodnia może być aktywna naraz.
Acceptance Criteria
Gracz może aktywować torch, jeśli ma ją w inventory.
Nie można aktywować pochodni, jeśli gracz jej nie posiada.
Po aktywacji gra przechowuje informację, że pochodnia jest aktywna.
HUD albo debug panel może odczytać stan aktywnej pochodni.
Aktywacja nie psuje istniejących itemów, takich jak spear, campfire i cooked_meat.
Notes

Nie dodawać rozbudowanego menu ekwipunku, jeśli nie jest potrzebne.

Issue 3: Add torch duration
Title

Add torch duration

Description

Dodać ograniczony czas działania aktywnej pochodni.

Pochodnia po aktywacji powinna działać przez określony czas, po czym efekt wygasa. Czas działania powinien być łatwy do zmiany w konfiguracji balansu.

Scope
Dodać timer aktywnej pochodni.
Po zakończeniu timera dezaktywować efekt pochodni.
Udostępnić aktualny czas pozostały dla HUD/debug panelu.
Dodać wartość balansu dla czasu działania pochodni.
Acceptance Criteria
Aktywna pochodnia ma ograniczony czas działania.
Po upływie czasu pochodnia gaśnie.
Po wygaśnięciu znika jej efekt gameplayowy.
Gracz może aktywować kolejną pochodnię, jeśli posiada ją w inventory.
Czas działania pochodni jest możliwy do zmiany z jednego miejsca, np. GameBalance.gd.
Suggested Balance Value
const TORCH_DURATION_SECONDS = 45.0
Issue 4: Add torch night protection effect
Title

Add torch night protection effect

Description

Dodać prosty efekt gameplayowy aktywnej pochodni podczas nocy lub zmierzchu.

Pochodnia ma działać jako słabsza, mobilna wersja safe zone. Nie musi mieć zaawansowanego systemu światła. Najważniejsze jest to, żeby wpływała na zachowanie agresywnych zwierząt.

Scope
Wykrywać, czy pochodnia jest aktywna.
Wykrywać, czy aktualna faza dnia to night albo dusk.
Zmniejszać zagrożenie wokół gracza.
Wpływać na agresywne zwierzęta w pobliżu gracza.
Possible Effects

Wystarczy zaimplementować jeden lub dwa z poniższych efektów:

zmniejszenie detection range agresywnych zwierząt,
zmniejszenie szansy przejścia w chase,
wymuszenie flee u słabszych zwierząt,
opóźnienie ataku,
zmniejszenie night aggression multiplier w pobliżu gracza.
Acceptance Criteria
Aktywna pochodnia wpływa na zachowanie agresywnych zwierząt podczas night albo dusk.
Efekt pochodni jest słabszy niż efekt campfire safe zone.
Efekt przestaje działać po wygaśnięciu pochodni.
Efekt nie działa w nieskończoność.
Parametry efektu są możliwe do zmiany z jednego miejsca.
Suggested Balance Values
const TORCH_SAFE_RADIUS = 96.0
const TORCH_DETECTION_RANGE_MULTIPLIER = 0.65
const TORCH_AGGRESSION_MULTIPLIER = 0.7
Issue 5: Add optional torch light visual
Title

Add optional torch light visual

Description

Dodać prosty wizualny efekt aktywnej pochodni, jeśli projekt ma już system światła 2D albo można go dodać bez dużej przebudowy.

To zadanie jest opcjonalne względem gameplayu. Najważniejszy jest efekt mechaniczny pochodni, a nie zaawansowane oświetlenie.

Scope
Dodać prosty PointLight2D albo odpowiednik Godot 2D do gracza.
Pokazywać światło tylko wtedy, gdy pochodnia jest aktywna.
Ukrywać światło po wygaśnięciu pochodni.
Nie przebudowywać całego systemu renderowania ani mapy.
Acceptance Criteria
Aktywna pochodnia pokazuje prosty efekt światła.
Światło znika po wygaśnięciu pochodni.
Efekt działa szczególnie w nocy lub przy zmierzchu.
Brak światła nie blokuje działania gameplayowego efektu pochodni.
Implementacja jest prosta i łatwa do usunięcia lub rozbudowy.
Notes

Jeżeli projekt nie ma jeszcze żadnego systemu światła, można ograniczyć się do prostego sprite’a/ikony/statusu w HUD.

Issue 6: Add debug panel toggle
Title

Add debug panel toggle

Description

Dodać panel developerski do szybkiego testowania prototypu. Panel powinien być włączany i wyłączany klawiszem F3.

Scope
Dodać scenę albo UI panel debugowy.
Podłączyć toggle pod F3.
Panel domyślnie powinien być ukryty.
Panel nie powinien wpływać na rozgrywkę, dopóki gracz nie użyje przycisków debugowych.
Acceptance Criteria
F3 pokazuje debug panel.
Ponowne naciśnięcie F3 ukrywa debug panel.
Panel nie jest widoczny przy starcie gry.
Panel działa niezależnie od normalnego HUD.
Kod panelu jest oddzielony od zwykłej logiki rozgrywki tam, gdzie ma to sens.
Issue 7: Display core game state in debug panel
Title

Display core game state in debug panel

Description

Uzupełnić debug panel o podstawowe informacje o stanie gry.

Scope

Debug panel powinien pokazywać:

aktualny dzień,
aktualną fazę dnia,
poziom adaptacji świata,
health gracza,
hunger/energy gracza,
ilość podstawowych zasobów,
crafted items,
stan campfire,
stan torch,
liczbę zwierząt na mapie.
Acceptance Criteria
Debug panel pokazuje aktualny dzień.
Debug panel pokazuje fazę dnia.
Debug panel pokazuje poziom adaptacji.
Debug panel pokazuje health i hunger/energy.
Debug panel pokazuje ilości zasobów.
Debug panel pokazuje crafted items, w tym torch.
Debug panel pokazuje, czy campfire jest aktywny.
Debug panel pokazuje, czy torch jest aktywna i ile czasu jej zostało.
Debug panel pokazuje liczbę zwierząt na mapie.
Dane aktualizują się podczas gry.
Issue 8: Add resource debug buttons
Title

Add resource debug buttons

Description

Dodać przyciski debugowe do szybkiego dodawania zasobów i itemów.

Scope

Dodać przyciski:

Add wood
Add stone
Add plant_fiber
Add meat
Add torch
Add spear
Acceptance Criteria
Kliknięcie Add wood dodaje drewno do inventory.
Kliknięcie Add stone dodaje kamień do inventory.
Kliknięcie Add plant_fiber dodaje włókno roślinne do inventory.
Kliknięcie Add meat dodaje mięso do inventory.
Kliknięcie Add torch dodaje pochodnię do inventory.
Kliknięcie Add spear dodaje włócznię do inventory.
HUD i debug panel aktualizują wartości po kliknięciu.
Przyciski używają istniejącego inventory managera, zamiast modyfikować stan gry na skróty w kilku miejscach.
Issue 9: Add world state debug buttons
Title

Add world state debug buttons

Description

Dodać przyciski debugowe do testowania cyklu dnia, adaptacji świata i spawnów zwierząt.

Scope

Dodać przyciski:

Next phase
Next day
Increase adaptation
Spawn aggressive animal
Spawn neutral animal
Acceptance Criteria
Next phase przełącza grę do kolejnej fazy dnia.
Next day przechodzi do kolejnego dnia albo wymusza pełny cykl zgodnie z istniejącą logiką.
Increase adaptation zwiększa poziom adaptacji świata.
Spawn aggressive animal tworzy agresywne zwierzę w świecie.
Spawn neutral animal tworzy neutralne zwierzę w świecie.
Przyciski korzystają z istniejących managerów, jeśli już istnieją.
HUD/debug panel aktualizują się po zmianach.
Issue 10: Add player state debug buttons
Title

Add player state debug buttons

Description

Dodać przyciski debugowe do testowania zdrowia, głodu i porażki gracza.

Scope

Dodać przyciski:

Damage player
Heal player
Reduce hunger/energy
Restore hunger/energy
Acceptance Criteria
Damage player zmniejsza health gracza.
Heal player przywraca część health gracza.
Reduce hunger/energy zmniejsza hunger/energy.
Restore hunger/energy zwiększa hunger/energy.
Przyciski pozwalają szybko przetestować warunek przegranej.
UI aktualizuje się po użyciu przycisków.
Przyciski nie omijają istniejących metod gracza, jeśli takie istnieją.
Issue 11: Create GameBalance configuration
Title

Create GameBalance configuration

Description

Dodać centralny plik/skrypt z wartościami balansującymi grę, np. GameBalance.gd.

Celem jest ograniczenie magic numbers i ułatwienie strojenia prototypu.

Scope

Dodać centralne miejsce na wartości takie jak:

koszty craftingu,
czas działania pochodni,
zasięg efektu pochodni,
siła efektu pochodni,
zasięg campfire safe zone,
tempo spalania paliwa campfire,
hunger/energy decay rate,
obrażenia przy głodzie,
night danger multiplier,
adaptation growth per day,
spear attack cooldown,
trap effect duration.
Acceptance Criteria
Istnieje centralny plik/skrypt z wartościami balansu.
Nowe wartości dla pochodni są pobierane z tego pliku.
Nowe wartości dla debug/testowanych mechanik nie są wpisane jako magic numbers.
Plik jest łatwy do znalezienia i edycji.
Nie przebudowuje się działających systemów na siłę.
Issue 12: Move crafting costs to GameBalance
Title

Move crafting costs to GameBalance

Description

Przenieść koszty craftingu do centralnego miejsca konfiguracji balansu.

Nie chodzi o pełną przebudowę craftingu, tylko o to, żeby receptury były łatwe do zmiany.

Scope

Przenieść lub ujednolicić koszty:

campfire
spear
torch
cooked_meat
basic_trap
Acceptance Criteria
Koszt campfire jest definiowany w jednym miejscu.
Koszt spear jest definiowany w jednym miejscu.
Koszt torch jest definiowany w jednym miejscu.
Koszt cooked_meat jest definiowany w jednym miejscu.
Koszt basic_trap jest definiowany w jednym miejscu.
Crafting korzysta z tych wartości.
Zmiana kosztu w konfiguracji wpływa na crafting.
Issue 13: Move torch balance values to GameBalance
Title

Move torch balance values to GameBalance

Description

Przenieść wszystkie wartości związane z pochodnią do centralnej konfiguracji balansu.

Scope

Wartości do wydzielenia:

czas działania pochodni,
zasięg efektu pochodni,
redukcja detection range,
redukcja agresji,
ewentualny zasięg światła,
ewentualna intensywność światła.
Acceptance Criteria
Czas działania pochodni jest definiowany w GameBalance.
Zasięg efektu pochodni jest definiowany w GameBalance.
Siła redukcji zagrożenia jest definiowana w GameBalance.
Kod pochodni nie zawiera nowych magic numbers.
Zmiana wartości w GameBalance wpływa na działanie pochodni.
Issue 14: Add torch status to HUD
Title

Add torch status to HUD

Description

Dodać informację o stanie pochodni do istniejącego HUD.

HUD powinien pokazywać przynajmniej, czy pochodnia jest aktywna. Dobrze, jeśli pokazuje też pozostały czas działania.

Scope
Pokazać stan aktywnej pochodni.
Pokazać pozostały czas działania pochodni.
Aktualizować HUD po aktywacji i wygaśnięciu pochodni.
Acceptance Criteria
HUD pokazuje, czy torch jest aktywna.
HUD pokazuje pozostały czas działania torch albo prosty wskaźnik aktywności.
HUD aktualizuje się po aktywacji pochodni.
HUD aktualizuje się po wygaśnięciu pochodni.
HUD nie zasłania ważnych elementów gry.
Issue 15: Add torch tests / manual test checklist
Title

Add torch manual test checklist

Description

Dodać krótką checklistę manualnego testowania pochodni do dokumentacji projektu albo pliku testowego.

Scope

Checklist powinna opisywać:

jak zebrać zasoby,
jak stworzyć pochodnię,
jak aktywować pochodnię,
jak sprawdzić czas działania,
jak sprawdzić wpływ na zwierzęta nocą,
jak sprawdzić wygaśnięcie efektu,
jak sprawdzić aktywację kolejnej pochodni.
Acceptance Criteria
W repozytorium istnieje krótka instrukcja testowania pochodni.
Instrukcja zawiera kroki manualnego testu.
Instrukcja opisuje oczekiwany rezultat każdego kroku.
Instrukcja jest zrozumiała bez znajomości całego kodu.
Issue 16: Add debug panel manual test checklist
Title

Add debug panel manual test checklist

Description

Dodać checklistę testowania debug panelu.

Scope

Checklist powinna obejmować:

otwieranie i zamykanie panelu,
dodawanie zasobów,
dodawanie itemów,
zmianę fazy dnia,
zmianę dnia,
zwiększanie adaptacji,
spawnowanie zwierząt,
zadawanie obrażeń graczowi,
leczenie gracza,
sprawdzenie aktualizacji HUD.
Acceptance Criteria
Istnieje instrukcja testowania debug panelu.
Każdy przycisk debugowy ma opisany oczekiwany efekt.
Instrukcja pozwala szybko sprawdzić, czy panel działa po zmianach w kodzie.