---
name: frontend-project-style
description: >
  Design system e style guide configurável para projetos frontend. Use esta skill SEMPRE que
  for criar, editar ou gerar qualquer componente, página, tela, artifact, interface ou trecho de
  código frontend — React, Next.js, Angular, Vue, HTML/CSS. Também deve ser usada para qualquer
  tarefa de UI/UX, layouts, dashboards, landing pages, ou quando o usuário mencionar palavras como
  "componente", "tela", "página", "UI", "frontend", "estilização", "layout", "design".
  Se há qualquer dúvida se esta skill é relevante para uma tarefa, use-a.
---

# Frontend Project Style — Skill

Esta skill garante que todo código frontend gerado siga o design system do projeto atual.

---

## 🚦 Passo 1 — Verificar configuração

Antes de qualquer coisa, verifique se existe o arquivo `PROJECT_STYLE.md` no diretório raiz do
projeto (onde o usuário está trabalhando) ou em `~/.claude/PROJECT_STYLE.md`.

**Se o arquivo existir** → leia-o e siga as definições nele. Pule para o Passo 3.

**Se o arquivo NÃO existir** → execute o onboarding (Passo 2).

---

## 🛠️ Passo 2 — Onboarding (primeira vez)

Informe o usuário:

> "Não encontrei um `PROJECT_STYLE.md` para este projeto. Vou fazer algumas perguntas rápidas
> para configurar o design system. Você pode pular qualquer pergunta — usarei padrões modernos
> para o que não for definido."

Então colete as informações abaixo **em uma única mensagem com todas as perguntas**,
não uma de cada vez. Agrupe-as de forma clara e amigável.

### Perguntas de onboarding

```
1. PROJETO
   - Qual o nome do projeto?
   - Em uma frase, o que ele faz e para quem é?
   - Qual o tom/personalidade? (ex: profissional, descontraído, técnico,
     agressivo, minimalista, luxo, jovem, confiável...)

2. STACK
   - Qual o framework? (Next.js / React / Angular / Vue / HTML puro / outro)
   - Usa TypeScript? (sim/não)
   - Biblioteca de componentes? (Shadcn/ui / MUI / Chakra / nenhuma / outra)
   - Biblioteca de ícones? (Lucide / Heroicons / FontAwesome / outra)
   - Animações? (Framer Motion / GSAP / CSS puro / nenhuma)

3. VISUAL
   - Tem paleta de cores definida? Se sim, informe os hex das cores:
     • Primária (botões, links, destaque)
     • Background da página
     • Background de cards/painéis
     • Bordas
     • Texto principal
     • Texto secundário/muted
     • Cor de sucesso / erro / aviso (opcional)
   - Tem fontes definidas? Se sim:
     • Fonte de headings/títulos (nome + origem: Google Fonts, local, etc.)
     • Fonte de corpo/UI
   - Prefere dark mode, light mode, ou suporte a ambos?

4. LAYOUT & TOKENS
   - Qual o estilo de arredondamento?
     (nenhum/quadrado | suave/moderno | bem arredondado | totalmente circular em badges)
   - Densidade visual preferida?
     (compacto | balanceado | espaçoso/arejado)

5. COMPONENTES ESPECÍFICOS (opcional)
   - Há algum componente ou padrão de UI específico do seu domínio que devo
     conhecer? (ex: card de produto, tela de quiz, feed de posts, etc.)
```

Após receber as respostas, gere o `PROJECT_STYLE.md` usando o template do Passo 2a
e salve no diretório raiz do projeto. Confirme ao usuário onde foi salvo.

---

## 📝 Passo 2a — Template do PROJECT_STYLE.md

```markdown
# PROJECT_STYLE.md
# Design system deste projeto. Edite à vontade.
# Gerado em: [data]

## Projeto
name: [nome do projeto]
description: [descrição em uma frase]
tone: [tom/personalidade]

## Stack
framework: [Next.js 14 / React / Angular / Vue / HTML]
typescript: [sim / não]
component_library: [Shadcn/ui / MUI / nenhuma / outra]
icons: [Lucide / Heroicons / outra]
animations: [Framer Motion / CSS / nenhuma]

## Cores
primary: "#XXXXXX"
primary_hover: "#XXXXXX"
background: "#XXXXXX"
surface: "#XXXXXX"
border: "#XXXXXX"
text_primary: "#XXXXXX"
text_secondary: "#XXXXXX"
accent: "#XXXXXX"
success: "#10b981"
error: "#ef4444"
warning: "#f59e0b"

## Dark Mode
dark_mode: [light_only / dark_only / both]
# Se "both", adicione abaixo:
# dark_background: "#XXXXXX"
# dark_surface: "#XXXXXX"
# dark_border: "#XXXXXX"
# dark_text_primary: "#XXXXXX"
# dark_text_secondary: "#XXXXXX"

## Tipografia
font_heading: "[nome] — [origem: Google Fonts / local / sistema]"
font_body: "[nome] — [origem]"
font_mono: "JetBrains Mono — Google Fonts"

## Layout & Tokens
# Arredondamento: none | subtle (4-6px) | modern (8-12px) | rounded (16px+)
border_radius: modern

# Densidade: compact | balanced | spacious
density: balanced

## Componentes Específicos do Domínio
# Descreva componentes únicos do seu produto.
# Exemplo:
# - QuizCard: enunciado + alternativas A/B/C/D, estados: default/selected/correct/wrong
# - ProfileCard: avatar + nome + badge de disponibilidade + skills como tags
```

---

## ⚙️ Passo 3 — Aplicar o design system

Com o `PROJECT_STYLE.md` carregado, siga estas regras ao gerar qualquer código:

### Cores
- Use CSS variables ou tokens Tailwind com nomes semânticos — nunca hex hardcoded
- Tailwind: configure no `tailwind.config` com `primary`, `surface`, `border`, etc.
- CSS puro: use `var(--color-primary)` etc.

### Tipografia

| Token   | Tailwind   | Uso                          |
|---------|------------|------------------------------|
| xs      | text-xs    | labels, captions, badges     |
| sm      | text-sm    | body secundário, metadados   |
| base    | text-base  | body principal               |
| lg/xl   | text-lg/xl | subtítulos                   |
| 2xl–4xl | text-2xl+  | headings de seção            |
| 5xl+    | text-5xl+  | display, heroes              |

### Arredondamento por `border_radius`

| Config  | Botões      | Cards        | Badges       | Avatares     |
|---------|-------------|--------------|--------------|--------------|
| none    | rounded-none| rounded-none | rounded-none | rounded-none |
| subtle  | rounded     | rounded-md   | rounded-md   | rounded-full |
| modern  | rounded-lg  | rounded-xl   | rounded-full | rounded-full |
| rounded | rounded-xl  | rounded-2xl  | rounded-full | rounded-full |

### Densidade por `density`

| Config   | Padding cards | Gap listas | Padding botões |
|----------|---------------|------------|----------------|
| compact  | p-3           | gap-2      | px-3 py-1.5    |
| balanced | p-4 / p-6     | gap-3/4    | px-4 py-2      |
| spacious | p-6 / p-8     | gap-6      | px-6 py-3      |

### Padrões de componente

**Botão primário**
```tsx
<button className="bg-primary hover:bg-primary-hover text-white font-medium 
  transition-colors [border-radius] [padding]">
```

**Card**
```tsx
<div className="bg-surface border border-border shadow-sm hover:shadow-md 
  transition-shadow [border-radius] [padding]">
```

**Input**
```tsx
<input className="border border-border bg-background text-text-primary
  placeholder:text-text-secondary focus:ring-2 focus:ring-primary 
  focus:border-transparent [border-radius] [padding]">
```

### Regras de Qualidade
- TypeScript estrito — sem `any`
- Props destruturas no parâmetro da função
- Eventos nomeados `handleNomeDoEvento`
- Mobile-first: base mobile, depois `md:` e `lg:`
- Touch targets ≥ 44×44px
- Imagens: `next/image` (Next.js) ou `loading="lazy"` (HTML)
- Listas: `key` com ID único, nunca índice do array
- Loading: skeleton `animate-pulse` ou `Loader2 animate-spin`
- Empty state: sempre mostrar ícone + mensagem — nunca `null` silencioso
- Dark mode: usar `dark:` prefix quando `dark_mode: both`

### Anti-Patterns Proibidos
- ❌ `style={{ }}` inline — usar Tailwind
- ❌ `!important`
- ❌ IDs CSS para estilização
- ❌ Componentes com mais de 200 linhas sem quebrar em subcomponentes

---

## 🔄 Atualizar configuração

Se o usuário pedir para atualizar o design system — leia o `PROJECT_STYLE.md` atual,
aplique as mudanças e salve o arquivo. Confirme o que foi alterado.

---

## 💡 Nota para distribuição

Skill genérica e sem configuração prévia. Na primeira vez que for usada em qualquer
projeto, o onboarding coleta as informações e gera o `PROJECT_STYLE.md` automaticamente.
O arquivo gerado fica no projeto e pode ser versionado junto com o código.
