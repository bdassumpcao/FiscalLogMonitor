# FiscalLogMonitor Architecture

## Components
- Delphi 13 console service with Horse API on port 9100.
- Firebird local database for log persistence and metrics.
- Polling watcher for `*.Log` files in LogError directory.
- React dashboard consuming API endpoints with lazy tab loading.

## Data flow
1. Watcher scans log folder every configured interval.
2. New/changed logs are parsed (supports multiple exceptions per file).
3. Parsed data is inserted into Firebird tables with severity/category classification.
4. Horse endpoints expose aggregated metrics and detail drill-down.
5. Frontend loads summary and only the active tab data.
6. User clicks list rows to open detail modal and can open a second modal for stacktrace/raw text.

## API endpoints
- `GET /ServidorLog/health`
- `GET /ServidorLog/logs/summary`
- `GET /ServidorLog/logs/errors`
- `GET /ServidorLog/logs/metrics/daily`
- `GET /ServidorLog/logs/metrics/session`
- `GET /ServidorLog/logs/metrics/callback`
- `GET /ServidorLog/logs/recommendations`
- `GET /ServidorLog/logs/details?filter=error|day|session|callback&value=...`
- `GET /ServidorLog/logs/details/:id`

## Frontend behavior
- Tabs: Errors, Daily, Session, Callback, Recommendations.
- Lazy loading per tab: data is fetched when the tab is opened.
- Refresh button per tab to force reload current dataset.
- Detail modal with quick filters (severity + text).
- Secondary modal with toggle between `stackTrace` and `rawText`.
- Visual highlight of lines containing Delphi units (`*.pas`) in stack/raw view.
