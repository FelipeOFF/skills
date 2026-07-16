# Webhooks com Stripe CLI (criar, testar, manter)

## O Stripe CLI suporta isso?
Sim. O CLI suporta:
- escutar/encaminhar eventos (`stripe listen`)
- listar/inspecionar eventos (`stripe events ...`)
- reenviar eventos (`stripe events resend`)
- disparar eventos de teste (`stripe trigger`)
- trabalhar com endpoints cadastrados no Dashboard (`--load-from-webhooks-api`)

## Fluxo recomendado de manutenção

### 1) Desenvolvimento local
```bash
stripe listen --forward-to localhost:4242/webhook
```
- copie o `whsec_...` gerado e use no app local.
- mantenha esse secret por ambiente (dev/staging/prod separados).

### 2) Filtro de eventos (evitar ruído)
```bash
stripe listen \
  --events checkout.session.completed,invoice.paid,invoice.payment_failed,customer.subscription.updated,customer.subscription.deleted \
  --forward-to localhost:4242/webhook
```

### 3) Reproduzir cenários
```bash
stripe trigger checkout.session.completed
stripe trigger invoice.paid
stripe trigger customer.subscription.updated
```

### 4) Diagnóstico de falhas
```bash
stripe logs tail
stripe events list --limit 20
stripe events retrieve evt_xxx
stripe events resend evt_xxx --webhook-endpoint=we_xxx
```

## Boas práticas de operação
- implementar idempotência por `event.id`
- validar assinatura sempre (header `Stripe-Signature`)
- aplicar timeout curto + retry controlado no seu consumer
- usar dead-letter/reprocessamento para erros transitórios
- monitorar taxa de falhas por tipo de evento

## Rotina de segurança
- nunca commitar `whsec_*`
- rotacionar secret ao suspeitar vazamento
- não usar o mesmo endpoint para dev/prod
