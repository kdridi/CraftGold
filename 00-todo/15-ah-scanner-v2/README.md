# 15 — AH Scanner v2

| Metadata      | Value                                                       |
|---------------|-------------------------------------------------------------|
| Phase         | Phase 4 — Données réelles                                   |
| Prerequisites | Capsule 14 — AH Scanner v1                                  |
| Type          | Semi-autonomous                                             |
| Concepts      | Pagination (50 résultats/page), throttling, `CanSendAuctionQuery()`, file d'attente, fraîcheur des données |

## Why This Capsule?

*(To be written during Phase A)*

## Objectives

1. **Paginer** les résultats (50 par page, index à partir de 0)
2. **Throttler** les requêtes (~0.3s entre les queries)
3. **File d'attente** pour scanner plusieurs items sans bloquer

## Going Further

- → Capsule 16 : Profit Analyzer v2
