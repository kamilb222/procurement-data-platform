# AGENTS.md — Procurement Data Platform

---

## 1. Project overview

**Project name:** `procurement-data-platform` (working title; suggest a better one in Stage 1 if you have one, but ask before renaming).

**One-sentence pitch:** An end-to-end analytics platform for public procurement data: a layered SQL pipeline with data-quality validation (Stage 1), a Power BI semantic layer (Stage 2), an LLM-powered natural-language-to-SQL interface with a rigorous correctness benchmark (Stage 3), and a thin React/TypeScript UI (Stage 4).

**Purpose:** This is a portfolio project for a data-analytics student applying to internships. The audience is technical recruiters who will (a) skim the README, (b) try to run it, (c) maybe read the code. Therefore: **a smaller, finished, runnable stage always beats a larger, unfinished one.** Polish, reproducibility, and documentation are first-class deliverables, not afterthoughts.

**Dataset:** California State Purchase Order Data (SCPRS extract, fiscal years 2012–2015, ~350k rows). Source: https://data.ca.gov/dataset/purchase-order-data (also mirrored on Kaggle as "Large Purchases by the State of CA"). The raw CSV will be placed by the human at `data/raw/` before Stage 1 begins. **Never commit raw data to git** — `data/raw/` and `data/processed/` must be in `.gitignore` from the first commit. Instead, provide `scripts/download_data.md` with manual download instructions (and a download script only if the direct CSV URL proves stable).

**Known/expected data quality issues** (verify during profiling, do not assume): dates stored as text in mixed formats; monetary columns containing `$` and thousands separators; inconsistent supplier names for the same supplier code; missing zip codes / CalCard flags; rows with zero, negative, or absurd prices; duplicated PO line items; multiple UNSPSC codes breaking row formatting; trailing/extraneous characters in text fields.

---

## 2. Stage gating — the most important rule

Work proceeds in **four strictly ordered stages**. Each stage ends in a tagged release.

- **Never start work on stage N+1 until the human explicitly says the current stage is accepted.**
- Within a stage, follow the task order given in that stage's section.
- If you finish a stage's Definition of Done, stop, summarize what was built, list anything you consciously deferred, and wait.
- If you discover mid-stage that the plan in this file is wrong or suboptimal, say so and propose an alternative **before** implementing it. Do not silently deviate.

| Stage | Deliverable | Release tag |
|---|---|---|
| 1 | SQL pipeline + data validation + pytest | `v0.1.0` |
| 2 | Analytics export layer + Power BI support artifacts | `v0.2.0` |
| 3 | Text-to-SQL service + evaluation benchmark | `v0.3.0` |
| 4 | React/TS frontend + vitest | `v1.0.0` |

---

## 3. Tech stack (fixed — do not substitute without asking)

- **Language:** Python 3.11+ (backend), TypeScript (frontend, Stage 4 only)
- **Database:** PostgreSQL 16 via Docker Compose. No ORM for the pipeline — raw SQL files are the point of this project. `psycopg` (v3) for connectivity from Python.
- **SQL organization:** plain `.sql` files executed by a thin Python runner. Do NOT bring in dbt, SQLAlchemy ORM, or Alembic — the recruiter must see hand-written SQL. (Lightweight use of `sqlalchemy.engine` purely as a connection helper for pandas export in Stage 2 is acceptable.)
- **API (Stage 3):** FastAPI + uvicorn, Pydantic v2 models.
- **LLM (Stage 3):** provider-agnostic client targeting any **OpenAI-compatible chat-completions endpoint**, configured entirely via env vars: `LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY` (key optional — local endpoints don't need one). Never hard-code a provider, model name, or key.
  - **Default / zero-cost provider:** local **Ollama** (`LLM_BASE_URL=http://localhost:11434/v1`), suggested model: a ~7B coder-class model (e.g. `qwen2.5-coder:7b`). The human runs Ollama on the Windows host with an RTX 5060; from WSL2 the base URL may need the Windows host IP instead of `localhost` — document both variants in `.env.example` and README.
  - **Optional paid providers** (Anthropic, OpenAI, Gemini, Groq): must work through the same abstraction by changing env vars only. If a provider needs a thin adapter (e.g. Anthropic's native Messages API), isolate it behind the same internal interface; do not let provider-specific code leak into `generator.py` logic.
  - **Cost decision checkpoint:** whether any paid provider is used at all is a human decision made **after Stage 2 acceptance**. Until the human explicitly opts in, assume local-only: no paid SDK calls anywhere, and the benchmark targets the local model.
- **Frontend (Stage 4):** Vite + React + TypeScript, vitest + React Testing Library. Plain CSS or CSS modules — no Tailwind, no component library (keep the diff readable and the build simple).
- **Testing:** pytest (+ pytest-postgresql or testcontainers — prefer testcontainers if Docker-in-Docker is not an issue locally; otherwise run tests against the compose Postgres with a dedicated `test` schema).
- **Tooling:** `ruff` (lint + format), `uv` or `pip-tools` for pinned dependencies (pick `uv` if available), `pre-commit` config with ruff + a secrets scanner (e.g. `detect-secrets` or `gitleaks` if available).
- **CI:** GitHub Actions workflow that runs ruff + pytest on every push (add in Stage 1; extend with vitest in Stage 4).

---

## 4. Repository layout

Create this skeleton in Stage 1 and grow it; do not restructure later without asking.

```
procurement-data-platform/
├── AGENTS.md
├── CLAUDE.md                  # contains only: @AGENTS.md
├── README.md                  # top-level: pitch, architecture diagram, per-stage sections, quickstart
├── docker-compose.yml         # postgres (+ later: api)
├── .env.example               # every env var the project uses, with dummy values
├── .gitignore                 # data/, .env, .pbix backups, node_modules, __pycache__, etc.
├── .pre-commit-config.yaml
├── .github/workflows/ci.yml
├── pyproject.toml
├── data/
│   ├── raw/                   # gitignored; human drops CSV here
│   └── processed/             # gitignored
├── scripts/
│   ├── download_data.md       # manual download instructions with URL + expected filename + row count
│   └── run_pipeline.py        # CLI entry: python scripts/run_pipeline.py [--stage staging|transform|marts|all]
├── sql/
│   ├── 00_init/               # schema creation: raw, staging, marts schemas
│   ├── 10_staging/            # typed, cleaned copies of raw tables
│   ├── 20_transform/          # deduplication, supplier name normalization, derived columns
│   └── 30_marts/              # star schema: fact_purchase_orders + dim_supplier, dim_department, dim_unspsc, dim_date
├── src/
│   └── pdp/                   # importable package
│       ├── config.py          # env-driven settings (pydantic-settings)
│       ├── db.py              # connection helpers
│       ├── pipeline/          # runner that executes sql/ in order, logging row counts per step
│       ├── validation/        # data-quality checks (Stage 1)
│       ├── export/            # Stage 2: mart -> CSV/parquet export for Power BI
│       ├── nl2sql/            # Stage 3: prompt building, SQL guardrails, execution
│       └── api/               # Stage 3: FastAPI app
├── benchmark/                 # Stage 3: gold question->SQL pairs + eval harness + results
├── tests/                     # pytest, mirrors src/ structure
├── powerbi/                   # Stage 2: .pbix (human-made), screenshots, model documentation
└── frontend/                  # Stage 4: Vite app
```

---

## 5. Global rules (apply in every stage)

### Git & commits
- Small, atomic commits with conventional-commit messages (`feat:`, `fix:`, `test:`, `docs:`, `chore:`).
- Work on `main` directly is forbidden after Stage 1 scaffolding; use short-lived feature branches and describe the intended merge in your summary (the human performs merges/PRs on GitHub).
- Never run `git push`, never create tags/releases — the human does this after review.
- Never rewrite published history (`rebase`/`force push` on anything shared).

### Secrets & data
- `.env` is gitignored from commit #1; keep `.env.example` current at all times.
- Never print API keys, even partially, in logs or test output.
- Never commit anything from `data/`. If a test needs sample data, generate a small synthetic fixture (≤200 rows) into `tests/fixtures/` — synthetic, not copied from the real dataset.

### Code quality
- Every Python module gets type hints and docstrings. Ruff must pass with zero warnings.
- No function over ~50 lines; no file over ~400 lines without a good, stated reason.
- Prefer boring, readable code over clever code. A recruiter will skim this.
- Every SQL file starts with a comment block: purpose, inputs (tables), outputs (tables), grain of the output table.

### Testing
- New logic ships with tests in the same commit. Target: validation logic and nl2sql guardrails at high coverage; thin wrappers may be untested.
- Tests must not require the real dataset; use fixtures.
- Tests must not call the Anthropic API. Mock the client; the live benchmark run in Stage 3 is a separate, explicitly human-triggered script.

### Documentation
- README is a living document: after each stage, add a section with what the stage does, how to run it, and 1–2 screenshots (leave a `TODO(human): screenshot` marker where a screenshot is needed — the human captures those).
- Maintain `CHANGELOG.md` (Keep-a-Changelog format). Prepare release notes text for the human at the end of each stage.

### Interaction with the human
- Whenever a decision is ambiguous and consequential (naming, schema grain, model choice, adding a dependency), present 2–3 options with a recommendation instead of picking silently.
- At the end of every working session, write/refresh `PROGRESS.md`: what's done, what's in flight, exact next steps. Assume the next session starts with zero conversational memory.

---

## 6. Stage 1 — SQL pipeline + data validation (target: `v0.1.0`)

**Goal:** Raw CSV → clean, documented star schema in Postgres, with a data-quality report and tests. This stage alone must be a complete, presentable project.

### Task order
1. **Scaffolding:** repo layout above, docker-compose with Postgres 16 (named volume, healthcheck), pyproject, ruff, pre-commit, CI workflow, `.env.example` (DB credentials, ports).
2. **Data profiling script** (`scripts/profile_raw.py`): load the raw CSV with pandas (`dtype=str`, no type inference), output a markdown profile to `docs/data_profile.md`: per-column null %, distinct counts, min/max, top-10 values, detected format anomalies. **Stop after this step and show the human the profile** — the concrete cleaning rules in step 4 must be agreed based on real findings, not assumptions.
3. **Load layer:** `sql/00_init` creates schemas `raw`, `staging`, `marts`. Loader copies the CSV into `raw.purchase_orders` verbatim (all TEXT columns) using `COPY`. Log row count.
4. **Staging layer** (`sql/10_staging`): typed casts with explicit failure handling (rows that fail casts go to `staging.rejected_rows` with a reason column — never silently drop), date parsing, money parsing, trimming, canonical casing.
5. **Transform layer** (`sql/20_transform`): dedup PO line items (define and document the uniqueness key), supplier name normalization (same supplier code → one canonical name; document the chosen strategy, e.g. most frequent variant), derived columns (fiscal year check, price sanity flags).
6. **Marts layer** (`sql/30_marts`): star schema — `fact_purchase_orders`, `dim_supplier`, `dim_department`, `dim_unspsc`, `dim_date`. Document grain in each file header. Add useful analytical views (spend by department/quarter, top suppliers, acquisition-method breakdown).
7. **Validation module** (`src/pdp/validation/`): rule-based checks that run post-pipeline and produce `docs/data_quality_report.md` + non-zero exit code on hard failures. Checks: row-count reconciliation between layers, referential integrity fact→dims, no negative totals in fact, date ranges within FY2012–2015, duplicate-key check, null thresholds per critical column. Design it as a small declarative framework (list of Check objects), not ad-hoc asserts — this is a portfolio highlight.
8. **Tests:** unit tests for parsers/normalizers with synthetic fixtures; integration test running the whole pipeline on a 200-row synthetic CSV inside a test schema/container.
9. **Docs & wrap-up:** README stage section, architecture diagram (Mermaid is fine), CHANGELOG entry, draft release notes for `v0.1.0`, PROGRESS.md.

### Definition of Done (Stage 1)
- `docker compose up -d && python scripts/run_pipeline.py --stage all` works from a clean clone (given the CSV in place) and finishes with a green validation report.
- CI green; ruff clean; all tests pass without the real dataset.
- `docs/data_profile.md` and `docs/data_quality_report.md` exist and are readable by a non-engineer.

---

## 7. Stage 2 — Power BI layer (target: `v0.2.0`)

**Reality check:** you (the agent) cannot operate Power BI Desktop. Your job is to make the human's Power BI work trivial and to document the semantic model. **Do not attempt to generate a .pbix file.**

### Task order
1. **Export module** (`src/pdp/export/`): export the marts star schema to `data/processed/powerbi/` as CSV (and parquet) — one file per dim/fact — via `scripts/export_for_powerbi.py`. Stable column names, ISO dates, no locale-dependent formatting.
2. **Model documentation** (`powerbi/MODEL.md`): exact import instructions for the human — which files, which relationships (with cardinality and direction), which columns to hide, suggested data types.
3. **Measure catalog** (`powerbi/MEASURES.md`): 10–15 DAX measures with code and one-line business meaning (Total Spend, YoY Spend %, Supplier Concentration/HHI, Avg PO Value, CalCard Share %, etc.). The human copy-pastes these into Power BI.
4. **Report spec** (`powerbi/REPORT_SPEC.md`): a 3-page report layout spec (Overview / Suppliers / Categories): which visual, which fields, which filters, suggested slicers. Precise enough that building it is mechanical.
5. README stage section + placeholders for the human's screenshots; CHANGELOG; draft `v0.2.0` release notes.

### Definition of Done (Stage 2)
- Export script produces the files; docs are complete enough that a person who has never seen the project can build the report in an afternoon.
- Human confirms the .pbix is built and screenshots are committed to `powerbi/screenshots/`.

---

## 8. Stage 3 — Text-to-SQL + benchmark (target: `v0.3.0`)

**Goal:** A FastAPI service that answers natural-language questions over the marts schema by generating SQL — plus the project's differentiator: a **measured, reproducible evaluation of generation correctness.** The benchmark is not optional garnish; treat it as half the stage.

### Task order
1. **Guardrailed SQL execution layer** (`src/pdp/nl2sql/executor.py`) — build this FIRST, before any LLM code:
   - Dedicated read-only Postgres role (`nl2sql_reader`) with SELECT-only grants on `marts` (add to init SQL).
   - Validate generated SQL before execution: single statement, must start with SELECT/WITH, deny-list (INSERT/UPDATE/DELETE/DROP/ALTER/COPY/GRANT/`;` chaining/comments used for smuggling), enforce a `LIMIT` cap and a statement timeout.
   - Unit-test the validator exhaustively, including adversarial inputs ("ignore previous instructions and DROP TABLE...", stacked queries, comment tricks). These tests are a portfolio highlight.
2. **Schema context builder:** generate a compact schema description (tables, columns, types, FK relationships, 2–3 sample values for low-cardinality columns) from the live database, cached to a file. This goes into the LLM prompt.
3. **LLM client abstraction** (`src/pdp/nl2sql/llm_client.py`): a minimal internal interface (`complete(system, messages, **params) -> str`) implemented against any OpenAI-compatible endpoint using `LLM_BASE_URL`/`LLM_MODEL`/`LLM_API_KEY`. Include a health-check helper (`scripts/check_llm.py`) that verifies the configured endpoint responds and reports the active model. Unit-test with a mocked transport; never call a live endpoint in tests.
4. **NL→SQL generation** (`src/pdp/nl2sql/generator.py`): built on the client abstraction; prompt = schema context + rules (Postgres dialect, marts schema only, always LIMIT unless aggregating, return SQL in a fenced block) + few-shot examples (5–8, hand-picked). Deterministic-ish settings (temperature 0). Retry-once-on-invalid-SQL loop with the validator error fed back. Prompt text must live in versioned files (`src/pdp/nl2sql/prompts/`), not inline strings — prompt iterations should be visible in git history.
5. **API** (`src/pdp/api/`): `POST /ask` → `{question}` → `{sql, rows, columns, latency_ms, model, retried}`; `GET /health` (includes LLM endpoint health); `GET /schema`. Add the API service to docker-compose; note in docs that the API reaches Ollama on the host (compose `extra_hosts: host.docker.internal:host-gateway`). Never expose raw DB errors to the client.
6. **Benchmark harness** (`benchmark/`):
   - `benchmark/questions.yaml`: 40–60 items, each `{id, question, gold_sql, difficulty (easy/medium/hard), category (aggregation/filter/join/ranking/time)}`. **You draft it; the human reviews and corrects gold SQL before any results are reported** — mark the file DRAFT until then.
   - Scoring = **execution accuracy**: run generated SQL and gold SQL, compare result sets (order-insensitive unless the question demands ordering, float tolerance, column-name-insensitive). Not string comparison.
   - **Multi-model by design:** `scripts/run_benchmark.py --config benchmark/models.yaml` where `models.yaml` lists one or more `{name, base_url, model, api_key_env, paid: true|false}` entries. Results are written per model to `benchmark/results/<timestamp>_<model>.json` + a markdown report per run: overall accuracy, breakdown by difficulty and category, latency stats, table of failures with gold vs. generated SQL. A comparison report is generated automatically when results for ≥2 models exist.
   - **Cost gate:** entries with `paid: true` are skipped unless the human passes `--include-paid --yes`, and the script prints an estimated call/token count before proceeding. Local (Ollama) runs need no flag. Default `models.yaml` ships with the local model only.
7. **Analysis** (`benchmark/ANALYSIS.md`): after the human runs the benchmark, help interpret: error taxonomy (wrong join, wrong aggregation, hallucinated column, ambiguous question…), accuracy-by-category chart (matplotlib PNG committed to repo). If the human has opted into a paid provider, extend the analysis into a local-vs-cloud comparison (accuracy, latency, cost per 100 queries, data-privacy considerations) — this comparison is a headline feature of the project when available, but the stage is complete without it.
8. README stage section (with the headline accuracy number once known), CHANGELOG, draft `v0.3.0` notes.

### Definition of Done (Stage 3)
- API runs via compose; validator test suite green, including adversarial cases.
- Benchmark harness runs end-to-end on a 3-question smoke subset with a mocked LLM in CI.
- Human has reviewed gold SQL and executed at least one full benchmark run **against the local model**; results and analysis are committed. Paid-provider comparison is optional and human-initiated.

---

## 9. Stage 4 — Frontend (target: `v1.0.0`)

**Goal:** A thin, clean UI over the Stage 3 API. Deliberately small scope — this stage proves TS/React/testing literacy, not design ambition.

### Task order
1. Vite + React + TS scaffold in `frontend/`; ESLint + Prettier consistent with repo style; vitest + RTL configured.
2. Single-page app: question input → loading state → results table (sortable columns, CSV download of results) → collapsible "Show generated SQL" panel with copy button → error states (invalid question, API down, query rejected by guardrails) rendered distinctly.
3. Small niceties, nothing more: history of last 10 questions (in-memory), 3–4 example-question chips, latency display.
4. Tests: component tests for the main flow with a mocked API client (success, error, guardrail-rejection paths).
5. Serve frontend via compose (either a static build behind the API or a `frontend` dev service); update CI to run vitest; final README polish: full architecture diagram of all four stages, demo GIF placeholder for the human.

### Definition of Done (Stage 4)
- `docker compose up` gives a working end-to-end demo at a documented URL.
- vitest + pytest + ruff green in CI; README quickstart verified from a clean clone.

---

## 10. Things you must never do

- Skip ahead a stage, or start Stage N+1 "in the background".
- Commit data files, `.env`, `.pbix` temp files, or anything containing an API key.
- Push, tag, or publish releases (human-only actions).
- Call any live LLM endpoint (local or remote) from tests or CI — mock the client.
- Use any paid LLM provider anywhere before the human explicitly opts in (decision scheduled after Stage 2 acceptance), and never run paid benchmark entries without `--include-paid --yes` being a conscious human action.
- Add heavyweight dependencies (dbt, Airflow, LangChain, ORMs, component libraries) — the hand-rolled simplicity is the point.
- Present the benchmark as final while `questions.yaml` is still marked DRAFT.
- Invent dataset facts. Everything about the data must come from the profiling step.