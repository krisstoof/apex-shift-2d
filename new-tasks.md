Issue 31
Title

[BALANCE] Scale Varnak population with day progression

Labels

type: balancing, area: creatures, area: ecosystem, area: world, area: ai, priority: high, stage: stabilization

Body
Cel

Sprawić, aby świat z każdym kolejnym dniem stawał się bardziej niebezpieczny przez stopniowe zwiększanie liczby Varnaków.

Na początku gry presja Varnaków powinna być niska, aby gracz miał czas na poznanie podstaw przetrwania. Z kolejnymi dniami liczba Varnaków, ich aktywność albo szansa spawnu powinny rosnąć.

Kontekst

Obecnie dokumentacja wskazuje, że WorldConfig.VARNAK_TARGET_COUNT wynosi 8, a Varnaki mają własne parametry spawnu, głodu i polowania. Warto zastąpić sztywną liczbę Varnaków skalowaniem zależnym od dnia.

Zakres

Dodać skalowanie populacji Varnaków zależne od numeru dnia.

System powinien wpływać na:

maksymalną liczbę Varnaków
szansę spawnu Varnaka
uzupełnianie brakujących Varnaków po czasie
opcjonalnie agresywność lub aktywność Varnaków
Proponowany balans startowy
Dzień 1: 1–2 Varnaki
Dzień 2: 2–3 Varnaki
Dzień 3: 3–4 Varnaki
Dzień 4+: stopniowy wzrost do limitu 8–12
Proponowane wartości w GameBalance

Dodać np.:

const VARNAK_DAY_SCALING = {
    "day_1_min": 1,
    "day_1_max": 2,
    "day_2_min": 2,
    "day_2_max": 3,
    "day_3_min": 3,
    "day_3_max": 4,
    "max_varnaks": 12,
    "daily_growth": 1,
    "spawn_check_interval_seconds": 10.0,
    "spawn_batch_limit": 2
}
Wymagania
Dzień gry powinien wpływać na docelową populację Varnaków.
System nie powinien spawnować wszystkich brakujących Varnaków naraz.
Spawn musi respektować:
world bounds,
wodę,
płyciznę/głęboką wodę,
odległość od gracza,
minimalną odległość od innych stworzeń.
Populacja powinna mieć twardy limit maksymalny.
Debug panel powinien pokazywać:
aktualny dzień,
aktualny target Varnaków,
live Varnak count,
max Varnak count.
Acceptance Criteria
Dzień 1 ma małą liczbę Varnaków.
W kolejnych dniach liczba Varnaków stopniowo rośnie.
Populacja Varnaków ma limit maksymalny.
Varnaki nie pojawiają się w wodzie.
Varnaki nie pojawiają się poza mapą.
System nie powoduje nagłych skoków FPS/stutteringu.
Tester może zauważyć wzrost zagrożenia wraz z upływem dni.
Debug panel pokazuje aktualny target populacji Varnaków.
Issue 32
Title

[ECOSYSTEM] Stabilize SmallPrey and Grazer population recovery

Labels

type: balancing, type: bug, area: ecosystem, area: creatures, area: ai, priority: critical, stage: stabilization

Body
Cel

Zapobiec sytuacji, w której populacje SmallPrey i Grazerów stale maleją, aż świat robi się pusty.

Populacje mogą spadać pod wpływem głodu, polowania, biomasy i presji Varnaków, ale powinny mieć możliwość częściowej odbudowy, jeżeli warunki środowiskowe na to pozwalają.

Problem

Obecnie wygląda na to, że SmallPrey i Grazery umierają, są zjadane albo znikają szybciej, niż system jest w stanie je odbudować.

Możliwe przyczyny:

zbyt częste polowania Varnaków
zbyt szybki głód zwierząt
brak reprodukcji lub zbyt słaba reprodukcja
spawn tylko na początku gry
zbyt silna presja biomasy
błędy przy save/load
zwierzęta ginące poza ekranem
zwierzęta wychodzące poza granice mapy
zbyt niskie limity populacji
zbyt wysokie predation_rate
Kontekst

EcosystemDirector zarządza populacjami SmallPrey i Grazerów, a dokumentacja zawiera już wartości typu initial_small_prey_population, small_prey_growth_rate, grazer_growth_rate, small_prey_predation_rate, grazer_starvation_rate, max_small_prey_population i max_grazer_population. Te wartości wymagają zbalansowania i prawdopodobnie dodatkowego mechanizmu odbudowy.

Zakres

Dodać lub poprawić mechanizm odbudowy populacji:

naturalny respawn po czasie
dzienny przyrost populacji
reprodukcję zależną od biomasy
minimalny próg bezpiecznej populacji
docelową populację dla biomu
limit maksymalny populacji
osłabienie presji drapieżników, jeśli populacja ofiar jest krytycznie niska
Proponowany balans startowy

SmallPrey:

minimalna populacja: 12
docelowa populacja: 20–30
maksymalna populacja: 40

Grazery:

minimalna populacja: 6
docelowa populacja: 10–18
maksymalna populacja: 25

Varnaki:

minimalna populacja: 1
docelowa populacja rośnie z dniami
maksymalna populacja: 8–12
Proponowane wartości w GameBalance

Dodać lub dostroić:

const POPULATION_RECOVERY = {
    "small_prey_min_population": 12,
    "small_prey_target_population": 25,
    "small_prey_max_population": 40,
    "small_prey_recovery_per_day": 4,

    "grazer_min_population": 6,
    "grazer_target_population": 14,
    "grazer_max_population": 25,
    "grazer_recovery_per_day": 2,

    "critical_population_predation_multiplier": 0.35,
    "healthy_biomass_recovery_multiplier": 1.25,
    "depleted_biomass_recovery_multiplier": 0.45
}
Reguły
Jeśli biomasa jest zdrowa, populacja może odbudowywać się szybciej.
Jeśli biomasa jest niska, populacja odbudowuje się wolniej.
Jeśli populacja spadnie poniżej minimum, system powinien stopniowo ją ratować.
Varnaki nie powinny całkowicie czyścić mapy z ofiar.
Populacja nie powinna rosnąć ponad limit maksymalny.
Odbudowa nie powinna być natychmiastowa ani magiczna — powinna być rozłożona w czasie.
Debug

Debug panel powinien pokazywać:

SmallPrey current population
SmallPrey min / target / max population
Grazer current population
Grazer min / target / max population
daily recovery amount
predation pressure
starvation pressure
population trend: growing / stable / declining
Acceptance Criteria
SmallPrey nie znikają całkowicie po kilku dniach.
Grazery nie znikają całkowicie po kilku dniach.
Populacje mogą spadać, ale później częściowo się odbudowują.
Varnaki nadal mogą polować, ale nie czyszczą całej mapy z ofiar.
Po kilku dniach świat nadal wygląda na żywy.
Save/load nie resetuje ani nie psuje populacji.
Debug panel pozwala zobaczyć, dlaczego populacja rośnie albo spada.
Populacje mają minimum, target i maximum.
Issue 33
Title

[VISUALS] Increase biome texture density and variation

Labels

type: polish, area: visuals, area: world, area: biome, priority: medium, stage: polish

Body
Cel

Sprawić, aby biomy wyglądały mniej pusto i bardziej naturalnie przez zagęszczenie tekstur oraz dodanie większej liczby subtelnych wariantów wizualnych.

Problem

Przy większym świecie i płynniejszych biomach jednolite powierzchnie terenu mogą wyglądać pusto. Biomy powinny być bardziej zróżnicowane wizualnie, ale nadal czytelne.

Zakres

Dostosować biome texture system:

zwiększyć gęstość tekstur / detali biomów
dodać więcej wariantów patternów na jednym biomie
zmniejszyć wrażenie dużych jednolitych plam
zachować czytelność przejść między biomami
dopilnować wydajności przy większym świecie
Wymagania
Tekstury biomów powinny pozostać subtelne.
Tekstury nie mogą zasłaniać:
gracza,
zwierząt,
zasobów,
wody,
mięsa,
pocisków,
elementów interaktywnych.
Biome texture cache powinien nadal działać wydajnie.
Zagęszczenie tekstur powinno być konfigurowalne w GameBalance.
Proponowane wartości w GameBalance
const BIOME_TEXTURES = {
    "detail_density_multiplier": 1.35,
    "detail_alpha": 0.18,
    "secondary_detail_alpha": 0.10,
    "variation_noise_strength": 0.22,
    "max_detail_per_chunk": 120
}
Acceptance Criteria
Biomy wyglądają gęściej i mniej pusto.
Różne obszary mapy są bardziej wizualnie zróżnicowane.
Nadal da się łatwo rozpoznać typ biomu.
Tekstury nie zasłaniają ważnych obiektów.
Nie ma dużego spadku FPS po zagęszczeniu tekstur.
Tekstury nadal współpracują z tintem biomasy i przejściami między biomami.