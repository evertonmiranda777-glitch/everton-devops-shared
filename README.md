# everton-devops-shared

Reusable GitHub Actions + scripts pra **auto-revert de prod** quando o site cai.
Compartilhado entre projetos do Everton (marketscoupons, Oryk, futuros).

## ⚠️ AVISO IMPORTANTE — Arquitetura final adotada (2026-05-01)

**O que NÃO usamos** (descartado):
- ❌ **Better Stack** — testamos, free tier não tem outgoing webhook direto, só via Zapier. Mais um hop, dependência de conta externa, fricção de signup.
- ❌ **Zapier** — descartado junto. Cada novo projeto precisaria criar Zap próprio + manter conexão Better Stack→Zapier funcionando. Frágil.
- ❌ **GitHub Actions cron** — estouraria free tier (2000min/mês) com cron de 5min em repos privados.

**O que usamos** (single source of truth):

```
Supabase pg_cron (5min)
  ↓ chama edge function `health-monitor`
  ↓ edge function pinga 3 URLs do projeto
  ↓ guarda contador consecutivo em tabela `health_state`
  ↓ se 3 ciclos consecutivos falharem (~15min downtime confirmado)
  ↓ POST repository_dispatch no GitHub (event_type=prod-down)
GitHub Action `auto-revert.yml` (este repo, reusable)
  ↓ confirma que site continua down (3 attempts/30s gap)
  ↓ promove deploy READY anterior via Vercel API
  ↓ alerta Telegram
```

Zero contas externas. Tudo no que já temos (Supabase free + GitHub free + Vercel free).

## O que tem aqui

```
.github/workflows/
  auto-revert.yml       # reusable workflow chamado pelo wrapper de cada projeto

scripts/
  health-check.sh       # 3 tentativas com 30s gap, valida 200 + content (usado pelo workflow pra dupla-confirmar antes de reverter)
  vercel-revert.sh      # rollback via Vercel API (sem CLI)
  notify-telegram.sh    # alerta Telegram bot
```

## Como adicionar a outro projeto (ex: Oryk)

### 1. Criar wrapper no projeto-alvo
Em `<projeto>/.github/workflows/auto-revert.yml`:

```yaml
name: Auto-revert on prod down
on:
  repository_dispatch:
    types: [prod-down]
  workflow_dispatch:
jobs:
  revert:
    uses: evertonmiranda777-glitch/everton-devops-shared/.github/workflows/auto-revert.yml@main
    with:
      project_name: <projeto>
      vercel_project_id: prj_XXXXXXXX  # pegar via: curl -H "Authorization: Bearer $VERCEL_TOKEN" "https://api.vercel.com/v9/projects?search=<nome>"
      health_urls: |
        https://<projeto>.com|<keyword pra confirmar render>
        https://<projeto>.com/critical-page|<outra keyword>
    secrets:
      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
      TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
      TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
```

### 2. Adicionar secrets no repo do projeto

```bash
# VERCEL_TOKEN ja deve estar no ~/.bashrc do dev
gh secret set VERCEL_TOKEN --repo evertonmiranda777-glitch/<projeto>
gh secret set TELEGRAM_BOT_TOKEN --repo evertonmiranda777-glitch/<projeto>
gh secret set TELEGRAM_CHAT_ID --repo evertonmiranda777-glitch/<projeto>
```

### 3. Adicionar URL ao health-monitor do Supabase

No projeto Supabase, edita `supabase/functions/health-monitor/index.ts` (existe no `marketscoupons` — pode replicar a função em outro projeto Supabase ou centralizar).

Adiciona a URL ao array `TARGETS` e re-deploy:
```bash
SUPABASE_ACCESS_TOKEN=<token> npx supabase functions deploy health-monitor --project-ref <ref>
```

### 4. Adicionar secret GITHUB_DISPATCH_TOKEN no Supabase
A edge function precisa de um GitHub PAT pra POST `repository_dispatch`:
```bash
SUPABASE_ACCESS_TOKEN=<token> npx supabase secrets set \
  GITHUB_DISPATCH_TOKEN="$(gh auth token)" \
  GITHUB_DISPATCH_REPO="evertonmiranda777-glitch/<projeto>" \
  --project-ref <ref>
```

### 5. Schedule pg_cron (uma vez por projeto Supabase)

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
SELECT cron.schedule('health-monitor-5min', '*/5 * * * *', $$
  SELECT net.http_post(
    url := 'https://<ref>.supabase.co/functions/v1/health-monitor',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer <SERVICE_ROLE_KEY>'
    )
  )
$$);
```

## Implementação de referência (marketscoupons)

- Edge function: `marketscoupons-repo/supabase/functions/health-monitor/index.ts` — pinga homepage, /apex, /app.js
- Tabela `health_state`: `url text PRIMARY KEY, fail_count int, last_check_at timestamptz, last_status text` (RLS service_role only)
- pg_cron job ID 19, schedule `*/5 * * * *`
- Threshold: 3 ciclos consecutivos = ~15min downtime confirmado antes de reverter

## Camadas planejadas (futuro)

- [x] **Camada 3** — Auto-revert (este repo)
- [ ] **Camada 1** — Pre-push lint hook (.husky/) pra bloquear erros bobos antes de push
- [ ] **Camada 2** — Playwright e2e on PR pra catch bugs visuais antes do merge

## Por que só Camada 3 por enquanto

Camada 3 é a rede de segurança final. Mesmo que Camadas 1 e 2 falhem em pegar o bug, este sistema reverte automaticamente. ROI máximo: 95% de proteção com 1 setup só.
