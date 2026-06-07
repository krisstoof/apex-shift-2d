# Apex Shift 2D - GitHub issues v0.1.1-v0.1.4

Performance patch jest już częścią v0.1, dlatego poniższe issues koncentrują się na stabilizacji, balansie, UX i buildzie testowym.

## [BUG] Stabilize small prey and grazer population decay

**Version scope:** `v0.1.1`

### Cel
Naprawić problem ciągle zmniejszającej się populacji small prey i grazerów.

### Zakres
- Sprawdzić głód, dostęp do jedzenia, presję Varnaków, respawn i despawn.
- Dodać minimalne progi populacji bezpieczeństwa.
- Dodać łagodny mechanizm odbudowy populacji bez nagłego overspawnu.
- Upewnić się, że debug pokazuje aktualne populacje.

### Acceptance Criteria
- Po kilku dniach small prey nadal istnieją.
- Po kilku dniach grazery nadal istnieją.
- Populacje mogą naturalnie spadać, ale nie znikają losowo.
- Odbudowa populacji nie powoduje nagłego zalewu mapy.

### Codex notes
```text
First inspect existing ecosystem, hunger, death, respawn and population systems. Do not rewrite the living world architecture. Prefer safeguards and tuning existing values. Keep thresholds configurable. Do not undo v0.1 performance optimizations.
```

## [BUG] Verify all creature and resource spawns avoid water

**Version scope:** `v0.1.1`

### Cel
Upewnić się, że żadne zasoby ani stworzenia nie spawnują się w wodzie.

### Zakres
- Sprawdzić spawn resources, small prey, grazerów, Varnaków i meat drops.
- Użyć wspólnej walidacji pozycji, jeśli już istnieje.
- Ograniczyć liczbę prób szukania poprawnej pozycji.
- Dodać bezpieczny fallback i debug ostrzeżenie przy nieudanym spawnie.

### Acceptance Criteria
- Zasoby nie spawnują się w wodzie.
- Zwierzęta nie spawnują się w wodzie.
- System nie wpada w infinite loop przy spawn retry.
- Błędne próby są możliwe do debugowania.

### Codex notes
```text
Find existing spawn validation before creating a new validator. Do not duplicate water/bounds checks in many scripts. Consolidate only the validation part if needed. Keep the fix minimal.
```

## [BUG] Ensure animals remain inside world bounds

**Version scope:** `v0.1.1`

### Cel
Zamknąć problem wychodzenia zwierząt poza mapę.

### Zakres
- Sprawdzić ruch small prey, grazerów i Varnaków.
- Dodać clamp albo zmianę celu po dotarciu do granicy.
- Sprawdzić save/load pozycji poza mapą.
- Upewnić się, że AI nie blokuje się na krawędzi świata.

### Acceptance Criteria
- Zwierzęta nie wychodzą poza mapę.
- Po save/load pozycje są poprawne.
- AI nie blokuje się na granicy.
- Zwierzę wybiera nowy sensowny kierunek po dojściu do krawędzi.

### Codex notes
```text
Do not change all movement code unless necessary. Prefer using existing world bounds or WorldConfig. Make the behavior graceful and avoid animals getting stuck at the edge.
```

## [SAVE] Validate ecosystem save/load consistency

**Version scope:** `v0.1.1`

### Cel
Upewnić się, że zapis i wczytanie ekosystemu są spójne po kilku dniach gry.

### Zakres
- Sprawdzić zapis small prey, grazerów, Varnaków, resources, meat drops, dnia i regrowth.
- Sprawdzić brak duplikacji bytów po load.
- Sprawdzić brak resetu populacji po load.
- Dodać manualny scenariusz walidacji, jeśli automatyczne testy są ograniczone.

### Acceptance Criteria
- Save/load nie duplikuje zwierząt.
- Save/load nie usuwa populacji.
- Po wczytaniu AI dalej działa.
- Regrowth dalej działa, a dzień i stan świata są poprawnie odtworzone.

### Codex notes
```text
Do not redesign the save system. Focus on consistency and missing ecosystem state. Avoid saving transient data unless required. Add validation checklist if automated tests are not available.
```

## [BALANCE] Tune first 7 days survival curve

**Version scope:** `v0.1.2`

### Cel
Ustawić sensowną krzywą trudności pierwszego tygodnia gry.

### Zakres
- Dzień 1: nauka i niskie zagrożenie.
- Dzień 2: pierwsza presja.
- Dzień 3: Varnaki zaczynają mieć znaczenie.
- Dni 4-5: obóz, ognisko i pułapki zaczynają być ważne.
- Dni 6-7: świat wyraźnie robi się groźniejszy.

### Acceptance Criteria
- Dzień 1 nie jest zbyt karzący.
- Od dnia 3 rośnie presja.
- Od dnia 5 przygotowanie obozu ma znaczenie.
- Da się przetrwać 7 dni przy rozsądnej grze.

### Codex notes
```text
Do not hardcode balance values deep inside AI scripts. Use config/export variables. Keep values easy to tune. Add comments describing the intended early/mid difficulty curve. Do not introduce new systems.
```

## [BALANCE] Tune Varnak day scaling and aggression

**Version scope:** `v0.1.2`

### Cel
Varnaki mają być narastającym zagrożeniem, ale nie powinny niszczyć gry zbyt wcześnie.

### Zakres
- Dostroić liczbę Varnaków po dniach.
- Dostroić agresję i aktywność nocną.
- Upewnić się, że Varnaki nie wybijają całego ekosystemu.
- Dodać lub zweryfikować limity dzienne i populacyjne.

### Acceptance Criteria
- Dzień 1 ma niskie zagrożenie.
- Dni 3-5 są wyraźnie groźniejsze.
- Po dniu 7 Varnaki są realnym problemem.
- Varnaki nie wybijają prey/grazerów zbyt szybko.

### Codex notes
```text
Tune existing Varnak scaling only. Do not rewrite Varnak AI. Keep population caps explicit. Preserve v0.1 performance optimizations.
```

## [BALANCE] Tune resource regrowth and food availability

**Version scope:** `v0.1.2`

### Cel
Zapewnić sensowny dostęp do jedzenia dla gracza i ekosystemu.

### Zakres
- Dostroić tempo regrowth.
- Dostroić dostępność roślin i mięsa.
- Sprawdzić wpływ grazerów na rośliny.
- Sprawdzić wpływ polowania Varnaków na dostępność mięsa i populacje.

### Acceptance Criteria
- Gracz nie głoduje z powodu losowego braku zasobów.
- Grazery mają realną szansę znaleźć jedzenie.
- Zasoby nie odnawiają się zbyt szybko.
- Mapa nie jest ani pusta, ani przeładowana.

### Codex notes
```text
Do not increase resource counts blindly. Check whether the issue is spawn amount, regrowth speed, AI access, or consumption rate. Prefer tuning several small values over one extreme value.
```

## [BALANCE] Tune biome density without increasing active entity cost

**Version scope:** `v0.1.2`

### Cel
Poprawić gęstość wizualną biomów bez cofania performance patcha.

### Zakres
- Zagęścić tekstury/dekoracje biomów.
- Preferować statyczne dekoracje zamiast aktywnych node'ów.
- Sprawdzić FPS przed i po zmianie.
- Upewnić się, że dekoracje nie blokują ruchu ani spawnu.

### Acceptance Criteria
- Biomy wyglądają mniej pusto.
- FPS nie spada zauważalnie.
- Dekoracje nie psują spawnu/pathfindingu.
- Woda i granice biomów pozostają czytelne.

### Codex notes
```text
Do not spawn many active nodes. Prefer static rendering, tiles, or lightweight decoration. Measure or compare FPS before and after. Keep biome visuals separate from gameplay entities.
```

## [UX] Improve day progression and danger feedback

**Version scope:** `v0.1.3`

### Cel
Pokazać graczowi, że świat zmienia się z dniami i zagrożenie rośnie.

### Zakres
- Dodać komunikat nowego dnia.
- Dodać ostrzeżenie przed nocą.
- Dodać komunikat wzrostu zagrożenia lub aktywności Varnaków.
- Upewnić się, że komunikaty nie spamują ekranu.

### Acceptance Criteria
- Gracz wie, kiedy zaczyna się nowy dzień.
- Gracz rozumie, że zagrożenie rośnie.
- Komunikaty są krótkie i czytelne.
- Komunikaty nie zasłaniają rozgrywki.

### Codex notes
```text
Use existing HUD/message system. Do not create a new UI framework. Keep messages short. Make display duration configurable.
```

## [UX] Improve ecosystem debug readability

**Version scope:** `v0.1.3`

### Cel
Ułatwić testowanie living world i zachowań AI.

### Zakres
- Dodać lub uporządkować debug populacji.
- Pokazać stany AI: wandering, hungry, eating, fleeing, hunting.
- Dodać przełącznik debug info, jeśli go brakuje.
- Aktualizować debug w interwale, nie co klatkę.

### Acceptance Criteria
- Tester może zobaczyć, czy AI faktycznie działa.
- Debug można wyłączyć.
- Normalna rozgrywka nie jest zaśmiecona.
- Debug nie powoduje zauważalnego spadku FPS.

### Codex notes
```text
Keep this debug-only. Do not expose internal states in normal gameplay UI. Update debug info on a timer, not every frame. Preserve v0.1 performance improvements.
```

## [UX] Improve player feedback for hunger, damage and danger

**Version scope:** `v0.1.3`

### Cel
Gracz ma lepiej rozumieć głód, obrażenia i bliskie zagrożenie.

### Zakres
- Poprawić czytelność głodu.
- Dodać feedback otrzymania obrażeń.
- Dodać feedback niskiego zdrowia.
- Dodać informację o bliskim zagrożeniu, jeśli istnieje taka mechanika.

### Acceptance Criteria
- Gracz rozumie, dlaczego traci HP/głód.
- Gracz wie, kiedy jest w niebezpieczeństwie.
- Feedback nie jest przesadzony.
- UI pozostaje czytelne.

### Codex notes
```text
Do not redesign the whole HUD. Improve existing indicators and messages. Keep effects subtle. Avoid expensive per-frame UI operations.
```

## [UX] Add simple world event log

**Version scope:** `v0.1.3`

### Cel
Dodać prosty log najważniejszych zdarzeń świata dla testów i czytelności.

### Zakres
- Log ostatnich kilku zdarzeń.
- Ograniczona liczba wpisów.
- Krótkie komunikaty typu: Day 3 begins, Night is approaching, Varnaks are more active.
- Możliwość ukrycia logu.

### Acceptance Criteria
- Log pokazuje najważniejsze zdarzenia.
- Nie spamuje.
- Nie rośnie bez limitu.
- Można go wyłączyć.

### Codex notes
```text
Keep the event log lightweight. Do not store unlimited messages. Use existing signals where possible. Do not add complex notification architecture.
```

## [TEST] Add v0.1.4 smoke test checklist

**Version scope:** `v0.1.4`

### Cel
Dodać checklistę ręcznego testowania przed buildem.

### Zakres
- Nowa gra startuje poprawnie.
- Zbieranie zasobów, głód, walka, spawn poza wodą, bounds, AI, regrowth, save/load, minimapa i debug overlay.
- Minimum 15-30 minut gry bez crasha.
- Każdy test ma expected result.

### Acceptance Criteria
- Istnieje TESTING.md albo podobny plik.
- Każdy test ma expected result.
- Checklistę można wykonać bez znajomości kodu.
- Znane problemy są opisane osobno.

### Codex notes
```text
Documentation-only issue. Do not modify gameplay code. Keep checklist practical and short. Use clear expected results.
```

## [DOCS] Add tester instructions and known issues

**Version scope:** `v0.1.4`

### Cel
Przygotować prostą dokumentację dla testera.

### Zakres
- Jak uruchomić grę.
- Sterowanie i cel gry.
- Co testować i jak zgłaszać bugi.
- Znane ograniczenia oraz czego jeszcze nie oceniać.

### Acceptance Criteria
- Tester rozumie pierwsze 5 minut gry.
- Tester wie, jak zgłosić problem.
- Dokumentacja nie obiecuje przyszłych funkcji.
- Znane problemy są oddzielone od planów rozwoju.

### Codex notes
```text
Do not over-document. Write for non-programmer testers. Separate bugs, limitations, and future ideas.
```

## [RELEASE] Prepare v0.1.4 Windows tester package

**Version scope:** `v0.1.4`

### Cel
Przygotować paczkę testową Windows.

### Zakres
- Eksport Windows.
- Sprawdzić .exe + .pck.
- Dodać numer wersji i changelog.
- Dodać instrukcję uruchomienia i informację, gdzie zgłaszać bugi.

### Acceptance Criteria
- Paczka działa bez Godota.
- Tester ma wszystkie potrzebne pliki.
- Wersja jest widoczna.
- Changelog opisuje zmiany od v0.1.

### Codex notes
```text
Do not commit large exported binaries unless explicitly intended. Prefer updating export presets and release documentation. Validate that .exe and .pck are packaged together.
```

## [TEST] Add tester feedback template

**Version scope:** `v0.1.4`

### Cel
Ustandaryzować feedback od testerów.

### Zakres
- Template: wersja gry, czas gry, FPS/płynność, zrozumiałość, żywy świat, balans, bugi, frustracje, najlepszy moment, sugestie.
- Template powinien być krótki.
- Odpowiedzi mają dać się zamienić na issues.

### Acceptance Criteria
- Istnieje markdown template feedbacku.
- Tester może go szybko wypełnić.
- Odpowiedzi da się zamienić na issues.
- Template nie jest zbyt długi.

### Codex notes
```text
Create a markdown template. Do not integrate external forms unless requested. Keep it concise.
```
