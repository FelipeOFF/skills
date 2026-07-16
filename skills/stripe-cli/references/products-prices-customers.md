# Produtos, Preços e Clientes via Stripe CLI

## O Stripe CLI suporta CRUD básico?
Sim. Você pode criar, listar, atualizar e (em alguns recursos) desativar/deletar.

---

## 1) Produtos

### Criar
```bash
stripe products create \
  --name="Plano Professional" \
  --description="Plano profissional mensal"
```

### Listar
```bash
stripe products list --limit 20
```

### Atualizar
```bash
stripe products update prod_xxx --name="Plano Professional v2"
```

### Arquivar (recomendado em vez de apagar)
```bash
stripe products update prod_xxx --active=false
```

---

## 2) Preços (Prices)

> Regra importante: em Stripe, preço normalmente é **imutável** para valores-chave.
> Para mudar valor/intervalo, crie um novo `price` e migre subscriptions.

### Criar preço mensal
```bash
stripe prices create \
  --unit-amount=14990 \
  --currency=brl \
  --recurring[interval]=month \
  --product=prod_xxx
```

### Criar preço anual
```bash
stripe prices create \
  --unit-amount=149900 \
  --currency=brl \
  --recurring[interval]=year \
  --product=prod_xxx
```

### Listar preços de um produto
```bash
stripe prices list --product=prod_xxx --limit 20
```

### Desativar preço antigo
```bash
stripe prices update price_xxx --active=false
```

---

## 3) Clientes

### Criar cliente
```bash
stripe customers create --name="Cliente Teste" --email="cliente@exemplo.com"
```

### Listar
```bash
stripe customers list --limit 20
```

### Buscar por email
```bash
stripe customers search --query="email:'cliente@exemplo.com'"
```

### Atualizar metadata
```bash
stripe customers update cus_xxx -d "metadata[tenant_id]=abc123"
```

### Remover (delete)
```bash
stripe customers delete cus_xxx
```

---

## 4) Troca de preço em assinaturas

### Passo 1: descobrir subscription item id
```bash
stripe subscriptions retrieve sub_xxx
```

### Passo 2: atualizar preço da assinatura
```bash
stripe subscriptions update sub_xxx \
  -d "items[0][id]=si_xxx" \
  -d "items[0][price]=price_new" \
  -d proration_behavior=always_invoice
```

### Preview financeiro antes de aplicar
```bash
stripe invoices create_preview \
  -d customer=cus_xxx \
  -d subscription=sub_xxx \
  -d "subscription_details[items][0][id]=si_xxx" \
  -d "subscription_details[items][0][price]=price_new"
```

---

## Notas de segurança e governança
- use somente `sk_test_*` em desenvolvimento
- nunca reaproveite IDs de produção em sandbox
- audite mudanças de preço (quem mudou, quando, motivo)
- prefira desativar recursos em vez de apagar imediatamente
