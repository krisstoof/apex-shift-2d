# Regression Tests Strategy

Ten dokument opisuje strategię testów regresyjnych dla projektu oraz checklistę wymaganą przed wydaniem wersji `0.x`.

Plik dotyczy przede wszystkim testów uruchamianych przez:

```bash
godot --headless --path . -s res://tests/regression/regression_test_runner.gd
```

albo:

```bash
godot4 --headless --path . -s res://tests/regression/regression_test_runner.gd
```

---

## Cel testów regresyjnych

Testy regresyjne mają chronić projekt przed powrotem błędów, które zostały już znalezione, naprawione albo uznane za krytyczne dla stabilności gry.

W tym projekcie test regresyjny powinien sprawdzać pełny przepływ gry z perspektywy gracza albo systemu, na przykład:

* start gry z menu,
* tworzenie nowej gry,
* continue / load save,
* save/load świata,
* inventory,
* crafting,
* storage box,
* HUD,
* game over flow,
* kilka dni symulacji świata,
* visibility culling,
* stan gracza po save/load,
* stan świata po save/load.

Test regresyjny nie musi sprawdzać jednej małej funkcji. Jego zadaniem jest złapanie sytuacji, w której kilka systemów działa osobno poprawnie, ale razem psują grę.

---

## Testy jednostkowe, integracyjne i regresyjne

### Testy jednostkowe

Test jednostkowy sprawdza mały, izolowany fragment logiki.

Przykłady:

* `Inventory.add_item()` dodaje item do slotu.
* `Inventory.remove_item()` poprawnie zmniejsza stack.
* `PlayerStats.restore_from_data()` odtwarza health, hunger, stamina i rest.
* Funkcja licząca target populacji Varnaków zwraca poprawną wartość dla danego dnia.
* Resource regrowth zwiększa `growth_stage` po zadanej liczbie dni.

Cechy testu jednostkowego:

* szybki,
* mało zależności,
* bez pełnego bootu gry,
* bez prawdziwego UI,
* bez prawdziwego save/load sceny, jeżeli nie jest to konieczne,
* dobry do testowania czystej logiki.

Test jednostkowy odpowiada na pytanie:

> Czy ta jedna część kodu działa poprawnie?

---

### Testy integracyjne

Test integracyjny sprawdza współpracę kilku systemów.

Przykłady:

* `SaveSystem` zapisuje i odtwarza `Player`, `World`, `DayNightSystem`.
* `HUD` poprawnie czyta dane z `Player` i inventory.
* `World` poprawnie rejestruje zasoby i stworzenia.
* `DayNightSystem.day_changed` powoduje regrowth zasobów.
* `StorageBox` otwiera UI i pozwala przenosić itemy między inventory gracza i skrzynią.

Cechy testu integracyjnego:

* sprawdza kilka systemów naraz,
* może ładować scenę,
* może używać prawdziwych node’ów Godota,
* zwykle nie musi przechodzić całego flow gracza od menu,
* jest szerszy niż unit test, ale węższy niż regresja.

Test integracyjny odpowiada na pytanie:

> Czy te systemy poprawnie współpracują?

---

### Testy regresyjne

Test regresyjny sprawdza pełny scenariusz, który może się zepsuć po refaktorze, optymalizacji albo dodaniu nowej funkcji.

Przykłady:

* Start z menu tworzy grywalną sesję.
* Continue odtwarza ten sam świat, seed, landmarki i stan gracza.
* Save/load zachowuje pełny stan świata.
* Storage box zachowuje zawartość po load.
* Game over poprawnie pauzuje grę, restartuje sesję, ładuje save i wraca do menu.
* Kilka dni symulacji nie psuje świata.
* Visibility culling nie usuwa obiektów z gry ani z save.
* HUD po load pokazuje aktualne dane.

Cechy testu regresyjnego:

* sprawdza realny flow gry,
* często startuje od `StartMenu -> New Game`,
* używa prawdziwych scen,
* używa prawdziwego `SaveSystem`,
* używa prawdziwego `HUD`,
* używa prawdziwego `World`,
* może trwać dłużej niż unit/integration test,
* powinien failować, jeżeli wróci znany problem.

Test regresyjny odpowiada na pytanie:

> Czy gra nadal działa w krytycznym scenariuszu, który wcześniej był ryzykowny?

---

## Kiedy dodać test regresyjny

Nowy test regresyjny należy dodać, gdy błąd:

* psuje zapis albo odczyt gry,
* psuje start gry,
* psuje Continue,
* psuje UI flow,
* powoduje konflikt ekranów UI,
* powoduje utratę itemów,
* powoduje utratę budynków,
* powoduje utratę storage boxa,
* powoduje utratę stanu gracza,
* powoduje utratę stanu świata,
* powoduje crash po kilku dniach gry,
* powoduje znikanie obiektów po visibility cullingu,
* powoduje wyjście stworzeń poza mapę,
* powoduje niepoprawny stan `GameSession`,
* powoduje błąd, który może wrócić po refaktorze,
* został znaleziony manualnie i jest ważny dla release.

Nie każdy bug musi mieć test regresyjny. Do regresji powinny trafiać przede wszystkim błędy, które:

* są krytyczne dla grywalności,
* trudno wykryć krótkim smoke testem,
* dotyczą kilku systemów naraz,
* są podatne na powrót,
* mogłyby zablokować release.

---

## Jak uruchomić regression runner

Z katalogu głównego projektu:

```bash
godot --headless --path . -s res://tests/regression/regression_test_runner.gd
```

albo, jeżeli lokalna komenda Godota nazywa się `godot4`:

```bash
godot4 --headless --path . -s res://tests/regression/regression_test_runner.gd
```

Oczekiwane wyniki:

```text
0 - wszystkie scenariusze przeszły
1 - co najmniej jeden scenariusz zakończył się błędem
```

Przykład poprawnego wyniku:

```text
[RegressionTests] Running StartMenu_NewGame_BootsPlayableSession...
[RegressionTests] StartMenu_NewGame_BootsPlayableSession: OK
[RegressionTests] All regression tests passed.
```

Przykład błędu:

```text
[RegressionTests] StorageBox_Transfer_SaveLoad: FAILED - Storage box inventory mismatch after load
```

---

## Aktualna struktura testów regresyjnych

Testy regresyjne znajdują się w katalogu:

```text
tests/regression/
```

Główny runner:

```text
tests/regression/regression_test_runner.gd
```

Wspólne helpery:

```text
tests/regression/regression_test_utils.gd
```

Scenariusze regresyjne powinny być osobnymi plikami:

```text
tests/regression/test_<scenario_name>.gd
```

Przykłady:

```text
test_start_menu_new_game_boots_playable_session.gd
test_continue_restores_saved_world_bootstrap.gd
test_basic_survival_loop_from_empty_inventory.gd
test_storage_box_transfer_save_load.gd
test_ui_modal_stack_inventory_map_pause_storage.gd
test_full_player_state_save_load.gd
test_torch_lifecycle_save_load_ui.gd
test_game_over_restart_load_main_menu.gd
test_multi_day_world_persistence.gd
test_visibility_culling_does_not_break_interaction_or_save.gd
```

---

## Jak dodawać nowy scenariusz regresyjny

### 1. Dodaj nowy plik testu

Utwórz plik:

```text
tests/regression/test_<nazwa_scenariusza>.gd
```

Plik powinien mieć strukturę:

```gdscript
extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []

	# test steps

	return failures
```

Zasada:

* pusta tablica `failures` oznacza sukces,
* każdy string w `failures` oznacza konkretny błąd,
* pierwszy błąd jest pokazywany przez runner jako powód failure.

---

### 2. Dodaj preload w runnerze

W `tests/regression/regression_test_runner.gd` dodaj:

```gdscript
const NEW_SCENARIO_TEST := preload("res://tests/regression/test_<nazwa_scenariusza>.gd")
```

---

### 3. Dodaj scenariusz do listy

W tablicy `scenarios` dodaj:

```gdscript
{
	"name": "Readable_Scenario_Name",
	"method": "_scenario_readable_scenario_name"
}
```

---

### 4. Dodaj metodę runnera

```gdscript
func _scenario_readable_scenario_name() -> Dictionary:
	var suite := NEW_SCENARIO_TEST.new()
	var failures: Array[String] = await suite.run(self)
	if failures.is_empty():
		return {"ok": true}
	return {"ok": false, "reason": failures[0]}
```

---

### 5. Upewnij się, że test sprząta po sobie

Każdy test regresyjny powinien:

* usuwać save file przed startem,
* nie zostawiać aktywnej sceny,
* nie zostawiać gry w stanie pause,
* nie zostawiać zmienionego `GameSession.load_save_requested`,
* nie zależeć od kolejności innych testów,
* dawać czytelny powód failure.

Runner również czyści save między scenariuszami, ale test powinien być samodzielny.

---

## Standard pisania testu regresyjnego

Dobry test regresyjny powinien:

* mieć jasną nazwę,
* startować przez realny flow, jeżeli test dotyczy flow gracza,
* używać prawdziwego `StartMenu`, jeżeli test dotyczy startu gry,
* używać prawdziwego `SaveSystem`, jeżeli test dotyczy save/load,
* używać prawdziwego `HUD`, jeżeli test dotyczy UI,
* nie omijać problemu przez ręczne ustawianie końcowego stanu,
* failować z czytelnym komunikatem,
* testować stan przed i po akcji,
* mutować stan po zapisie, żeby mieć pewność, że load faktycznie coś przywraca,
* sprawdzać brak skutków ubocznych, na przykład `get_tree().paused == false` po wyjściu z modala.

---

## Czego unikać w regresjach

Unikaj testów, które:

* tylko sprawdzają, czy scena się ładuje, jeżeli problem dotyczy głębszego flow,
* ustawiają wynik ręcznie zamiast przejść przez mechanikę,
* polegają wyłącznie na losowym spawnie,
* zależą od kolejności innych testów,
* nie czyszczą save,
* sprawdzają wyłącznie brak crasha, ale nie sprawdzają stanu,
* są zbyt ogólne i nie mówią, co dokładnie się zepsuło,
* ukrywają błąd przez `force_*` helper zamiast sprawdzić produkcyjny flow.

---

## Typy błędów, które powinny trafiać do regresji

Do testów regresyjnych powinny trafiać szczególnie:

### Save/load

* gracz wraca w złej pozycji,
* inventory nie wraca po load,
* `has_spear`, `has_bow`, torch albo stats nie wracają,
* world seed albo landmarki zmieniają się po Continue,
* budynki znikają po load,
* storage box wraca pusty,
* dzień / czas gry nie wraca,
* stworzenia albo zasoby znikają po load.

### UI i flow

* menu nie uruchamia nowej gry,
* Continue ładuje zły świat,
* pause zostaje aktywny po zamknięciu ekranu,
* inventory / map / pause / storage nachodzą na siebie,
* Game Over nie pauzuje gry,
* Restart zostawia grę w złym stanie,
* Main Menu zostawia zły `GameSession`.

### Gameplay

* gracz nie może zebrać zasobu,
* crafting nie tworzy obiektu,
* torch aktywuje się bez itemu,
* storage box gubi itemy,
* meat drop nie powstaje albo znika,
* resource regrowth nie działa po dniach.

### World simulation

* stworzenia wychodzą poza mapę,
* Varnaki przekraczają limit populacji,
* kilka dni symulacji psuje świat,
* visibility culling trwale ukrywa albo usuwa obiekty,
* AI przestaje działać po ukryciu / pokazaniu obiektu.

---

## Testy wymagane przed release 0.x

Przed każdym release `0.x` należy uruchomić pełny regression runner.

Release nie powinien być zaakceptowany, jeżeli którykolwiek z wymaganych scenariuszy regresyjnych failuje.

Minimalny zestaw wymagany przed release:

```text
[ ] Start z menu działa.
[ ] New Game działa.
[ ] Continue działa.
[ ] Save/load zachowuje świat.
[ ] Save/load zachowuje pełny stan gracza.
[ ] Gracz może zebrać zasoby.
[ ] Gracz może craftować podstawowe obiekty.
[ ] Torch lifecycle działa.
[ ] Storage box działa.
[ ] Storage box zachowuje zawartość po load.
[ ] Inventory, mapa, pause i storage nie konfliktują.
[ ] Game over flow działa.
[ ] Restart po Game Over działa.
[ ] Load Save po Game Over działa.
[ ] Powrót do Main Menu po Game Over działa.
[ ] Kilka dni symulacji nie psuje świata.
[ ] Regrowth zasobów działa po progresji dni.
[ ] Populacja zwierząt pozostaje poprawna.
[ ] Varnaki nie przekraczają limitu populacji.
[ ] Zwierzęta nie wychodzą poza mapę.
[ ] Visibility culling nie usuwa obiektów.
[ ] Visibility culling nie psuje interakcji.
[ ] Visibility culling nie psuje save/load.
[ ] HUD pokazuje aktualne dane.
[ ] Po zakończeniu testów gra nie zostaje zapauzowana.
```

---

## Minimalna checklist release 0.x

Przed oznaczeniem release:

### Boot i menu

```text
[ ] Gra uruchamia się bez crasha.
[ ] StartMenu ładuje się poprawnie.
[ ] New Game przechodzi do main.tscn.
[ ] Continue jest aktywne tylko wtedy, gdy istnieje save.
[ ] Continue ładuje zapisany świat.
[ ] Powrót do menu nie zostawia gry w stanie pause.
```

### Save/load

```text
[ ] Save tworzy plik save.
[ ] Load odtwarza pozycję gracza.
[ ] Load odtwarza stats gracza.
[ ] Load odtwarza inventory.
[ ] Load odtwarza broń.
[ ] Load odtwarza torch.
[ ] Load odtwarza dzień i czas.
[ ] Load odtwarza seed świata i landmarki.
[ ] Load odtwarza zasoby.
[ ] Load odtwarza stworzenia.
[ ] Load odtwarza budynki.
[ ] Load odtwarza storage boxy.
```

### Gameplay

```text
[ ] Gracz może zebrać wood.
[ ] Gracz może zebrać stone.
[ ] Gracz może zebrać fiber.
[ ] Gracz może craftować campfire.
[ ] Gracz może craftować spear.
[ ] Gracz może craftować torch.
[ ] Gracz może craftować bow.
[ ] Gracz może craftować trap.
[ ] Gracz może craftować wall.
[ ] Gracz może craftować tent.
[ ] Gracz może craftować storage box.
```

### UI

```text
[ ] HUD pokazuje aktualne HP.
[ ] HUD pokazuje hunger.
[ ] HUD pokazuje stamina.
[ ] HUD pokazuje rest.
[ ] HUD pokazuje dzień.
[ ] HUD pokazuje inventory/resources.
[ ] HUD pokazuje torch state.
[ ] Inventory otwiera się i zamyka.
[ ] Map otwiera się i zamyka.
[ ] Pause menu otwiera się i zamyka.
[ ] Storage screen otwiera się i zamyka.
[ ] Inventory, map, pause i storage nie zostają otwarte równocześnie w konflikcie.
```

### World simulation

```text
[ ] Dzień przechodzi poprawnie.
[ ] Regrowth zasobów działa.
[ ] Po kilku dniach świat nie crashuje.
[ ] Zwierzęta pozostają w granicach mapy.
[ ] Varnaki nie przekraczają limitu populacji.
[ ] Meat drop zostaje zachowany, jeżeli nie został zebrany.
```

### Game over

```text
[ ] Śmierć gracza pokazuje GameOverScreen.
[ ] Po śmierci gra jest zapauzowana.
[ ] Martwy gracz nie porusza się.
[ ] Restart z GameOverScreen tworzy świeżą sesję.
[ ] Restart odpauzowuje grę.
[ ] Load Save z GameOverScreen ładuje save.
[ ] Load Save odpauzowuje grę.
[ ] Main Menu z GameOverScreen wraca do start_menu.tscn.
[ ] Powrót do menu nie zostawia złego stanu GameSession.
```

### Visibility culling

```text
[ ] Obiekty poza widocznością mogą zostać ukryte.
[ ] Ukryte zasoby nie znikają ze świata.
[ ] Ukryte stworzenia nie znikają z rejestru.
[ ] Ukryte stworzenia nie dostają pozycji NaN/INF.
[ ] Po powrocie kamera/gracz przywraca widoczność obiektów.
[ ] Po powrocie można zebrać zasób.
[ ] Save/load zachowuje obiekty ukryte przez culling.
```

---

## Kolejność wykonywania przed release

Zalecana kolejność:

```text
1. Uruchom unit testy, jeżeli istnieją.
2. Uruchom testy integracyjne, jeżeli istnieją.
3. Uruchom pełny regression runner.
4. Wykonaj krótki manual smoke test w edytorze.
5. Przygotuj build testowy.
6. Uruchom build lokalnie.
7. Udostępnij build testerowi.
8. Zbierz feedback.
9. Dodaj nowe regresje dla krytycznych błędów znalezionych w testach.
```

---

## Zasada blokowania release

Release `0.x` powinien być zablokowany, jeżeli:

```text
[ ] regression runner kończy się exit code 1,
[ ] New Game nie działa,
[ ] Continue nie działa,
[ ] Save/load gubi świat,
[ ] Save/load gubi gracza,
[ ] storage box gubi itemy,
[ ] game over zostawia grę zapauzowaną,
[ ] kilka dni symulacji crashuje grę,
[ ] visibility culling trwale usuwa obiekty,
[ ] HUD pokazuje nieaktualne dane po load.
```

Błędy kosmetyczne mogą trafić do patcha, ale błędy powodujące utratę progresu, utratę świata, softlock albo crash powinny blokować release.

---

## Zasada dodawania regresji po bugfixie

Jeżeli bug był istotny i został naprawiony, dodaj test regresyjny przed uznaniem go za zamknięty.

Format:

```text
Bug:
- Krótki opis błędu.

Ryzyko:
- Co mogło się zepsuć dla gracza.

Regresja:
- Jaki scenariusz testowy ma wykrywać powrót błędu.

Acceptance:
- Test failuje przed fixem.
- Test przechodzi po fixie.
```

Przykład:

```text
Bug:
Storage box po load wracał pusty.

Ryzyko:
Gracz tracił zasoby po wczytaniu gry.

Regresja:
test_storage_box_transfer_save_load.gd

Acceptance:
Test zapisuje storage box z zawartością, mutuje zawartość, wykonuje load i sprawdza, że inventory storage boxa wraca.
```

---

## Podsumowanie

Testy jednostkowe chronią małe fragmenty logiki.

Testy integracyjne chronią współpracę systemów.

Testy regresyjne chronią konkretne scenariusze gry, które są ważne dla stabilności release.

Przed release `0.x` pełny regression runner musi przejść bez błędów.
