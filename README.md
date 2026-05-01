# everton-devops-shared

Reusable GitHub Actions + scripts pra monitoramento + auto-revert de projetos Vercel.

## O que tem aqui

```
.github/workflows/
  prod-monitor.yml      # reusable workflow: chamado por outros projetos
  auto-revert.yml       # standalone: dispara via repository_dispatch (webhook do Better Stack)

scripts/
  health-check.sh       # 3 tentativas com 30s entre, valida 200 + content
  vercel-revert.sh      # rollback via API Vercel (sem CLI)
  notify-telegram.sh    # alerta Telegram
```

## Como usar em outros projetos

No projeto-alvo (ex: `marketscoupons`), adicione `.github/workflows/monitor.yml`:

```yaml
name: Auto-revert on prod down
on:
  repository_dispatch:
    types: [prod-down]
jobs:
  revert:
    uses: evertonmiranda777-glitch/everton-devops-shared/.github/workflows/auto-revert.yml@main
    with:
      project_name: marketscoupons
      vercel_project_id: prj_XXXXXXXX
    secrets:
      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
      TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
      TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
```

Configure Better Stack pra disparar webhook:
- URL: `https://api.github.com/repos/evertonmiranda777-glitch/<projeto>/dispatches`
- Headers: `Authorization: Bearer <PAT>`, `Accept: application/vnd.github+json`
- Body: `{"event_type":"prod-down","client_payload":{"reason":"better-stack-down"}}`

## Fluxo

```
Better Stack ping URLs prod (30s/3min)
  ↓ 3 falhas consecutivas
Webhook -> GitHub repository_dispatch
  ↓
auto-revert.yml dispara
  ↓
Vercel API: pega último deploy READY anterior, promove
  ↓
Telegram: "marketscoupons revertido pra deploy XYZ"
```

## Camadas planejadas

- [x] Camada 3 — Auto-revert via webhook (este repo)
- [ ] Camada 1 — Pre-push lint hook (`.husky/`)
- [ ] Camada 2 — Playwright e2e on push
