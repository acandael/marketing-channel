# AGENTS.md

## Tech Stack

Rails 8 + Hotwire (Turbo + Stimulus) + PostgreSQL. Views are plain ERB. TypeScript-authored Stimulus controllers, Vite 7, Propshaft. Ruby 3.3.6.

Styling is vanilla CSS via one hand-written stylesheet (`app/frontend/styles/nhd.css`) organized into BEM-style blocks (`.topnav__link`, `.manage__panel`, `.dialog__content`, etc.). No Tailwind, no `cva`, no component framework — templates use the CSS class names directly.

Background jobs, caching, and WebSockets use the Rails 8 "Solid" trifecta (Solid Queue, Solid Cache, Solid Cable), all database-backed. **All four share the single PostgreSQL database** (`<app_name>_<env>`, where `app_name` is the repo's folder name — `build_new` for this template) — there are no separate cache/cable/queue databases, no `db/cache_schema.rb` / `db/cable_schema.rb` / `db/queue_schema.rb`, and `config/cache.yml` / `config/cable.yml` / `config/queue.yml` have no separate connection blocks. Override the connection via `DATABASE_URL` or the `DATABASE_USER` / `DATABASE_PASSWORD` / `DATABASE_HOST` / `DATABASE_PORT` env vars (see `config/database.yml`).

**Per-app, per-worktree DB naming.** `config/database.yml` derives the development _and_ test DB names automatically, so an app forked from this template gets its own databases with no edits to the file. The name has two parts: an `app_name` (the repository's own folder name, sanitized to a legal Postgres identifier — `coolapp`, or `build-new` → `build_new`) and a worktree suffix. In the **main checkout** (where `.git` is a directory) the suffix is empty: `<app_name>_development` / `<app_name>_test`. In a **git worktree** (where `.git` is a pointer file written by `git worktree add`, e.g. Conductor workspaces) the worktree's own folder name is appended — `<app_name>_development_<worktree>` / `<app_name>_test_<worktree>` — so parallel worktrees never share or clobber each other's schemas, and parallel `bin/rails test` runs no longer collide on a shared test DB. `app_name` is found from the main repo even inside a worktree: the worktree's `.git` pointer (`gitdir: <repo>/.git/worktrees/<wt>`) is read and walked up to the main repo root, whose folder name becomes `app_name`. This matters when forking this template into a new app: if two checkouts shared a dev DB, migrations from one would land in the other and `db:schema:dump` would commit phantom tables. Override the development name entirely with `DATABASE_NAME`. Staging/production are named the same way but are overridden by `DATABASE_URL` on real deploys, so the derived name there is only a local fallback.

## Commands

```bash
bin/setup              # Initial setup (bundle, db:prepare, start dev)
bin/dev                # Dev server (Rails :3000 + Vite :3036)
bin/rails test         # Minitest
bin/rails test:system  # Capybara + headless Chrome
npm run check          # TypeScript type checking (Stimulus controllers)
bin/rubocop            # Ruby linting (rubocop-rails-omakase)
bin/brakeman           # Security scanning
```

## Merging to main triggers a deployment

Merging anything into `main` automatically triggers a production deployment on Hatchbox. When the user asks you to merge into `main`, treat that request as authorization to ship — the deployment is the intended outcome, so go ahead and merge without pausing to ask for separate permission to deploy.

After completing a merge into `main`, make it easy for the user to watch the deployment:

1. Output this repo's Hatchbox app URL: https://app.hatchbox.io/apps/13694-holistichealth
2. Automatically open that URL in the user's browser (`open <url>` on macOS)

## Deployment (Hatchbox)

The app targets Hatchbox on a Ubuntu VPS with PostgreSQL, Nginx, and Puma. The following pieces are already wired up in the repo:

- **`Procfile`** — `web` (Puma) + `jobs` (Solid Queue via `bin/jobs`).
- **`config/environments/production.rb`** — SSL forced, S3 storage (`config.active_storage.service = :amazon`), Resend SMTP, `default_url_options.host` read from `ENV["APP_HOST"]`, DNS-rebinding `config.hosts` gated on `APP_HOST` with `/up` health-check exempted.
- **`config/storage.yml`** — `amazon:` block reads AWS creds from env vars (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_S3_BUCKET`) with a fallback to Rails credentials.
- **`Gemfile`** — `aws-sdk-s3` is bundled.
- **`config/sitemap.rb`** — reads host from `ENV["APP_HOST"]`; regenerate with `bin/rails sitemap:refresh:no_ping` on deploy.

**Required environment variables in Hatchbox:**

- `RAILS_MASTER_KEY` — contents of local `config/master.key` (needed to decrypt `credentials.yml.enc`).
- `APP_HOST` — deployed domain, e.g. `holistichealth.de`. Drives mailer links, `config.hosts` allow-list, sitemap URLs.
- `RESEND_API_KEY` — from Resend dashboard.
- `MAIL_FROM` — sender header, e.g. `"Holistic Health <hello@holistichealth.de>"`.
- `GEOCODER_CONTACT_EMAIL` — real address (Nominatim's usage policy rejects `example.com`).
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET` — S3 IAM credentials + bucket name. `AWS_REGION` defaults to `eu-central-1`.

**Manual file edits still needed the first time** (both are static files that can't be templated):

- **`public/robots.txt`** — change the `Sitemap: https://example.com/sitemap.xml` line to your real domain.
- **`public/llms.txt`** — change the four `https://example.com/...` URLs to your real domain.

**First-deploy commands** (run once in the Hatchbox console after the first successful deploy):

```bash
bin/rails db:seed          # creates admin@test.com + 10 demo practitioners; delete demos in prod if unwanted
bin/rails sitemap:refresh:no_ping
```

Immediately change the admin password afterwards via `bin/rails console`; the seed `test123` is dev-only.

**Ongoing deploys:** push (or merge) to `main` — Hatchbox auto-deploys and runs `db:migrate`.

## Architecture

Standard Rails MVC. Controllers render ERB views. Turbo Drive handles page navigation without full reloads; Turbo Frames + Turbo Streams handle partial updates; Stimulus controllers cover the small amount of client-side behaviour.

### Layouts

Each controller (or namespace) picks a layout via `layout "..."`:

| Layout                                    | Used by                                                        | What it renders                                           |
| ----------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------- |
| `layouts/application.html.erb`            | fallback (unused today)                                        | Bare `<head>` + flash + yield                             |
| `layouts/auth.html.erb`                   | sessions, registrations, passwords, practitioner_registrations | Top nav + centered `.auth__card`                          |
| `layouts/public.html.erb`                 | pages (home), public/practitioners, settings, profiles         | Top nav + main + site footer                              |
| `layouts/admin.html.erb`                  | admin::*                                                       | Top nav + sidebar admin nav + `.manage__main` + footer    |
| `layouts/practitioner_dashboard.html.erb` | dashboard::*                                                   | Top nav + sidebar dashboard nav + status banners + footer |

All layouts include `shared/_meta.html.erb` in the `<head>` (which loads `entrypoints/hotwire.ts` and the `application.css` stylesheet via Vite) and render `shared/_flash.html.erb` in the body.

### Adding a new page

1. Add a route in `config/routes.rb`.
2. Controller action assigns instance variables and either lets Rails auto-render `<action>.html.erb` or calls `render layout: "<layout>"` explicitly. Set `layout "..."` at class level when every action shares a layout, per-action otherwise.
3. Create `app/views/<controller>/<action>.html.erb`.
4. Set `<title>`, `<meta name="description">`, `<meta property="og:title">`, and `<meta property="og:description">` via `content_for` at the top of the template (see "Page metadata" below).
5. If the page is **publicly viewable** (no `require_authentication`), also:
   - Add it to `config/sitemap.rb` so crawlers discover it.
   - Add it to `public/llms.txt` under the right section.
   - Make sure it is not blocked in `public/robots.txt`.

### Key files

- `app/views/layouts/*.html.erb` — one per section (application, auth, public, admin, practitioner_dashboard).
- `app/views/shared/_meta.html.erb` — canonical `<head>` contents, loaded by every layout.
- `app/views/shared/_flash.html.erb` — flash toast (auto-dismisses via the flash Stimulus controller).
- `app/views/shared/_top_nav.html.erb`, `_site_footer.html.erb` — global chrome.
- `app/views/shared/_dialog.html.erb`, `_dropdown.html.erb` — reusable primitives that pair with the matching Stimulus controllers.
- `app/javascript/entrypoints/hotwire.ts` — Turbo + Stimulus entrypoint.
- `app/javascript/controllers/index.ts` — registers each Stimulus controller.
- `app/javascript/entrypoints/application.css` — imports `app/frontend/styles/nhd.css`.
- `app/frontend/styles/nhd.css` — the entire design-system stylesheet (BEM classes).
- `app/controllers/application_controller.rb` — modern-browser guard + auth include.
- `app/controllers/concerns/authentication.rb` — session helpers, `require_authentication`.
- `config/routes.rb` — all routes.
- `config/sitemap.rb` — sitemap_generator config; lists every public URL.
- `public/robots.txt` — crawler allow/deny rules + sitemap pointer.
- `public/llms.txt` — curated, plain-text site map for LLM crawlers.

## Controller response patterns

Rails + Turbo, standard idioms:

### Mutation success → redirect

```ruby
if record.save
  redirect_to record_path(record), notice: "Saved."
else
  render :new, status: :unprocessable_entity
end
```

Turbo Drive follows redirects (SPA-feel nav). On `422 :unprocessable_entity`, Turbo replaces the body in place, so the form re-renders with `record.errors` visible.

### Mutation with Turbo Streams

For inline updates without a full page swap (add/edit/delete a row without leaving the list), respond with a Turbo Stream:

```ruby
def create
  @thing = Thing.create(thing_params)
  respond_to do |format|
    format.turbo_stream    # renders create.turbo_stream.erb
    format.html { redirect_to things_path, notice: "Added." }
  end
end
```

Templates use `turbo_stream.replace`, `turbo_stream.append`, `turbo_stream.remove`, etc. Examples live under `app/views/admin/focus_areas/` (whole-list swap on CRUD, single-row swap on rename) and `app/views/dashboard/treatments/` (dialog form flow).

### Dialog flow (Stimulus + Turbo)

Add or edit dialogs use the `dialog` Stimulus controller (`app/javascript/controllers/dialog_controller.ts`). Attach `data-action="turbo:submit-end->dialog#closeOnSuccess"` to the form — it closes only on 2xx/3xx, staying open on 422 so validation errors render inline. Set `data-dialog-open-on-load-value="true"` on the wrapping controller element to auto-open the dialog on page load (used by the treatments add flow when the form re-renders with errors).

### Tests

Mutation success → `assert_redirected_to`. Mutation failure → `assert_response :unprocessable_entity` (was `:redirect` under Inertia).

## Crawler discovery: sitemap.xml, robots.txt, llms.txt

Three discovery files live at the site root and must stay in sync as public pages are added or removed:

**`config/sitemap.rb` → `public/sitemap.xml`** (sitemap_generator gem). Regenerate with `bin/rails sitemap:refresh:no_ping` (writes the file) or `bin/rails sitemap:refresh` (writes + pings search engines). The host comes from `APP_HOST` env var, falling back to `Rails.application.config.action_controller.default_url_options[:host]`. **Whenever a publicly viewable route is added, removed, or has its URL changed, update `config/sitemap.rb` accordingly and regenerate.** Auth-gated routes must not appear here.

**`public/robots.txt`** — explicitly allows all user-agents and lists the auth-gated route prefixes (`/login`, `/dashboard`, `/profile`, etc.) under `Disallow:`. Also contains a `Sitemap:` line pointing at `https://example.com/sitemap.xml` — change that host on first deploy of each app forked from this template. **When new auth-gated route prefixes are added, add matching `Disallow:` lines** so they aren't crawled.

**`public/llms.txt`** — a curated, hand-maintained markdown index of public pages, following the [llmstxt.org](https://llmstxt.org) convention. LLM crawlers ingest this directly and prefer it over scraping rendered HTML. **Whenever a public page is added, removed, or significantly retitled, update `public/llms.txt` to match** — slot it into the appropriate section (Main pages / About / Product / Resources) with a one-line description. Keep the entries scoped to publicly viewable pages only.

## Page metadata (every page, no exceptions)

Every ERB template must set, via `content_for`, **all four** of: title, meta description, `og:title`, and `og:description`. Title + description drive search and accessibility; the `og:` tags drive social previews (Slack, Discord, X, LinkedIn, iMessage). Without explicit `og:` tags, social platforms fall back to `<title>` + `<meta name="description">` — which works, but doesn't let you tune the social-specific copy independently.

```erb
<% content_for :title, "Pricing" %>
<% content_for :description, "Plans, pricing, and what's included in each tier of <Product Name>." %>
<% content_for :og_title, "Pricing" %>
<% content_for :og_description, "Plans, pricing, and what's included in each tier of <Product Name>." %>

<%# ...page content... %>
```

`app/views/shared/_meta.html.erb` reads all four via `content_for(:title)` etc. and emits the tags.

**Rules.**

- **Title:** specific to the page — not the app name. Keep under ~60 characters so it doesn't get truncated in search results. If `content_for(:title)` is blank, the layout falls back to `"Holistic Health"`.
- **Description:** unique per page, written for humans, 120–160 characters, summarizes what the page is and why someone would land on it. Avoid keyword stuffing.
- **`og:title` + `og:description`:** mirror title and description by default. Override only when the social-share copy should differ from the search-result copy (e.g. punchier headline, more conversion-focused).
- Public marketing pages (home, pricing, about, blog, docs, etc.) are crawled — these tags show up directly in search results, AI answers, and link previews, so they matter most.
- Authenticated pages still need them — they're disallowed in `robots.txt` but the title/description shows up in browser tabs, history, and link previews when someone shares an internal link.
- For richer social previews on a public page, also add `og:image` (1200×630), `og:type`, and `twitter:card="summary_large_image"` inside the layout's `<%= yield :head %>` block.

`app/views/pages/home.html.erb` is the canonical example to copy from.

## Conventions

- Ruby: `rubocop-rails-omakase` style, `frozen_string_literal: true`.
- `ApplicationController` restricts to modern browsers.
- `Current.user` (delegated from `Current.session.user`) is the authenticated user; use it directly in views for anything auth-gated.
- PostgreSQL (database `<app_name>_<env>`, derived from the repo's folder name — `build_new` for this template) is the only database — Active Record + Solid Queue/Cache/Cable all share it.

## Testing and verification

- **After implementing a significant feature, ensure we have test coverage for that feature** and that the full test suite still passes 100%. Run `bin/rails test` (and `bin/rails test:system` for system tests) before reporting the task as complete.
- **When making any front-end UI changes or features, verify with the `agent-browser` skill** that all user paths and flows actually work end-to-end and remain accessible.
- **Never run the self-verification dev server on port 3000.** Port 3000 is reserved for the human's own manual browsing at `http://localhost:3000`. `bin/dev` defaults to `PORT=3000` and Vite defaults to `3036` (`config/vite.json`), so starting a verification server with the defaults — especially from a second worktree while another app is already running — hijacks port 3000 and the page the human has open silently flips to the app you're testing. Instead, always start the verification server on a dedicated non-3000 port pair and point the browser at it:

  ```bash
  PORT=4000 VITE_RUBY_PORT=4036 bin/dev
  ```

  Then have `agent-browser` (or any browser tool) navigate to `http://localhost:4000`, **not** `http://localhost:3000`. `bin/dev` honors `PORT` and vite-plugin-ruby honors `VITE_RUBY_PORT` (keeping Rails and Vite in agreement), so no file edits are needed. If you're verifying multiple worktrees at once, give each its own distinct pair (`4000`/`4036`, `4100`/`4136`, …) so they don't collide with each other either. Tear down the verification server when finished.

- **For new pages, new layouts, or significant UI changes, take a screenshot and evaluate your own work** — confirm styling, design, visual balance, and responsiveness (desktop + mobile widths) are executed correctly. Store these verification screenshots in `tmp/screenshots/` so they're easy to find and don't pollute the repo.

## `_build_plan/`

The `_build_plan/` folder contains the initial PRD and per-milestone prompts used to scaffold this codebase during its initial build-out phase. These files are **temporary** — they exist for documentation and guidance only. They are **not** functional: no code, configuration, or runtime logic in this codebase should import, reference, or depend on anything inside `_build_plan/`.

Do not treat `_build_plan/` as long-living documentation for the codebase. The codebase will evolve past the assumptions and decisions captured here. Once the initial milestones are complete, this folder is expected to be deleted.
