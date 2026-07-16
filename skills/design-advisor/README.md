# Design Advisor Skill

Claude Code skill que fornece recomendacoes de UI/UX especificas por industria em segundos. 550+ regras de design, 50 paletas de cores, 30+ combinacoes tipograficas e exemplos reais de componentes.

## Como usar

No Claude Code, digite:

```
/design-advisor landing page for a SaaS project management tool
```

```
/design-advisor dashboard for a fintech portfolio tracker
```

```
/design-advisor homepage for a local restaurant
```

## O que voce recebe

Cada resposta inclui um design brief estruturado:

1. **Style Direction** — Estilo visual recomendado e justificativa
2. **Color Palette** — 6 hex codes com roles (primary, secondary, CTA, background, text, border)
3. **Typography** — Font pairing com link do Google Fonts pronto para usar
4. **Page Structure** — Ordem das secoes e posicionamento de CTAs
5. **Key Effects** — Animacoes e interacoes recomendadas
6. **Anti-Patterns** — O que evitar, com nivel de severidade
7. **21st.dev Examples** — Componentes reais (se MCP configurado)
8. **Next Step** — Comando `/ui` para gerar o componente

## Banco de dados

| Arquivo | Entradas | Conteudo |
|---|---|---|
| `data/colors.csv` | 50 | Paletas por industria com 6 roles de cor |
| `data/typography.csv` | 30+ | Font pairings com mood, use cases e Google Fonts URLs |
| `data/ui-reasoning.csv` | 40 | Padroes de design e anti-patterns por industria |
| `data/styles.csv` | 15 | Estilos visuais com implementacao CSS |
| `data/landing.csv` | 15 | Layouts de landing page com estrategias de CTA |
| `data/ux-guidelines.csv` | 40 | Regras UX do/don't com codigo e severidade |
| `data/charts.csv` | 20 | Recomendacoes de visualizacao por tipo de dado |

## Instalacao

### Via symlink (recomendado)

```bash
# Clone o repositorio
git clone https://github.com/FelipeOFF/design-advisor-skill.git ~/.agents/skills/design-advisor

# Crie o symlink
ln -sf ../../.agents/skills/design-advisor ~/.claude/skills/design-advisor
```

### Manual

Copie a pasta para `~/.claude/skills/design-advisor/`.

Reinicie o Claude Code para carregar o skill.

## Customizacao

### Adicionar uma industria

Adicione uma nova linha em cada CSV relevante:

- `colors.csv` — Pesquise as 5 maiores empresas do setor e extraia o padrao de cores
- `typography.csv` — Veja quais fontes os lideres da industria usam
- `ui-reasoning.csv` — Identifique erros de design comuns no setor

### Ajustar recomendacoes

Edite a linha da sua industria nos CSVs ou adicione overrides de marca no SKILL.md.

## Integracao com 21st.dev (opcional)

Para receber exemplos de componentes reais, configure o MCP do 21st.dev:

```json
{
  "mcpServers": {
    "magic": {
      "command": "npx",
      "args": ["-y", "@21st-dev/magic@latest"],
      "env": {
        "TWENTY_FIRST_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

Sem o MCP, o skill funciona normalmente — apenas sem exemplos visuais do 21st.dev.

## Creditos

Baseado no [Design Advisor Skill Guide](https://nustimulus.com) por Kyle Whitrow / Nu Stimulus.
