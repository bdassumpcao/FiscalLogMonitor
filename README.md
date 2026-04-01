# FiscalLogMonitor

Projeto para monitorar logs do Fiscal Facil, salvar em Firebird local e expor analises via API Horse + dashboard React.

## Estrutura
- Backend Delphi 13 + Horse + Firebird: `Backend/`
- Frontend React (dashboard): `Frontend/`
- Documentacao: `Docs/`

## Configuracao inicial
1. Ajuste `Backend/appsettings.json` se precisar alterar pasta de logs.
2. Crie o banco Firebird e execute `Backend/database/scripts/001_init.sql`.
3. Se o banco ja existir, execute tambem `Backend/database/scripts/002_add_metrics_columns.sql`.
4. Compile e rode `Backend/FiscalLogMonitor.dpr` no Delphi 13.
5. Configure o Nginx conforme `Docs/NGINX.md`.

## Endpoints
- `GET /ServidorLog/health`
- `GET /ServidorLog/logs/summary`
- `GET /ServidorLog/logs/errors`
- `GET /ServidorLog/logs/metrics/daily`
- `GET /ServidorLog/logs/metrics/session`
- `GET /ServidorLog/logs/metrics/callback`
- `GET /ServidorLog/logs/recommendations`
- `GET /ServidorLog/logs/details?filter=error|day|session|callback&value=...`
- `GET /ServidorLog/logs/details/:id`

## Frontend (dashboard)
- Carregamento lazy por aba: inicia com resumo + aba aberta e so busca as outras ao clicar.
- Botao `Refresh` em cada aba para recarregar somente o dataset da aba atual.
- Clique em linha das listas (Erros/Diario/Sessao/Callback) abre modal de sublista.
- Modal de sublista com filtros rapidos por severidade e busca textual.
- Clique no item da sublista abre segundo modal com toggle entre `stackTrace` e `rawText`.
- Destaque visual de linhas com referencia a unit Delphi (`*.pas`).

## Como executar o frontend
1. Entre em `Frontend/`.
2. Instale dependencias com `yarn install`.
3. Rode com `yarn dev`.
4. Ajuste `Frontend/src/services/api.ts` se o IP/porta da API mudar.

## Observacao sobre frontend
O servidor de logs nao precisa de Node/NPM para o backend funcionar.
O frontend React pode ser compilado em outra maquina e publicado como estatico.
